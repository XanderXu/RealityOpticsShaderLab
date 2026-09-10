import RealityKit
import simd

/// A slightly conical disc with radial UVs. The outward-tilting normals let the
/// shader graph recover the radial direction from the normal alone (no position
/// node needed), and mimic how a real CD's curvature sweeps reflections across
/// its surface. UV: u = angle/2pi (groove direction), v = normalized radius.
enum DiscMesh {

    static func make(
        innerRadius: Float = 0.05,
        outerRadius: Float = 0.30,
        slope: Float = 0.22,
        radialSegments: Int = 96,
        rings: Int = 24
    ) throws -> MeshResource {
        var positions: [SIMD3<Float>] = []
        var normals: [SIMD3<Float>] = []
        var uvs: [SIMD2<Float>] = []
        var indices: [UInt32] = []

        positions.reserveCapacity((rings + 1) * (radialSegments + 1))
        for r in 0...rings {
            let t = Float(r) / Float(rings)
            let radius = innerRadius + t * (outerRadius - innerRadius)
            let y = slope * radius
            for s in 0...radialSegments {
                let phi = Float(s) / Float(radialSegments) * 2 * .pi
                let cosPhi = cos(phi)
                let sinPhi = sin(phi)
                positions.append(SIMD3<Float>(radius * cosPhi, y, radius * sinPhi))
                normals.append(normalize(SIMD3<Float>(-slope * cosPhi, 1, -slope * sinPhi)))
                uvs.append(SIMD2<Float>(Float(s) / Float(radialSegments), t))
            }
        }

        let stride = radialSegments + 1
        for r in 0..<rings {
            for s in 0..<radialSegments {
                let a = r * stride + s
                let b = a + 1
                let c = a + stride
                let d = c + 1
                indices.append(contentsOf: [UInt32(a), UInt32(c), UInt32(b)])
                indices.append(contentsOf: [UInt32(b), UInt32(c), UInt32(d)])
            }
        }

        var descriptor = MeshDescriptor()
        descriptor.positions = MeshBuffer(positions)
        descriptor.normals = MeshBuffer(normals)
        descriptor.textureCoordinates = MeshBuffer(uvs)
        descriptor.primitives = .triangles(indices)
        return try MeshResource.generate(from: [descriptor])
    }
}
