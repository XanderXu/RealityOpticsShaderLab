#if os(iOS)
import SwiftUI
import RealityKit
import ARKit
import Combine

/// One persistent renderer for virtual and AR preview; switching drawers never rebuilds it.
struct MobileOpticsSceneView: UIViewRepresentable {
    @Environment(AppModel.self) private var model
    @Environment(MobilePreviewState.self) private var preview
    @Environment(\.scenePhase) private var scenePhase

    func makeCoordinator() -> Coordinator { Coordinator(model: model, preview: preview) }

    func makeUIView(context: Context) -> ARView {
        let view = ARView(frame: .zero, cameraMode: .nonAR, automaticallyConfigureSession: false)
        context.coordinator.attach(to: view)
        return view
    }

    func updateUIView(_ view: ARView, context: Context) {
        _ = model.materialRevision
        _ = model.selectedEffect
        context.coordinator.update(active: scenePhase == .active, ar: preview.isAR,
                                   reset: preview.resetRevision)
        model.syncSceneObjects()
    }

    static func dismantleUIView(_ view: ARView, coordinator: Coordinator) { coordinator.stop() }

    @MainActor final class Coordinator: NSObject, ARSessionDelegate {
        let model: AppModel
        let preview: MobilePreviewState
        weak var view: ARView?
        let root = Entity()
        let anchor = AnchorEntity(world: .zero)
        let camera = PerspectiveCamera()
        // ARView.Scene.subscribe returns a Cancellable: retain it for the scene lifetime.
        private var subscription: (any Cancellable)?
        private var active = false
        private var ar = false
        private var placed = false
        private var lastReset = 0
        private var lastSize = CGSize.zero
        private var orbit = SIMD2<Float>.zero
        private var orbitStart = SIMD2<Float>.zero
        private var zoom: Float = 1
        private var zoomStart: Float = 1
        private var spin: Float = 0
        private var previousSamples: [ObjectIdentifier] = []
        private var wideLayout = false
        private var statusElapsed: Double = 0

        init(model: AppModel, preview: MobilePreviewState) {
            self.model = model; self.preview = preview
        }

