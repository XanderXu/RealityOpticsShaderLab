import SwiftUI
import simd

enum PreviewShape: String, CaseIterable, Identifiable {
    case sphere, plane, ruler, disc

    var id: String { rawValue }

    var title: String {
        switch self {
        case .sphere: return "球体"
        case .plane: return "平面"
        case .ruler: return "尺子"
        case .disc: return "光盘"
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

    func orientation(at time: Float) -> simd_quatf {
        // Thin samples rock about their own centers, so their fronts stay visible.
        let sway = sin(time * 0.5) * 0.55
        switch self {
        case .sphere:
            return simd_quatf(angle: time * 0.25, axis: SIMD3(0, 1, 0))
        case .plane, .ruler:
            return simd_quatf(angle: sway, axis: SIMD3(0, 1, 0))
                * simd_quatf(angle: -0.12, axis: SIMD3(1, 0, 0))
        case .disc:
            // DiscMesh lies in XZ with +Y normals; turn its face toward +Z.
            return simd_quatf(angle: sway, axis: SIMD3(0, 1, 0))
                * simd_quatf(angle: .pi / 2 - 0.18, axis: SIMD3(1, 0, 0))
        }
    }
}

enum PreviewGroup: String, CaseIterable {
    case basic, instruments

    var shapes: [PreviewShape] {
        self == .basic ? [.sphere, .plane] : [.ruler, .disc]
    }

    var title: String { self == .basic ? "球体 / 平面" : "尺子 / 光盘" }
}

/// Explicit sRGB display swatches; the gray preset is a linear 18% gray.
enum PreviewColor: String, CaseIterable, Identifiable {
    case black, white, gray, red, green, blue, cyan, magenta, yellow

    var id: String { rawValue }

    var title: String {
        switch self {
        case .black: return "黑色"
        case .white: return "白色"
        case .gray: return "18% 灰"
        case .red: return "红色"
        case .green: return "绿色"
        case .blue: return "蓝色"
        case .cyan: return "青色"
        case .magenta: return "品红"
        case .yellow: return "黄色"
        }
    }

    var rgb: SIMD3<Double> {
        switch self {
        case .black: return SIMD3(repeating: 0)
        case .white: return SIMD3(repeating: 1)
        case .gray: return SIMD3(repeating: 0.4613561295)
        case .red: return SIMD3(1, 0, 0)
        case .green: return SIMD3(0, 1, 0)
        case .blue: return SIMD3(0, 0, 1)
        case .cyan: return SIMD3(0, 1, 1)
        case .magenta: return SIMD3(1, 0, 1)
        case .yellow: return SIMD3(1, 1, 0)
        }
    }

    var color: Color { Color(.sRGB, red: rgb.x, green: rgb.y, blue: rgb.z, opacity: 1) }
    static let materialColorSpace = CGColorSpace(name: CGColorSpace.extendedLinearSRGB)!
    static let originalMaterialColor = CGColor(colorSpace: materialColorSpace,
        components: [0.2140411405, 0.2140411405, 0.2140411405, 1])!

    var materialColor: CGColor {
        let linear = self == .gray ? SIMD3<Double>(repeating: 0.18) : rgb
        return CGColor(colorSpace: Self.materialColorSpace, components: [linear.x, linear.y, linear.z, 1])!
    }
    var contrastingColor: Color {
        switch self {
        case .black, .red, .blue, .magenta: return .white
        default: return .black
        }
    }
}
