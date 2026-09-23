#!/usr/bin/env python3
"""Build the bilingual app string catalog from the authored effect copy."""
import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
APP = ROOT / 'RealityOpticsShaderLab'
SOURCE = (APP / 'Effects/OpticsEffect.swift').read_text()
DEST = APP / 'Localization/Localizable.xcstrings'

# id | full title | picker title | visible phenomenon | rendering principle
EFFECTS = '''
gemFire|Gemstone Dispersion and Fire|Gemstone Fire|Colored facet flashes shift with the viewing angle.|A fixed environment map, three refracted wavelength bands and one approximate internal reflection produce gemstone fire. Program normals suggest facets; this does not trace the real gem interior or camera background.
absorbingGlass|Colored Absorbing Glass|Absorbing Glass|Thickness and viewing angle change the transmitted glass color.|A finite slab path uses RGB Beer-Lambert absorption and Fresnel surface reflection. The background is a prepared environment, not a refraction of the real camera image; thickness is controlled by a parameter.
lenticular|Lenticular Image Switching|Lenticular Views|Four colorful images switch as you look from side to side.|The view slope in object space selects one of four atlas images. Lenticular stripes perturb the view index. Compute generates the atlas once; this is an image-selection approximation.
moire|Color Moiré|Color Moiré|Parallax moves colored waves between two patterned layers.|The phase difference of two gratings yields a low-frequency beat mapped to three color channels. An analytic low-pass avoids subpixel flicker; zero layer gap removes parallax.
parallaxNebula|Layered Parallax Nebula|Parallax Nebula|Clouds and stars at different depths shift as the viewpoint moves.|Four Compute-generated layers shift at fixed depths and composite from back to front. Parallax and occlusion are bounded; there is no screen-space postprocessing or complete volumetric scattering.
rainbow|Primary and Secondary Rainbows|Double Rainbow|A primary bow and reversed-color secondary bow appear opposite the sun.|An 81-wavelength angular LUT uses the stationary deviation angles of dispersive drops. Gaussian width and approximate intensity replace full Mie scattering; moving the view or light direction changes the bow.
atmosphere|Planetary Atmosphere and Sunset|Atmospheric Glow|A blue limb fades toward orange and red near sunset.|An analytic path through a spherical shell and a spectral single-scattering Rayleigh LUT respond to sun direction and approximate sunset attenuation. The glow is shown on the surface, without a real external volume.
thinFilm|Thin-Film Interference · Soap Bubble|Thin Film|Rainbow bands on soap bubbles and oil films change with thickness and angle.|A nonabsorbing, nondispersive three-medium Fresnel and Airy spectrum is integrated under CIE 1931/D65 into linear RGB. Thickness is averaged over a Gaussian distribution.
grating|Diffraction Grating · CD|Diffraction Grating|CDs and records show rainbow reflections highly sensitive to viewing angle.|The grating equation, Gaussian spectral bands and weighted orders use a lookup table. Light and view point outward; the radial diffraction term is (L+V)·P and incident cosine controls brightness.
nacre|Nacre and Pearlescence|Nacre|Shells and pearls show softer, less saturated colors than bubbles.|Independent film reflections at three thicknesses are averaged, with thickness variance and reduced saturation. This approximates pearlescence rather than a coherent multilayer stack.
opal|Opal Play of Color|Opal|Small patches of color flash within an opal-like surface.|A 2D Worley distance field perturbs grating-LUT coordinates to suggest patches; it does not solve a 3D photonic crystal band structure or scattering.
birefringence|Birefringence and Photoelasticity|Birefringence|Stress stripes and dark areas appear between crossed polarizers.|A procedural stress field approximates phase delay. Spectral transmission uses sin²(δ·550/2λ) and an axis extinction factor; the white-light phase LUT stays continuous rather than wrapping at 2π.
speckle|Laser Speckle|Laser Speckle|Fine granular contrast on a rough surface moves with the viewer.|View displacement in object space shifts 3D cell noise; a threshold forms grains without spherical-UV pole distortion. This is a speckle appearance, not coherent wave-field interference.
morpho|Morpho Butterfly Structural Color|Morpho Wing|Bright blue wing color changes with view angle.|An equivalent chitin film with noisy thickness has a visible reflection peak near 449 nm for a 216 nm film. It does not solve the actual branched multilayer scales.
beetle|Iridescent Beetle Shell|Beetle Shell|Green structural color turns into rainbow bands as the shell rotates.|A green-band chitin film mixes with grating colors varying along mesh tangents; elliptical polarization is not calculated.
feather|Iridescent Hummingbird and Peacock Feather|Iridescent Feather|Film colors, directional highlights and glints combine on a feather.|Equivalent chitin-film color, sinusoidal barbule stripes and cell-noise glints approximate feather nanostructure.
hologram|Rainbow Hologram|Rainbow Hologram|Rainbow rows on security labels slide across with the viewing angle.|The grating LUT is reused: U phase combines surface coordinate, tangent-view slide and row offset; V fixes each row's diffraction density, while gaps modulate brightness.
lcd|Twisted LCD Cell|LCD Twist|LCD pixels darken and tint when viewed obliquely.|Fixed cell-noise thresholds toggle pixels with voltage; |N·V|⁴ approximates off-axis purple-green leakage. No liquid-crystal director or Jones matrix is solved.
newton|Newton's Rings|Newton's Rings|Concentric colors arise in the gap between a lens and glass plate.|A dedicated glass-air-glass Fresnel/Airy LUT uses a gap increasing as r². The external angle is first refracted with Snell's law; opacity clips the disc edge.
pearl|Cultured Pearl|Pearl|Directional luster and a rose-gold body gradient sweep across a pearl.|The nacre LUT is reused with thickness offset, a |N·V| curvature hue sweep, body tint and a separate highlight.
dragonfly|Dragonfly Wing Iridescence|Dragonfly Wing|A faint rainbow sits over dark veins and a translucent wing.|An ultra-thin-film LUT combines with a triangular-wave vein grid, opaque veins and a translucent membrane.
chameleon|Chameleon Structural Color|Chameleon Skin|Crystal spacing shifts the skin's structural color.|Random phase in Worley crystal domains and time-driven grating-LUT hue sampling approximate color changes, with brightness texture modulation.
scarab|Circular-Polarization Scarab|Polarized Scarab|Two color branches represent polarization-selective beetle reflections.|Two equivalent film thicknesses are blended linearly by the R-to-L control. This illustrates color branches, not actual circular-polarization selection or analyzer-angle response.
catEye|Cat's-Eye Gemstone|Cat's Eye|A narrow highlight sweeps over parallel fibers.|An object-space fiber axis controls an anisotropic angular lobe driven by normal/half-vector deviation. It approximates directional reflections from inclusions.
starGem|Star Sapphire Asterism|Star Gem|Three inclusion directions form a six-rayed moving star.|The cat's-eye template combines three highlight bands separated by 60°. It does not trace repeated refraction inside a gemstone.
moonstone|Moonstone Adularescence|Moonstone|Blue-white soft light drifts inside a milky gem.|Low-frequency 3D texture and a broad angular scattering lobe suggest adularescence; volumetric multiple scattering is not solved.
labradorite|Labradorite Labradorescence|Labradorite|Large blue and golden flashes emerge as a dark stone rotates.|3D crystal domains modulate directional flashes. An equivalent chitin-film LUT approximates lamellar interference color, not real feldspar exsolution layers.
sunstone|Sunstone Aventurescence|Sunstone|Copper-gold platelet glints flash with light and view.|Object-space cells place random inclusions; platelet orientation and a half-vector control each glint. There is no volumetric ray tracing.
alexandrite|Alexandrite Color Change|Alexandrite|Green body color changes toward red-purple under warm light.|Representative linear RGB endpoints for two reference illuminants mix with Beer-Lambert RGB absorption. This is a light-source color-change illustration, not a measured alexandrite spectrum.
pleochroism|Crystal Pleochroism|Pleochroism|Body colors differ along different crystal viewing axes.|RGB absorption along three orthogonal crystal axes is weighted by squared view components and attenuated by Beer-Lambert law. Polarization splitting and facet refraction are omitted.
dichroic|Dichroic Multilayer Glass|Dichroic Glass|Multilayer filters reflect and transmit complementary colors.|Complex-amplitude recursion integrates a six-layer quarter-wave H/L stack. For its nonabsorbing stack, transmission uses T=1−R. The display channel switches without refracting the background.
retroreflective|Retroreflective Material|Retroreflection|The material brightens when the light is near the viewer's direction.|A narrow return lobe based on light/view angle is multiplied by incident cosine. This shows angular retroreflection without tracing beads or corner cubes.
oilFilm|Oil Film on Water|Oil Film|Flow-like color bands appear across a surface oil film.|A spectral three-medium stack uses air, n=1.47 oil and n=1.333 water. Texture varies local thickness, without fluid simulation.
titanium|Anodized Titanium|Anodized Titanium|Oxide thickness paints vivid colors over metal.|A film model uses air, an n=2.4 oxide and an absorbing metal with complex index 2.7+3.3i. These representative constants cannot predict voltage or real swatches.
lensCoating|Lens Antireflection Coating|Lens Coating|Low-reflection glass retains a faint purple-green sheen.|Interference through a single n=1.38 MgF₂ layer on n=1.52 glass suppresses green reflection near 100 nm. It is not a commercial broadband stack.
'''.strip().splitlines()

