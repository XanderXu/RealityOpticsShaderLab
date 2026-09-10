import SwiftUI
import RealityKit
import OpticsPhysics
import OpticsContent

/// One slider in the per-effect settings panel, bound to AppModel state
/// through getter/setter closures (keeps the UI generic and data-driven).
struct SettingSpec: Identifiable {
    let id: String
    let label: String
    let range: ClosedRange<Float>
    let get: () -> Float
    let set: (Float) -> Void
}

@MainActor
@Observable
final class AppModel {

    var selectedEffect: OpticsEffect = .thinFilm

    init() {
        // Launcher override for automated verification:
        // SIMCTL_CHILD_OPTICS_EFFECT=nacre xcrun simctl launch ...
        if let raw = ProcessInfo.processInfo.environment["OPTICS_EFFECT"],
           let effect = OpticsEffect(rawValue: raw) {
            selectedEffect = effect
        }
    }

    // MARK: - Film (soap bubble) parameters

    var thicknessScale: Float = 0.85 { didSet { pushFilmParameters() } }
    var thicknessBias: Float = 0.12 { didSet { pushFilmParameters() } }
    var noiseAmount: Float = 0.12 { didSet { pushFilmParameters() } }
    var filmGain: Float = 2.2 { didSet { pushFilmParameters() } }
    var filmOpacity: Float = 0.92 { didSet { pushFilmParameters() } }
    var soapIOR: Float = 1.333 {
        didSet { rebuildFilmLUT() }
    }

    // MARK: - Grating (CD) parameters

    var densityScale: Float = 0.45 { didSet { pushGratingParameters() } }
    var densityBias: Float = 0.25 { didSet { pushGratingParameters() } }
    var gratingGain: Float = 1.6 { didSet { pushGratingParameters() } }
    var lightAzimuthDeg: Float = 120 {
        didSet { pushGratingParameters() }
    }

    // MARK: - Nacre parameters

    var nacreThicknessScale: Float = 0.55 { didSet { pushNacreParameters() } }
    var nacreThicknessBias: Float = 0.25 { didSet { pushNacreParameters() } }
    var nacreNoiseAmount: Float = 0.08 { didSet { pushNacreParameters() } }
    var nacreGain: Float = 1.4 { didSet { pushNacreParameters() } }

    // MARK: - Opal parameters

    var opalCellScale: Float = 6 { didSet { pushOpalParameters() } }
    var opalJitter: Float = 0.5 { didSet { pushOpalParameters() } }
    var opalGain: Float = 1.5 { didSet { pushOpalParameters() } }

    // MARK: - Birefringence parameters

    var birefrPhaseScale: Float = 2.0 { didSet { pushBirefringenceParameters() } }
    var birefrNoiseAmount: Float = 0.3 { didSet { pushBirefringenceParameters() } }
    var birefrGain: Float = 1.3 { didSet { pushBirefringenceParameters() } }

    // MARK: - Speckle parameters

    var speckleScale: Float = 220 { didSet { pushSpeckleParameters() } }
    var speckleFlow: Float = 0.35 { didSet { pushSpeckleParameters() } }
    var speckleThreshold: Float = 0.82 { didSet { pushSpeckleParameters() } }
    var speckleGain: Float = 1.6 { didSet { pushSpeckleParameters() } }

    // MARK: - Morpho parameters

    // 216nm chitin => first-order reflection peak at 450nm blue at normal incidence
    var morphoThicknessBias: Float = 0.18 { didSet { pushMorphoParameters() } }
    var morphoNoiseAmount: Float = 0.06 { didSet { pushMorphoParameters() } }
    var morphoGain: Float = 1.8 { didSet { pushMorphoParameters() } }

    /// Drives the turntable rotation in the scene's update handler.
    var isAnimating = true

    // MARK: - Built artifacts

    private(set) var filmMaterial: ShaderGraphMaterial?
    private(set) var gratingMaterial: ShaderGraphMaterial?
    private(set) var nacreMaterial: ShaderGraphMaterial?
    private(set) var opalMaterial: ShaderGraphMaterial?
    private(set) var birefringenceMaterial: ShaderGraphMaterial?
    private(set) var speckleMaterial: ShaderGraphMaterial?
    private(set) var morphoMaterial: ShaderGraphMaterial?
    private(set) var filmLUT: LUTTexture?
    private(set) var gratingLUT: LUTTexture?
    private(set) var nacreLUT: LUTTexture?
    private(set) var birefringenceLUT: LUTTexture?
    private(set) var morphoLUT: LUTTexture?
    private(set) var statusMessage = "Booting optics…"

