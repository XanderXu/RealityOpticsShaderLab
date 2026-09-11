# Shader 全量审查与修复

日期：2026-09-11。范围：16 个 USDA 材质、OpticsPhysics 光谱与 LUT、Swift 参数绑定、纹理上传和模型方向。此前的三栏 UI 调整继续保留。

## 主要问题

### 坐标和数值

- **跨坐标系点积**：原材质直接混合默认 object-space 法线与默认 world-space 视线，转动物体时光学角度会错误。现在法线、切线及相关视线显式使用世界坐标并归一化。散斑的位置与视线同时使用物体坐标。
- **退化切向量**：原径向/全息方向通过固定 Up 与法线投影或叉乘构造，平行时可能变成零向量。现在使用网格的切线/副切线；径向、半向量及偏振轴投影采用带最小长度保护的归一化。CD 三角形绕序改为与上向法线一致。
- **LUT 默认回绕**：全部查表节点显式设置 U/V clamp，避免膜厚、视角端点与另一端插值。
- **负相位取模**：周期图案统一使用 `x - floor(x)`，保证负输入仍处于 `[0,1)`。物理上不周期的白光相位不再取模。
- **强度超过 1 后出现负辐射值**：统一改为内置 `mix`，并对输出作非负钳制。保留线性 HDR 增益。
- 参数入口拒绝 NaN/Inf 并限制在滑杆范围内；材质绑定和 GPU 上传失败会返回错误状态，不再静默显示 Ready。

