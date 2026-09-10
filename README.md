# RealityOpticsShaderLab — 用 RealityKit ShaderGraph + LowLevelTexture 实现波动光学效果

一个 visionOS 演示 App，在 Apple 平台上以"物理优先"的方式实时呈现两种波动光学现象：

| 物体 | 效果 | 物理机制 |
|---|---|---|
| 左：肥皂泡球 | 随厚度与视角变化的彩虹薄膜色 | 薄膜干涉（Airy 级数 + Fresnel 振幅） |
| 右：CD 圆盘 | 高光附近的径向彩虹条纹 | 反射式衍射光栅方程 |

## 架构

```
┌─────────────── CPU（Swift，物理模拟）───────────────┐
│ Spectrum:  CIE 1931 CMF × D65 → XYZ → 线性 sRGB      │
│ ThinFilm:   精确 Fresnel (s/p) + Airy 求和 + σd 抗混叠 │
│ Grating:    sinθi − sinθo = mλ/d，多阶光谱合成        │
│ LUTBuilder: 光谱积分 → RGBA16F 字节                    │
└────────────────────┬──────────────────────────────────┘
                     │ LowLevelTexture(descriptor: .rgba16Float)
                     │ texture.replace(region:withBytes:)  ← 运行时可热更新
                     ▼ TextureResource(from:)
┌─────────── GPU（手写 .usda MaterialX 材质图）──────────┐
│ NdotV / 厚度(remap+fractal3d) → combine2 → 采样 LUT     │
│ → multiply → ND_realitykit_unlit (color + opacity)     │
│ 参数经 ShaderGraphMaterial.setParameter 注入            │
└─────────────────────────────────────────────────────────┘
```

物理在 CPU 完整做光谱积分（380–780nm，81 采样），烘焙成 2D LUT；材质图只做廉价的每像素查表与几何计算。改 IOR 滑杆会后台重建薄膜 LUT 并热替换，无需重建材质。

## 目录

```
RealityOpticsShaderLab/
├── RealityOpticsShaderLab.xcodeproj  # visionOS 2.0+，objectVersion 77（文件系统同步组）
├── RealityOpticsShaderLab/           # App：RealityView 场景 + 控制面板 + LUT 纹理工厂
│   ├── AppModel.swift             # 参数状态、材质加载、LUT 热更新
│   ├── OpticsSceneView.swift      # 气泡球 + CD 盘，转台式自转
│   ├── DiscMesh.swift             # 微锥形 CD 网格（法线外倾 ⇒ 图内可恢复径向）
│   └── LUTTextureFactory.swift    # LowLevelTexture → TextureResource → upload()
├── Packages/OpticsPhysics/        # 纯 Swift 物理包（swift test 可在 macOS 直接跑）
│   ├── Spectrum.swift             # CIE CMF / D65 / XYZ→sRGB / 白点归一化
│   ├── ThinFilm.swift             # 三层膜反射率光谱
│   ├── DiffractionGrating.swift   # 光栅方程 + 阶数合成
│   └── LUTBuilder.swift           # 两个 LUT + f32→f16 编码
├── Packages/OpticsContent/        # 材质包（.usda 以松散资源随 bundle 发布）
│   └── Materials/{IridescentFilmMaterial, DiffractionGratingMaterial}.usda
└── artifacts/                     # 模拟器验收截图
```

## 物理要点

**薄膜干涉**（肥皂泡 = air/soap(n≈1.333)/air）：
- 相位差 `δ = 4π·n₂·d·cosθ₂ / λ`，Fresnel 振幅的符号自动携带 π 半波损失
- 反射率 `R(λ) = |(r₁₂ + r₂₃e^{-iδ}) / (1 + r₁₂r₂₃e^{-iδ})|²`，s/p 偏振取平均
- 厚度方向按 N(d, σd=15nm) 数值积分抗混叠（Belcour & Barla 2017 思路）
- LUT：U = cosθ ∈ [0,1]，V = 厚度 ∈ [0, 1200nm]，256×256 RGBA16F

