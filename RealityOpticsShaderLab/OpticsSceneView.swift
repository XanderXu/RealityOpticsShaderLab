import SwiftUI
import RealityKit

struct OpticsSceneView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
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
                guard model.isAnimating else { return }
                spin += Float(event.deltaTime)
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
        }
        .onChange(of: model.materialRevision) { _, _ in
            model.syncSceneObjects()
        }
        .onChange(of: model.selectedEffect) { _, _ in
            model.syncSceneObjects()
        }
    }
}
