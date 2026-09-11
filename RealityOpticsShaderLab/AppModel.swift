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

    init(id: String, label: String, range: ClosedRange<Float>, get: @escaping () -> Float, set: @escaping (Float) -> Void) {
        self.id = id
        self.label = label
        self.range = range
        self.get = get
        self.set = { value in
            guard value.isFinite else { return }
            let clamped = min(max(value, range.lowerBound), range.upperBound)
            guard clamped != get() else { return }
            set(clamped)
        }
    }
}

@MainActor
@Observable
final class AppModel {

    var selectedEffect: OpticsEffect = .thinFilm
    var previewGroup: PreviewGroup = .basic
    var previewBaseColor: PreviewColor? {
        didSet {
            guard previewBaseColor != oldValue else { return }
            for effect in OpticsEffect.allCases { pushPreviewAppearance(for: effect) }
        }
    }
    private(set) var previewBaseAmount: Float = 0.35

    func setPreviewBaseAmount(_ value: Float) {
        guard value.isFinite else { return }
        let clamped = min(max(value, 0), 1)
        guard clamped != previewBaseAmount else { return }
        previewBaseAmount = clamped
        for effect in OpticsEffect.allCases { pushPreviewAppearance(for: effect) }
    }

    init() {
        #if DEBUG
        if ProcessInfo.processInfo.environment["OPTICS_AUDIT"] == "1"
            || ProcessInfo.processInfo.environment["OPTICS_PREVIEW_AUDIT"] == "1" {
            isAnimating = false
        }
        #endif
        // Launcher override for automated verification:
        // SIMCTL_CHILD_OPTICS_EFFECT=nacre xcrun simctl launch ...
        if let raw = ProcessInfo.processInfo.environment["OPTICS_EFFECT"],
           let effect = OpticsEffect(rawValue: raw) {
            selectedEffect = effect
        }
        // SIMCTL_CHILD_OPTICS_INTENSITY=0.2 — applied once materials exist.
        if let raw = ProcessInfo.processInfo.environment["OPTICS_INTENSITY"],
           let value = Float(raw), value.isFinite {
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

    // A 216 nm chitin film has a visible reflection maximum at 4nd/3 ≈ 449 nm.
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
    /// 0 renders the selected base color, 1 is the optical look, >1 exaggerates it.
    private var intensities: [OpticsEffect: Float] = [:]

    func intensity(for effect: OpticsEffect) -> Float {
        intensities[effect] ?? 1
    }

    func setIntensity(_ value: Float, for effect: OpticsEffect) {
        guard value.isFinite else { return }
        intensities[effect] = min(max(value, 0), 2)
        pushIntensity(for: effect)
    }

    // MARK: - Built artifacts

    private var additionalMaterials: [OpticsEffect: ShaderGraphMaterial] = [:]
    private var additionalValues: [OpticsEffect: [String: Float]] = [:]

    private func additionalValue(_ control: EffectControl, for effect: OpticsEffect) -> Float {
        additionalValues[effect]?[control.name] ?? control.value
    }

    private func pushAdditionalParameters(for effect: OpticsEffect) {
        guard var material = additionalMaterials[effect] else { return }
        for control in effect.additionalControls {
            setParam(&material, control.name, .float(additionalValue(control, for: effect)))
        }
        additionalMaterials[effect] = material
        materialRevision += 1
    }

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
    private(set) var statusMessage = "Booting optics…"

    /// Bumped whenever a material is (re)created or re-parameterized.
    /// The scene view syncs entities against this instead of reading materials
    /// inside RealityView's make closure (which would re-run and duplicate the
    /// scene on every observable write).
    private(set) var materialRevision = 0

    /// Set once by the scene; used by the revision-driven sync to reach entities.
    weak var sceneRoot: Entity?

    private var rebuildTask: Task<Void, Never>?
    @ObservationIgnored private let resources = OpticsResources()
    @ObservationIgnored private let meshes = OpticsMeshes()
    @ObservationIgnored private var loadTasks: [OpticsEffect: Task<Void, Error>] = [:]
    @ObservationIgnored private var parameterHandles: [String: MaterialParameters.Handle] = [:]
    private var appliedFilmIOR: Float?
    private let launchTime = ContinuousClock.now
    private var reportedFirstReady = false
    var isLoadingSelected: Bool { material(for: selectedEffect) == nil }
    private var parameterErrors: [String] = []

    func report(error: String) {
        statusMessage = error
    }

    // MARK: - Per-effect settings

    func settingsFor(_ effect: OpticsEffect) -> [SettingSpec] {
        var specs = effectSettings(effect)
        // The master intensity leads every effect's panel: it scales how far
        // the optical colors deviate from the selected base (0 = off).
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
                SettingSpec(id: "ior", label: "Film IOR", range: 1.2...1.45,
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
                SettingSpec(id: "mBias", label: "Thickness (blue band)", range: 0.12...0.45,
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
                SettingSpec(id: "sAnalyzer", label: "Analyzer blend (R → L)", range: 0...1,
                            get: { [weak self] in self?.scarabAnalyzer ?? 0 },
                            set: { [weak self] in self?.scarabAnalyzer = $0 }),
                SettingSpec(id: "sGain", label: "Gain", range: 0.5...3,
                            get: { [weak self] in self?.scarabGain ?? 0 },
                            set: { [weak self] in self?.scarabGain = $0 }),
            ]
        default:
            return effect.additionalControls.map { control in
                SettingSpec(id: control.name, label: control.label, range: control.range,
                    get: { [weak self] in self?.additionalValue(control, for: effect) ?? control.value },
                    set: { [weak self] value in
                        guard let self else { return }
                        self.additionalValues[effect, default: [:]][control.name] = value
                        self.pushAdditionalParameters(for: effect)
                    })
            }
        }
    }

    // MARK: - Build

    /// SwiftUI cancels the previous selection's waiter; shared resource work
    /// finishes into the cache and cannot overwrite the new selection's status.
    func prepareSelectedEffect() async {
        let effect = selectedEffect
        let start = ContinuousClock.now
        statusMessage = "正在加载\(effect.menuTitle)…"
        do {
            try await ensureLoaded(effect)
            try Task.checkCancellation()
            guard selectedEffect == effect else { return }
            if effect == .thinFilm, appliedFilmIOR != soapIOR {
                rebuildFilmLUT()
                await rebuildTask?.value
            }
            try Task.checkCancellation()
            guard selectedEffect == effect else { return }
            // A failed or superseded IOR update must not be reported as Ready.
            if effect == .thinFilm, appliedFilmIOR != soapIOR { return }
            if parameterErrors.isEmpty { statusMessage = "Ready" }
            if !reportedFirstReady {
                reportedFirstReady = true
                print("OPTICS_PERF FIRST_READY \(effect.rawValue): \(launchTime.duration(to: .now))")
            }
            print("OPTICS_PERF SELECT \(effect.rawValue): \(start.duration(to: .now)); templates=\(resources.templateCount), textures=\(resources.textureCount), textureBytes=\(resources.textureBytes)")
            fflush(stdout)
        } catch is CancellationError {
            // A newer selection owns the visible status.
        } catch {
            if selectedEffect == effect { report(error: "加载失败：\(error.localizedDescription)") }
        }
    }

    private func ensureLoaded(_ effect: OpticsEffect) async throws {
        if material(for: effect) != nil { return }
        if let pending = loadTasks[effect] { return try await pending.value }
        let task = Task { @MainActor in
            let initialIOR = soapIOR
            let material = try await resources.material(for: effect, soapIOR: initialIOR)
            store(material, for: effect)
            if effect == .thinFilm { appliedFilmIOR = initialIOR }
            // Use current controls, not the values from when loading began.
            pushParameters(for: effect)
            pushIntensity(for: effect)
            pushPreviewAppearance(for: effect)
        }
        loadTasks[effect] = task
        defer { loadTasks[effect] = nil }
        try await task.value
    }

    private func pushParameters(for effect: OpticsEffect) {
        switch effect {
        case .thinFilm: pushFilmParameters()
        case .grating: pushGratingParameters()
        case .nacre: pushNacreParameters()
        case .opal: pushOpalParameters()
        case .birefringence: pushBirefringenceParameters()
        case .speckle: pushSpeckleParameters()
        case .morpho: pushMorphoParameters()
        case .beetle: pushBeetleParameters()
        case .feather: pushFeatherParameters()
        case .hologram: pushHologramParameters()
        case .lcd: pushLCDParameters()
        case .newton: pushNewtonParameters()
        case .pearl: pushPearlParameters()
        case .dragonfly: pushDragonflyParameters()
        case .chameleon: pushChameleonParameters()
        case .scarab: pushScarabParameters()
        default: pushAdditionalParameters(for: effect)
        }
    }

    #if DEBUG
    /// Opt-in development smoke test. Exercises real material loading, binding,
    /// scene selection, and minimum/maximum controls without simulated gestures.
    /// The external capture script takes a screenshot at each DEFAULT marker.
    func runShaderAuditIfRequested() async throws {
        guard ProcessInfo.processInfo.environment["OPTICS_AUDIT"] == "1" else { return }
        try await ensureLoaded(selectedEffect)
        let grouped = OpticsEffectGroup.allCases.flatMap(\.effects)
        guard grouped.count == OpticsEffect.allCases.count,
              Set(grouped) == Set(OpticsEffect.allCases) else {
            throw NSError(domain: "OpticsAuditCatalog", code: 1)
        }
        let originalEffect = selectedEffect
        let originalAnimation = isAnimating
        defer {
            selectedEffect = originalEffect
            isAnimating = originalAnimation
        }
        isAnimating = false
        let effects = ProcessInfo.processInfo.environment["OPTICS_AUDIT_ONLY_SELECTED"] == "1"
            ? [originalEffect] : OpticsEffect.allCases
        for effect in effects {
            selectedEffect = effect
            try await ensureLoaded(effect)
            let specs = settingsFor(effect)
            let saved = specs.map { $0.get() }
            defer { for (spec, value) in zip(specs, saved) { spec.set(value) } }
            for phase in ["DEFAULT", "MIN", "MAX"] {
                if phase != "DEFAULT" {
                    // Intensity=0 hides every other parameter's minimum. Keep
                    // the optical branch visible while checking physical controls.
                    for spec in specs where spec.id != "intensity" {
                        spec.set(phase == "MIN" ? spec.range.lowerBound : spec.range.upperBound)
                    }
                    setIntensity(1, for: effect)
                    await rebuildTask?.value
                }
                // Allow the RealityView update and GPU shader pipeline to run.
                try await Task.sleep(for: .seconds(1))
                guard sceneRoot?.children.count == 2,
                      previewGroup.shapes.allSatisfy({ sceneRoot?.findEntity(named: $0.rawValue) != nil }),
                      material(for: effect) != nil, parameterErrors.isEmpty else {
                    throw NSError(domain: "OpticsAudit", code: 2,
                                  userInfo: [NSLocalizedDescriptionKey: "Scene/binding failed: \(effect.rawValue)"])
                }
                print("OPTICS_AUDIT \(phase) \(effect.rawValue) \(specs.count) parameters")
                fflush(stdout)
                if phase == "DEFAULT" { try await Task.sleep(for: .seconds(3)) }
            }
            // Capture meaningful comparison states at nominal gain/path length,
            // rather than relying on simultaneously saturated MAX controls.
            let comparisons: [(String, String, Float)]
            switch effect {
            case .dichroic:
                comparisons = [("dichroic-reflection", "Transmission", 0),
                               ("dichroic-transmission", "Transmission", 1)]
            case .pleochroism:
                comparisons = [("pleochroism-third-axis", "AxisTilt", 90)]
            default: comparisons = []
            }
            for (name, control, value) in comparisons {
                for (spec, savedValue) in zip(specs, saved) { spec.set(savedValue) }
                setIntensity(1, for: effect)
                specs.first { $0.id == control }?.set(value)
                try await Task.sleep(for: .seconds(1))
                guard parameterErrors.isEmpty else { throw NSError(domain: "OpticsAuditComparison", code: 1) }
                print("OPTICS_AUDIT CAPTURE \(name)")
                fflush(stdout)
                try await Task.sleep(for: .seconds(3))
            }
        }
        await rebuildTask?.value
        print("OPTICS_AUDIT PASS: \(effects.count) materials, default/min/max scenes, no binding failures")
        fflush(stdout)
    }
    /// Explicit development regression for lazy loading, coalescing and instances.
    func runPerformanceAuditIfRequested() async throws {
        guard ProcessInfo.processInfo.environment["OPTICS_PERF_AUDIT"] == "1" else { return }
        defer { fflush(stdout) }
        func check(_ condition: @autoclosure () -> Bool, _ message: String) throws {
            if !condition() { throw NSError(domain: "OpticsPerformance", code: 1,
                userInfo: [NSLocalizedDescriptionKey: message]) }
        }
        let original = selectedEffect
        let originalIOR = soapIOR
        let originalGain = nacreGain
        defer {
            selectedEffect = original
            soapIOR = originalIOR
            nacreGain = originalGain
        }
        try await ensureLoaded(.thinFilm)
        try check(resources.templateCount == 1 && resources.textureCount == 1, "Cold start eagerly loaded extra resources")
        print("OPTICS_PERF_AUDIT lazy start: 1 template / 1 LUT")

        async let nacreA: Void = ensureLoaded(.nacre)
        async let nacreB: Void = ensureLoaded(.nacre)
        async let morpho: Void = ensureLoaded(.morpho)
        _ = try await (nacreA, nacreB, morpho)
        try check(resources.templateCount == 1 && resources.textureCount == 3, "Film-family template / request reuse failed")
        try check(nacreMaterial?.getParameter(name: "Opacity") == .float(1), "Nacre opacity changed")
        try check(morphoMaterial?.getParameter(name: "Opacity") == .float(0.92), "Morpho opacity changed")
        let filmGainBefore = filmMaterial?.getParameter(name: "Gain")
        let morphoGainBefore = morphoMaterial?.getParameter(name: "Gain")
        nacreGain = 2.7
        try check(filmMaterial?.getParameter(name: "Gain") == filmGainBefore
            && morphoMaterial?.getParameter(name: "Gain") == morphoGainBefore,
            "One material instance mutated another instance")
        nacreGain = originalGain
        print("OPTICS_PERF_AUDIT instances: 3 effects / 1 template; independent parameters")

        let before = resources.textureBuildCount
        async let textureA = resources.texture(.film(ior: 1.234))
        async let textureB = resources.texture(.film(ior: 1.234))
        async let textureC = resources.texture(.film(ior: 1.234))
        let (a, b, c) = try await (textureA, textureB, textureC)
        try check(a === b && b === c && resources.textureBuildCount == before + 1, "Duplicate LUT compute dispatch")
        print("OPTICS_PERF_AUDIT coalescing: 3 concurrent requests / 1 dispatch")

        // Cancel the waiter while a cold material is loading. Its shared task
        // may complete into cache, but it must not replace the selected status.
        selectedEffect = .hologram
        let obsolete = Task { await prepareSelectedEffect() }
        try await Task.sleep(for: .milliseconds(10))
        selectedEffect = .thinFilm
        obsolete.cancel()
        await prepareSelectedEffect()
        await obsolete.value
        try await ensureLoaded(.hologram)
        try check(selectedEffect == .thinFilm && statusMessage == "Ready", "Stale selection overwrote current state")
        print("OPTICS_PERF_AUDIT cancelled selection: current effect remains Ready")

        let dragBefore = resources.textureBuildCount
        for i in 0..<30 { soapIOR = 1.2 + Float(i) * 0.005 }
        await rebuildTask?.value
        try check(appliedFilmIOR == soapIOR && resources.textureBuildCount <= dragBefore + 1,
            "IOR drag did not coalesce / last value lost")
        // Returning to the currently displayed value cancels an in-flight edit.
        let displayed = soapIOR
        soapIOR = 1.44
        soapIOR = displayed
        await rebuildTask?.value
        try check(statusMessage == "Ready" && appliedFilmIOR == displayed, "Cancelled IOR edit left stale loading status")
        for value: Float in [1.21, 1.24, 1.27, 1.30, 1.36, 1.40] {
            soapIOR = value
            await rebuildTask?.value
        }
        try check(resources.variableTextureCount <= 4, "IOR cache grew beyond four variants")
        soapIOR = originalIOR
        await rebuildTask?.value
        print("OPTICS_PERF_AUDIT IOR: last edit wins; four-variant LRU bound")

        for effect in OpticsEffect.allCases { try await ensureLoaded(effect) }
        try check(resources.templateCount == Set(OpticsEffect.allCases.map(\.templateName)).count, "Unexpected template count")
        let builds = resources.textureBuildCount
        let loads = resources.templateLoadCount
        // Added families also share only immutable definitions, never slider state.
        for (edited, neighbor, name) in [(OpticsEffect.catEye, OpticsEffect.starGem, "Gain"),
                                         (.oilFilm, .titanium, "Thickness"),
                                         (.dichroic, .lensCoating, "Thickness")] {
            let spec = settingsFor(edited).first { $0.id == name }!
            let saved = spec.get()
            let other = material(for: neighbor)?.getParameter(name: name)
            spec.set(spec.range.lowerBound)
            try check(material(for: neighbor)?.getParameter(name: name) == other,
                "Shared extended template leaked parameters to another effect")
            spec.set(saved)
        }
        try check(additionalMaterials[.catEye]?.getParameter(name: "StarAmount") == .float(0)
            && additionalMaterials[.starGem]?.getParameter(name: "StarAmount") == .float(1),
            "Cat-eye and star modes were not isolated")
        let channel = settingsFor(.dichroic).first { $0.id == "Transmission" }!
        let savedChannel = channel.get()
        try check(material(for: .dichroic)?.getParameter(name: "TransmissionLUT") == nil,
            "Dichroic retained a duplicate transmission lookup")
        try check(resources.textureCount == resources.variableTextureCount + 9,
            "Unexpected fixed lookup allocation")
        channel.set(1); channel.set(savedChannel)
        try check(resources.textureBuildCount == builds && resources.templateLoadCount == loads,
            "Extended controls rebuilt immutable resources")
        print("OPTICS_PERF_AUDIT extended: isolated cat/star and coating parameters; cached R/T channel")
        let start = ContinuousClock.now
        for _ in 0..<10 {
            for effect in OpticsEffect.allCases { try await ensureLoaded(effect) }
        }
        try check(resources.textureBuildCount == builds && resources.templateLoadCount == loads, "Warm selections rebuilt resources")
        try check(parameterErrors.isEmpty, "Parameter binding failed")
        print("OPTICS_PERF_AUDIT warm: \(OpticsEffect.allCases.count * 10) cached material requests in \(start.duration(to: .now)); zero rebuilds")
        print("OPTICS_PERF_AUDIT PASS: lazy/coalesced resources, isolated material instances, cancelled selection, bounded IOR cache; templates=\(resources.templateCount), textures=\(resources.textureCount), textureBytes=\(resources.textureBytes)")
        fflush(stdout)
    }
    func runPreviewAuditIfRequested() async throws {
        guard ProcessInfo.processInfo.environment["OPTICS_PREVIEW_AUDIT"] == "1" else { return }
        func check(_ condition: @autoclosure () -> Bool, _ message: String) throws {
            if !condition() { throw NSError(domain: "OpticsPreview", code: 1,
                userInfo: [NSLocalizedDescriptionKey: message]) }
        }
        let savedEffect = selectedEffect
        let savedColor = previewBaseColor
        let savedAmount = previewBaseAmount
        let savedGroup = previewGroup
        let savedAnimation = isAnimating
        defer {
            selectedEffect = savedEffect
            previewBaseColor = savedColor
            setPreviewBaseAmount(savedAmount)
            previewGroup = savedGroup
            isAnimating = savedAnimation
            syncSceneObjects()
            fflush(stdout)
        }
        isAnimating = false
        try await ensureLoaded(selectedEffect)
        for _ in 0..<100 where sceneRoot == nil { try await Task.sleep(for: .milliseconds(20)) }
        guard let root = sceneRoot else { throw NSError(domain: "OpticsPreview", code: 2) }

        func checkPair() throws {
            syncSceneObjects()
            syncSceneObjects() // Repeated updates must not add duplicate samples.
            try check(root.children.count == 2, "Expected exactly two live samples")
            for shape in previewGroup.shapes {
                let sample = root.children.first(where: { $0.name == shape.rawValue })
                let material = sample?.components[ModelComponent.self]?.materials.first as? ShaderGraphMaterial
                try check(material != nil, "Missing sample material: \(shape.rawValue)")
                try check(material?.getParameter(name: "BaseAmount") == .float(previewBaseColor == nil ? 0 : previewBaseAmount), "Stale sample base amount")
                guard case .color(let actualColor) = material?.getParameter(name: "BaseColor"),
                      let components = actualColor.converted(to: PreviewColor.materialColorSpace, intent: .relativeColorimetric, options: nil)?.components else {
                    throw NSError(domain: "OpticsPreview", code: 3)
                }
                let expected = (previewBaseColor?.materialColor ?? PreviewColor.originalMaterialColor).components!
                try check(components.count == expected.count && zip(components, expected).allSatisfy { abs($0 - $1) < 0.000001 }, "Stale sample base color")
                try check(material?.getParameter(name: "Intensity") == .float(intensity(for: selectedEffect)), "Samples differ in optical intensity")
            }
        }

        // These controls must work during a cold start without warming other effects.
        let coldLoads = resources.templateLoadCount
        let coldBuilds = resources.textureBuildCount
        for group in PreviewGroup.allCases {
            previewGroup = group
            for color in PreviewColor.allCases {
                previewBaseColor = color
                try checkPair()
            }
        }
        try check(resources.templateLoadCount == coldLoads && resources.textureBuildCount == coldBuilds, "Preview changes rebuilt GPU resources")

        // Every template (including shared film instances) binds to both shape groups.
        for effect in OpticsEffect.allCases {
            selectedEffect = effect
            try await ensureLoaded(effect)
            for group in PreviewGroup.allCases {
                previewGroup = group
                for color in PreviewColor.allCases {
                    previewBaseColor = color
                    try checkPair()
                    for amount: Float in [0, 0.35, 1] {
                        setPreviewBaseAmount(amount)
                        try checkPair()
                    }
                }
            }
        }
        try check(parameterErrors.isEmpty, "Preview shader binding failed")
        try check(resources.templateCount == Set(OpticsEffect.allCases.map(\.templateName)).count, "Paired samples duplicated material templates")
        print("OPTICS_PREVIEW_AUDIT bindings: \(OpticsEffect.allCases.count) effects / 2 groups / 9 colors / 3 amounts; two live samples; no color/group resource builds")

        func capture(_ name: String) async throws {
            await prepareSelectedEffect()
            try checkPair()
            try await Task.sleep(for: .seconds(1))
            print("OPTICS_PREVIEW_AUDIT CAPTURE \(name)")
            fflush(stdout)
            try await Task.sleep(for: .seconds(3))
        }
        selectedEffect = .thinFilm
        previewGroup = .basic
        previewBaseColor = nil
        try await capture("basic-original")
        previewBaseColor = .red
        setPreviewBaseAmount(0.35)
        try await capture("basic-red")
        previewBaseColor = .gray
        setPreviewBaseAmount(1)
        try await capture("basic-gray-only")
        selectedEffect = .grating
        previewGroup = .instruments
        previewBaseColor = nil
        try await capture("instruments-original")
        previewBaseColor = .white
        setPreviewBaseAmount(0.35)
        try await capture("instruments-white")
        print("OPTICS_PREVIEW_AUDIT PASS: paired geometry, all material base colors, original restore, shared resources")
        fflush(stdout)
    }
    #endif

    // MARK: - Scene object management

    /// Both samples share the selected material and its LUTs; only two are live.
    func syncSceneObjects() {
        guard let root = sceneRoot else { return }
        guard let material = material(for: selectedEffect) else {
            root.children.removeAll()
            return
        }
        let shapes = previewGroup.shapes
        for child in Array(root.children) where !shapes.contains(where: { $0.rawValue == child.name }) {
            child.removeFromParent()
        }
        do {
            for (index, shape) in shapes.enumerated() {
                if let current = root.children.first(where: { $0.name == shape.rawValue }) {
                    assign(material, to: current)
                } else {
                    let object = try meshes.makeEntity(for: shape, material: material)
                    object.position = SIMD3(index == 0 ? -0.17 : 0.17, 0, 0)
                    root.addChild(object)
                }
            }
        } catch { report(error: "模型加载失败：\(error.localizedDescription)") }
    }

    private func assign(_ material: ShaderGraphMaterial, to entity: Entity) {
        guard var component = entity.components[ModelComponent.self] else { return }
        component.materials = [material]
        entity.components[ModelComponent.self] = component
    }

    // MARK: - Hot updates

    func rebuildFilmLUT() {
        rebuildTask?.cancel()
        // Defer changes to an invisible or not-yet-loaded soap bubble.
        guard filmMaterial != nil, selectedEffect == .thinFilm else { return }
        guard appliedFilmIOR != soapIOR else {
            if parameterErrors.isEmpty { statusMessage = "Ready" }
            return
        }
        let ior = soapIOR
        statusMessage = "正在更新薄膜…"
        rebuildTask = Task { @MainActor in
            do {
                // Coalesce a continuous slider drag before dispatching GPU work.
                try await Task.sleep(for: .milliseconds(120))
                let texture = try await resources.texture(.film(ior: ior))
                try Task.checkCancellation()
                guard soapIOR == ior, var material = filmMaterial else { return }
                setParam(&material, "FilmLUT", .textureResource(texture.resource))
                filmMaterial = material
                appliedFilmIOR = ior
                materialRevision += 1
                if selectedEffect == .thinFilm, parameterErrors.isEmpty { statusMessage = "Ready" }
            } catch is CancellationError {
            } catch {
                if selectedEffect == .thinFilm { report(error: "薄膜更新失败：\(error.localizedDescription)") }
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
        default: return additionalMaterials[effect]
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
        default: additionalMaterials[effect] = material
        }
    }

    private func pushIntensity(for effect: OpticsEffect) {
        guard var m = material(for: effect) else { return }
        setParam(&m, "Intensity", .float(intensity(for: effect)))
        store(m, for: effect)
        materialRevision += 1
    }

    private func pushPreviewAppearance(for effect: OpticsEffect) {
        guard var material = material(for: effect) else { return }
        // A nil selection restores the exact original neutral-gray intensity base.
        let color = previewBaseColor?.materialColor ?? PreviewColor.originalMaterialColor
        setParam(&material, "BaseColor", .color(color))
        setParam(&material, "BaseAmount", .float(previewBaseColor == nil ? 0 : previewBaseAmount))
        store(material, for: effect)
        materialRevision += 1
    }

    private func setParam(_ material: inout ShaderGraphMaterial, _ name: String, _ value: MaterialParameters.Value) {
        do {
            let handle = parameterHandles[name] ?? ShaderGraphMaterial.parameterHandle(name: name)
            parameterHandles[name] = handle
            guard material.getParameter(handle: handle) != value else { return }
            try material.setParameter(handle: handle, value: value)
        } catch {
            // A typo'd parameter name must be visible, not silently ignored.
            let message = "setParameter(\(name)): \(error.localizedDescription)"
            parameterErrors.append(message)
            statusMessage = message
            print("RealityOpticsShaderLab: \(message)")
        }
    }
}
