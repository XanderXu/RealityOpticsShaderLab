# 效果分组与新增光学演示

效果库共 28 项，按主要视觉特征与光学机制分为六组；一种效果只归入一组。跨机制的生物结构色归入最接近的外观组。分组标题固定在滚动区域顶部，支持中文名称、英文标识和组名搜索。

| 组 | 效果 |
|---|---|
| 薄膜与镀膜（7） | 薄膜干涉、油膜、阳极氧化钛、镜头镀膜、二向色玻璃、牛顿环、蜻蜓翅膀 |
| 结构色与晕彩（6） | 欧泊、拉长石、闪蝶翅膀、吉丁虫鞘翅、孔雀羽、变色龙皮肤 |
| 珠光与柔光（3） | 珍珠母、珍珠、月光石 |
| 定向反光（4） | 猫眼效应、星光宝石、日光石、逆反射材料 |
| 偏振与体色（5） | 双折射、液晶旋光、圆偏振金龟、多色性、变石效应 |
| 衍射与散斑（3） | 衍射光栅、彩虹全息、激光散斑 |

## 新增效果与操作

| 新增项 | 实现模型及边界 | 建议观察方法 |
|---|---|---|
| 猫眼效应 | 法线与半角矢量的偏差在纤维轴上投影，控制窄定向反射带；包裹体外观近似 | 球体，调光源方位、纤维方向和亮带锐度 |
| 星光宝石 | 共享猫眼模板，三组相差 60° 的亮带形成六射星光 | 球体，调整星芒方向和锐度 |
| 月光石 | 宽散射瓣、低频三维云纹和视线偏移表现蓝白内部柔光；无体积多重散射 | 球体旋转，调内部层次与柔光集中度 |
| 拉长石 | 晶域掩膜、定向闪光、等效膜光谱颜色；并非真实长石层片堆栈 | 调光源方位、等效层厚、晶域尺度 |
| 日光石 | 物体空间稀疏包裹体、随机片层朝向与半角矢量产生铜金闪点 | 旋转球体，调包裹体密度、稀疏度 |
| 变石效应 | 日光与暖光下的代表性 RGB 端点，Beer–Lambert RGB 透过率控制深浅；非实测吸收光谱 | 调“参考照明”从 0 到 1，观察绿到红紫的变化；旋转不是变色的主要来源 |
| 多色性 | 三个正交晶轴的 RGB 吸收系数按视线分量平方加权，指数衰减 | 旋转模型或晶轴方向/倾角，调光程；未模拟偏振分束与切面折射 |
| 二向色玻璃 | 六层 H/L 四分之一波膜的相干复振幅递推；无吸收时 T=1−R，单张未截断 RGB LUT 重建 R/T | 调中心波长和反射→透射显示通道；透射显示材质颜色，不折射真实背景 |
| 逆反射材料 | 视线与光源的窄夹角回归瓣乘入射余弦；不追踪微珠/角锥内部光路 | 从 0° 增大光源偏角，观察亮度迅速降低；实际对齐取决于当前视线 |
| 油膜 | 空气／n=1.47 油／n=1.333 水的三介质干涉 | 调平均厚度与厚度变化；三维纹理只模拟流纹 |
| 阳极氧化钛 | 空气／n=2.4 氧化层／n+ik=2.7+3.3i 金属；保留基底吸收 | 调氧化层厚度；固定光学常数为代表性近似，不预测电压或实物色卡 |
| 镜头镀膜 | 空气／n=1.38 MgF₂／n=1.52 玻璃，单层减反射膜 | 在约 100 nm 附近观察残余紫绿反射；增益默认 6 便于看清弱反射，不表示实际反射率提高 |

所有模型共享双几何体预览、原始/九种材质基础色、底色占比及效果强度。基础色保持原有线性混合行为，不额外推断真实有色基底的光谱。光源方位属于解析演示光源，并不读取模拟器房间中的灯光。

## 资源与数值实现

