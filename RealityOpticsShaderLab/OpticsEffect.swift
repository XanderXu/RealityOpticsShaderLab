import SwiftUI

/// Catalog of wave-optics effects demoed by the app.
/// All 16 effects are wired up. Mechanisms distinguish spectral models from
/// illustrative approximations so the UI does not imply a full physical solver.
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

    var materialName: String {
        switch self {
        case .thinFilm: return "IridescentFilmMaterial"
        case .grating: return "DiffractionGratingMaterial"
        case .lcd: return "LCDMaterial"
        default: return rawValue.prefix(1).uppercased() + rawValue.dropFirst() + "Material"
        }
    }

    var title: String {
        switch self {
        case .thinFilm: return "薄膜干涉 · 肥皂泡（Thin-Film Interference）"
        case .grating: return "衍射光栅 · CD 光盘（Diffraction Grating）"
        case .nacre: return "珍珠母/珠光（Nacre, Pearlescence）"
        case .opal: return "欧泊变彩（Opal, Play-of-Color）"
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
        case .chameleon: return "变色龙皮肤（Chameleon Structural Color）"
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
        case .nacre: return "circle.lefthalf.filled"
        case .opal: return "diamond"
        case .birefringence: return "ruler"
        case .speckle: return "sparkles"
        case .morpho: return "fanblades.fill"
        case .beetle: return "ant"
        case .feather: return "leaf.fill"
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
            return "正交偏振片下，应力塑料和尺子上的彩色条纹与消光区域"
        case .speckle:
            return "相干光照在粗糙表面上的细密颗粒状明暗图样，随观察者移动而流动"
        case .morpho:
            return "翅鳞纳米结构产生鲜明蓝色，本演示用等效几丁质薄膜近似"
        case .beetle:
            return "绿色结构色与转动时的彩虹条带，本演示混合两种光谱查表"
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
            return "虹彩细胞内纳米晶体间距变化可改变结构色，本演示以晶域色彩循环近似"
        case .scarab:
            return "部分金龟子的螺旋层状结构选择反射圆偏振光；此处展示两支颜色的混合示意"
        }
    }

    /// Actual implemented model, including its approximation limits.
    var mechanism: String {
        switch self {
        case .thinFilm:
            return "无吸收、无色散的三介质 Fresnel + Airy 光谱积分；CIE 1931 / D65 转线性 RGB，膜厚按高斯分布平均"
        case .grating:
            return "光栅方程与高斯谱带、多阶加权查表；L/V 均从表面向外，径向衍射量为 (L+V)·P，入射余弦控制亮度"
        case .nacre:
            return "三种厚度的独立薄膜反射取平均，增加膜厚方差并降饱和；属于珠光外观近似，不求解相干多层堆栈"
        case .opal:
            return "二维 Worley 距离场扰动光栅 LUT 坐标，模拟斑块变彩；不求解三维光子晶体的能带与散射"
        case .birefringence:
            return "程序化应力场近似相位延迟，光谱透过率 sin²(δ·550/2λ) 乘轴向消光因子；白光相位连续查表，不按 2π 重复"
        case .speckle:
            return "物体空间视线偏移三维坐标，cellnoise 加阈值模拟颗粒并避免球面 UV 极点拉伸；这是散斑外观近似，不计算相干波场叠加"
        case .morpho:
            return "几丁质等效薄膜 + 噪声膜厚扰动；216 nm 膜在约 449 nm 有可见反射峰，不求解真实树状多层结构"
        case .beetle:
            return "几丁质绿带薄膜与沿网格切向变化的光栅色混合；不包含椭圆偏振计算"
        case .feather:
            return "等效几丁质薄膜色 + 正弦羽枝条纹 + cellnoise 闪点；真实羽毛纳米结构采用外观近似"
        case .hologram:
            return "复用光栅 LUT：U 相位 = 表面坐标 + 视线·切向滑动 + 行偏移，V 锁定每行衍射密度，行间隙亮度调制"
        case .lcd:
            return "固定 cellnoise 像素阈值随电压启闭，|N·V|⁴ 模拟斜视与紫绿泄漏；不求解液晶指向矢或 Jones 矩阵"
        case .newton:
            return "专用玻璃—空气—玻璃 Fresnel/Airy LUT，空气隙厚度按 r² 增长；外部视角先经 Snell 折射，圆盘边缘以透明度裁切"
        case .pearl:
            return "复用珍珠母 LUT：厚度偏置 + |N·V|×曲率项（中心到边缘色相渐变）+ 体色叠加 + 高光"
        case .dragonfly:
            return "薄膜 LUT（超薄偏置）+ 三角波抖动网格脉络（横脉×纵脉×边缘）+ 脉络不透明/翅膜半透明"
        case .chameleon:
            return "worley 晶域随机相位 + time 驱动循环采样光栅 LUT 色相轴，皮肤纹理亮度扰动"
        case .scarab:
            return "两个等效薄膜厚度采样，由 R→L 滑杆线性混合；这是偏振色支示意，不代表真实圆偏振选择反射或检偏器角度响应"
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