**衍射光栅**（CD ≈ 625 线/mm）：
- 光栅方程 `sinθᵢ − sinθₒ = mλ/d`，m = ±1, ±2，按 1/m² 加权
- LUT：U = (sinθᵢ − sinθₒ + 2)/4，V = 密度 300–2000 线/mm，256×128
- 图内用 `NdotH^18` 的镜面权重把彩虹约束在反射高光附近

## 构建与运行

```bash
# 物理单测（16 个，host 直接跑）
cd Packages/OpticsPhysics && swift test

# 构建 + 模拟器运行
xcodebuild -project RealityOpticsShaderLab.xcodeproj -scheme RealityOpticsShaderLab \
  -destination 'platform=xros Simulator,name=Apple Vision Pro,OS=26.5' build
xcrun simctl install booted <DerivedData>/Debug-xrsimulator/RealityOpticsShaderLab.app
xcrun simctl launch booted com.reality.RealityOpticsShaderLab
```

Xcode 26.6 / visionOS 26.5 模拟器验证通过；部署目标 visionOS 2.0。

## 手写 .usda 材质图的踩坑记录

0. **RealityView 的 make 闭包里不要读 @Observable 状态**：SwiftUI 会在状态变化时重跑
   make，导致场景被重建/订阅堆积。本项目 make 只建空根节点，物体创建与材质同步由
   `AppModel.materialRevision` 驱动（`syncSceneObjects()`），make 内经非结构化 Task
   补一次初始同步。
0. **不要用 `MTLTexture.replace(region:withBytes:)` 直写 `LowLevelTexture.read()` 返回的
   纹理**：会与 RealityKit 在飞行中的帧竞争，模拟器上偶发主线程死锁（进程僵死、
   SIGTERM 杀不掉，`sample` 可见卡在 replace）。应走文档化 GPU 路径：
   `lowLevelTexture.replace(using: commandBuffer)` 取目标纹理 + blit 编码器从
   staging buffer 拷入（同参考工程的 compute-shader 模式）。
1. **`.rkassets` 会被编译进单一 `.reality` 归档**（Xcode 26.6）。要从
   `ShaderGraphMaterial(named:from:)` 按 usda 路径加载，需把 usda 放在普通目录并声明
   `resources: [.copy("Materials")]` 随 bundle 松散发布。
2. **`LoadError error 6` = 端口类型不匹配**。真因要去系统日志里找：
   `log show … | grep shadergraph`，例如
   `float (mtlx:named(float)) != float3` / `Unknown input name 'in'`。
3. MaterialX 节点输入名/类型陷阱（SDK 不会校验 usda，错在运行时）：
   - `ND_fractal3d_color3`：`amplitude` 是 **float3**、`octaves` 是 **int**
   - `ND_power_float` 输入是 **in1/in2**（不是 in/power）
   - 二元数学节点（multiply/add/subtract/dotproduct）一律 `in1`/`in2`
   - `ND_mix_float` 是 `bg/fg/mix`；`ND_clamp_float` 是 `in/low/high`
4. Material prim 骨架建议带一个 inactive 的 `DefaultSurfaceShader`
   （`info:id = "UsdPreviewSurface"`）并把 `outputs:surface.connect` 指向它，
   `outputs:mtlx:surface.connect` 指向真正使用的表面节点。

## 参数面板

- **Pause/Play**：暂停或恢复转台自转，便于从不同角度观察静态的干涉/衍射色
- 薄膜：ThicknessScale/Bias（厚度分布）、NoiseAmount（fractal 扰动）、Gain、Opacity、
  Film IOR（**触发 LUT 重建**，1.20–1.45）
- 光栅：DensityScale/Bias（径向密度映射）、Gain、LightAzimuth（光源方位角）

## 参考

- Belcour & Barla, *A Practical Extension to Microfacet Theory for the Modeling of
  Varying Iridescence*, SIGGRAPH 2017（厚度抗混叠思想）
- Andrew Glassner, *Soap Bubbles*（肥皂泡光学基础）
- CIE 1931 2° 标准观察者 / D65 标准光源数据
- 项目结构参考：VisionOSShadersBookExample（LowLevelTexture 链路）、
  RealityGlitchArt / RealityShaderExtension（ND_* 节点清单与 usda 语法）
