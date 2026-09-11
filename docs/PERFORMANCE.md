# 性能优化与实测

2026-09-11。本轮针对初始化、资源复用和调参更新；延续前一轮光学修复与三栏 UI。

## 结果

| 项目 | 优化前 | 当前 |
|---|---|---|
| 初始化策略 | 先生成 6 张 LUT，再加载 16 个材质，全部完成才 Ready | 只加载当前效果和依赖；未访问效果不初始化 |
| 首个效果资源就绪 | 全量加载器此前记录约 29.5–35.2 秒 | 新进程实测 1.15–1.30 秒 |
| 首次薄膜的 LUT 负载 | 全部 6 张，共约 2.76 MiB | 1 张，0.50 MiB |
| 材质模板 | 16 个独立加载入口 | 访问全部效果后 14 个模板；3 个薄膜类效果共享 1 个模板 |
| IOR 连续输入 | 每次输入启动一份 CPU 积分，取消只丢弃最终结果 | 120 ms 防抖；相同键请求合并；最多缓存 4 个 IOR 版本 |
| 网格 | 切换时反复生成 | 球、平面、尺子、光盘共 4 种共享资源 |
| GPU 等待 | 主线程 `waitUntilCompleted()` | completion handler + async continuation |

启动数据来自本机 visionOS 26.5 模拟器、Debug 配置的新进程。应用资源缓存为空，系统/驱动缓存未清空。旧计时是全量加载函数耗时，新计时从 AppModel 创建到当前效果资源 Ready；**均不代表光子级首帧呈现测量，也不代表真机帧率**。记录见 [旧加载日志](../artifacts/shader-audit/runtime.log)、[新加载与全部效果截图日志](../artifacts/performance-audit/runtime.log)、[缓存回归日志](../artifacts/performance-cache-audit/runtime.log)。

## 按需加载与取消

`ContentView.task(id: selectedEffect)` 驱动当前效果的加载。`AppModel`、`OpticsResources` 分别合并相同效果、相同模板、相同 LUT 的并发请求。切换时取消旧的界面等待，已开始的共享资源任务完成后存入缓存；旧请求不会更新新效果的状态。

加载完成后使用最新的参数，而非任务开始时的参数快照。IOR 更新只应用最后一次编辑，回到已显示的 IOR 会立即退出更新状态。不可见薄膜的修改推迟到再次访问时处理。失败时提供重试入口；GPU 提交失败不会伪装成 Ready。

缓存保存在进程内。固定的五张 LUT 只在用到时各生成一次；可变 soap LUT 使用四项 LRU。全部访问并多次调 IOR 后，缓存上界为 9 张，像素负载约 **4.26 MiB**。该数字不包含 RealityKit/Metal 的内部纹理池、驱动元数据或正在显示的已淘汰纹理引用。

## Compute Shader 与精度

`OpticsLUT.metal` 在 GPU 上完成光谱积分，直接写入 `LowLevelTexture.replace(using:)` 返回的纹理。一个 device、queue、pipeline 和颜色权重 buffer 供全部 LUT 复用。生成结果作为不可变 `TextureResource` 分享给材质，正常流程没有 GPU→CPU 回读或 staging-buffer 复制。