    /// Bumped whenever a material is (re)created or re-parameterized.
    /// The scene view syncs entities against this instead of reading materials
    /// inside RealityView's make closure (which would re-run and duplicate the
    /// scene on every observable write).
    private(set) var materialRevision = 0

    /// Set once by the scene; used by the revision-driven sync to reach entities.
    weak var sceneRoot: Entity?

    private var rebuildTask: Task<Void, Never>?

    func report(error: String) {
        statusMessage = error
    }

    // MARK: - Per-effect settings

    func settingsFor(_ effect: OpticsEffect) -> [SettingSpec] {
        switch effect {
        case .thinFilm:
            return [
                SettingSpec(id: "tScale", label: "Thickness scale", range: 0...1.5,
                            get: { [weak self] in self?.thicknessScale ?? 0 },
                            set: { [weak self] in self?.thicknessScale = $0 }),
                SettingSpec(id: "tBias", label: "Thickness bias", range: 0...0.8,
                            get: { [weak self] in self?.thicknessBias ?? 0 },
                            set: { [weak self] in self?.thicknessBias = $0 }),
                SettingSpec(id: "noise", label: "Noise amount", range: 0...0.4,
                            get: { [weak self] in self?.noiseAmount ?? 0 },
                            set: { [weak self] in self?.noiseAmount = $0 }),
                SettingSpec(id: "gain", label: "Gain", range: 0.5...4,
                            get: { [weak self] in self?.filmGain ?? 0 },
                            set: { [weak self] in self?.filmGain = $0 }),
                SettingSpec(id: "opacity", label: "Opacity", range: 0.3...1,
                            get: { [weak self] in self?.filmOpacity ?? 0 },
                            set: { [weak self] in self?.filmOpacity = $0 }),
                SettingSpec(id: "ior", label: "Film IOR (rebuilds LUT)", range: 1.2...1.45,
                            get: { [weak self] in self?.soapIOR ?? 0 },
                            set: { [weak self] in self?.soapIOR = $0 }),
            ]
        case .grating:
            return [
                SettingSpec(id: "dScale", label: "Density scale", range: 0.1...1,
                            get: { [weak self] in self?.densityScale ?? 0 },
                            set: { [weak self] in self?.densityScale = $0 }),
                SettingSpec(id: "dBias", label: "Density bias", range: 0...0.6,
                            get: { [weak self] in self?.densityBias ?? 0 },
                            set: { [weak self] in self?.densityBias = $0 }),
                SettingSpec(id: "gGain", label: "Gain", range: 0.5...3,
                            get: { [weak self] in self?.gratingGain ?? 0 },
                            set: { [weak self] in self?.gratingGain = $0 }),
                SettingSpec(id: "az", label: "Light azimuth", range: 0...360,
                            get: { [weak self] in self?.lightAzimuthDeg ?? 0 },
                            set: { [weak self] in self?.lightAzimuthDeg = $0 }),
            ]
        case .nacre:
            return [
                SettingSpec(id: "nScale", label: "Thickness scale", range: 0...1.2,
                            get: { [weak self] in self?.nacreThicknessScale ?? 0 },
                            set: { [weak self] in self?.nacreThicknessScale = $0 }),
                SettingSpec(id: "nBias", label: "Thickness bias", range: 0...0.6,
                            get: { [weak self] in self?.nacreThicknessBias ?? 0 },
                            set: { [weak self] in self?.nacreThicknessBias = $0 }),
                SettingSpec(id: "nNoise", label: "Noise amount", range: 0...0.3,
                            get: { [weak self] in self?.nacreNoiseAmount ?? 0 },
                            set: { [weak self] in self?.nacreNoiseAmount = $0 }),
                SettingSpec(id: "nGain", label: "Gain", range: 0.5...3,
                            get: { [weak self] in self?.nacreGain ?? 0 },
                            set: { [weak self] in self?.nacreGain = $0 }),
            ]
        case .opal:
            return [
                SettingSpec(id: "oCell", label: "Cell scale (Voronoi)", range: 2...16,
                            get: { [weak self] in self?.opalCellScale ?? 0 },
                            set: { [weak self] in self?.opalCellScale = $0 }),
                SettingSpec(id: "oJitter", label: "Domain jitter", range: 0...1,
                            get: { [weak self] in self?.opalJitter ?? 0 },
                            set: { [weak self] in self?.opalJitter = $0 }),
                SettingSpec(id: "oGain", label: "Gain", range: 0.5...3,
                            get: { [weak self] in self?.opalGain ?? 0 },
                            set: { [weak self] in self?.opalGain = $0 }),
            ]
        case .birefringence:
            return [
                SettingSpec(id: "bPhase", label: "Phase rings", range: 0.5...4,
                            get: { [weak self] in self?.birefrPhaseScale ?? 0 },
                            set: { [weak self] in self?.birefrPhaseScale = $0 }),
                SettingSpec(id: "bNoise", label: "Stress noise", range: 0...1,
                            get: { [weak self] in self?.birefrNoiseAmount ?? 0 },
                            set: { [weak self] in self?.birefrNoiseAmount = $0 }),
                SettingSpec(id: "bGain", label: "Gain", range: 0.5...3,
                            get: { [weak self] in self?.birefrGain ?? 0 },
                            set: { [weak self] in self?.birefrGain = $0 }),
            ]
        case .speckle:
            return [
                SettingSpec(id: "sScale", label: "Grain density", range: 60...400,
                            get: { [weak self] in self?.speckleScale ?? 0 },
                            set: { [weak self] in self?.speckleScale = $0 }),
                SettingSpec(id: "sFlow", label: "View flow", range: 0...1,
                            get: { [weak self] in self?.speckleFlow ?? 0 },
                            set: { [weak self] in self?.speckleFlow = $0 }),
                SettingSpec(id: "sThresh", label: "Spot threshold", range: 0.5...0.98,
                            get: { [weak self] in self?.speckleThreshold ?? 0 },
                            set: { [weak self] in self?.speckleThreshold = $0 }),
                SettingSpec(id: "sGain", label: "Gain", range: 0.5...3,
                            get: { [weak self] in self?.speckleGain ?? 0 },
                            set: { [weak self] in self?.speckleGain = $0 }),
            ]
        case .morpho:
            return [
                SettingSpec(id: "mBias", label: "Thickness (blue band)", range: 0.2...0.45,
                            get: { [weak self] in self?.morphoThicknessBias ?? 0 },
                            set: { [weak self] in self?.morphoThicknessBias = $0 }),
                SettingSpec(id: "mNoise", label: "Ridge noise", range: 0...0.35,
                            get: { [weak self] in self?.morphoNoiseAmount ?? 0 },
                            set: { [weak self] in self?.morphoNoiseAmount = $0 }),
                SettingSpec(id: "mGain", label: "Gain", range: 0.5...3,
                            get: { [weak self] in self?.morphoGain ?? 0 },
                            set: { [weak self] in self?.morphoGain = $0 }),
            ]
        default:
            return []
        }
    }

