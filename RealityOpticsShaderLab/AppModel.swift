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
        // SIMCTL_CHILD_OPTICS_INTENSITY=0.2 — applied once materials exist.
        if let raw = ProcessInfo.processInfo.environment["OPTICS_INTENSITY"],
           let value = Float(raw) {
            intensities[selectedEffect] = min(max(value, 0), 2)
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

    // MARK: - Beetle parameters

    var beetleGreenBand: Float = 0.22 { didSet { pushBeetleParameters() } }
    var beetleRainbowMix: Float = 0.35 { didSet { pushBeetleParameters() } }
    var beetleGain: Float = 1.8 { didSet { pushBeetleParameters() } }

    // MARK: - Feather parameters

    var featherThicknessBias: Float = 0.3 { didSet { pushFeatherParameters() } }
    var featherStripeCount: Float = 24 { didSet { pushFeatherParameters() } }
    var featherGlitterScale: Float = 300 { didSet { pushFeatherParameters() } }
    var featherGain: Float = 1.5 { didSet { pushFeatherParameters() } }

    // MARK: - Hologram parameters

    var holoRows: Float = 22 { didSet { pushHologramParameters() } }
    var holoSlideAmount: Float = 1.2 { didSet { pushHologramParameters() } }
    var holoStripeContrast: Float = 6 { didSet { pushHologramParameters() } }
    var holoGain: Float = 1.8 { didSet { pushHologramParameters() } }

    // MARK: - LCD parameters

    // 0.35: calculator look — greenish base with scattered dark segments.
    var lcdVoltage: Float = 0.35 { didSet { pushLCDParameters() } }
    var lcdPixelScale: Float = 40 { didSet { pushLCDParameters() } }
    var lcdTintAmount: Float = 1 { didSet { pushLCDParameters() } }
    var lcdGain: Float = 1 { didSet { pushLCDParameters() } }

    // MARK: - Newton's rings parameters

    var newtonRingScale: Float = 2.2 { didSet { pushNewtonParameters() } }
    var newtonNoise: Float = 0.015 { didSet { pushNewtonParameters() } }
    var newtonGain: Float = 2 { didSet { pushNewtonParameters() } }

    // MARK: - Pearl parameters

    var pearlThicknessBias: Float = 0.32 { didSet { pushPearlParameters() } }
    var pearlCurvature: Float = 0.28 { didSet { pushPearlParameters() } }
    var pearlTintHue: Float = 0.5 { didSet { pushPearlParameters() } }
    var pearlGain: Float = 1.5 { didSet { pushPearlParameters() } }

    // MARK: - Dragonfly parameters

    var dragonflyThicknessBias: Float = 0.12 { didSet { pushDragonflyParameters() } }
    var dragonflyCrossVeins: Float = 24 { didSet { pushDragonflyParameters() } }
    var dragonflyVeinWidth: Float = 0.09 { didSet { pushDragonflyParameters() } }
    var dragonflyMembraneOpacity: Float = 0.55 { didSet { pushDragonflyParameters() } }
    var dragonflyGain: Float = 1.6 { didSet { pushDragonflyParameters() } }

    // MARK: - Chameleon parameters

    var chameleonCellScale: Float = 10 { didSet { pushChameleonParameters() } }
    var chameleonHueSpeed: Float = 0.15 { didSet { pushChameleonParameters() } }
    var chameleonViewSwing: Float = 0.15 { didSet { pushChameleonParameters() } }
    var chameleonGain: Float = 1.6 { didSet { pushChameleonParameters() } }

    // MARK: - Scarab parameters

    var scarabThicknessBias: Float = 0.22 { didSet { pushScarabParameters() } }
    var scarabBranchShift: Float = 0.12 { didSet { pushScarabParameters() } }
    var scarabAnalyzer: Float = 0 { didSet { pushScarabParameters() } }
    var scarabGain: Float = 1.8 { didSet { pushScarabParameters() } }

    /// Drives the turntable rotation in the scene's update handler.
    var isAnimating = true

    // MARK: - Master effect intensity

    /// Per-effect strength, remembered while switching between effects.
    /// 0 renders the neutral gray slab, 1 is the physical look, >1 saturates.
    private var intensities: [OpticsEffect: Float] = [:]

    func intensity(for effect: OpticsEffect) -> Float {
        intensities[effect] ?? 1
    }

    func setIntensity(_ value: Float, for effect: OpticsEffect) {
        intensities[effect] = value
        pushIntensity(for: effect)
    }

    // MARK: - Built artifacts

    private(set) var filmMaterial: ShaderGraphMaterial?
    private(set) var gratingMaterial: ShaderGraphMaterial?
    private(set) var nacreMaterial: ShaderGraphMaterial?
    private(set) var opalMaterial: ShaderGraphMaterial?
    private(set) var birefringenceMaterial: ShaderGraphMaterial?
    private(set) var speckleMaterial: ShaderGraphMaterial?
    private(set) var morphoMaterial: ShaderGraphMaterial?
    private(set) var beetleMaterial: ShaderGraphMaterial?
    private(set) var featherMaterial: ShaderGraphMaterial?
    private(set) var hologramMaterial: ShaderGraphMaterial?
    private(set) var lcdMaterial: ShaderGraphMaterial?
    private(set) var newtonMaterial: ShaderGraphMaterial?
    private(set) var pearlMaterial: ShaderGraphMaterial?
    private(set) var dragonflyMaterial: ShaderGraphMaterial?
    private(set) var chameleonMaterial: ShaderGraphMaterial?
    private(set) var scarabMaterial: ShaderGraphMaterial?
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
        var specs = effectSettings(effect)
        // The master intensity leads every effect's panel: it scales how far
        // the optical colors deviate from a neutral gray base (0 = off).
        specs.insert(
            SettingSpec(id: "intensity", label: "Effect intensity", range: 0...2,
                        get: { [weak self] in self?.intensity(for: effect) ?? 1 },
                        set: { [weak self] in self?.setIntensity($0, for: effect) }),
            at: 0)
        return specs
    }

    private func effectSettings(_ effect: OpticsEffect) -> [SettingSpec] {
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
        case .beetle:
            return [
                SettingSpec(id: "kGreen", label: "Green band", range: 0.15...0.3,
                            get: { [weak self] in self?.beetleGreenBand ?? 0 },
                            set: { [weak self] in self?.beetleGreenBand = $0 }),
                SettingSpec(id: "kRainbow", label: "Rainbow mix", range: 0...1,
                            get: { [weak self] in self?.beetleRainbowMix ?? 0 },
                            set: { [weak self] in self?.beetleRainbowMix = $0 }),
                SettingSpec(id: "kGain", label: "Gain", range: 0.5...3,
                            get: { [weak self] in self?.beetleGain ?? 0 },
                            set: { [weak self] in self?.beetleGain = $0 }),
            ]
        case .feather:
            return [
                SettingSpec(id: "fBias", label: "Thickness band", range: 0.2...0.42,
                            get: { [weak self] in self?.featherThicknessBias ?? 0 },
                            set: { [weak self] in self?.featherThicknessBias = $0 }),
                SettingSpec(id: "fStripe", label: "Barbule stripes", range: 8...60,
                            get: { [weak self] in self?.featherStripeCount ?? 0 },
                            set: { [weak self] in self?.featherStripeCount = $0 }),
                SettingSpec(id: "fGlitter", label: "Glitter density", range: 100...600,
                            get: { [weak self] in self?.featherGlitterScale ?? 0 },
                            set: { [weak self] in self?.featherGlitterScale = $0 }),
                SettingSpec(id: "fGain", label: "Gain", range: 0.5...3,
                            get: { [weak self] in self?.featherGain ?? 0 },
                            set: { [weak self] in self?.featherGain = $0 }),
            ]
        case .hologram:
            return [
                SettingSpec(id: "hRows", label: "Stripe rows", range: 6...48,
                            get: { [weak self] in self?.holoRows ?? 0 },
                            set: { [weak self] in self?.holoRows = $0 }),
                SettingSpec(id: "hSlide", label: "View slide amount", range: 0...3,
                            get: { [weak self] in self?.holoSlideAmount ?? 0 },
                            set: { [weak self] in self?.holoSlideAmount = $0 }),
                SettingSpec(id: "hContrast", label: "Stripe contrast", range: 2...12,
                            get: { [weak self] in self?.holoStripeContrast ?? 0 },
                            set: { [weak self] in self?.holoStripeContrast = $0 }),
                SettingSpec(id: "hGain", label: "Gain", range: 0.5...3,
                            get: { [weak self] in self?.holoGain ?? 0 },
                            set: { [weak self] in self?.holoGain = $0 }),
            ]
        case .lcd:
            return [
                SettingSpec(id: "lVolt", label: "Drive voltage (dark segments)", range: 0...1,
                            get: { [weak self] in self?.lcdVoltage ?? 0 },
                            set: { [weak self] in self?.lcdVoltage = $0 }),
                SettingSpec(id: "lPixel", label: "Pixel domain scale", range: 16...90,
                            get: { [weak self] in self?.lcdPixelScale ?? 0 },
                            set: { [weak self] in self?.lcdPixelScale = $0 }),
                SettingSpec(id: "lTint", label: "Off-axis tint", range: 0...1,
                            get: { [weak self] in self?.lcdTintAmount ?? 0 },
                            set: { [weak self] in self?.lcdTintAmount = $0 }),
                SettingSpec(id: "lGain", label: "Gain", range: 0.5...2,
                            get: { [weak self] in self?.lcdGain ?? 0 },
                            set: { [weak self] in self?.lcdGain = $0 }),
            ]
        case .newton:
            return [
                SettingSpec(id: "nScale", label: "Curvature (ring density)", range: 0.5...5,
                            get: { [weak self] in self?.newtonRingScale ?? 0 },
                            set: { [weak self] in self?.newtonRingScale = $0 }),
                SettingSpec(id: "nNoise", label: "Gap dust (noise)", range: 0...0.06,
                            get: { [weak self] in self?.newtonNoise ?? 0 },
                            set: { [weak self] in self?.newtonNoise = $0 }),
                SettingSpec(id: "nGain", label: "Gain", range: 0.5...3,
                            get: { [weak self] in self?.newtonGain ?? 0 },
                            set: { [weak self] in self?.newtonGain = $0 }),
            ]
        case .pearl:
            return [
                SettingSpec(id: "pBias", label: "Nacre thickness", range: 0.1...0.6,
                            get: { [weak self] in self?.pearlThicknessBias ?? 0 },
                            set: { [weak self] in self?.pearlThicknessBias = $0 }),
                SettingSpec(id: "pCurv", label: "Curvature hue sweep", range: 0...0.6,
                            get: { [weak self] in self?.pearlCurvature ?? 0 },
                            set: { [weak self] in self?.pearlCurvature = $0 }),
                SettingSpec(id: "pHue", label: "Body tint (rose-gold)", range: 0...1,
                            get: { [weak self] in self?.pearlTintHue ?? 0 },
                            set: { [weak self] in self?.pearlTintHue = $0 }),
                SettingSpec(id: "pGain", label: "Gain", range: 0.5...3,
                            get: { [weak self] in self?.pearlGain ?? 0 },
                            set: { [weak self] in self?.pearlGain = $0 }),
            ]
        case .dragonfly:
            return [
                SettingSpec(id: "dBias", label: "Membrane thickness", range: 0.04...0.3,
                            get: { [weak self] in self?.dragonflyThicknessBias ?? 0 },
                            set: { [weak self] in self?.dragonflyThicknessBias = $0 }),
                SettingSpec(id: "dCross", label: "Cross veins", range: 8...48,
                            get: { [weak self] in self?.dragonflyCrossVeins ?? 0 },
                            set: { [weak self] in self?.dragonflyCrossVeins = $0 }),
                SettingSpec(id: "dWidth", label: "Vein width", range: 0.03...0.2,
                            get: { [weak self] in self?.dragonflyVeinWidth ?? 0 },
                            set: { [weak self] in self?.dragonflyVeinWidth = $0 }),
                SettingSpec(id: "dOpacity", label: "Membrane opacity", range: 0.2...0.9,
                            get: { [weak self] in self?.dragonflyMembraneOpacity ?? 0 },
                            set: { [weak self] in self?.dragonflyMembraneOpacity = $0 }),
                SettingSpec(id: "dGain", label: "Gain", range: 0.5...3,
                            get: { [weak self] in self?.dragonflyGain ?? 0 },
                            set: { [weak self] in self?.dragonflyGain = $0 }),
            ]
        case .chameleon:
            return [
                SettingSpec(id: "cCell", label: "Chromatophore scale", range: 4...24,
                            get: { [weak self] in self?.chameleonCellScale ?? 0 },
                            set: { [weak self] in self?.chameleonCellScale = $0 }),
                SettingSpec(id: "cSpeed", label: "Color switching speed", range: 0...0.6,
                            get: { [weak self] in self?.chameleonHueSpeed ?? 0 },
                            set: { [weak self] in self?.chameleonHueSpeed = $0 }),
                SettingSpec(id: "cSwing", label: "View-angle hue swing", range: 0...0.4,
                            get: { [weak self] in self?.chameleonViewSwing ?? 0 },
                            set: { [weak self] in self?.chameleonViewSwing = $0 }),
                SettingSpec(id: "cGain", label: "Gain", range: 0.5...3,
                            get: { [weak self] in self?.chameleonGain ?? 0 },
                            set: { [weak self] in self?.chameleonGain = $0 }),
            ]
        case .scarab:
            return [
                SettingSpec(id: "sBias", label: "Bragg thickness", range: 0.1...0.5,
                            get: { [weak self] in self?.scarabThicknessBias ?? 0 },
                            set: { [weak self] in self?.scarabThicknessBias = $0 }),
                SettingSpec(id: "sShift", label: "L/R branch shift", range: 0...0.3,
                            get: { [weak self] in self?.scarabBranchShift ?? 0 },
                            set: { [weak self] in self?.scarabBranchShift = $0 }),
                SettingSpec(id: "sAnalyzer", label: "Quarter-wave analyzer", range: 0...1,
                            get: { [weak self] in self?.scarabAnalyzer ?? 0 },
                            set: { [weak self] in self?.scarabAnalyzer = $0 }),
                SettingSpec(id: "sGain", label: "Gain", range: 0.5...3,
                            get: { [weak self] in self?.scarabGain ?? 0 },
                            set: { [weak self] in self?.scarabGain = $0 }),
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

        do {
            // Beetle: green film band + view-swept rainbow bands, both LUTs reused.
            var beetle = try await ShaderGraphMaterial(
                named: "/Root/BeetleMaterial",
                from: "Materials/BeetleMaterial.usda",
                in: opticsContentBundle
            )
            try beetle.setParameter(name: "FilmLUT", value: .textureResource(morphoTexture.resource))
            try beetle.setParameter(name: "RainbowLUT", value: .textureResource(gratingTexture.resource))
            beetle.faceCulling = .none
            self.beetleMaterial = beetle
            pushBeetleParameters()
        } catch {
            statusMessage = "beetle err: \(error.localizedDescription)"
            return
        }

        do {
            // Feather: chitin film (blue-green band) + barbule stripes +
            // static glitter sparkles, all composed in-graph.
            var feather = try await ShaderGraphMaterial(
                named: "/Root/FeatherMaterial",
                from: "Materials/FeatherMaterial.usda",
                in: opticsContentBundle
            )
            try feather.setParameter(name: "FilmLUT", value: .textureResource(morphoTexture.resource))
            feather.faceCulling = .none
            self.featherMaterial = feather
            pushFeatherParameters()
        } catch {
            statusMessage = "feather err: \(error.localizedDescription)"
            return
        }

        do {
            let holo = try await loadLutMaterial(
                prim: "/Root/HologramMaterial",
                file: "Materials/HologramMaterial.usda",
                lutName: "HoloLUT",
                texture: gratingTexture.resource
            )
            self.hologramMaterial = holo
            pushHologramParameters()
        } catch {
            statusMessage = "hologram err: \(error.localizedDescription)"
            return
        }

        do {
            // LCD is fully procedural (worley domains + cos^4 view falloff).
            var lcd = try await ShaderGraphMaterial(
                named: "/Root/LCDMaterial",
                from: "Materials/LCDMaterial.usda",
                in: opticsContentBundle
            )
            lcd.faceCulling = .none
            self.lcdMaterial = lcd
            pushLCDParameters()
        } catch {
            statusMessage = "lcd err: \(error.localizedDescription)"
            return
        }

        do {
            // Newton's rings: film LUT with the thickness axis fed by r^2.
            let newton = try await loadLutMaterial(
                prim: "/Root/NewtonMaterial",
                file: "Materials/NewtonMaterial.usda",
                lutName: "NewtonLUT",
                texture: filmTexture.resource
            )
            self.newtonMaterial = newton
            pushNewtonParameters()
        } catch {
            statusMessage = "newton err: \(error.localizedDescription)"
            return
        }

        do {
            let pearl = try await loadLutMaterial(
                prim: "/Root/PearlMaterial",
                file: "Materials/PearlMaterial.usda",
                lutName: "PearlLUT",
                texture: nacreTexture.resource
            )
            self.pearlMaterial = pearl
            pushPearlParameters()
        } catch {
            statusMessage = "pearl err: \(error.localizedDescription)"
            return
        }

        do {
            let dragonfly = try await loadLutMaterial(
                prim: "/Root/DragonflyMaterial",
                file: "Materials/DragonflyMaterial.usda",
                lutName: "FilmLUT",
                texture: morphoTexture.resource
            )
            self.dragonflyMaterial = dragonfly
            pushDragonflyParameters()
        } catch {
            statusMessage = "dragonfly err: \(error.localizedDescription)"
            return
        }

        do {
            let chameleon = try await loadLutMaterial(
                prim: "/Root/ChameleonMaterial",
                file: "Materials/ChameleonMaterial.usda",
                lutName: "ChromaLUT",
                texture: gratingTexture.resource
            )
            self.chameleonMaterial = chameleon
            pushChameleonParameters()
        } catch {
            statusMessage = "chameleon err: \(error.localizedDescription)"
            return
        }

        do {
            let scarab = try await loadLutMaterial(
                prim: "/Root/ScarabMaterial",
                file: "Materials/ScarabMaterial.usda",
                lutName: "ScarabLUT",
                texture: morphoTexture.resource
            )
            self.scarabMaterial = scarab
            pushScarabParameters()
        } catch {
            statusMessage = "scarab err: \(error.localizedDescription)"
            return
        }

        // Apply any stored (env-provided) intensity now that materials exist.
        for effect in OpticsEffect.allCases {
            pushIntensity(for: effect)
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
        case .beetle: return "BeetleShell"
        case .feather: return "FeatherVane"
        case .hologram: return "HoloCard"
        case .lcd: return "LCDPanel"
        case .newton: return "NewtonPlate"
        case .pearl: return "PearlOrb"
        case .dragonfly: return "DragonflyWing"
        case .chameleon: return "ChameleonSkin"
        case .scarab: return "ScarabShell"
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
        let knownNames = OpticsEffect.allCases.map { entityName(for: $0) } + ["Placeholder"]
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

        case .beetle:
            guard let beetle = beetleMaterial else { return }
            if let shell = root.findEntity(named: keep) {
                assign(beetle, to: shell)
            } else {
                let shell = ModelEntity(
                    mesh: .generateSphere(radius: 0.12),
                    materials: [beetle]
                )
                // Elongated elytra silhouette
                shell.scale = SIMD3(1.15, 0.8, 1.5)
                shell.name = keep
                shell.position = SIMD3(0, -0.02, 0)
                root.addChild(shell)
            }

        case .feather:
            guard let feather = featherMaterial else { return }
            if let vane = root.findEntity(named: keep) {
                assign(feather, to: vane)
            } else {
                let vane = ModelEntity(
                    mesh: .generatePlane(width: 0.34, height: 0.2),
                    materials: [feather]
                )
                vane.name = keep
                vane.position = SIMD3(0, -0.02, -0.02)
                root.addChild(vane)
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

        case .hologram:
            guard let holo = hologramMaterial else { return }
            if let card = root.findEntity(named: keep) {
                assign(holo, to: card)
            } else {
                let card = ModelEntity(
                    mesh: .generatePlane(width: 0.28, height: 0.16),
                    materials: [holo]
                )
                card.name = keep
                card.position = SIMD3(0, -0.02, 0)
                root.addChild(card)
            }

        case .lcd:
            guard let lcd = lcdMaterial else { return }
            if let panel = root.findEntity(named: keep) {
                assign(lcd, to: panel)
            } else {
                let panel = ModelEntity(
                    mesh: .generatePlane(width: 0.3, height: 0.22),
                    materials: [lcd]
                )
                panel.name = keep
                panel.position = SIMD3(0, -0.02, 0)
                root.addChild(panel)
            }

        case .newton:
            guard let newton = newtonMaterial else { return }
            if let plate = root.findEntity(named: keep) {
                assign(newton, to: plate)
            } else {
                let plate = ModelEntity(
                    mesh: .generatePlane(width: 0.26, height: 0.26),
                    materials: [newton]
                )
                plate.name = keep
                plate.position = SIMD3(0, -0.02, 0)
                root.addChild(plate)
            }

        case .pearl:
            guard let pearl = pearlMaterial else { return }
            if let orb = root.findEntity(named: keep) {
                assign(pearl, to: orb)
            } else {
                let orb = ModelEntity(
                    mesh: .generateSphere(radius: 0.1),
                    materials: [pearl]
                )
                orb.name = keep
                orb.position = SIMD3(0, -0.02, 0)
                root.addChild(orb)
            }

        case .dragonfly:
            guard let wing = dragonflyMaterial else { return }
            if let vane = root.findEntity(named: keep) {
                assign(wing, to: vane)
            } else {
                let vane = ModelEntity(
                    mesh: .generatePlane(width: 0.32, height: 0.2),
                    materials: [wing]
                )
                vane.name = keep
                vane.position = SIMD3(0, -0.02, 0)
                root.addChild(vane)
            }

        case .chameleon:
            guard let skin = chameleonMaterial else { return }
            if let patch = root.findEntity(named: keep) {
                assign(skin, to: patch)
            } else {
                let patch = ModelEntity(
                    mesh: .generateSphere(radius: 0.11),
                    materials: [skin]
                )
                patch.name = keep
                patch.position = SIMD3(0, -0.02, 0)
                root.addChild(patch)
            }

        case .scarab:
            guard let scarab = scarabMaterial else { return }
            if let shell = root.findEntity(named: keep) {
                assign(scarab, to: shell)
            } else {
                let shell = ModelEntity(
                    mesh: .generateSphere(radius: 0.12),
                    materials: [scarab]
                )
                shell.scale = SIMD3(1.15, 0.8, 1.5)
                shell.name = keep
                shell.position = SIMD3(0, -0.02, 0)
                root.addChild(shell)
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

    private func pushBeetleParameters() {
        guard var beetle = beetleMaterial else { return }
        setParam(&beetle, "GreenBand", .float(beetleGreenBand))
        setParam(&beetle, "RainbowMix", .float(beetleRainbowMix))
        setParam(&beetle, "Gain", .float(beetleGain))
        beetleMaterial = beetle
        materialRevision += 1
    }

    private func pushFeatherParameters() {
        guard var feather = featherMaterial else { return }
        setParam(&feather, "ThicknessBias", .float(featherThicknessBias))
        setParam(&feather, "StripeCount", .float(featherStripeCount))
        setParam(&feather, "GlitterScale", .float(featherGlitterScale))
        setParam(&feather, "Gain", .float(featherGain))
        featherMaterial = feather
        materialRevision += 1
    }

    private func pushHologramParameters() {
        guard var holo = hologramMaterial else { return }
        setParam(&holo, "Rows", .float(holoRows))
        setParam(&holo, "SlideAmount", .float(holoSlideAmount))
        setParam(&holo, "StripeContrast", .float(holoStripeContrast))
        setParam(&holo, "Gain", .float(holoGain))
        hologramMaterial = holo
        materialRevision += 1
    }

    private func pushLCDParameters() {
        guard var lcd = lcdMaterial else { return }
        setParam(&lcd, "Voltage", .float(lcdVoltage))
        setParam(&lcd, "PixelScale", .float(lcdPixelScale))
        setParam(&lcd, "TintAmount", .float(lcdTintAmount))
        setParam(&lcd, "Gain", .float(lcdGain))
        lcdMaterial = lcd
        materialRevision += 1
    }

    private func pushNewtonParameters() {
        guard var newton = newtonMaterial else { return }
        setParam(&newton, "RingScale", .float(newtonRingScale))
        setParam(&newton, "NoiseAmount", .float(newtonNoise))
        setParam(&newton, "Gain", .float(newtonGain))
        newtonMaterial = newton
        materialRevision += 1
    }

    private func pushPearlParameters() {
        guard var pearl = pearlMaterial else { return }
        setParam(&pearl, "ThicknessBias", .float(pearlThicknessBias))
        setParam(&pearl, "CurvatureAmount", .float(pearlCurvature))
        setParam(&pearl, "TintHue", .float(pearlTintHue))
        setParam(&pearl, "Luster", .float(30))
        setParam(&pearl, "Gain", .float(pearlGain))
        pearlMaterial = pearl
        materialRevision += 1
    }

    private func pushDragonflyParameters() {
        guard var wing = dragonflyMaterial else { return }
        setParam(&wing, "ThicknessBias", .float(dragonflyThicknessBias))
        setParam(&wing, "CrossVeins", .float(dragonflyCrossVeins))
        setParam(&wing, "LongVeins", .float(7))
        setParam(&wing, "VeinWidth", .float(dragonflyVeinWidth))
        setParam(&wing, "MembraneOpacity", .float(dragonflyMembraneOpacity))
        setParam(&wing, "Gain", .float(dragonflyGain))
        dragonflyMaterial = wing
        materialRevision += 1
    }

    private func pushChameleonParameters() {
        guard var skin = chameleonMaterial else { return }
        setParam(&skin, "CellScale", .float(chameleonCellScale))
        setParam(&skin, "HueSpeed", .float(chameleonHueSpeed))
        setParam(&skin, "ViewSwing", .float(chameleonViewSwing))
        setParam(&skin, "Gain", .float(chameleonGain))
        chameleonMaterial = skin
        materialRevision += 1
    }

    private func pushScarabParameters() {
        guard var scarab = scarabMaterial else { return }
        setParam(&scarab, "ThicknessBias", .float(scarabThicknessBias))
        setParam(&scarab, "BranchShift", .float(scarabBranchShift))
        setParam(&scarab, "Analyzer", .float(scarabAnalyzer))
        setParam(&scarab, "HandednessGain", .float(1.5))
        setParam(&scarab, "Gain", .float(scarabGain))
        scarabMaterial = scarab
        materialRevision += 1
    }

    private func material(for effect: OpticsEffect) -> ShaderGraphMaterial? {
        switch effect {
        case .thinFilm: return filmMaterial
        case .grating: return gratingMaterial
        case .nacre: return nacreMaterial
        case .opal: return opalMaterial
        case .birefringence: return birefringenceMaterial
        case .speckle: return speckleMaterial
        case .morpho: return morphoMaterial
        case .beetle: return beetleMaterial
        case .feather: return featherMaterial
        case .hologram: return hologramMaterial
        case .lcd: return lcdMaterial
        case .newton: return newtonMaterial
        case .pearl: return pearlMaterial
        case .dragonfly: return dragonflyMaterial
        case .chameleon: return chameleonMaterial
        case .scarab: return scarabMaterial
        default: return nil
        }
    }

    private func store(_ material: ShaderGraphMaterial, for effect: OpticsEffect) {
        switch effect {
        case .thinFilm: filmMaterial = material
        case .grating: gratingMaterial = material
        case .nacre: nacreMaterial = material
        case .opal: opalMaterial = material
        case .birefringence: birefringenceMaterial = material
        case .speckle: speckleMaterial = material
        case .morpho: morphoMaterial = material
        case .beetle: beetleMaterial = material
        case .feather: featherMaterial = material
        case .hologram: hologramMaterial = material
        case .lcd: lcdMaterial = material
        case .newton: newtonMaterial = material
        case .pearl: pearlMaterial = material
        case .dragonfly: dragonflyMaterial = material
        case .chameleon: chameleonMaterial = material
        case .scarab: scarabMaterial = material
        default: break
        }
    }

    private func pushIntensity(for effect: OpticsEffect) {
        guard var m = material(for: effect) else { return }
        setParam(&m, "Intensity", .float(intensity(for: effect)))
        store(m, for: effect)
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
