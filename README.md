# RealityOpticsShaderLab — 用 RealityKit ShaderGraph + LowLevelTexture 实现波动光学效果库

一个 visionOS 演示 App，实时呈现 **16 种波动光学与生物结构色**效果，通过效果库切换，每个效果带独立参数面板。薄膜、光栅与偏振延迟使用光谱模型，生物结构色等采用注明限制的外观近似。

2026-09-11 已完成全量计算与材质审查，修复坐标系、标准色度数据、牛顿环介质、白光相位、边界采样和数值稳定性等问题。详见 [逐项审查与验证记录](docs/SHADER_AUDIT.md)。

性能版已改为按选中效果懒加载、GPU Compute 生成 LUT 和共享材质实例；模拟器首个效果约 1.3 秒就绪。详见 [性能改动、实测与复现](docs/PERFORMANCE.md)。

## 效果目录（全部已实现）

| 效果 | 模型 / 近似 | 实现 | 几何 |
|---|---|---|---|
| 薄膜干涉·肥皂泡 | Fresnel + Airy 级数光谱积分 | 厚度×视角 LUT | 球 |
| 衍射光栅·CD | sinθi−sinθo = mλ/d 多阶合成 | sin差×密度 LUT | 微锥盘 |
| 珍珠母/珠光 | 三层板片膜平均 + σd=45 模糊 + 降饱和 | nacreLUT | 球 |
| 欧泊 play-of-color | Worley 距离场扰动的变彩近似 | worleynoise 扰动 LUT 坐标 | 球 |
| 双折射/光弹性 | 正交偏振片 T=sin²(δ·λref/2λ) | 相位差 LUT | 塑料尺盒 |
| 激光散斑 | 物体空间视线偏移 + 3D cellnoise + 阈值 | 纯图内（无 LUT） | 球 |
| 闪蝶翅膀 | 等效几丁质 216nm 膜，约 449nm 可见反射峰 | chitin filmLUT + abs(NdotV) | 翅面 |
| 吉丁虫鞘翅 | 绿带薄膜 + 视角彩虹条带混合 | 双 LUT mix | 椭球 |
| 蜂鸟/孔雀羽 | 薄膜蓝绿带 + 羽枝条纹 + glitter | filmLUT + sin 条纹 + cellnoise 星点 | 羽面 |
| 彩虹全息图 | 随视角滑动的分行衍射条纹 | gratingLUT + 行相位偏移 | 卡片 |
| 液晶旋光 | 像素晶域 + 斜视透过率与泄漏色 | cellnoise 像素 + 视角调色 | 面板 |
| 牛顿环 | 玻璃—空气—玻璃，空气隙按半径平方变化 | 专用 newtonLUT + r² | 圆形透明裁切平面 |
| 正圆珍珠 | 定向珠光 + 曲率体色渐变 | nacreLUT + 曲率与体色 | 球 |
| 蜻蜓翅膀 | 超薄膜干涉 + 半透明翅膜与脉络 | filmLUT + 脉络网格 | 翅面 |
| 变色龙皮肤 | 晶域主动变色 + 视角色相偏移 | gratingLUT + 晶域相位 | 球 |
| 圆偏振金龟子 | 左右旋色支与检偏器混合 | 双薄膜采样 + R→L 示意混合 | 椭球 |

## 界面布局

窗口默认 1280 × 820，最小 1060 × 680，采用三栏布局：

- **左侧效果库（242 pt）**：16 种效果双列排列，纵向滚动；选中项带蓝色描边和勾选标记。
- **中间实时预览**：随可用空间伸缩；RealityView 将视图边界转换到场景坐标，按模型的旋转包络等比缩放，避免模型侵入两侧控件。底部固定旋转开关与渲染状态。
- **右侧参数面板（330 pt）**：独立纵向滚动，每个参数以卡片展示名称、实时数值、滑杆和上下限；原生滑杆至少保留 44 pt 高度。切换效果回到参数顶部，已调整的值继续由 AppModel 保留。

效果说明位于参数末尾的折叠区，优先把操作空间留给调参。窗口最小尺寸由 `.windowResizability(.contentMinSize)` 约束，缩小时两侧通过滚动容纳内容。

新版模拟器截图：[三栏参数工作区](artifacts/ui_workspace_lcd.png)。

## 架构

```text
选择效果 → AppModel.ensureLoaded（合并并发请求）
             ├─ OpticsResources：按需加载 ShaderGraph 模板 / 复制参数实例
             └─ OpticsLUT：只请求该效果依赖的 LUT
                      ↓
               LUTRenderer + OpticsLUT.metal
               81 波长光谱积分 → LowLevelTexture.replace(using:)
                      ↓
               RGBA16F TextureResource（共享缓存）
                      ↓
               ShaderGraph：视角/厚度查表 → Unlit
```

正常路径在 GPU 生成 LUT：颜色权重使用 half4，光学相位、Fresnel 和光谱累加保留 float32，结果存为 RGBA16F。CPU 物理包作为独立数值参考及 Compute pipeline 不可用时的回退。GPU 完成以异步回调通知，不在主线程同步等待。

仅在首次访问效果时加载模板和依赖。薄膜、珍珠母、闪蝶使用同一个 ShaderGraph 模板的参数实例，16 种效果共 14 个运行时模板。光栅及几丁质等 LUT 在多个效果间共享。IOR 滑杆以 120 ms 合并连续输入，最多缓存 4 个 IOR 版本，旧请求不能覆盖最新值。其他效果的调参只改材质参数。