    // MARK: - Build

    func buildAll() async throws {
        statusMessage = "Integrating spectra…"

        let filmBytes = try await Task.detached(priority: .userInitiated) {
            LUTFactory.makeFilmLUT(ior: 1.333)
        }.value
        let gratingBytes = try await Task.detached(priority: .userInitiated) {
            LUTFactory.makeGratingLUT()
        }.value
        let nacreBytes = try await Task.detached(priority: .userInitiated) {
            LUTFactory.makeNacreLUT()
        }.value
        let birefrBytes = try await Task.detached(priority: .userInitiated) {
            LUTFactory.makeBirefringenceLUT()
        }.value
        let morphoBytes = try await Task.detached(priority: .userInitiated) {
            LUTFactory.makeMorphoLUT()
        }.value

        let filmTexture = try LUTTexture(width: 256, height: 256)
        filmTexture.upload(halves: filmBytes)
        let gratingTexture = try LUTTexture(width: 256, height: 128)
        gratingTexture.upload(halves: gratingBytes)
        let nacreTexture = try LUTTexture(width: 256, height: 256)
        nacreTexture.upload(halves: nacreBytes)
        let birefrTexture = try LUTTexture(width: 512, height: 8)
        birefrTexture.upload(halves: birefrBytes)
        let morphoTexture = try LUTTexture(width: 256, height: 256)
        morphoTexture.upload(halves: morphoBytes)
        self.filmLUT = filmTexture
        self.gratingLUT = gratingTexture
        self.nacreLUT = nacreTexture
        self.birefringenceLUT = birefrTexture
        self.morphoLUT = morphoTexture

        do {
            var film = try await ShaderGraphMaterial(
                named: "/Root/IridescentFilmMaterial",
                from: "Materials/IridescentFilmMaterial.usda",
                in: opticsContentBundle
            )
            try film.setParameter(name: "FilmLUT", value: .textureResource(filmTexture.resource))
            // Thin shell: render both faces so the bubble interior shows.
            film.faceCulling = .none
            self.filmMaterial = film
            pushFilmParameters()
        } catch {
            statusMessage = "film err: \(error.localizedDescription)"
            return
        }

        do {
            var grating = try await ShaderGraphMaterial(
                named: "/Root/DiffractionGratingMaterial",
                from: "Materials/DiffractionGratingMaterial.usda",
                in: opticsContentBundle
            )
            try grating.setParameter(name: "GratingLUT", value: .textureResource(gratingTexture.resource))
            grating.faceCulling = .none
            self.gratingMaterial = grating
            pushGratingParameters()
        } catch {
            statusMessage = "grating err: \(error.localizedDescription)"
            return
        }

        do {
            let nacre = try await loadLutMaterial(
                prim: "/Root/NacreMaterial",
                file: "Materials/NacreMaterial.usda",
                lutName: "NacreLUT",
                texture: nacreTexture.resource
            )
            self.nacreMaterial = nacre
            pushNacreParameters()
        } catch {
            statusMessage = "nacre err: \(error.localizedDescription)"
            return
        }

        do {
            // Opal reuses the grating LUT data; its look comes from the
            // Voronoi jitter applied to the lookup coordinates in-graph.
            let opal = try await loadLutMaterial(
                prim: "/Root/OpalMaterial",
                file: "Materials/OpalMaterial.usda",
                lutName: "OpalLUT",
                texture: gratingTexture.resource
            )
            self.opalMaterial = opal
            pushOpalParameters()
        } catch {
            statusMessage = "opal err: \(error.localizedDescription)"
            return
        }

        do {
            let birefr = try await loadLutMaterial(
                prim: "/Root/BirefringenceMaterial",
                file: "Materials/BirefringenceMaterial.usda",
                lutName: "PhaseLUT",
                texture: birefrTexture.resource
            )
            self.birefringenceMaterial = birefr
            pushBirefringenceParameters()
        } catch {
            statusMessage = "birefr err: \(error.localizedDescription)"
            return
        }

        do {
            // Speckle is fully procedural in-graph (cell hash on view-shifted
            // UVs); no LUT needed.
            var speckle = try await ShaderGraphMaterial(
                named: "/Root/SpeckleMaterial",
                from: "Materials/SpeckleMaterial.usda",
                in: opticsContentBundle
            )
            speckle.faceCulling = .none
            self.speckleMaterial = speckle
            pushSpeckleParameters()
        } catch {
            statusMessage = "speckle err: \(error.localizedDescription)"
            return
        }

        do {
            let morpho = try await loadLutMaterial(
                prim: "/Root/MorphoMaterial",
                file: "Materials/MorphoMaterial.usda",
                lutName: "MorphoLUT",
                texture: morphoTexture.resource
            )
            self.morphoMaterial = morpho
            pushMorphoParameters()
        } catch {
            statusMessage = "morpho err: \(error.localizedDescription)"
            return
        }

        statusMessage = "Ready"
    }