# Literal UI copy and the labels used by runtime-generated setting specifications.
UI = '''
AR 已暂停，返回应用后恢复|AR paused. It will resume when you return to the app.
AR 跟踪暂不可用|AR tracking is unavailable.
AR 预览需要支持 ARKit 的真机，模拟器请使用 3D 预览。|AR preview needs an ARKit-capable device. Use the 3D preview in Simulator.
Analyzer blend (R → L)|检偏色支混合（右 → 左）
Booting optics…|光学效果启动中…
Barbule stripes|羽枝条纹
Body tint (rose-gold)|体色（玫瑰金）
Bragg thickness|布拉格层厚
Cell scale (Voronoi)|细胞尺度（Voronoi）
Chromatophore scale|虹彩细胞尺度
Color switching speed|变色速度
Cross veins|横向翅脉
Curvature (ring density)|曲率（环密度）
Curvature hue sweep|曲率色相变化
Density bias|密度偏置
Density scale|密度尺度
Domain jitter|晶域扰动
Drive voltage (dark segments)|驱动电压（暗像素）
Effect intensity|效果强度
Film IOR|薄膜折射率
Gain|亮度
Gap dust (noise)|间隙尘点（噪声）
Glitter density|闪点密度
Grain density|颗粒密度
Green band|绿色色带
L/R branch shift|左右色支偏移
Light azimuth|光源方位
Membrane opacity|翅膜不透明度
Membrane thickness|翅膜厚度
MgF₂ 厚度（nm）|MgF₂ thickness (nm)
Nacre thickness|珍珠母厚度
Noise amount|噪声量
Off-axis tint|斜视色调
Opacity|不透明度
Phase rings|相位环
Pixel domain scale|像素晶域尺度
Rainbow mix|虹彩混合
Ridge noise|脊线噪声
Spot threshold|闪点阈值
Stress noise|应力噪声
Stripe contrast|条纹对比度
Stripe rows|条纹行数
Thickness (blue band)|膜厚（蓝色带）
Thickness band|膜厚色带
Thickness bias|膜厚偏置
Thickness scale|膜厚尺度
Vein width|翅脉宽度
View flow|视线流动
View slide amount|视角滑动幅度
View-angle hue swing|视角色相摆幅
中心波长变化（nm）|Center-wavelength variation (nm)
云层尺度|Cloud scale
云层遮挡|Cloud occlusion
亮带锐度|Highlight sharpness
亮度|Brightness
偏振与体色|Polarization and Body Color
光源偏离视线基准（°）|Light offset from view (°)
光源方位（°）|Light direction (°)
光盘|Disc
内部反射|Internal reflection
内部层次|Inner depth
内部深度|Interior depth
准备中|Preparing
准备材质…|Preparing material…
切面倾角|Facet tilt
切面密度|Facet density
包裹体密度|Inclusion density
厚度变化（nm）|Thickness variation (nm)
原始|Original
原始效果|Original appearance
参数|Parameters
参数调节|Adjust Parameters
参考照明：日光 → 暖光|Reference light: day → warm
双层频率差|Layer frequency mismatch
反射显示增益|Reflection display gain
吸收光程|Absorption path length
吸收厚度|Absorption thickness
吸收配色：青 → 琥珀|Absorption tint: cyan → amber
回归光束集中度|Return-beam sharpness
复位视角或 AR 位置|Reset view or AR placement
大气光学|Atmospheric Optics
大气光学厚度|Atmosphere optical depth
太阳方位（°）|Sun direction (°)
定向反光|Directional Highlights
尺子|Ruler
层间视差|Layer parallax
平均膜厚（nm）|Average film thickness (nm)
平面|Plane
底色替换|Base-color replacement
开始旋转|Start rotation
折射率|Refractive index
搜索效果|Search effects
搜索效果或分类|Search effects or groups
收起面板|Close panel
效果库|Effect Library
效果说明|Effect Principle
日落偏移|Sunset shift
星芒方向（°）|Star direction (°)
星芒锐度|Star sharpness
显示通道：反射 → 透射|Display channel: reflection → transmission
晶域尺度|Crystal-domain scale
晶轴倾角（°）|Crystal-axis tilt (°)
晶轴方向（°）|Crystal-axis direction (°)
暂停旋转|Pause rotation
替换|Replace
替换材质体色或中性底色，保留光学纹理与高光；0% 恢复原始，100% 完成替换。|Replace the material's body or neutral base while preserving optical patterns and highlights. 0% restores the original; 100% completes replacement.
材质基础色|Material Base Color
条纹密度|Stripe density
柔光集中度|Soft-glow focus
查看内容|Show Content
柱镜条纹密度|Lenticular stripe density
正在启动 AR…|Starting AR…
正在更新薄膜…|Updating film…
正在请求相机权限…|Requesting camera permission…
此效果尚未接入，当前显示占位几何。|This effect is unavailable; placeholder geometry is shown.
氧化层厚度（nm）|Oxide thickness (nm)
没有匹配的效果|No matching effects
波动光学 · 结构色实验室|Wave Optics · Structural Color Lab
渲染就绪|Render ready
珠光与柔光|Pearlescence and Soft Glow
球体|Sphere
球体 / 平面 · 尺子 / 光盘|Sphere / Plane · Ruler / Disc
白色|White
相机权限未开启，请在系统设置中允许 Optics Lab 使用相机。|Camera access is disabled. Allow Optics Lab to use the camera in Settings.
第二层旋角（°）|Second-layer rotation (°)
等效层厚（nm）|Equivalent layer spacing (nm)
红色|Red
纤维方向（°）|Fiber direction (°)
结构色与晕彩|Structural Color and Iridescence
继续旋转|Resume rotation
绿色|Green
膜厚变化（nm）|Film-thickness variation (nm)
色散与吸收|Dispersion and Absorption
色散强度|Dispersion strength
蓝色|Blue
薄膜与镀膜|Films and Coatings
虹带展宽（°）|Rainbow-band width (°)
衍射与散斑|Diffraction and Speckle
视图过渡宽度|View blend width
视差与叠层|Parallax and Layers
视角切换灵敏度|View-switch sensitivity
设计中心波长（nm）|Design center wavelength (nm)
请缓慢移动手机，正在恢复跟踪…|Move your phone slowly to restore tracking…
轻点画面放置模型|Tap to place the samples
重新加载|Retry loading
闪光集中度|Flash focus
闪点稀疏度|Glint sparsity
闪点锐度|Glint sharpness
预览模式|Preview mode
黑色|Black
雨虹与双虹|Primary and secondary rainbows
效果强度|Effect intensity
薄膜干涉|Thin film
'''.strip().splitlines()

