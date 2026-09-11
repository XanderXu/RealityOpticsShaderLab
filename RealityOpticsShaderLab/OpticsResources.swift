import CoreGraphics
import RealityKit
import OpticsContent
import OpticsPhysics

/// Lazy, coalesced GPU lookups and ShaderGraph templates. A material value copied
/// from a template keeps its own parameters while sharing the shader definition.
@MainActor
final class OpticsResources {
    private var rendererTask: Task<LUTRenderer, Error>?
    private var textures: [OpticsLUT: LUTTexture] = [:]
    private var textureTasks: [OpticsLUT: Task<LUTTexture, Error>] = [:]
    private var recentFilms: [OpticsLUT] = []
    private var templates: [String: ShaderGraphMaterial] = [:]
    private var templateTasks: [String: Task<ShaderGraphMaterial, Error>] = [:]
    private(set) var textureBuildCount = 0
    private(set) var templateLoadCount = 0

    var textureCount: Int { textures.count }
    var variableTextureCount: Int { textures.keys.filter(\.isVariable).count }
    var templateCount: Int { templates.count }
    var textureBytes: Int { textures.keys.reduce(0) { $0 + $1.byteCount } }

    func texture(_ key: OpticsLUT) async throws -> LUTTexture {
        if let cached = textures[key] { touch(key); return cached }
        if let pending = textureTasks[key] { return try await pending.value }
        let task = Task { @MainActor in
            if rendererTask == nil { rendererTask = Task { try await LUTRenderer() } }
            do {
                let renderer = try await rendererTask!.value
                let value = try await renderer.make(key)
                textureBuildCount += 1
                textures[key] = value
                touch(key)
                return value
            } catch {
                // Permit a retry after transient device/pipeline setup failure.
                if textures.isEmpty { rendererTask = nil }
                throw error
            }
        }
        textureTasks[key] = task
        defer { textureTasks[key] = nil }
        return try await task.value
    }

    private func touch(_ key: OpticsLUT) {
        guard key.isVariable else { return }
        recentFilms.removeAll { $0 == key }
        recentFilms.append(key)
        // IOR drags must not accumulate one texture per slider event. Materials
        // retain any currently displayed texture even after cache eviction.
        while recentFilms.count > 4 { textures[recentFilms.removeFirst()] = nil }
    }

    private func template(_ name: String) async throws -> ShaderGraphMaterial {
        if let cached = templates[name] { return cached }
        if let pending = templateTasks[name] { return try await pending.value }
        let task = Task { @MainActor in
            var value = try await ShaderGraphMaterial(named: "/Root/\(name)",
                from: "Materials/\(name).usda", in: opticsContentBundle)
            value.faceCulling = .none
            templates[name] = value
            templateLoadCount += 1
            return value
        }
        templateTasks[name] = task
        defer { templateTasks[name] = nil }
        return try await task.value
    }

    func material(for effect: OpticsEffect, soapIOR: Float) async throws -> ShaderGraphMaterial {
        let name = effect.templateName
        // USD loading and this effect's GPU lookup can overlap. No unrelated LUTs.
        async let base = template(name)
        var bindings: [(String, OpticsLUT)] = []
        switch effect {
        case .thinFilm: bindings = [("FilmLUT", .film(ior: soapIOR))]
        case .grating: bindings = [("GratingLUT", .grating)]
        case .nacre: bindings = [("FilmLUT", .nacre)]
        case .opal: bindings = [("OpalLUT", .grating)]
        case .birefringence: bindings = [("PhaseLUT", .birefringence)]
        case .morpho: bindings = [("FilmLUT", .morpho)]
        case .beetle: bindings = [("FilmLUT", .morpho), ("RainbowLUT", .grating)]
        case .feather, .dragonfly: bindings = [("FilmLUT", .morpho)]
        case .hologram: bindings = [("HoloLUT", .grating)]
        case .newton: bindings = [("NewtonLUT", .newton)]
        case .pearl: bindings = [("PearlLUT", .nacre)]
        case .chameleon: bindings = [("ChromaLUT", .grating)]
        case .scarab: bindings = [("ScarabLUT", .morpho)]
        case .labradorite: bindings = [("FilmLUT", .morpho)]
        case .oilFilm: bindings = [("FilmLUT", .layered(.oil))]
        case .titanium: bindings = [("FilmLUT", .layered(.titanium))]
        case .lensCoating: bindings = [("FilmLUT", .layered(.coating))]
        case .dichroic: bindings = [("FilmLUT", .layered(.dichroic))]
        case .lcd, .speckle, .catEye, .starGem, .moonstone, .sunstone, .alexandrite, .pleochroism, .retroreflective: break
        }
        var loaded: [(String, TextureResource)] = []
        for (parameter, key) in bindings { loaded.append((parameter, try await texture(key).resource)) }
        var instance = try await base
        for (parameter, texture) in loaded { try instance.setParameter(name: parameter, value: .textureResource(texture)) }
        if effect == .nacre { try instance.setParameter(name: "Opacity", value: .float(1)) }
        if effect == .morpho { try instance.setParameter(name: "Opacity", value: .float(0.92)) }
        if effect == .starGem {
            try instance.setParameter(name: "StarAmount", value: .float(1))
            try instance.setParameter(name: "BodyTint", value: .color(CGColor(colorSpace: PreviewColor.materialColorSpace, components: [0.018, 0.035, 0.12, 1])!))
            try instance.setParameter(name: "ShineTint", value: .color(CGColor(colorSpace: PreviewColor.materialColorSpace, components: [0.7, 0.86, 1, 1])!))
        }
        let layer: LayeredFilm?
        switch effect {
        case .oilFilm: layer = .oil
        case .titanium: layer = .titanium
        case .lensCoating: layer = .coating
        case .dichroic: layer = .dichroic
        default: layer = nil
        }
        if let layer {
            // Use the same D65 integration white as the CPU reference; subtract
            // before gamut clipping so saturated reflected colors keep correct T.
            let white = Spectrum.rgb(samples: [Float](repeating: 1, count: Spectrum.sampleCount))
            let color = CGColor(colorSpace: PreviewColor.materialColorSpace,
                components: [CGFloat(white.x), CGFloat(white.y), CGFloat(white.z), 1])!
            try instance.setParameter(name: "IlluminantWhite", value: .color(color))
            try instance.setParameter(name: "DomainMin", value: .float(layer.domainMinimum))
            try instance.setParameter(name: "DomainMax", value: .float(layer.domainSpan))
        }
        return instance
    }
}