    /// Common loader for the LUT-sampling unlit materials.
    private func loadLutMaterial(
        prim: String, file: String, lutName: String, texture: TextureResource
    ) async throws -> ShaderGraphMaterial {
        var material = try await ShaderGraphMaterial(named: prim, from: file, in: opticsContentBundle)
        try material.setParameter(name: lutName, value: .textureResource(texture))
        material.faceCulling = .none
        return material
    }

    // MARK: - Scene object management

    private func entityName(for effect: OpticsEffect) -> String {
        switch effect {
        case .thinFilm: return "Bubble"
        case .grating: return "CompactDisc"
        case .nacre: return "NacreSphere"
        case .opal: return "OpalSphere"
        case .birefringence: return "BirefrRuler"
        case .speckle: return "SpeckleSphere"
        case .morpho: return "MorphoWing"
        default: return "Placeholder"
        }
    }

    /// Shows exactly one object: the effect's shader-carrying mesh, or a
    /// placeholder for effects not yet implemented. Called from the scene's
    /// make closure (via an unstructured Task, so observable reads here never
    /// re-trigger the make closure) and on materialRevision/effect changes.
    func syncSceneObjects() {
        guard let root = sceneRoot else { return }
        let effect = selectedEffect
        let keep = entityName(for: effect)

        // Remove entities that belong to a different effect.
        let knownNames = ["Bubble", "CompactDisc", "NacreSphere", "OpalSphere",
                          "BirefrRuler", "SpeckleSphere", "MorphoWing", "Placeholder"]
        for name in knownNames where name != keep {
            root.findEntity(named: name)?.removeFromParent()
        }

        switch effect {
        case .thinFilm:
            guard let film = filmMaterial else { return }
            if let bubble = root.findEntity(named: keep) {
                assign(film, to: bubble)
            } else {
                let bubble = ModelEntity(
                    mesh: .generateSphere(radius: 0.11),
                    materials: [film]
                )
                bubble.name = keep
                bubble.position = SIMD3(0, -0.02, 0)
                root.addChild(bubble)
            }

        case .nacre:
            guard let nacre = nacreMaterial else { return }
            if let shell = root.findEntity(named: keep) {
                assign(nacre, to: shell)
            } else {
                let shell = ModelEntity(
                    mesh: .generateSphere(radius: 0.11),
                    materials: [nacre]
                )
                shell.name = keep
                shell.position = SIMD3(0, -0.02, 0)
                root.addChild(shell)
            }

        case .opal:
            guard let opal = opalMaterial else { return }
            if let stone = root.findEntity(named: keep) {
                assign(opal, to: stone)
            } else {
                let stone = ModelEntity(
                    mesh: .generateSphere(radius: 0.11),
                    materials: [opal]
                )
                stone.name = keep
                stone.position = SIMD3(0, -0.02, 0)
                root.addChild(stone)
            }

        case .birefringence:
            guard let birefr = birefringenceMaterial else { return }
            if let ruler = root.findEntity(named: keep) {
                assign(birefr, to: ruler)
            } else {
                let ruler = ModelEntity(
                    mesh: .generateBox(width: 0.36, height: 0.02, depth: 0.07),
                    materials: [birefr]
                )
                ruler.name = keep
                ruler.position = SIMD3(0, -0.03, 0)
                root.addChild(ruler)
            }

        case .speckle:
            guard let speckle = speckleMaterial else { return }
            if let screen = root.findEntity(named: keep) {
                assign(speckle, to: screen)
            } else {
                let screen = ModelEntity(
                    mesh: .generateSphere(radius: 0.11),
                    materials: [speckle]
                )
                screen.name = keep
                screen.position = SIMD3(0, -0.02, 0)
                root.addChild(screen)
            }

        case .morpho:
            guard let morpho = morphoMaterial else { return }
            if let wing = root.findEntity(named: keep) {
                assign(morpho, to: wing)
            } else {
                let wing = ModelEntity(
                    mesh: .generatePlane(width: 0.34, height: 0.2),
                    materials: [morpho]
                )
                wing.name = keep
                wing.position = SIMD3(0, -0.02, -0.02)
                root.addChild(wing)
            }

        case .grating:
            guard let grating = gratingMaterial else { return }
            if let cd = root.findEntity(named: keep) {
                assign(grating, to: cd)
            } else if let disc = try? DiscMesh.make(
                innerRadius: 0.035,
                outerRadius: 0.22,
                slope: 0.20
            ) {
                let cd = ModelEntity(mesh: disc, materials: [grating])
                cd.name = keep
                cd.position = SIMD3(0, -0.06, 0)
                root.addChild(cd)
            }

        default:
            guard root.findEntity(named: keep) == nil else { return }
            let placeholder: ModelEntity
            switch effect {
            case .birefringence:
                // Stretched plastic ruler silhouette
                placeholder = ModelEntity(
                    mesh: .generateBox(width: 0.36, height: 0.02, depth: 0.07),
                    materials: [SimpleMaterial(color: UIColor(white: 0.78, alpha: 1), isMetallic: false)]
                )
                placeholder.position = SIMD3(0, -0.03, 0)
            case .morpho, .feather:
                // Wing / feather vane silhouette
                placeholder = ModelEntity(
                    mesh: .generatePlane(width: 0.34, height: 0.2),
                    materials: [SimpleMaterial(color: UIColor(white: 0.78, alpha: 1), isMetallic: false)]
                )
                placeholder.position = SIMD3(0, -0.02, -0.02)
            default:
                placeholder = ModelEntity(
                    mesh: .generateSphere(radius: 0.11),
                    materials: [SimpleMaterial(color: UIColor(white: 0.78, alpha: 1), isMetallic: false)]
                )
                placeholder.position = SIMD3(0, -0.02, 0)
            }
            placeholder.name = keep
            root.addChild(placeholder)
        }
    }