- 薄膜与珍珠母使用对称介质的 Airy 化简式，Fresnel 系数和相位在一个 texel 的光谱循环中复用。
- 牛顿环利用 Snell 关系直接取得空气隙中的余弦，避免临界附近相减损失有效位。
- 膜厚平均仍为五点 Gauss–Hermite；仍使用 81 个波长和原 LUT 分辨率。
- 小幅度颜色权重存为 **half4**，纹理保留 **RGBA16F**。相位、余弦、Fresnel 分母、光谱累加和坐标使用 **float32**。
- 首次 pipeline 编译也异步完成。Compute pipeline 不可用时，保留后台 CPU 参考计算和异步 blit 回退。
- Compute 使用 `dispatchThreadgroups` 完整线程组调度，组数向上取整，内核检查纹理边界。修复了 visionOS 26.5 模拟器开启 Metal API Validation 时，`dispatchThreads` 因设备不支持非均匀线程组而触发断言的问题；单行 LUT 的线程组高度为 1。参见 Apple 的 [线程组与网格尺寸说明](https://developer.apple.com/documentation/metal/calculating-threadgroup-and-grid-sizes)。

使用方式依据 Apple 的 [LowLevelTexture 文档](https://developer.apple.com/documentation/realitykit/lowleveltexture) 和 [空间绘画示例](https://developer.apple.com/videos/play/wwdc2024/10104/)。

完整分辨率逐 texel 比较结果：

| LUT | CPU `-O` 积分 | GPU 提交至完成 | 最大 RGB 绝对误差 |
|---|---:|---:|---:|
| Soap，IOR 1.333 | 209.2 ms | 3.37 ms | 0.000977 |
| Morpho | 209.7 ms | 4.86 ms | 0.000977 |
| Nacre | 645.3 ms | 14.02 ms | 0.000488 |
| Grating | 19.3 ms | 2.51 ms | 0.000244 |
| Birefringence | 0.63 ms | 4.10 ms | 0.000977 |
| Newton | 100.4 ms | 1.28 ms | 0.000488 |

这里是 macOS 上同一 Metal 内核与 CPU 参考的单次测量，GPU 列包含提交/等待开销，不含 pipeline 初次编译、RealityKit 纹理封装和 GPU 结果回读。小尺寸的双折射 LUT 中，提交开销高于 CPU 计算；它仍只生成一次并缓存，不是逐帧工作。另验证了 IOR 1.20 与 1.45。全部通道最大误差低于 0.001，最大 RMSE 约 0.000088；验证也覆盖 V 轴方向、有限性、非负输出及 alpha=1。原始数据见 [Compute 对照日志](../artifacts/performance-audit/compute-parity.log)。

## 材质实例与其他复用

薄膜、珍珠母、闪蝶的实际图结构一致，统一从 `IridescentFilmMaterial` 模板复制 `ShaderGraphMaterial` 参数实例，分别绑定 soap/nacre/chitin LUT，并维持各自的厚度、增益与透明度。实例参数隔离已经实测。原 Nacre/Morpho USDA 保留为独立参考和兼容资源，正常路径不加载它们。

这采用了 Apple 推荐的 [材质实例复用方式](https://developer.apple.com/videos/play/wwdc2024/10186/)。共享的是材质定义和相关资源，具体 GPU 管线变体仍由 RealityKit 决定；本轮没有测量内部着色器分配字节数。

当前预览同时仅显示一个实体，已经只有一个待绘制对象，因此主要收益来自共享模板、LUT 与网格资源。大量重复物体场景才有可合并的 mesh draw instancing 工作，本轮没有为单物体预览引入 visionOS 26 专属的批量实例 API。

额外优化包括：缓存参数 handle，跳过值相同的参数写入；暂停时只在新实体出现后设置一次姿态；保持一个活动实体，复用四种网格。生物结构色沿用之前注明的视觉近似。视线/法线决定的颜色仍实时计算；没有把随观察角变化的结果烘焙成固定贴图。

## 验证

- 34 项 CPU 物理回归通过；16 材质、558 节点及 62 个参数默认值静态检查通过。
- 8 组完整 LUT 的 Metal/CPU 对照通过（含 3 个 soap IOR）。
- 16 效果按需加载、默认/最小/最大共 48 组场景/绑定检查通过；保存了全部默认截图，复查了共享模板和四类几何的画面。
- 三个效果仅加载一个模板；修改一个实例不影响另外两个实例。
- 三个并发同键 LUT 请求只生成一次并返回同一纹理对象。
- 取消过期选择后当前效果仍为 Ready；30 次连续 IOR 修改只产生一次新的计算。
- IOR 四项 LRU 上界通过；160 次已加载材质请求没有模板重载或 LUT 重算。后者仅为缓存 API 检查，不当作交互帧率。
- Debug 和 Release 模拟器配置构建通过；真机 GPU 帧时间、功耗和系统内存峰值尚未测量。
- 调度兼容性修复后，Debug 重建通过；开启 Metal API Validation 的 visionOS 26.5 模拟器通过全部效果加载与缓存回归。macOS 同时开启 API/GPU Validation，8 组原尺寸 LUT 与新增 257×129 边缘线程用例全部通过，最大 RGB 误差为 0.000977。记录见 [模拟器日志](../artifacts/dispatch-compatibility-audit/runtime.log) 和 [Compute 对照日志](../artifacts/dispatch-compatibility-audit/compute-parity.log)。

```bash
swift test --package-path Packages/OpticsPhysics -c release
python3 Scripts/validate_materials.py
python3 Scripts/verify_compute.py

# 安装 Debug app 后（检查入口不会编入 Release）
python3 Scripts/capture_shader_audit.py --device booted --output artifacts/performance-audit
python3 Scripts/capture_shader_audit.py --device booted --performance --output artifacts/performance-cache-audit

# Metal 校验与非整除尺寸回归
MTL_DEBUG_LAYER=1 MTL_SHADER_VALIDATION=1 python3 Scripts/verify_compute.py
SIMCTL_CHILD_MTL_DEBUG_LAYER=1 python3 Scripts/capture_shader_audit.py --device booted --performance --output artifacts/dispatch-compatibility-audit
```

实现入口：`AppModel.swift`（加载/调参）、`OpticsResources.swift`（缓存/实例）、`OpticsLUT.metal` 与 `LUTTextureFactory.swift`（GPU）、`OpticsMeshes.swift`（网格复用）。
