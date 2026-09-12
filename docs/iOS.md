# iPhone / iPad 版本

在 Xcode 中打开 `RealityOpticsShaderLab.xcodeproj`，选择共享 Scheme **RealityOpticsShaderLab-iOS**，再选择 iPhone 或 iPad 运行。最低系统为 iOS / iPadOS 18.0。原 visionOS Scheme 为 **RealityOpticsShaderLab**。

真机运行：连接手机，在 iOS Target 的 Signing & Capabilities 中使用自己的开发团队，按 Run；设备需开启开发者模式。项目沿用已有团队配置，Bundle ID 为 `com.reality.RealityOpticsShaderLab.ios`。模拟器构建不需要签名；未签名的真机构建产物不能直接安装到手机。

## 界面与交互

- 上半屏固定 3D / AR 预览，同时显示球体、平面、尺子和光盘。竖屏 2×2 排列，宽预览区域横向排列四个模型。
- 下半屏默认显示效果库／参数入口及基础色控制。打开底部面板后，下半屏切换为效果库或参数；关闭按钮或下拉顶部拖动条可收起，上方预览始终保留。
- 选择效果不会自动跳到参数页。效果卡片和滑块采用紧凑样式。
- 3D：拖动改变视角，双指缩放，双击或顶部按钮复位。顶部播放／暂停控制所有模型自动旋转。
- AR：首次使用请求相机权限，跟踪稳定后在前方显示四模型。轻点画面重新放置，双指调节大小；可随时返回 3D。模拟器或不支持 ARKit 的设备保留 3D 并显示说明。
- 材质维持原有 Unlit 输出，无灯光选项或额外环境色乘法。AR 会话关闭不需要的光照估计和环境纹理生成。

## 实现与验证

两个 Target 共用 35 种效果、ShaderGraph、Compute 和 LUT 缓存；四个模型共享所选材质。iOS 的 ARView 协调器持有场景更新订阅，显式同步前后台状态，暂停／继续只改变旋转，不重建材质。AR 离开或应用进入后台时暂停相机会话，错误和权限拒绝有可返回 3D 的提示。

```bash
xcodebuild -project RealityOpticsShaderLab.xcodeproj -scheme RealityOpticsShaderLab-iOS -configuration Debug -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO build
xcodebuild -project RealityOpticsShaderLab.xcodeproj -scheme RealityOpticsShaderLab-iOS -configuration Release -destination 'generic/platform=iOS' CODE_SIGNING_ALLOWED=NO build
python3 Scripts/capture_shader_audit.py --mobile --device <iPhone模拟器UUID> --bundle com.reality.RealityOpticsShaderLab.ios --output artifacts/ios-mobile-controls-final
python3 Scripts/capture_shader_audit.py --preview --device <iPhone模拟器UUID> --bundle com.reality.RealityOpticsShaderLab.ios --output artifacts/ios-four-model-audit
```

移动端检查直接验证四个实体、旋转推进／暂停／恢复、效果选择保留当前面板、预览实体不重建、基础色和模拟器 AR 提示；另保存横竖屏画面。它不代替触摸手势手动验收、真机 AR 跟踪或性能测量。

记录：[手机布局与旋转](../artifacts/ios-mobile-controls-final/)、[四模型回归](../artifacts/ios-four-model-audit/)。

本次构建：iOS 模拟器 Debug、iPhone 真机架构 Release（未签名）与 visionOS Debug 通过；[构建与静态校验日志](../artifacts/ios-mobile-verification/)。AR 相机、平面放置和跟踪尚未经过真机现场验证。

四模型回归通过：35 种效果、5 种基础色、3 种混合占比，所有场景保持 4 个模型；切换颜色与旧分组属性未新增材质模板或纹理。移动端专项检查和四模型回归各保存 7 张截图。
