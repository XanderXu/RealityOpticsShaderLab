import SwiftUI

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
    case hologram
    case lcd
    case newton
    case pearl
    case dragonfly
    case chameleon
    case scarab

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
        case .hologram: return "彩虹全息图（Rainbow Hologram）"
        case .lcd: return "液晶旋光/电控调光（LCD Twist Cell）"
        case .newton: return "牛顿环/等厚干涉（Newton's Rings）"
        case .pearl: return "正圆珍珠（Cultured Pearl）"
        case .dragonfly: return "蜻蜓翅膀（Dragonfly Wing）"
        case .chameleon: return "变色龙/乌贼皮肤（Chameleon Chromatophores）"
        case .scarab: return "圆偏振金龟子（Circular-Polarization Scarab）"
        }
    }

    /// Short label for the picker menu.
    var menuTitle: String {
        switch self {
        case .thinFilm: return "薄膜干涉"
        case .grating: return "衍射光栅"
        case .nacre: return "珍珠母"
        case .opal: return "欧泊"
        case .birefringence: return "双折射"
        case .speckle: return "激光散斑"
        case .morpho: return "闪蝶翅膀"
        case .beetle: return "吉丁虫鞘翅"
        case .feather: return "孔雀羽"
        case .hologram: return "彩虹全息"
        case .lcd: return "液晶旋光"
        case .newton: return "牛顿环"
        case .pearl: return "珍珠"
        case .dragonfly: return "蜻蜓翅膀"
        case .chameleon: return "变色龙皮肤"
        case .scarab: return "圆偏振金龟"
        }
    }

    /// SF Symbol used on the effect card.
    var iconName: String {
        switch self {
        case .thinFilm: return "circle.dashed"
        case .grating: return "opticaldisc"
        case .nacre: return "seashell"
        case .opal: return "diamond"
        case .birefringence: return "ruler"
        case .speckle: return "sparkles"
        case .morpho: return "butterfly"
        case .beetle: return "ant"
        case .feather: return "feather"
        case .hologram: return "creditcard"
        case .lcd: return "rectangle.on.rectangle"
        case .newton: return "circle.circle"
        case .pearl: return "circle.fill"
        case .dragonfly: return "wind"
        case .chameleon: return "hare"
        case .scarab: return "shield.lefthalf.filled"
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
        case .hologram:
            return "信用卡/防伪标上随视角水平滑动的彩虹条纹，一行条纹对应一个衍射视角"
        case .lcd:
            return "液晶屏黑场的旋光纹理、计算器屏幕斜看发灰发紫——旋光角随电压/视角变化"
        case .newton:
            return "平凸透镜贴平板玻璃的同心彩色圆环，空气隙厚度随半径平方变化"
        case .pearl:
            return "正圆珍珠的多层定向珠光 + 表面曲率驱动的体色渐变（粉白-金）"
        case .dragonfly:
            return "翅膜超薄薄膜干涉的微弱虹彩 + 深色脉络网格 + 半透明翅膜"
        case .chameleon:
            return "虹彩细胞（鸟嘌呤纳米晶格晶域）随信号主动变温变色——晶域逐个切换色相"
        case .scarab:
            return "金龟子鞘翅的螺旋层状结构选择反射左旋圆偏振光，四分之一波片可翻转色支"
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
        case .hologram:
            return "复用光栅 LUT：U 相位 = 表面坐标 + 视线·切向滑动 + 行偏移，V 锁定每行衍射密度，行间隙亮度调制"
        case .lcd:
            return "worley 域 = 像素段，透过率 cos⁴(N·V) 决定斜视灰变，每域在紫/绿泄漏色间二选一"
        case .newton:
            return "复用薄膜 LUT：厚度轴换成 r²（到接触点距离平方），一个乘法即得同心环"
        case .pearl:
            return "复用珍珠母 LUT：厚度偏置 + |N·V|×曲率项（中心到边缘色相渐变）+ 体色叠加 + 高光"
        case .dragonfly:
            return "薄膜 LUT（超薄偏置）+ 三角波抖动网格脉络（横脉×纵脉×边缘）+ 脉络不透明/翅膜半透明"
        case .chameleon:
            return "worley 晶域随机相位 + time 驱动循环采样光栅 LUT 色相轴，皮肤纹理亮度扰动"
        case .scarab:
            return "同一薄膜 LUT 两个厚度偏移采样 = 左/右旋圆偏振色支，几何手性 h=N·(V×T) 与检偏器角度共同选择混合权重"
        }
    }

    var isImplemented: Bool {
        switch self {
        case .thinFilm, .grating, .nacre, .opal, .birefringence, .speckle,
             .morpho, .beetle, .feather,
             .hologram, .lcd, .newton, .pearl, .dragonfly, .chameleon, .scarab:
            return true
        }
    }
}