    private func assign(_ material: ShaderGraphMaterial, to entity: Entity) {
        guard var component = entity.components[ModelComponent.self] else { return }
        component.materials = [material]
        entity.components[ModelComponent.self] = component
    }

    // MARK: - Hot updates

    func rebuildFilmLUT() {
        guard let filmLUT else { return }
        // The IOR slider fires continuously; only the last value should win.
        rebuildTask?.cancel()
        let ior = soapIOR
        statusMessage = "Rebuilding film LUT (IOR \(String(format: "%.3f", ior)))…"
        rebuildTask = Task.detached(priority: .userInitiated) {
            let bytes = LUTFactory.makeFilmLUT(ior: ior)
            guard !Task.isCancelled else { return }
            await MainActor.run {
                guard !Task.isCancelled else { return }
                filmLUT.upload(halves: bytes)
                self.statusMessage = "Ready"
            }
        }
    }

    private func pushFilmParameters() {
        guard var film = filmMaterial else { return }
        setParam(&film, "ThicknessScale", .float(thicknessScale))
        setParam(&film, "ThicknessBias", .float(thicknessBias))
        setParam(&film, "NoiseAmount", .float(noiseAmount))
        setParam(&film, "Gain", .float(filmGain))
        setParam(&film, "Opacity", .float(filmOpacity))
        filmMaterial = film
        materialRevision += 1
    }

