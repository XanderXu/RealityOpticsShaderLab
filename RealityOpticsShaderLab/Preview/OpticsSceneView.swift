import SwiftUI
import RealityKit

struct OpticsSceneView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        #if os(iOS)
        MobileOpticsSceneView()
        #else
        GeometryReader3D { geometry in
            RealityView { content in
                // This closure must not READ any @Observable state: SwiftUI re-runs it
                // on observed changes, which would rebuild/duplicate the scene. Object
                // creation is driven by AppModel.syncSceneObjects() instead.
                let root = Entity()
                root.name = "OpticsRoot"
                content.add(root)
                model.sceneRoot = root

                // Catch materials that were built before the scene existed.
                Task { @MainActor in
                    model.syncSceneObjects()
                }

                // One clock keeps all four material samples in sync.
                var spin: Float = 0
                var lastObject: ObjectIdentifier?
                _ = content.subscribe(to: SceneEvents.Update.self) { event in
                    guard let object = root.children.first else { lastObject = nil; return }
                    let identity = ObjectIdentifier(object)
                    guard model.isAnimating || lastObject != identity else { return }
                    lastObject = identity
                    if model.isAnimating {
                        // Bound the clock to one full turn to retain precision over long sessions.
                        spin = (spin + Float(event.deltaTime)).truncatingRemainder(dividingBy: 8 * .pi)
                    }
                    for child in root.children {
                        guard let shape = PreviewShape(rawValue: child.name) else { continue }
                        child.orientation = shape.orientation(at: spin)
                    }
                }
            } update: { content in
                // Refit after the asynchronously loaded geometry becomes available.
                // Reading the revision here also refreshes the fit after hot updates.
                _ = model.materialRevision
                guard let root = content.entities.first else { return }
                let bounds = content.convert(geometry.frame(in: .local), from: .local, to: .scene)
                // Fit the entire rotational envelope, not the current orientation.
                // This keeps wide discs and wings clear of both inspector panels.
                let size = PreviewLayout.gridSize
                // Leave room for the perspective expansion of geometry in front
                // of the window, so the lower disc stays clear of the controls.
                let scale = max(0.01, min(bounds.extents.x / size.x, bounds.extents.y / size.y) * 0.88)
                root.scale = SIMD3(repeating: scale)
                // A window's proposed depth is not the preview's display plane.
                // Keep z at the window plane instead of moving toward the viewer.
                // RealityView's origin already follows the center of its 2D frame.
                root.position = .zero
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
        }
        .onChange(of: model.materialRevision) { _, _ in
            model.syncSceneObjects()
        }
        .onChange(of: model.selectedEffect) { _, _ in
            model.syncSceneObjects()
        }
        #endif
    }
}