Apple 文档明确了 [Normal](https://developer.apple.com/documentation/shadergraph/geometric/normal)、[Tangent](https://developer.apple.com/documentation/shadergraph/geometric/tangent) 的 object 默认值，以及 [View Direction](https://developer.apple.com/documentation/shadergraph/realitykit/view-direction-(realitykit)) 的 world 默认值和表面指向相机的方向。标准节点端口同时与 [MaterialX 官方定义](https://github.com/AcademySoftwareFoundation/MaterialX/blob/main/libraries/stdlib/stdlib_defs.mtlx) 核对。

### 光谱与薄膜

- **CIE/D65 数据错误**：替换原有不准确的数组，直接采用 CIE 官方数据的 380–780 nm、5 nm 样本。移除会掩盖错误白点的逐 RGB 通道补偿，仅作 Y 归一化。光谱混合保持线性，到纹理编码阶段才裁切负 RGB。
- **薄膜的零厚度、匹配介质和全反射边界**：零厚度返回外介质—基底界面反射率；相同介质完全消失。对倏逝波使用复数 Fresnel/Airy，保留全反射相位与薄空气隙的隧穿行为。
- **厚度分布平均**：改为五点 Gauss–Hermite 正态分布节点与权重；sigma=0 直接求值。
- **衍射谱带跳变**：原来谱带中心越过可见区边界时整阶被丢弃，并改变归一化分母。现在保留高斯尾部，按全部建模阶次的固定权重归一化，消除边界亮度突跳。
- **半精度转换**：改用 Swift `Float16` 的标准舍入，修复 65520 等溢出舍入边界。

数据来源和校验值：

| 数据 | 来源 | 下载文件 MD5 |
|---|---|---|
| CIE 1931 2° CMF | [CIE 数据页](https://www.cie.co.at/datatable/cie-1931-colour-matching-functions-2-degree-observer)，DOI 10.25039/CIE.DS.xvudnb9b | `17cca777db64b17170f06f67ce9d3ab7` |
| CIE D65 | [CIE 数据页](https://www.cie.co.at/datatable/cie-standard-illuminant-d65)，DOI 10.25039/CIE.DS.hjfjmt59 | `03d4eb9b837c60671627c946fb534deb` |

## 16 个效果的结果

下表中的每个效果均应用了上述适用的共性修复，并完成实际材质加载和参数边界运行。链接为默认参数截图。

| 效果 | 独立检查与修复 | 模型边界 |
|---|---|---|
| [薄膜干涉](../artifacts/shader-audit/thinFilm.jpg) | 修正光谱数据、Fresnel 边界、膜厚平均；双面角度使用绝对余弦；启动与热更新使用当前 IOR | 无吸收、无色散的单层膜；透明度为展示参数 |
| [衍射光栅](../artifacts/shader-audit/grating.jpg) | L/V 均向表面外，改用 `(L+V)·P`；恢复正确径向，防止零向量；入射余弦控制衍射亮度，微弱镜面单独添加 | 1/m² 阶次效率和高斯谱宽为近似，不求解 blaze 或偏振 |
| [珍珠母](../artifacts/shader-audit/nacre.jpg) | 使用修正的 CIE、薄膜及厚度积分；修正背面角度和 LUT 边界 | 三种独立膜厚的非相干平均与降饱和，不是相干多层传输矩阵 |
| [欧泊](../artifacts/shader-audit/opal.jpg) | 修正切向退化、视线坐标和光栅 LUT 边界 | Worley 距离场扰动的斑块外观，不是三维光子晶体求解 |
| [双折射](../artifacts/shader-audit/birefringence.jpg) | 白光谱相位不能按参考波长的 2π 周期重复；改为连续 0–40π LUT；轴投影使用一致坐标；移除 0.05 的假消光下限 | 应力场是程序化近似；透过率公式对应理想正交偏振片 |
| [激光散斑](../artifacts/shader-audit/speckle.jpg) | 阈值上界不再超过噪声最大值；三维物体空间噪声替代球面 UV，消除极点拉伸；向量运算替代逐分量拼接 | 哈希颗粒外观，不是相干波场叠加；极高密度仍受屏幕采样限制 |
| [闪蝶](../artifacts/shader-audit/morpho.jpg) | 默认厚度 0.18 原先低于滑杆下限 0.2，下限改为 0.12；修正蓝峰阶次说明和通用角度计算 | 等效几丁质薄膜，不求解翅鳞树状纳米结构 |
| [吉丁虫](../artifacts/shader-audit/beetle.jpg) | 原有带符号的虹彩坐标遗漏偏置，导致一半视角夹死；改为 `0.25·VdotP+0.5` | 绿带薄膜与衍射色混合，无椭圆偏振求解 |
| [孔雀羽](../artifacts/shader-audit/feather.jpg) | 检查羽枝正弦、闪点阈值及厚度范围；应用坐标、光谱、采样修复并删去冗余节点 | 条纹与闪点是外观近似 |
| [彩虹全息](../artifacts/shader-audit/hologram.jpg) | 网格切线替代固定 Up 叉乘；负的视线/行相位用 floor-fract，避免边缘停滞 | 分行衍射图案，不重建真实物体波前 |
| [液晶](../artifacts/shader-audit/lcd.jpg) | Worley 距离值改为每像素固定随机阈值；电压 0 全关闭、1 全开启暗像素；视角余弦先绝对值并钳制 | 经验像素与漏光模型，不求解液晶指向矢/Jones 矩阵 |
| [牛顿环](../artifacts/shader-audit/newton.jpg) | 不再借用 air/soap/air LUT；新建 glass/air/glass LUT，外部视角先经 Snell 折射；支持 0–3000 nm；圆盘用 `0.25-r²` 与透明度裁切 | 球面透镜空气隙的近轴 r² 近似；不含外玻璃表面反射 |
| [珍珠](../artifacts/shader-audit/pearl.jpg) | 检查曲率偏置、体色及高光范围；应用珠光积分、世界空间角度与 clamp 修复 | 人工曲率体色、高光与非相干珠光模型 |
| [蜻蜓翅](../artifacts/shader-audit/dragonfly.jpg) | 翅脉 smoothstep 区间随宽度缩放，避免变细时峰值消失；透明度直接在膜与 0.95 的翅脉间 mix | 规则网格代表翅脉，等效薄膜代表翅膜 |
| [变色龙](../artifacts/shader-audit/chameleon.jpg) | 检查时间、视角、晶域相位路径；周期图案显式 floor-fract；应用坐标与光谱修复 | Worley 与色彩循环的外观模型，不计算生物信号或晶格动力学 |
| [圆偏振金龟子](../artifacts/shader-audit/scarab.jpg) | 删除把 `N·(V×T)` 当成偏振手性的错误项；滑杆直接控制两支的线性混合，两个端点可达；移除多余手性参数 | 明确标为色支示意，非真实圆偏振或检偏器角响应 |

## 简化与性能

- D65、CMF、XYZ→RGB 的线性权重预计算一次，避免每个 texel 重复光谱到 XYZ 再到 RGB 的准备工作。
- Fresnel 系数按视角列预计算；Airy 化简为一次 `sin²`，各偏振共享相位。仅全反射路径使用复数计算。
- 光栅利用正负阶对称性，复用输出缓冲区，不再逐阶分配临时光谱数组。
- 双折射改为单行 1024×1 LUT，替换重复八行的 512×8 LUT；范围扩大同时去掉无效重复存储。
- 六个独立 LUT 并发生成，统一材质加载与纹理绑定循环；保留 IOR 重建取消过期任务的行为。
- 材质节点总数从 **584 降到 558**（均含 inactive PreviewSurface）。双折射与光栅因数值保护增加少量节点，其余通过 mix、向量运算和删除死节点减少重复计算。

节点减少不直接等于 GPU 帧率提升，编译器可能原本就会折叠部分算式。本轮不宣称未测量的加速比例。

## 验证与复现

### 已执行

1. **Swift 物理测试 34/34 通过**（原有 19 项，新增 15 项）：官方 D65 色度、解析四分之一/半波膜、零厚度、匹配介质、全反射/受抑全反射、独立复数展开比较、牛顿环光学周期、光栅谱带连续性、Float16 舍入、非周期白光延迟及 LUT 有限性。
2. **16 个材质、558 个节点、62 个效果参数默认值检查通过**：端口类型、引用、环路、无用节点、坐标空间、LUT clamp、关键公式的边界回归。另用 MaterialX 官方 stdlib 核对标准节点定义。
3. **Xcode 26.6 / visionOS 26.5 模拟器构建成功**，部署目标 visionOS 2.0。
4. **16/16 材质实际加载成功，默认/最小/最大共 48 组状态通过绑定和场景检查**，并逐张检查默认参数截图。见 [运行日志](../artifacts/shader-audit/runtime.log)。随后对三维散斑修复单独重复三组检查，见 [散斑复查日志](../artifacts/shader-audit/speckle-runtime.log)。

运行检查同时设置某效果全部滑杆的最小值或最大值；不穷举每个参数之间的所有组合。算术脚本中的纹理、噪声及几何来源使用有限值夹具，验证的是图中算术和连接，不替代 GPU 渲染。模拟器系统日志中未发现本项目材质节点或端口加载失败；仍有系统组件的网络、TBB 和默认二进制缓存提示。尚未在 Vision Pro 真机测量性能、双眼差异和手势交互。

### 命令

```bash
swift test --package-path Packages/OpticsPhysics -c release
python3 Scripts/validate_materials.py
# 可选：已下载的官方 MaterialX stdlib_defs.mtlx
python3 Scripts/validate_materials.py --stdlib /path/to/stdlib_defs.mtlx

xcodebuild -project RealityOpticsShaderLab.xcodeproj \
  -scheme RealityOpticsShaderLab \
  -destination 'platform=visionOS Simulator,name=Apple Vision Pro,OS=26.5' \
  -derivedDataPath /tmp/RealityOpticsShaderAudit-build CODE_SIGNING_ALLOWED=NO build
xcrun simctl install booted \
  /tmp/RealityOpticsShaderAudit-build/Build/Products/Debug-xrsimulator/RealityOpticsShaderLab.app
python3 Scripts/capture_shader_audit.py --device booted
# 仅复查单个效果（使用独立输出目录保留全量日志）
python3 Scripts/capture_shader_audit.py --device booted --effect speckle --output /tmp/speckle-audit
```

自动检查入口仅在 DEBUG 且显式设置 `OPTICS_AUDIT=1` 时运行，不改变正常启动行为。脚本在检查结束后关闭本应用；可用 `xcrun simctl launch booted com.reality.RealityOpticsShaderLab` 恢复正常运行。