    private func pushGratingParameters() {
        guard var grating = gratingMaterial else { return }
        setParam(&grating, "DensityScale", .float(densityScale))
        setParam(&grating, "DensityBias", .float(densityBias))
        setParam(&grating, "Gain", .float(gratingGain))
        let az = lightAzimuthDeg * .pi / 180
        let dir = SIMD3<Float>(cos(az) * 0.65, 0.55, sin(az) * 0.65)
        setParam(&grating, "LightDirection", .simd3Float(dir))
        gratingMaterial = grating
        materialRevision += 1
    }

    private func pushNacreParameters() {
        guard var nacre = nacreMaterial else { return }
        setParam(&nacre, "ThicknessScale", .float(nacreThicknessScale))
        setParam(&nacre, "ThicknessBias", .float(nacreThicknessBias))
        setParam(&nacre, "NoiseAmount", .float(nacreNoiseAmount))
        setParam(&nacre, "Gain", .float(nacreGain))
        nacreMaterial = nacre
        materialRevision += 1
    }

    private func pushOpalParameters() {
        guard var opal = opalMaterial else { return }
        setParam(&opal, "CellScale", .float(opalCellScale))
        setParam(&opal, "Jitter", .float(opalJitter))
        setParam(&opal, "Gain", .float(opalGain))
        opalMaterial = opal
        materialRevision += 1
    }

    private func pushBirefringenceParameters() {
        guard var birefr = birefringenceMaterial else { return }
        setParam(&birefr, "PhaseScale", .float(birefrPhaseScale))
        setParam(&birefr, "NoiseAmount", .float(birefrNoiseAmount))
        setParam(&birefr, "Gain", .float(birefrGain))
        birefringenceMaterial = birefr
        materialRevision += 1
    }

    private func pushSpeckleParameters() {
        guard var speckle = speckleMaterial else { return }
        setParam(&speckle, "SpeckScale", .float(speckleScale))
        setParam(&speckle, "Flow", .float(speckleFlow))
        setParam(&speckle, "Threshold", .float(speckleThreshold))
        setParam(&speckle, "Gain", .float(speckleGain))
        speckleMaterial = speckle
        materialRevision += 1
    }

    private func pushMorphoParameters() {
        guard var morpho = morphoMaterial else { return }
        // No spatial thickness gradient: the whole wing sits in the blue band,
        // noise only adds subtle ridge-scale variation.
        setParam(&morpho, "ThicknessScale", .float(0.0))
        setParam(&morpho, "ThicknessBias", .float(morphoThicknessBias))
        setParam(&morpho, "NoiseAmount", .float(morphoNoiseAmount))
        setParam(&morpho, "Gain", .float(morphoGain))
        morphoMaterial = morpho
        materialRevision += 1
    }

    private func setParam(_ material: inout ShaderGraphMaterial, _ name: String, _ value: MaterialParameters.Value) {
        do {
            try material.setParameter(name: name, value: value)
        } catch {
            // A typo'd parameter name must be visible, not silently ignored.
            print("RealityOpticsShaderLab: setParameter(\(name)) failed: \(error)")
        }
    }
}
