# RealityOpticsShaderLab

[中文](#中文) · [English](#english)

## iPhone 效果截图 / iPhone Shader gallery

以下图片取自 iPhone 17 Pro 模拟器，仅展示球体、平面、尺子和光盘上的 Shader 效果；点击可查看原始尺寸。 / These iPhone 17 Pro simulator crops show the Shader on the sphere, plane, ruler, and disc. Click for the full-size image.

| 效果 / Effect | 效果 / Effect |
|---|---|
| **薄膜干涉 · 肥皂泡 / Thin-Film Interference**<br><a href="docs/images/effects/thinFilm.jpg"><img src="docs/images/effects/thinFilm.jpg" alt="薄膜干涉 / Thin-Film Interference" width="420"></a> | **衍射光栅 · 光盘 / Diffraction Grating**<br><a href="docs/images/effects/grating.jpg"><img src="docs/images/effects/grating.jpg" alt="衍射光栅 / Diffraction Grating" width="420"></a> |
| **宝石火彩 / Gemstone Fire**<br><a href="docs/images/effects/gemFire.jpg"><img src="docs/images/effects/gemFire.jpg" alt="宝石火彩 / Gemstone Fire" width="420"></a> | **柱镜变图 / Lenticular Images**<br><a href="docs/images/effects/lenticular.jpg"><img src="docs/images/effects/lenticular.jpg" alt="柱镜变图 / Lenticular Images" width="420"></a> |
| **欧泊变彩 / Opal Play-of-Color**<br><a href="docs/images/effects/opal.jpg"><img src="docs/images/effects/opal.jpg" alt="欧泊变彩 / Opal Play-of-Color" width="420"></a> | **双折射 · 光弹性 / Birefringence**<br><a href="docs/images/effects/birefringence.jpg"><img src="docs/images/effects/birefringence.jpg" alt="双折射 / Birefringence" width="420"></a> |
| **彩色莫尔纹 / Color Moiré**<br><a href="docs/images/effects/moire.jpg"><img src="docs/images/effects/moire.jpg" alt="彩色莫尔纹 / Color Moiré" width="420"></a> | **彩虹全息图 / Rainbow Hologram**<br><a href="docs/images/effects/hologram.jpg"><img src="docs/images/effects/hologram.jpg" alt="彩虹全息图 / Rainbow Hologram" width="420"></a> |
| **拉长石晕彩 / Labradorite Labradorescence**<br><a href="docs/images/effects/labradorite.jpg"><img src="docs/images/effects/labradorite.jpg" alt="拉长石晕彩 / Labradorite Labradorescence" width="420"></a> | **视差星云 / Parallax Nebula**<br><a href="docs/images/effects/parallaxNebula.jpg"><img src="docs/images/effects/parallaxNebula.jpg" alt="视差星云 / Parallax Nebula" width="420"></a> |

## 中文


支持 visionOS 与 iOS 18+、基于 RealityKit ShaderGraph 与 Metal Compute 的光学效果库，实时展示 35 种光学与结构色效果。手机使用 `RealityOpticsShaderLab-iOS` Scheme。

### 效果清单

| 分组 | 效果 |
|---|---|
| 薄膜与镀膜（7） | 薄膜干涉／肥皂泡、油膜、阳极氧化钛、镜头镀膜、二向色玻璃、牛顿环、蜻蜓翅膀 |
| 结构色与晕彩（6） | 欧泊、拉长石、闪蝶翅膀、吉丁虫鞘翅、孔雀羽、变色龙皮肤 |
| 珠光与柔光（3） | 珍珠母、珍珠、月光石 |
| 定向反光（4） | 猫眼效应、星光宝石、日光石、逆反射材料 |
| 偏振与体色（5） | 双折射／光弹性、液晶旋光、圆偏振金龟、变石效应、多色性 |
| 衍射与散斑（3） | 衍射光栅／CD、彩虹全息、激光散斑 |
| 色散与吸收（2） | 宝石火彩、吸收玻璃 |
| 视差与叠层（3） | 柱镜变图、彩色莫尔纹、视差星云 |
| 大气光学（2） | 雨虹与双虹、大气霞光 |

薄膜、光栅和偏振延迟采用光谱模型；生物结构色、宝石柔光等结合程序纹理与外观近似，主要用于观察效果与参数变化。

### 整体渲染逻辑

```text
选择效果 → AppModel 管理参数与加载状态
             ↓
        OpticsResources 按需取得材质模板及依赖
             ├─ 光谱效果：Metal Compute → LowLevelTexture → 共享 LUT
             └─ 程序效果：ShaderGraph 内直接计算
             ↓
        ShaderGraph 根据视角、法线、厚度与纹理计算光学颜色
             ↓
        替换体色／中性底色，保留光学分量 → 强度与透明度 → Unlit 输出
             ↓
        RealityKit 预览：visionOS 与 iOS 均显示四模型，共享材质与 LUT
```

LUT 将昂贵的光谱积分预计算为查找表：按 81 个波长采样，结合 CIE 1931 与 D65 转换为线性 RGB。运行时根据厚度、入射／观察角或相位差查表；视线相关变化仍逐帧计算。宝石与玻璃采样预制环境；柱镜与星云使用 Compute 生成的四视图／四层图集；雨虹与大气按光源、视线角度查询光谱表，不依赖屏幕空间后期。Compute pipeline 不可用时，使用后台 CPU 计算并通过异步 blit 上传。

基础色在光学合成前替换：宝石、行星、星云和 LCD 使用独立体色／背景分量，玻璃改变吸收系数；RGB LUT 以 `min(R,G,B)` 分离中性成分，保留彩色差值，并只在低饱和暗部补入底色。这是底色外观近似，不修改光谱 LUT；100% 替换仍保留彩色纹理、角度变化及独立高光。

### 性能优化

- **懒加载与请求合并**：只加载当前效果需要的模板和 LUT；同键并发请求共享任务，已加载资源直接复用，过期请求不会覆盖新选择。
- **GPU 预计算与缓存**：Compute 直接写入 `LowLevelTexture`，正常路径无需回读 CPU；共用计算管线与颜色权重；雨虹偏向角和 Rayleigh 系数按波长预计算一次，异步等待 GPU 完成。
- **材质实例与网格复用**：35 种效果共用 29 个 ShaderGraph 模板，各效果参数独立；两端同时显示球体、平面、尺子和光盘，复用网格、材质与 LUT。
- **混合精度**：颜色权重使用 `half4`，LUT 使用 `RGBA16F`；相位、Fresnel、坐标与光谱累加保留 `float32`。
- **减少重复计算与采样**：复用光谱循环中的公共项；油膜、阳极氧化钛、镜头镀膜和二向色玻璃均单次查表，二向色玻璃由未裁剪的反射颜色推导透射颜色。细微结构通过程序纹理和解析近似呈现；莫尔纹直接计算低频拍频，避免细条纹的亚像素闪烁；柱镜仅采样相邻两幅视图；图集限制采样范围，避免相邻视图串色。
- **按需更新**：肥皂膜折射率输入采用 120 ms 防抖，最多缓存 4 个版本；普通参数与基础色只更新材质参数，跳过相同值写入。暂停旋转时停止重复更新姿态。

## English

RealityOpticsShaderLab is a wave-optics and structural-color gallery for visionOS and iOS 18+. RealityKit ShaderGraph and Metal Compute render 35 effects on four shared preview shapes. Select the `RealityOpticsShaderLab-iOS` scheme for iPhone or iPad; `RealityOpticsShaderLab` runs on Vision Pro. The app follows the device's preferred Chinese or English language.

### Effects

| Group | Effects |
|---|---|
| Films and coatings (7) | Thin-film interference / soap bubbles, oil film, anodized titanium, lens coating, dichroic glass, Newton's rings, dragonfly wing |
| Structural color and iridescence (6) | Opal, labradorite, Morpho wing, beetle shell, iridescent feather, chameleon skin |
| Pearlescence and soft glow (3) | Nacre, cultured pearl, moonstone |
| Directional highlights (4) | Cat's eye, star gemstone, sunstone, retroreflective material |
| Polarization and body color (5) | Birefringence / photoelasticity, LCD twist, polarized scarab, alexandrite color change, pleochroism |
| Diffraction and speckle (3) | Diffraction grating / CD, rainbow hologram, laser speckle |
| Dispersion and absorption (2) | Gemstone fire, colored absorbing glass |
| Parallax and layers (3) | Lenticular images, color moiré, parallax nebula |
| Atmospheric optics (2) | Primary and secondary rainbows, planetary atmospheric glow |

Film, grating and polarization-delay effects use spectral models. Biological structural colors and gemstone glows combine procedural textures with visual approximations so their response to parameters and viewpoint remains easy to inspect.

### Rendering

```text
Select effect → AppModel manages parameters and load state
              → OpticsResources loads only the template and dependent LUTs
                 ├─ Spectral work: Metal Compute → LowLevelTexture → shared LUT
                 └─ Procedural work: direct ShaderGraph calculations
              → ShaderGraph uses view angle, normal, thickness and texture
              → Replace body/neutral base while retaining optical color
              → Intensity and opacity → Unlit output
              → Four RealityKit samples share the selected material and LUTs
```

The expensive spectra are sampled at 81 wavelengths and converted with CIE 1931/D65 to linear RGB before being cached as LUTs. View-dependent terms still update in the graph. A background CPU builder with asynchronous upload remains available when the Compute pipeline is unavailable. Base-color replacement targets a body's color, absorption, or the neutral component of an RGB LUT before optical composition. Colored fringes and separate highlights remain; RGB separation is an appearance approximation rather than a new spectral model.

### Performance

- Only the selected effect's template and LUTs load; requests for the same resource coalesce and cached resources are reused.
- Compute writes shared RGBA16F lookup textures without CPU readback on the normal path. Color weights use `half4`; spectral accumulation, phase, Fresnel and coordinates retain `float32`.
- The 35 effects share 29 ShaderGraph templates, while their mutable parameters stay independent. Sphere, plane, ruler and disc reuse meshes, selected material and LUTs on both devices.
- Optical formulas reuse common spectral terms. Coating and dichroic channels each take one LUT sample; moiré uses a low-frequency beat approximation; lenticular views sample only neighboring atlas images.
- Soap-film IOR edits are debounced by 120 ms and keep at most four LUT variants. Unchanged parameters and base colors avoid repeated material writes, and paused animation avoids repeated orientation updates.