TEMPLATES = {
    '正在加载%@…': ('Loading %@…', '正在加载%@…'),
    '加载失败：%@': ('Failed to load: %@', '加载失败：%@'),
    '模型加载失败：%@': ('Failed to load samples: %@', '模型加载失败：%@'),
    '薄膜更新失败：%@': ('Failed to update film: %@', '薄膜更新失败：%@'),
    'AR 已停止：%@': ('AR stopped: %@', 'AR 已停止：%@'),
    '正在准备%@…': ('Preparing %@…', '正在准备%@…'),
    '%@ · %d 项参数': ('%@ · %d parameters', '%@ · %d 项参数'),
    '%d 项': ('%d items', '%d 项'),
    '%d 种光学效果': ('%d optical effects', '%d 种光学效果'),
    '效果库 · %d': ('Effect Library · %d', '效果库 · %d'),
    '球体 / 平面 · 尺子 / 光盘　拖动观察 · 双击复位':
        ('Sphere / Plane · Ruler / Disc   Drag to orbit · Double-tap to reset',
         '球体 / 平面 · 尺子 / 光盘　拖动观察 · 双击复位'),
    '移动手机观察 · 轻点放置 · 双指缩放':
        ('Move your phone to observe · Tap to place · Pinch to scale',
         '移动手机观察 · 轻点放置 · 双指缩放'),
}


