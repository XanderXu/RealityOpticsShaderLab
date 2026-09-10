import SwiftUI
import RealityKit
import OpticsPhysics
import OpticsContent

@MainActor
@Observable
final class AppModel {

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

    /// Drives the turntable rotation in the scene's update handler.
    var isAnimating = true

    // MARK: - Built artifacts

    private(set) var filmMaterial: ShaderGraphMaterial?
    private(set) var gratingMaterial: ShaderGraphMaterial?
    private(set) var filmLUT: LUTTexture?
    private(set) var gratingLUT: LUTTexture?
    private(set) var statusMessage = "Booting optics…"

    /// Bumped whenever a material is (re)created or re-parameterized.
    /// The scene view syncs entities against this instead of reading materials
    /// inside RealityView's make closure (which would re-run and duplicate the
    /// scene on every observable write).
    private(set) var materialRevision = 0

    /// Set once by the scene; used by the revision-driven sync to reach entities.
    weak var sceneRoot: Entity?

    private var rebuildTask: Task<Void, Never>?

    /// Creates each demo object once its material exists and re-pushes the
    /// (value-type) materials into the entities' ModelComponents. Called from
    /// the scene's make closure via an unstructured Task (so observable reads
    /// here never re-trigger the make closure) and on every materialRevision
    /// change so slider edits reach the rendered surface.
    func syncSceneObjects() {
        guard let root = sceneRoot else { return }

        if let film = filmMaterial {
            if let bubble = root.findEntity(named: "Bubble") {
                assign(film, to: bubble)
            } else {
                let bubble = ModelEntity(
                    mesh: .generateSphere(radius: 0.11),
                    materials: [film]
                )
                bubble.name = "Bubble"
                bubble.position = SIMD3(-0.22, -0.02, 0)
                root.addChild(bubble)
            }
        }

        if let grating = gratingMaterial {
            if let cd = root.findEntity(named: "CompactDisc") {
                assign(grating, to: cd)
            } else if let disc = try? DiscMesh.make(
                innerRadius: 0.035,
                outerRadius: 0.22,
                slope: 0.20
            ) {
                let cd = ModelEntity(mesh: disc, materials: [grating])
                cd.name = "CompactDisc"
                cd.position = SIMD3(0.22, -0.06, 0)
                root.addChild(cd)
            }
        }
    }

    private func assign(_ material: ShaderGraphMaterial, to entity: Entity) {
        guard var component = entity.components[ModelComponent.self] else { return }
        component.materials = [material]
        entity.components[ModelComponent.self] = component
    }

    func report(error: String) {
        statusMessage = error
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

        let filmTexture = try LUTTexture(width: 256, height: 256)
        filmTexture.upload(halves: filmBytes)
        let gratingTexture = try LUTTexture(width: 256, height: 128)
        gratingTexture.upload(halves: gratingBytes)
        self.filmLUT = filmTexture
        self.gratingLUT = gratingTexture

        do {
            var film = try await ShaderGraphMaterial(
                named: "/Root/IridescentFilmMaterial",
                from: "Materials/IridescentFilmMaterial.usda",
                in: opticsContentBundle
            )
            try film.setParameter(name: "FilmLUT", value: .textureResource(filmTexture.resource))
            // Thin shell / disc: render both faces so the bubble interior shows
            // and the leaning disc never gets back-face culled mid-rotation.
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

        statusMessage = "Ready"
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

    private func setParam(_ material: inout ShaderGraphMaterial, _ name: String, _ value: MaterialParameters.Value) {
        do {
            try material.setParameter(name: name, value: value)
        } catch {
            // A typo'd parameter name must be visible, not silently ignored.
            print("RealityOpticsShaderLab: setParameter(\(name)) failed: \(error)")
        }
    }
}
