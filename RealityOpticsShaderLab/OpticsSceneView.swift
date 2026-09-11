import SwiftUI
import RealityKit

struct OpticsSceneView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
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

                // Turntable rotation for whichever effect object is present.
                // The morpho wing oscillates instead of spinning: grazing angles
                // wash the structural blue out with white Fresnel reflection.
                // Paused via the toolbar button for closer inspection.
                var spin: Float = 0
                let lean = simd_quatf(angle: -0.7, axis: SIMD3(1, 0, 0))
                // The photoelastic ruler leans while spinning: a flat slab spinning
                // about its own normal can never change |N·V| for a fixed camera,
                // but a leaning slab's normal precesses, so the retardance path
                // length 1/cos(θ) — and the interference colors — sweep as it turns.
                let rulerLean = simd_quatf(angle: -0.45, axis: SIMD3(1, 0, 0))
                _ = content.subscribe(to: SceneEvents.Update.self) { event in
                    if model.isAnimating { spin += Float(event.deltaTime) }
                    for child in root.children {
                        if child.name == "CompactDisc" {
                            child.orientation = simd_quatf(angle: spin * 0.4, axis: SIMD3(0, 1, 0)) * lean
                        } else if child.name == "BirefrRuler" {
                            child.orientation = simd_quatf(angle: spin * 0.25, axis: SIMD3(0, 1, 0)) * rulerLean
                        } else if child.name == "MorphoWing" || child.name == "DragonflyWing" {
                            // Wings oscillate instead of spinning: a spinning plane
                            // goes edge-on to the camera half the time.
                            let sway = sin(spin * 0.5) * 0.6
                            child.orientation = simd_quatf(angle: sway, axis: SIMD3(0, 1, 0))
                        } else {
                            child.orientation = simd_quatf(angle: spin * 0.25, axis: SIMD3(0, 1, 0))
                        }
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
                let scale = max(0.01, min(bounds.extents.x, bounds.extents.y) * 0.84 / previewDiameter)
                root.scale = SIMD3(repeating: scale)
                // A window's proposed depth is not the preview's display plane.
                // Keep z at the window plane instead of moving toward the viewer.
                // RealityView's origin already follows the center of its 2D frame.
                root.position = SIMD3(0, 0.02 * scale, 0)
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
        }
        .onChange(of: model.materialRevision) { _, _ in
            model.syncSceneObjects()
        }
        .onChange(of: model.selectedEffect) { _, _ in
            model.syncSceneObjects()
        }
    }

    /// Conservative diameters in meters, including geometry offsets and rotation.
    private var previewDiameter: Float {
        switch model.selectedEffect {
        case .grating: return 0.56
        case .birefringence: return 0.44
        case .morpho, .feather, .dragonfly: return 0.44
        case .beetle, .scarab: return 0.44
        case .hologram, .lcd, .newton: return 0.40
        default: return 0.30
        }
    }
}
