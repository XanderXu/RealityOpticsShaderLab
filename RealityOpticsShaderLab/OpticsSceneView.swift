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

            // Turntable rotation: keeps view/normal geometry sweeping so the
            // angular color changes stay visible without any head motion.
            // Paused via the toolbar button for closer inspection.
            var spin: Float = 0
            let lean = simd_quatf(angle: -0.7, axis: SIMD3(1, 0, 0))
            _ = content.subscribe(to: SceneEvents.Update.self) { event in
                guard model.isAnimating else { return }
                spin += Float(event.deltaTime)
                if let bubble = root.findEntity(named: "Bubble") {
                    bubble.orientation = simd_quatf(angle: spin * 0.25, axis: SIMD3(0, 1, 0))
                }
                if let cd = root.findEntity(named: "CompactDisc") {
                    cd.orientation = simd_quatf(angle: spin * 0.4, axis: SIMD3(0, 1, 0)) * lean
                }
                // Placeholder objects turn gently so their silhouette reads as 3D.
                if let ph = root.findEntity(named: "Placeholder") {
                    ph.orientation = simd_quatf(angle: spin * 0.15, axis: SIMD3(0, 1, 0))
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
