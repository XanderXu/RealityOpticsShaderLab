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

enum PreviewGroup: String, CaseIterable {
    case basic, instruments

    var shapes: [PreviewShape] {
        self == .basic ? [.sphere, .plane] : [.ruler, .disc]
    }

    var title: String { self == .basic ? "球体 / 平面" : "尺子 / 光盘" }
}

/// Black, white and RGB primaries have identical values in sRGB and linear sRGB.
enum PreviewColor: String, CaseIterable, Identifiable {
    case black, white, red, green, blue

    var id: String { rawValue }

    var title: String {
        switch self {
        case .black: return "黑色"
        case .white: return "白色"
        case .red: return "红色"
        case .green: return "绿色"
        case .blue: return "蓝色"
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
    var contrastingColor: Color {
        switch self {
        case .black, .red, .blue: return .white
        default: return .black
        }
    }
}