场景同时保留一个实体，复用球、平面、尺子、光盘四种网格资源；暂停时跳过重复的逐帧姿态写入。视线相关的颜色计算仍在 ShaderGraph 中实时执行。

## 目录

```
RealityOpticsShaderLab/
├── RealityOpticsShaderLab.xcodeproj  # visionOS 2.0+，objectVersion 77（文件系统同步组）
├── RealityOpticsShaderLab/           # App：RealityView 场景 + 控制面板 + LUT 纹理工厂
│   ├── AppModel.swift             # 参数状态、按需加载、取消与热更新
│   ├── OpticsResources.swift      # LUT / 材质模板缓存、参数实例
│   ├── OpticsLUT.metal            # GPU 光谱积分，half 权重 / float 相位
│   ├── OpticsMeshes.swift         # 四种共享网格资源
│   ├── ContentView.swift          # 三栏工作区、预览标题、旋转控制与状态
│   ├── EffectLibraryView.swift    # 双列效果库
│   ├── ParameterPanelView.swift   # 独立滚动参数卡片与折叠说明
│   ├── OpticsEffect.swift         # 16 种效果的名称、图标与机制说明
│   ├── OpticsSceneView.swift      # 自适应 RealityView、转台式自转
│   ├── DiscMesh.swift             # 微锥形 CD 网格（UV 副切线提供径向，绕序与法线一致）
│   └── LUTTextureFactory.swift    # GPU Compute → LowLevelTexture / CPU 回退
├── Packages/OpticsPhysics/        # 纯 Swift 物理包（swift test 可在 macOS 直接跑）
│   ├── Spectrum.swift             # 官方 CIE CMF / D65 / 预计算线性 RGB 积分权重
│   ├── ThinFilm.swift             # 三层膜反射率光谱
│   ├── DiffractionGrating.swift   # 光栅方程 + 阶数合成
│   ├── LUTBuilder.swift           # CPU 参考：光谱 LUT + Float16
│   └── OpticsLUT.swift             # 缓存键、尺寸、GPU 参数和 CPU 参考入口
├── Packages/OpticsContent/        # 材质包（.usda 以松散资源随 bundle 发布）
│   └── Materials/*.usda          # 16 个材质图
├── Scripts/                       # 材质图检查与模拟器自动截图
├── docs/SHADER_AUDIT.md            # 全量修复说明与验证边界
└── artifacts/                     # 模拟器验收截图与运行日志
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
- CPU 的 `sinIn/sinOut` 使用传播方向分量；图内 L、V 均指向表面外侧，因此用 `(L+V)·P` 查表（阶数正负对称）
- 图内以入射余弦调节衍射亮度，另加微弱零级镜面；不再用窄镜面瓣压掉有效衍射色
- 高斯谱带和阶次权重是简化效率模型，不等同于真实光栅的 blaze/偏振响应

## 构建与运行

```bash
# 物理单测（34 个，host 直接跑）
swift test --package-path Packages/OpticsPhysics -c release

# 16 个材质的连接、类型、坐标、边界与参数默认值检查
python3 Scripts/validate_materials.py

# 本机 Metal 与 CPU 的逐 texel 对照（含半精度误差检查）
python3 Scripts/verify_compute.py

# 构建 + 模拟器运行
xcodebuild -project RealityOpticsShaderLab.xcodeproj -scheme RealityOpticsShaderLab \
  -destination 'platform=visionOS Simulator,name=Apple Vision Pro,OS=26.5' build
xcrun simctl install booted <DerivedData>/Debug-xrsimulator/RealityOpticsShaderLab.app
xcrun simctl launch booted com.reality.RealityOpticsShaderLab
```

Xcode 26.6 / visionOS 26.5 模拟器验证通过；部署目标 visionOS 2.0。

## 手写 .usda 材质图的踩坑记录

- 几何节点必须显式选择坐标空间：Normal/Tangent 默认 object，View Direction 默认 world，不能直接混算。
- LUT 的 U/V 地址模式必须显式 clamp；厚度/视角端点不应回绕。

0. **RealityKit 纹理采样 V 轴与 blit 写入行序相反**：MaterialX 自下而上采样，
   CPU 字节自上而下写入，所有 LUT 的 V 轴实际读的是镜像数据（彩虹类效果看不出错，
   定向效果如闪蝶蓝带直接错位）。在 `LUTTexture.upload()` 统一翻转行序。
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

- **暂停旋转 / 继续旋转**：暂停或恢复转台自转，便于从不同角度观察静态的干涉/衍射色
- 薄膜：ThicknessScale/Bias（厚度分布）、NoiseAmount（fractal 扰动）、Gain、Opacity、
  Film IOR（**触发 LUT 重建**，1.20–1.45）
- 光栅：DensityScale/Bias（径向密度映射）、Gain、LightAzimuth（光源方位角）

## 参考

- Belcour & Barla, *A Practical Extension to Microfacet Theory for the Modeling of
  Varying Iridescence*, SIGGRAPH 2017（厚度抗混叠思想）
- Andrew Glassner, *Soap Bubbles*（肥皂泡光学基础）
- [CIE 1931 2° 标准观察者](https://www.cie.co.at/datatable/cie-1931-colour-matching-functions-2-degree-observer) / [CIE D65 标准光源](https://www.cie.co.at/datatable/cie-standard-illuminant-d65)：官方数据按 5nm 取样
- 项目结构参考：VisionOSShadersBookExample（LowLevelTexture 链路）、
  RealityGlitchArt / RealityShaderExtension（ND_* 节点清单与 usda 语法）