def entries(field):
    block = SOURCE.split(f'private var untranslated{field[0].upper() + field[1:]}: String {{', 1)[1].split('\n    }', 1)[0]
    found = re.findall(r'case \.([A-Za-z]+):\s*return "([^"\n]+)"', block)
    assert len(found) == 35, (field, len(found))
    return dict(found)


def unit(value):
    return {'stringUnit': {'state': 'translated', 'value': value}}


def main():
    data = {'sourceLanguage': 'zh-Hans', 'version': '1.0', 'strings': {}}
    def add(key, zh, en):
        assert key not in data['strings'], key
        data['strings'][key] = {'localizations': {'en': unit(en), 'zh-Hans': unit(zh)}}
    raw = {field: entries(field) for field in ['title', 'menuTitle', 'subtitle', 'mechanism']}
    for line in EFFECTS:
        name, *translations = line.split('|', 4)
        assert len(translations) == 4, name
        for field, value in zip(raw, translations):
            add(f'effect.{name}.{field}', raw[field].pop(name), value)
    assert all(not remaining for remaining in raw.values()), raw
    for line in UI:
        key, translation = line.split('|', 1)
        if any('\u4e00' <= ch <= '\u9fff' for ch in key): add(key, key, translation)
        else: add(key, translation, key)
    for key, (en, zh) in TEMPLATES.items(): add(key, zh, en)
    # Dynamic parameter labels bypass SwiftUI's literal-string extraction.
    for name in ['App/AppModel.swift', 'Effects/ExtendedEffectControls.swift']:
        source = (APP / name).read_text()
        labels = set(re.findall(r'label: "([^"\n]+)"', source))
        assert labels <= data['strings'].keys(), (name, labels - data['strings'].keys())
    for name in ['Views/visionOS/ContentView.swift', 'Views/iOS/MobileContentView.swift',
                 'Views/Shared/ParameterPanelView.swift', 'Views/Shared/EffectLibraryView.swift',
                 'Views/Shared/PreviewControlsView.swift', 'Preview/iOS/MobilePreviewState.swift',
                 'Preview/iOS/MobileOpticsSceneView.swift']:
        source = (APP / name).read_text()
        keys = set(re.findall(r'(?:Text|Label|Button|ProgressView|TextField|Picker|L10n\.text)\("([^"\n]+)"', source))
        keys -= {'3D', 'AR', 'Reality Optics Shader Lab'}
        keys = {key for key in keys if not key.startswith('\\(')}
        assert keys <= data['strings'].keys(), (name, keys - data['strings'].keys())
    DEST.write_text(json.dumps(data, ensure_ascii=False, indent=2, sort_keys=True) + '\n')
    print(f'PASS: {len(data["strings"])} keys, 35 effects × 4 fields, en/zh-Hans catalog')


if __name__ == '__main__': main()
