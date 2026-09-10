import Foundation

/// Catalog of wave-optics effects demoed by the app.
/// Implemented ones ship a physics LUT + shader graph; the rest are listed
/// with their planned approach and render placeholder geometry until wired up.
enum OpticsEffect: String, CaseIterable, Identifiable {
    case thinFilm
    case grating
    case nacre
    case opal
    case birefringence
    case speckle
    case morpho
    case beetle
    case feather

    var id: String { rawValue }

    var title: String {
        switch self {
        case .thinFilm: return "薄膜干涉 · 肥皂泡（Thin-Film Interference）"
        case .grating: return "衍射光栅 · CD 光盘（Diffraction Grating）"
        case .nacre: return "珍珠母/珠光（Nacre, Pearlescence）"
        case .opal: return "欧泊/猫眼石（Opal, Play-of-Color）"
        case .birefringence: return "双折射/光弹性（Birefringence, Photoelasticity）"
        case .speckle: return "激光散斑（Laser Speckle）"
        case .morpho: return "闪蝶翅膀（Morpho Butterfly）"
        case .beetle: return "吉丁虫/金龟子鞘翅（Beetle Shell）"
        case .feather: return "蜂鸟/孔雀羽（Iridescent Feather）"
        }
    }

    /// Short label for the picker menu.
    var menuTitle: String {
        switch self {
        case .thinFilm: return "薄膜干涉 · 肥皂泡"
        case .grating: return "衍射光栅 · CD"
        case .nacre: return "珍珠母/珠光"
        case .opal: return "欧泊/猫眼石"
        case .birefringence: return "双折射/光弹性"
        case .speckle: return "激光散斑"
        case .morpho: return "闪蝶翅膀"
        case .beetle: return "吉丁虫鞘翅"
        case .feather: return "蜂鸟/孔雀羽"
        }
    }

    /// What the viewer sees in the real phenomenon.
    var subtitle: String {
        switch self {
        case .thinFilm:
            return "肥皂泡/油膜的彩虹色，随膜厚与视角变化（已实现）"
        case .grating:
            return "CD/DVD 盘面、黑胶唱片的彩虹反光，对视角偏移极其敏感（已实现）"
        case .nacre:
            return "贝壳内壁、珍珠的柔和变色，比肥皂泡更低饱和更柔和"
        case .opal:
            return "蛋白石里二氧化硅微球密堆积形成三维光子晶体，闪烁的斑块状变色"
        case .birefringence:
            return "偏振片下应力塑料和尺子边缘的彩色条纹、肥皂泡受张力时的彩色流动纹"
        case .speckle:
            return "相干光照在粗糙表面上的细密颗粒状明暗图样，随观察者移动而流动"
        case .morpho:
            return "树状多层纳米结构产生超宽角虹彩——蓝色极亮且几乎全视角可见"
        case .beetle:
            return "椭圆偏振虹彩：高饱和金属绿 + 转动时的彩虹条带"
        case .feather:
            return "多层膜 + 各向异性高光 + glitter 的组合结构色"
        }
    }

    /// Planned implementation approach (from the optics survey).
    var mechanism: String {
        switch self {
        case .thinFilm:
            return "已实现：精确 Fresnel 振幅 + Airy 级数光谱积分，烘焙厚度×视角 LUT"
        case .grating:
            return "已实现：光栅方程 sinθi − sinθo = mλ/d，多阶光谱合成烘焙 LUT"
        case .nacre:
            return "2~3 层不同厚度的薄膜项取平均，再按板片法线扰动混入各向异性"
        case .opal:
            return "用 3D 噪声/Voronoi 把表面切成随机小晶域，每个域用自己的等效光栅方向"
        case .birefringence:
            return "拿应力场（噪声/距离场梯度）积分出相位差，相位差映射到光谱色（偏振拍频条纹）"
        case .speckle:
            return "高频噪声按视线向量做哈希抖动；常用于特效叠加而非独立材质"
        case .morpho:
            return "薄膜模型 + 故意加大结构间距的角向扩散（法线扰动方差大）"
        case .beetle:
            return "各向异性高光叠薄膜项"
        case .feather:
            return "多层膜 + 各向异性高光 + glitter 组合"
        }
    }

    var isImplemented: Bool {
        switch self {
        case .thinFilm, .grating, .nacre, .opal: return true
        default: return false
        }
    }
}