        func attach(to view: ARView) {
            self.view = view
            root.name = "OpticsRoot"
            anchor.addChild(root)
            camera.name = "PreviewCamera"
            camera.camera = PerspectiveCameraComponent(near: 0.01, far: 20,
                fieldOfViewInDegrees: 42, fieldOfViewOrientation: .vertical)
            anchor.addChild(camera)
            view.scene.addAnchor(anchor)
            view.environment.background = .color(.secondarySystemGroupedBackground)
            view.renderOptions.insert(.disableMotionBlur)
            view.renderOptions.insert(.disableDepthOfField)
            model.sceneRoot = root
            view.session.delegate = self
            view.session.delegateQueue = .main
            subscription = view.scene.subscribe(to: SceneEvents.Update.self) { [weak self] event in
                self?.tick(delta: event.deltaTime)
            }
            let pan = UIPanGestureRecognizer(target: self, action: #selector(drag(_:)))
            let pinch = UIPinchGestureRecognizer(target: self, action: #selector(pinch(_:)))
            let tap = UITapGestureRecognizer(target: self, action: #selector(place(_:)))
            let doubleTap = UITapGestureRecognizer(target: self, action: #selector(resetGesture))
            doubleTap.numberOfTapsRequired = 2
            tap.require(toFail: doubleTap)
            [pan, pinch, tap, doubleTap].forEach { view.addGestureRecognizer($0) }
        }

        func update(active: Bool, ar: Bool, reset: Int) {
            guard let view else { return }
            let modeChanged = self.ar != ar
            let becameActive = !self.active && active
            let becameInactive = self.active && !active
            self.active = active
            self.ar = ar
            if modeChanged {
                view.session.pause()
                placed = false
                orbit = .zero; zoom = 1
                root.transform = .identity
                if ar {
                    camera.removeFromParent()
                    view.cameraMode = .ar
                    view.environment.background = .cameraFeed()
                    root.isEnabled = false
                } else {
                    view.cameraMode = .nonAR
                    anchor.addChild(camera)
                    root.isEnabled = true
                    view.environment.background = .color(.secondarySystemGroupedBackground)
                    fitCamera()
                }
                layoutSamples()
                fitCamera()
            }
            if ar && active && (modeChanged || becameActive) { runSession(reset: modeChanged) }
            if becameInactive { view.session.pause() }
            if lastReset != reset { lastReset = reset; resetView() }
        }

        private func runSession(reset: Bool) {
            guard ARWorldTrackingConfiguration.isSupported else { return }
            let configuration = ARWorldTrackingConfiguration()
            configuration.planeDetection = [.horizontal, .vertical]
            configuration.isLightEstimationEnabled = false
            configuration.environmentTexturing = .none
            view?.session.run(configuration, options: reset ? [.resetTracking, .removeExistingAnchors] : [])
        }

        private func tick(delta: Double) {
            guard active, let view else { return }
            if !ar && view.bounds.size != lastSize {
                lastSize = view.bounds.size; layoutSamples(); fitCamera()
            }
            let samples = root.children.map { ObjectIdentifier($0) }
            if samples != previousSamples { layoutSamples() }
            if model.isAnimating || samples != previousSamples {
                previousSamples = samples
                if model.isAnimating { spin = (spin + Float(min(delta, 0.1))).truncatingRemainder(dividingBy: 8 * .pi) }
                for child in root.children {
                    if let shape = PreviewShape(rawValue: child.name) { child.orientation = shape.orientation(at: spin) }
                }
            }
            guard ar, let frame = view.session.currentFrame else { return }
            if !placed, case .normal = frame.camera.trackingState { placeBoard(at: nil) }
            statusElapsed += delta
            if statusElapsed >= 0.25 {
                statusElapsed = 0
                let message: String
                switch frame.camera.trackingState {
                case .normal: message = "轻点画面放置模型"
                case .limited: message = "请缓慢移动手机，正在恢复跟踪…"
                case .notAvailable: message = "AR 跟踪暂不可用"
                }
                if preview.message != message { preview.message = message }
            }
        }

        private func fitCamera() {
            guard !ar, let view, view.bounds.height > 0 else { return }
            let aspect = Float(view.bounds.width / view.bounds.height)
            let direction = SIMD3<Float>(sin(orbit.x) * cos(orbit.y), sin(orbit.y), cos(orbit.x) * cos(orbit.y))
            let right = SIMD3<Float>(cos(orbit.x), 0, -sin(orbit.x))
            let up = simd_cross(direction, right)
            let tangentY = tan(Float.pi * 42 / 360)
            let tangentX = tangentY * max(aspect, 0.1)
            // Fit each rotation sphere against the perspective frustum planes.
            // Unlike the old enclosing cube, this doesn't reserve empty corners
            // and excess depth. Refit only on resize, orbit, zoom or mode change.
            let inverseSinX = sqrt(1 + 1 / (tangentX * tangentX))
            let inverseSinY = sqrt(1 + 1 / (tangentY * tangentY))
            var fitted: Float = 0
            for shape in PreviewShape.allCases {
                let center = PreviewLayout.position(for: shape, wide: wideLayout)
                let horizontal = abs(simd_dot(center, right)) / tangentX + shape.rotationRadius * inverseSinX
                let vertical = abs(simd_dot(center, up)) / tangentY + shape.rotationRadius * inverseSinY
                fitted = max(fitted, simd_dot(center, direction) + max(horizontal, vertical))
            }
            let distance = fitted * 1.02 / zoom
            camera.look(at: .zero, from: direction * distance, relativeTo: nil)
        }

        private func layoutSamples() {
            wideLayout = !ar && (view?.bounds.width ?? 0) > (view?.bounds.height ?? 1) * 1.8
            for shape in PreviewShape.allCases {
                guard let sample = root.children.first(where: { $0.name == shape.rawValue }) else { continue }
                sample.position = PreviewLayout.position(for: shape, wide: wideLayout)
            }
        }

        @objc private func drag(_ gesture: UIPanGestureRecognizer) {
            guard !ar else { return }
            if gesture.state == .began { orbitStart = orbit }
            let movement = gesture.translation(in: view)
            orbit = SIMD2(orbitStart.x - Float(movement.x) * 0.008,
                          min(1.35, max(-1.35, orbitStart.y + Float(movement.y) * 0.008)))
            if gesture.state == .ended { orbit.x = orbit.x.truncatingRemainder(dividingBy: 2 * .pi) }
            fitCamera()
        }
        @objc private func pinch(_ gesture: UIPinchGestureRecognizer) {
            if gesture.state == .began { zoomStart = zoom }
            zoom = min(1.6, max(0.65, zoomStart * Float(gesture.scale)))
            if ar { root.scale = SIMD3(repeating: 0.6 * zoom) } else { fitCamera() }
        }
        @objc private func place(_ gesture: UITapGestureRecognizer) {
            guard ar, let view else { return }
            let hit = view.raycast(from: gesture.location(in: view), allowing: .estimatedPlane, alignment: .any).first
            placeBoard(at: hit?.worldTransform)
        }
        private func placeBoard(at hit: simd_float4x4?) {
            guard let frame = view?.session.currentFrame else { return }
            let transform = frame.camera.transform
            let position = hit?.columns.3 ?? transform * SIMD4<Float>(0, 0, -0.8, 1)
            root.position = SIMD3(position.x, position.y, position.z)
            // Keep the lower pair above a horizontal surface instead of placing
            // the board's center on the tabletop and burying half the samples.
            if let hit, abs(hit.columns.1.y) > 0.75 { root.position.y += 0.21 * zoom }
            root.orientation = simd_quatf(transform)
            root.scale = SIMD3(repeating: 0.6 * zoom)
            root.isEnabled = true
            placed = true
        }
        @objc private func resetGesture() { resetView() }
        private func resetView() {
            orbit = .zero; zoom = 1
            if ar { placeBoard(at: nil) } else { fitCamera() }
        }
        func stop() {
            subscription?.cancel(); subscription = nil
            view?.session.pause(); view?.session.delegate = nil
            if model.sceneRoot === root { model.sceneRoot = nil }
        }
        nonisolated func session(_ session: ARSession, didFailWithError error: Error) {
            let message = error.localizedDescription
            Task { @MainActor [weak self] in
                self?.preview.useVirtual()
                self?.preview.message = "AR 已停止：\(message)"
            }
        }
        nonisolated func sessionWasInterrupted(_ session: ARSession) {
            Task { @MainActor [weak self] in self?.preview.message = "AR 已暂停，返回应用后恢复" }
        }
        nonisolated func sessionInterruptionEnded(_ session: ARSession) {
            Task { @MainActor [weak self] in
                guard let self, self.ar, self.active else { return }
                self.placed = false; self.root.isEnabled = false
                self.runSession(reset: true)
            }
        }
    }
}
#endif
