import RealityKit

@MainActor
final class OpticsMeshes {
    private lazy var sphere = MeshResource.generateSphere(radius: 0.11)
    private lazy var plane = MeshResource.generatePlane(width: 1, height: 1)
    private lazy var ruler = MeshResource.generateBox(width: 0.36, height: 0.02, depth: 0.07)
    private var disc: MeshResource?

    func makeEntity(for effect: OpticsEffect, material: ShaderGraphMaterial) throws -> ModelEntity {
        let mesh: MeshResource
        var scale = SIMD3<Float>(repeating: 1)
        var position = SIMD3<Float>(0, -0.02, 0)
        switch effect {
        case .grating:
            if disc == nil { disc = try DiscMesh.make(innerRadius: 0.035, outerRadius: 0.22, slope: 0.20) }
            mesh = disc!
            position.y = -0.06
        case .birefringence:
            mesh = ruler
            position.y = -0.03
        case .morpho, .feather:
            mesh = plane
            scale = SIMD3(0.34, 0.2, 1)
            position.z = -0.02
        case .dragonfly:
            mesh = plane
            scale = SIMD3(0.32, 0.2, 1)
        case .hologram:
            mesh = plane
            scale = SIMD3(0.28, 0.16, 1)
        case .lcd:
            mesh = plane
            scale = SIMD3(0.3, 0.22, 1)
        case .newton:
            mesh = plane
            scale = SIMD3(0.26, 0.26, 1)
        case .beetle, .scarab:
            mesh = sphere
            scale = SIMD3(1.15, 0.8, 1.5) * (0.12 / 0.11)
        case .pearl:
            mesh = sphere
            scale = SIMD3(repeating: 0.1 / 0.11)
        default:
            mesh = sphere
        }
        let entity = ModelEntity(mesh: mesh, materials: [material])
        entity.scale = scale
        entity.position = position
        return entity
    }
}
