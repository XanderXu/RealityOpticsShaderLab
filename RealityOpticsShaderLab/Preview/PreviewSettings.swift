import SwiftUI
import simd

enum PreviewShape: String, CaseIterable, Identifiable {
    case sphere, plane, ruler, disc

    var id: String { rawValue }

    var title: String {
        switch self {
        case .sphere: return L10n.text("球体")
        case .plane: return L10n.text("平面")
        case .ruler: return L10n.text("尺子")
        case .disc: return L10n.text("光盘")
        }
    }

    var symbol: String {
        switch self {
        case .sphere: return "globe"
        case .plane: return "rectangle"
        case .ruler: return "ruler"
        case .disc: return "opticaldisc"
        }
    }

    /// Enclose each mesh about its origin throughout a complete rotation.
    /// Keep these dimensions aligned with OpticsMeshes and the conical DiscMesh.
    var rotationRadius: Float {
        switch self {
        case .sphere: return 0.12
        case .plane: return sqrt(0.12 * 0.12 + 0.10 * 0.10)
        case .ruler: return sqrt(0.135 * 0.135 + 0.0475 * 0.0475 + 0.007 * 0.007)
        case .disc: return sqrt(0.12 * 0.12 + 0.024 * 0.024)
        }
    }

    func orientation(at time: Float) -> simd_quatf {
        // Every sample makes a full turn around its own center in about 25 seconds.
        let yaw = simd_quatf(angle: time * 0.25, axis: SIMD3(0, 1, 0))
        switch self {
        case .sphere:
            return yaw
        case .plane, .ruler:
            return yaw * simd_quatf(angle: -0.12, axis: SIMD3(1, 0, 0))
        case .disc:
            // DiscMesh lies in XZ with +Y normals; turn its face toward +Z.
            return yaw * simd_quatf(angle: .pi / 2 - 0.18, axis: SIMD3(1, 0, 0))
        }
    }
}

enum PreviewLayout {
    static let columnSpacing: Float = 0.29
    static let rowSpacing: Float = 0.26

    /// Height of the board origin above a horizontal AR placement point.
    /// Account for camera tilt, zoom and every sample's full rotation envelope.
    static func surfaceClearance(orientation: simd_quatf, scale: Float) -> Float {
        let lowest = PreviewShape.allCases.map { shape in
            orientation.act(position(for: shape)).y - shape.rotationRadius
        }.min() ?? 0
        return max(0, -lowest * scale) + 0.01
    }

    static func position(for shape: PreviewShape, wide: Bool = false) -> SIMD3<Float> {
        let index = PreviewShape.allCases.firstIndex(of: shape)!
        return wide
            ? SIMD3((Float(index) - 1.5) * columnSpacing, 0, 0)
            : SIMD3(index % 2 == 0 ? -columnSpacing / 2 : columnSpacing / 2,
                    index < 2 ? rowSpacing / 2 : -rowSpacing / 2, 0)
    }

    /// Conservative bounds of the 2×2 board, including complete sample turns.
    static let gridSize: SIMD2<Float> = {
        var halfSize = SIMD2<Float>.zero
        for shape in PreviewShape.allCases {
            let center = position(for: shape)
            halfSize = simd_max(halfSize, SIMD2(abs(center.x), abs(center.y)) + shape.rotationRadius)
        }
        return halfSize * 2
    }()
}

/// Black, white and RGB primaries have identical values in sRGB and linear sRGB.
enum PreviewColor: String, CaseIterable, Identifiable {
    case black, white, red, green, blue

    var id: String { rawValue }

    var title: String {
        switch self {
        case .black: return L10n.text("黑色")
        case .white: return L10n.text("白色")
        case .red: return L10n.text("红色")
        case .green: return L10n.text("绿色")
        case .blue: return L10n.text("蓝色")
        }
    }

    var rgb: SIMD3<Double> {
        switch self {
        case .black: return SIMD3(repeating: 0)
        case .white: return SIMD3(repeating: 1)
        case .red: return SIMD3(1, 0, 0)
        case .green: return SIMD3(0, 1, 0)
        case .blue: return SIMD3(0, 0, 1)
        }
    }

    var color: Color { Color(.sRGB, red: rgb.x, green: rgb.y, blue: rgb.z, opacity: 1) }
    static let materialColorSpace = CGColorSpace(name: CGColorSpace.extendedLinearSRGB)!
    static let originalMaterialColor = CGColor(colorSpace: materialColorSpace,
        components: [0.2140411405, 0.2140411405, 0.2140411405, 1])!

    var materialColor: CGColor {
        CGColor(colorSpace: Self.materialColorSpace, components: [rgb.x, rgb.y, rgb.z, 1])!
    }
    /// Unit-path Beer–Lambert coefficients. Cache five swatches once; slider
    /// drags and the glass graph reuse these and the existing exponential math.
    private static let absorptionColors: [PreviewColor: CGColor] = Dictionary(uniqueKeysWithValues: allCases.map { color in
        let rgb = color.rgb
        let absorption = [-log(max(rgb.x, 0.002)), -log(max(rgb.y, 0.002)), -log(max(rgb.z, 0.002))]
        return (color, CGColor(colorSpace: materialColorSpace,
                              components: absorption.map { CGFloat($0) } + [1])!)
    })
    var absorptionColor: CGColor { Self.absorptionColors[self]! }
    var contrastingColor: Color {
        switch self {
        case .black, .red, .blue: return .white
        default: return .black
        }
    }
}
