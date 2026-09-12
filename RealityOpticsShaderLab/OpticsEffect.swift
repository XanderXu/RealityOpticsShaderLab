import SwiftUI

/// Catalog of wave-optics effects demoed by the app.
/// All catalog entries are wired up. Mechanisms distinguish spectral models from
/// illustrative approximations so the UI does not imply a full physical solver.
enum OpticsEffect: String, CaseIterable, Identifiable {
    case gemFire
    case absorbingGlass
    case lenticular
    case moire
    case parallaxNebula
    case rainbow
    case atmosphere
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
    case lensCoating
    case titanium
    case oilFilm
    case retroreflective
    case dichroic
    case pleochroism
    case alexandrite
    case sunstone
    case labradorite
    case moonstone
    case starGem
    case catEye

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
        case .gemFire: return "宝石火彩"
        case .absorbingGlass: return "吸收玻璃"
        case .lenticular: return "柱镜变图"
        case .moire: return "彩色莫尔纹"
        case .parallaxNebula: return "视差星云"
        case .rainbow: return "雨虹与双虹"
        case .atmosphere: return "大气霞光"
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
        case .catEye: return "猫眼效应"
        case .starGem: return "星光宝石"
        case .moonstone: return "月光石"
        case .labradorite: return "拉长石"
        case .sunstone: return "日光石"
        case .alexandrite: return "变石效应"
        case .pleochroism: return "多色性"
        case .dichroic: return "二向色玻璃"
        case .retroreflective: return "逆反射材料"
        case .oilFilm: return "油膜"
        case .titanium: return "阳极氧化钛"
        case .lensCoating: return "镜头镀膜"
        }
    }

    /// Short label for the picker menu.
    var menuTitle: String {
        switch self {
        case .gemFire: return "宝石火彩"
        case .absorbingGlass: return "吸收玻璃"
        case .lenticular: return "柱镜变图"
        case .moire: return "彩色莫尔纹"
        case .parallaxNebula: return "视差星云"
        case .rainbow: return "雨虹与双虹"
        case .atmosphere: return "大气霞光"
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
        case .catEye: return "猫眼效应"
        case .starGem: return "星光宝石"
        case .moonstone: return "月光石"
        case .labradorite: return "拉长石"
        case .sunstone: return "日光石"
        case .alexandrite: return "变石效应"
        case .pleochroism: return "多色性"
        case .dichroic: return "二向色玻璃"
        case .retroreflective: return "逆反射材料"
        case .oilFilm: return "油膜"
        case .titanium: return "阳极氧化钛"
        case .lensCoating: return "镜头镀膜"
        }
    }

    /// SF Symbol used on the effect card.
    var iconName: String {
        switch self {
        case .gemFire: return "diamond.inset.filled"
        case .absorbingGlass: return "drop.halffull"
        case .lenticular: return "rectangle.on.rectangle.angled"
        case .moire: return "circle.hexagongrid"
        case .parallaxNebula: return "sparkles.rectangle.stack"
        case .rainbow: return "rainbow"
        case .atmosphere: return "globe.americas.fill"
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
        case .catEye: return "eye"
        case .starGem: return "star"
        case .moonstone: return "moon.fill"
        case .labradorite: return "diamond.fill"
        case .sunstone: return "sun.max.fill"
        case .alexandrite: return "lightbulb.2"
        case .pleochroism: return "cube.transparent"
        case .dichroic: return "rectangle.lefthalf.filled"
        case .retroreflective: return "light.beacon.max"
        case .oilFilm: return "drop.fill"
        case .titanium: return "square.stack.3d.up.fill"
        case .lensCoating: return "camera.aperture"
        }
    }

    /// What the viewer sees in the real phenomenon.
    var subtitle: String {
        switch self {
        case .gemFire: return "切面中的彩色闪光随观察方向切换"
        case .absorbingGlass: return "厚度与观察角度共同改变玻璃透射色"
        case .lenticular: return "左右观察时切换四幅彩色图案"
        case .moire: return "双层条纹因视差产生移动的彩色波纹"
        case .parallaxNebula: return "多层彩云与星点随着视点移动产生深度"
        case .rainbow: return "反太阳方向出现主虹及颜色反转的副虹"
        case .atmosphere: return "球体边缘的蓝色大气与日落橙红渐变"
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
        case .catEye: return "平行纤维产生随视角扫动的窄亮带"
        case .starGem: return "三组定向包裹体形成六射星光"
        case .moonstone: return "蓝白柔光在乳白石体内漂移"
        case .labradorite: return "深色石体转动时出现蓝金色大块晕彩"
        case .sunstone: return "铜金色片状闪点随光源与视角闪烁"
        case .alexandrite: return "切换照明色谱，绿色体色转为红紫色"
        case .pleochroism: return "沿晶体不同方向观察呈现不同体色"
        case .dichroic: return "多层滤光膜反射与透射的互补颜色"
        case .retroreflective: return "光源靠近观察方向时突然明亮"
        case .oilFilm: return "水面油膜呈现流纹状干涉色"
        case .titanium: return "金属基底上随氧化层厚度变化的鲜明颜色"
        case .lensCoating: return "低反射镀膜残余的紫绿光泽"
        }
    }

    /// Actual implemented model, including its approximation limits.
    var mechanism: String {
        switch self {
        case .gemFire: return "以固定环境图、三波段折射和一次内部反射近似宝石火彩；切面由程序法线模拟，不追踪真实几何内部光路或现实背景"
        case .absorbingGlass: return "有限平板光程与 RGB Beer–Lambert 吸收，叠加 Fresnel 表面反射；背景为预制环境，非现实透视画面的折射，厚度由参数指定"
        case .lenticular: return "物体空间观察斜率选择四视图图集；柱镜条带扰动视图索引。图集由 Compute 一次生成，属于柱镜选图近似"
        case .moire: return "计算两层光栅的相位差，保留低频拍频并映射到三色通道；以解析低通代替易闪烁的亚像素混叠，层距为零时视差消失"
        case .parallaxNebula: return "四层 Compute 生成的纹理按固定深度偏移并从后向前合成；使用有界视差和亮度遮挡，无屏幕后期，也不是完整体积散射"
        case .rainbow: return "用色散水滴的驻定偏向角生成 81 波长角度 LUT；主虹和副虹采用高斯展宽及近似强度，非完整 Mie 散射。移动视点或调整光源才能改变虹带位置"
        case .atmosphere: return "解析球壳视线长度与光谱 Rayleigh 单次散射 LUT，结合太阳方向和近似日落衰减；在模型表面显示，不生成真实外部大气体积"
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
        case .catEye: return "物体空间纤维方向控制各向异性角度瓣；以法线和半角矢量的偏差驱动窄亮带，属于包裹体定向反射的外观近似"
        case .starGem: return "共享猫眼模板，叠加三组相差 60° 的定向亮带；不追踪宝石内部多次折射"
        case .moonstone: return "低频三维纹理与宽角度散射瓣模拟月光效应；不是体积多重散射求解"
        case .labradorite: return "三维晶域调制定向闪光，等效几丁质膜 LUT 近似层片干涉颜色；不模拟真实长石层片堆栈"
        case .sunstone: return "物体空间细胞随机包裹体，随机片层朝向与半角矢量控制闪点；无体积光线追踪"
        case .alexandrite: return "两种参考照明下的代表性线性 RGB 端点混合，并用 Beer–Lambert RGB 透过率控制深浅；是光源变色示意，非实测变石光谱"
        case .pleochroism: return "三个正交晶轴的 RGB 吸收系数按视线方向平方加权，经 Beer–Lambert 衰减；未模拟偏振分束及宝石切面折射"
        case .dichroic: return "六层高低折射率四分之一波膜的复振幅递推，光谱积分；透射使用无吸收堆栈的 T=1−R，显示通道可切换，不包含背景折射"
        case .retroreflective: return "光源与视线夹角的窄回归瓣乘入射余弦；展示逆反射角响应，不追踪微珠或角锥中的光路"
        case .oilFilm: return "空气／折射率 1.47 油膜／折射率 1.333 水的三介质光谱干涉；纹理改变局部膜厚，不模拟流体"
        case .titanium: return "空气／折射率 2.4 氧化层／复折射率 2.7+3.3i 金属基底的薄膜模型；常数 n、k 是代表性近似，不用于预测电压或真实色卡"
        case .lensCoating: return "空气／折射率 1.38 单层 MgF₂／折射率 1.52 玻璃的干涉模型；近 100 nm 抑制绿光反射，不代表商业多层宽带配方"
        }
    }

    var isImplemented: Bool { true }

    /// Runtime templates may be shared without sharing mutable parameters.
    var templateName: String {
        switch self {
        case .thinFilm, .nacre, .morpho: return "IridescentFilmMaterial"
        case .catEye, .starGem: return "ChatoyancyMaterial"
        case .oilFilm, .titanium, .lensCoating, .dichroic: return "LayeredFilmMaterial"
        default: return materialName
        }
    }

    var group: OpticsEffectGroup {
        OpticsEffectGroup.allCases.first { $0.effects.contains(self) }!
    }
}