- 28 项效果使用 22 个运行时模板：原薄膜族共享 1 个，猫眼/星光共享 1 个，四种新增膜类共享 1 个；参数值按效果独立保存。
- 新增膜类首次选择时生成相应 RGBA16F LUT。二向色仅生成一张带符号、未截断的反射 RGB LUT，以白点减反射重建透射；之后再做显示色域截断。四种膜类均为单次纹理采样，切换通道不重新计算。
- 新增膜类的 U 为观察余弦，V 为局部厚度（油 0–1000 nm，钛/镜头 0–300 nm）；二向色 V 为设计中心波长 400–700 nm。超出查表域的局部变化夹取到边界。
- 使用 81 个可见光样本。无色散假设下，折射余弦、界面 s/p 振幅、层的光程在光谱循环外预计算。逐波长只进行相位推进和复振幅递推。
- 计算保持 float32；仅颜色积分权重与最终纹理用 half。复数平方根对纯实数采用专门分支，避免 fast-math 舍入虚构微小吸收。
- GPU 继续采用完整线程组向上取整及内核边界保护，兼容不支持非均匀线程组的模拟器。
- 独立 Double 复数 CPU 实现提供回退与对照。测试同时覆盖油膜与原三介质 Airy 公式的一致性、零膜厚裸基底、减反射极小值、六层布拉格解析值、掠射角和无源边界。

新增图和匹配的 Swift 参数表由 `python3 Scripts/generate_extended_materials.py` 生成。生成的 USDA 仍作为可检查的源文件提交；生成器不在应用启动时执行。现有 16 项图保留原有手工维护方式。

复查修复、单 LUT 优化及最新验收记录见 [复查说明](REVIEW_FIXES.md)。

## 验证命令

```sh
swift test --package-path Packages/OpticsPhysics
python3 Scripts/validate_materials.py
# 可增加 --stdlib /path/to/stdlib_defs.mtlx 校验官方节点签名
MTL_DEBUG_LAYER=1 python3 Scripts/verify_compute.py
# 编译并安装 Debug app 后：
SIMCTL_CHILD_MTL_DEBUG_LAYER=1 python3 Scripts/capture_shader_audit.py --output artifacts/expanded-effects-audit
SIMCTL_CHILD_MTL_DEBUG_LAYER=1 python3 Scripts/capture_shader_audit.py --performance --output artifacts/expanded-cache-audit
SIMCTL_CHILD_MTL_DEBUG_LAYER=1 python3 Scripts/capture_shader_audit.py --preview --output artifacts/expanded-preview-audit
```

最终 Debug 与 Release 构建通过。28 项效果完成默认/最小/最大参数的运行检查；其后对星光、猫眼、拉长石的视觉细化另行复验，截图见 [最终星光](../artifacts/expanded-visual-audit/starGem/starGem.jpg)、[最终猫眼](../artifacts/expanded-visual-audit/catEye/catEye.jpg)、[最终拉长石](../artifacts/expanded-visual-audit/labradorite/labradorite.jpg)。分组自动滚动在截图中确认。

初版扩展的资源回归证实启动 1 个模板/1 张 LUT、本次模拟器新进程首个效果 1.24 秒就绪；全部访问后 22 个模板/14 张缓存纹理（6.76 MiB 像素数据）。280 次缓存请求不重复构建，猫眼/星光、四种膜的参数隔离与二向色 R/T 切换复用通过。此为模拟器资源就绪计时，系统缓存未清空，不是实际首帧或真机 FPS。

28 项 × 两组模型 × 九种底色 × 三档占比的绑定回归通过，始终保持两个实体，底色与形状切换不创建新模板/LUT。记录见 [预览回归](../artifacts/expanded-preview-audit/runtime.log)。

复查后为 41 项 CPU 测试；24 份图/984 个节点/107 个参数默认值的静态验证；13 个完整 LUT 加 257×129 非整除纹理的逐 texel GPU 对照通过。模拟器运行与截图记录保存在上述目录；自动检查可证明加载、参数绑定和场景结构，视觉质量仍需看截图。真机帧率和复杂光谱材料的实物匹配未测量。

## 参考

宝石现象的区别依据 [GIA：Phenomenal Gems](https://www.gia.edu/gems-gemology-summary-guide-to-phenomenal-gems) 与 [GIA：Optical Effects of Phenomenal Cabochons](https://www.gia.edu/gia-news-research/optical-effects-phenomenal-cabochons)。复折射率与导体反射背景参见 [PBRT：Specular Reflection and Transmission](https://www.pbr-book.org/4ed/Reflection_Models/Specular_Reflection_and_Transmission)。节点签名对照 [MaterialX 官方 stdlib 定义](https://github.com/AcademySoftwareFoundation/MaterialX/blob/main/libraries/stdlib/stdlib_defs.mtlx)。材料常数和 RGB 端点是本项目演示假设，不能视为上述资料提供的实测配方。
