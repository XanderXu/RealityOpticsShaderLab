import RealityKit

@MainActor
final class OpticsMeshes {
    private lazy var sphere = MeshResource.generateSphere(radius: 0.12)
    private lazy var plane = MeshResource.generatePlane(width: 0.24, height: 0.20)
    private lazy var ruler = MeshResource.generateBox(width: 0.27, height: 0.095, depth: 0.014)
    private var disc: MeshResource?

    func makeEntity(for shape: PreviewShape, material: ShaderGraphMaterial) throws -> ModelEntity {
        let mesh: MeshResource
        switch shape {
        case .disc:
            if disc == nil { disc = try DiscMesh.make(innerRadius: 0.02, outerRadius: 0.12, slope: 0.20) }
            mesh = disc!
        case .ruler:
            mesh = ruler
        case .plane:
            mesh = plane
        case .sphere:
            mesh = sphere
        }
        let entity = ModelEntity(mesh: mesh, materials: [material])
        entity.name = shape.rawValue
        entity.orientation = shape.orientation(at: 0)
        return entity
    }
}