enum OpticsEffectGroup: String, CaseIterable, Identifiable {
    case films, structural, softGlow, directional, polarization, diffraction, dispersion, parallax, atmospheric
    var id: String { rawValue }
    var title: String {
        switch self {
        case .dispersion: return "色散与吸收"
        case .parallax: return "视差与叠层"
        case .atmospheric: return "大气光学"
        case .films: return "薄膜与镀膜"
        case .structural: return "结构色与晕彩"
        case .softGlow: return "珠光与柔光"
        case .directional: return "定向反光"
        case .polarization: return "偏振与体色"
        case .diffraction: return "衍射与散斑"
        }
    }
    var effects: [OpticsEffect] {
        switch self {
        case .dispersion: return [.gemFire, .absorbingGlass]
        case .parallax: return [.lenticular, .moire, .parallaxNebula]
        case .atmospheric: return [.rainbow, .atmosphere]
        case .films: return [.thinFilm, .oilFilm, .titanium, .lensCoating, .dichroic, .newton, .dragonfly]
        case .structural: return [.opal, .labradorite, .morpho, .beetle, .feather, .chameleon]
        case .softGlow: return [.nacre, .pearl, .moonstone]
        case .directional: return [.catEye, .starGem, .sunstone, .retroreflective]
        case .polarization: return [.birefringence, .lcd, .scarab, .alexandrite, .pleochroism]
        case .diffraction: return [.grating, .hologram, .speckle]
        }
    }
}
