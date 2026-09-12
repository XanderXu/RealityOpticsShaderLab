# 材质基础色替换

基础色在各效果的体色、吸收或中性成分处生效。滑块默认 100%，表示完成底色替换；0% 或“原始”恢复原来的效果。效果强度、透明度仍独立控制。

| 类型 | 替换位置 | 保留内容 |
|---|---|---|
| 猫眼、星光宝石、月光石、拉长石、日光石、逆反射 | 带原有明暗的体色 | 亮带、星芒、闪点、柔光 |
| 珍珠、干涉、衍射、结构色等 RGB 图案 | 增益和后续高光合成之前的中性分量 | 彩色差值、纹理、独立高光与遮罩 |
| 吸收玻璃 | 单位光程吸收系数 | 折射方向、厚度吸收、Fresnel 表面反射 |
| LCD | 明态衬底 | 暗态像素、斜视漏光 |
| 星云、雨虹、大气 | 最远背景、天空或行星表面 | 云层遮挡、虹带、散射光 |
| 散斑 | 闪点之间的背景 | 激光色及闪点覆盖率 |

RGB LUT 的近似：把 `min(R,G,B)` 视作中性成分，替换其颜色而保留 RGB 彩色差值。在低饱和暗部补入底色；饱和的暗色干涉条纹不被白色抬亮。宝石火彩还保护了预制环境中的强高光。它不能恢复真实材料的完整光谱分层，适合当前 Unlit 演示架构。

玻璃保留相对光谱吸收，将公共吸收项替换为所选颜色对应的 `−ln(max(color, 0.002))`；五种色卡的系数在 CPU 上缓存，继续使用已有的光程和指数运算。厚度为零时不吸收，换色不影响表面反射。

颜色和替换比例仅更新材质参数。新增的是少量图内算术，不增加纹理采样、LUT 数量或重建；29 个模板仍供 35 种效果共享。统一生成入口是 `python3 Scripts/generate_extended_materials.py`，底色策略集中在 `Scripts/base_color.py`。

## 验证

- MaterialX 端口、类型、连接及算术检查通过：31 个材质文件、136 个 UI 默认值。
- 837 组原始采样在替换 0% 时保持一致，重复生成 31 个文件内容一致。
- iOS 模拟器 Debug、iPhone Release、visionOS Debug 构建通过。
- iOS 运行时检查覆盖 35 种效果、5 种颜色、3 个替换比例及四模型绑定，未因换色新增模板或纹理。
- visionOS 同样通过 35 种效果的双模型绑定与正反面回归，保存 [7 张预览图](../artifacts/base-color-vision-preview/)。
- 8 种代表效果各保存原始和两种底色，共 [24 张对比图](../artifacts/base-color-comparisons/)。检查的是模拟器渲染，未测量真机 GPU 帧耗时。

运行颜色对比（先编译并安装 Debug 应用）：

```sh
python3 Scripts/capture_shader_audit.py --device <模拟器 UUID> \
  --bundle com.reality.RealityOpticsShaderLab.ios --base-color \
  --output artifacts/base-color-comparisons
```

代表结果：[红色猫眼](../artifacts/base-color-comparisons/catEye-red.jpg)、[黑色珍珠](../artifacts/base-color-comparisons/pearl-black.jpg)、[蓝色 LCD](../artifacts/base-color-comparisons/lcd-blue.jpg)、[红色玻璃](../artifacts/base-color-comparisons/absorbingGlass-red.jpg)。
