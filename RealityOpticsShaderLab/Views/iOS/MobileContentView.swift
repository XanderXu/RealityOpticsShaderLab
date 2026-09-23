#if os(iOS)
import SwiftUI
import RealityKit
import simd

struct MobileContentView: View {
    @Environment(AppModel.self) private var model
    @State private var preview = MobilePreviewState()
    @State private var panel = 0
    @State private var showsPanel = false
    @State private var search = ""

    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 4) {
                toolbar
                    .padding(.horizontal, 4)
                scene.frame(height: max(150, (geometry.size.height - 55) * 0.49))
                ZStack(alignment: .bottom) {
                    controls.opacity(showsPanel ? 0 : 1).allowsHitTesting(!showsPanel)
                        .accessibilityHidden(showsPanel)
                    if showsPanel {
                        drawer.transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .clipped()
            }
            .padding(.horizontal, 4)
            .padding(.top, 2)
        }
        .background(Color(uiColor: .systemGroupedBackground))
        .environment(preview)
        .task(id: model.selectedEffect) { await model.prepareSelectedEffect() }
        #if DEBUG
        .task {
            do {
                try await model.runShaderAuditIfRequested()
                try await model.runPerformanceAuditIfRequested()
                try await model.runPreviewAuditIfRequested()
                try await runMobileAudit()
            } catch {
                model.report(error: "Error: \(error.localizedDescription)")
                print("OPTICS_AUDIT FAIL: \(error.localizedDescription)")
                fflush(stdout)
            }
        }
        #endif
    }

    private var toolbar: some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text(model.selectedEffect.menuTitle).font(.subheadline.bold()).lineLimit(1)
                Label(L10n.text(model.statusMessage == "Ready" ? "渲染就绪" : "准备中"), systemImage: "circle.fill")
                    .font(.system(size: 10)).foregroundStyle(model.statusMessage == "Ready" ? .green : .secondary)
            }
            Spacer(minLength: 0)
            Picker("预览模式", selection: Binding(get: { preview.isAR }, set: { ar in
                if ar { Task { await preview.useAR() } } else { preview.useVirtual() }
            })) {
                Text("3D").tag(false)
                Text("AR").tag(true)
            }.pickerStyle(.segmented).frame(width: 108)
                .accessibilityIdentifier("mobile.mode")
            Button { model.isAnimating.toggle() } label: {
                Image(systemName: model.isAnimating ? "pause.fill" : "play.fill")
                    .frame(width: 32, height: 34)
            }.accessibilityLabel(L10n.text(model.isAnimating ? "暂停旋转" : "开始旋转"))
                .accessibilityIdentifier("preview.animation")
            Button { preview.resetRevision += 1 } label: {
                Image(systemName: "arrow.counterclockwise").frame(width: 30, height: 34)
            }.accessibilityLabel("复位视角或 AR 位置")
        }
        .buttonStyle(.plain).font(.subheadline)
    }

    private var scene: some View {
        OpticsSceneView()
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(alignment: .topLeading) {
                if !preview.message.isEmpty {
                    Text(preview.message).font(.caption2).lineLimit(3)
                        .padding(8).background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10))
                        .padding(8).allowsHitTesting(false)
                }
            }
            .overlay(alignment: .bottom) {
                Text(L10n.text(preview.isAR ? "移动手机观察 · 轻点放置 · 双指缩放" : "球体 / 平面 · 尺子 / 光盘　拖动观察 · 双击复位"))
                    .font(.system(size: 10)).foregroundStyle(.secondary)
                    .padding(.horizontal, 8).padding(.vertical, 5)
                    .background(.regularMaterial, in: Capsule()).padding(6)
                    .allowsHitTesting(false)
            }
            .overlay {
                if model.isLoadingSelected {
                    if model.statusMessage.contains("失败") || model.statusMessage.contains("Failed") || model.statusMessage.contains("Error") {
                        Button("重新加载") { Task { await model.prepareSelectedEffect() } }
                    } else { ProgressView("准备材质…").font(.caption) }
                }
            }
    }

    private var controls: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 8) {
                    panelButton(L10n.format("效果库 · %d", OpticsEffect.allCases.count), icon: "square.grid.2x2", index: 0)
                    panelButton(L10n.text("参数调节"), icon: "slider.horizontal.3", index: 1)
                }
                VStack(alignment: .leading, spacing: 6) {
                    Text("材质基础色").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                    HStack(spacing: 4) {
                        baseButton(nil)
                        ForEach(PreviewColor.allCases) { baseButton($0) }
                    }
                    if model.previewBaseColor != nil {
                        HStack(spacing: 8) {
                            Text("替换").font(.caption)
                            Slider(value: Binding(get: { model.previewBaseAmount }, set: { model.setPreviewBaseAmount($0) }), in: 0...1)
                                .accessibilityLabel("底色替换").accessibilityIdentifier("preview.baseAmount")
                            Text(model.previewBaseAmount.formatted(.percent.precision(.fractionLength(0))))
                                .font(.caption.monospacedDigit()).frame(width: 34)
                        }.frame(minHeight: 32)
                    }
                }
                if preview.requestingAR { ProgressView("正在请求相机权限…").font(.caption) }
                if model.statusMessage != "Ready" {
                    Text(model.statusMessage).font(.caption2).foregroundStyle(.secondary)
                }
                VStack(alignment: .leading, spacing: 8) {
                    Label("效果说明", systemImage: "info.circle")
                        .font(.caption.weight(.semibold))
                    Text(model.selectedEffect.mechanism)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .lineSpacing(3)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(12)
                .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))
                .accessibilityIdentifier("mobile.description")
            }.padding(12)
        }
    }

    private func panelButton(_ title: String, icon: String, index: Int) -> some View {
        Button { panel = index; withAnimation(.easeOut(duration: 0.2)) { showsPanel = true } } label: {
            Label(title, systemImage: icon).font(.caption.weight(.semibold))
                .frame(maxWidth: .infinity, minHeight: 36)
                .background(Color.accentColor.opacity(0.09), in: RoundedRectangle(cornerRadius: 10))
        }.buttonStyle(.plain).accessibilityIdentifier("mobile.open.\(index)")
    }

    private func baseButton(_ color: PreviewColor?) -> some View {
        Button { model.previewBaseColor = color } label: {
            swatch(color?.color ?? Color(uiColor: .tertiaryLabel), title: color?.title ?? L10n.text("原始"),
                   selected: model.previewBaseColor == color)
        }.buttonStyle(.plain).accessibilityIdentifier("preview.color.\(color?.rawValue ?? "original")")
    }

    private func swatch(_ color: Color, title: String, selected: Bool) -> some View {
        VStack(spacing: 3) {
            Circle().fill(color).frame(width: 18, height: 18)
                .overlay(Circle().strokeBorder(.gray.opacity(0.3), lineWidth: 0.5))
            Text(title).font(.system(size: 10))
        }
        .frame(maxWidth: .infinity, minHeight: 42)
        .background(selected ? Color.accentColor.opacity(0.12) : .clear, in: RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(selected ? Color.accentColor : .clear, lineWidth: 1))
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private var drawer: some View {
        VStack(spacing: 8) {
            Capsule().fill(.secondary.opacity(0.25)).frame(width: 30, height: 4).padding(.top, 8)
                .frame(maxWidth: .infinity).contentShape(Rectangle())
                .gesture(DragGesture().onEnded { if $0.translation.height > 35 { closePanel() } })
            HStack(spacing: 12) {
                Picker("查看内容", selection: $panel) {
                    Text("效果库").tag(0)
                    Text("参数").tag(1)
                }.pickerStyle(.segmented).accessibilityIdentifier("mobile.panel")
                Button(action: closePanel) {
                    Image(systemName: "xmark").font(.caption.bold()).frame(width: 30, height: 30)
                }.buttonStyle(.plain).accessibilityLabel("收起面板")
                    .accessibilityIdentifier("mobile.close")
            }.padding(.horizontal, 12)
            if panel == 0 { effectList } else { parameterList }
        }
        .background(Color(uiColor: .secondarySystemGroupedBackground), in: UnevenRoundedRectangle(topLeadingRadius: 18, topTrailingRadius: 18))
        .accessibilityIdentifier("mobile.drawer")
    }

    private func closePanel() { withAnimation(.easeOut(duration: 0.2)) { showsPanel = false } }

    private var effectList: some View {
        VStack(spacing: 6) {
            TextField("搜索效果或分类", text: $search).font(.caption).textFieldStyle(.roundedBorder)
                .padding(.horizontal, 12).accessibilityIdentifier("effects.search")
            ScrollView {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 100), spacing: 6)], spacing: 6, pinnedViews: [.sectionHeaders]) {
                    ForEach(OpticsEffectGroup.allCases) { group in
                        let effects = group.effects.filter { search.isEmpty || $0.title.localizedCaseInsensitiveContains(search) || group.title.localizedCaseInsensitiveContains(search) }
                        if !effects.isEmpty {
                            Section {
                                ForEach(effects) { effect in
                                    Button { model.selectedEffect = effect } label: {
                                        Label(effect.menuTitle, systemImage: effect.iconName)
                                            .font(.system(size: 11, weight: .medium)).lineLimit(2)
                                            .frame(maxWidth: .infinity, minHeight: 38)
                                            .padding(.horizontal, 3)
                                            .background(model.selectedEffect == effect ? Color.accentColor.opacity(0.15) : Color(uiColor: .tertiarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 9))
                                    }.buttonStyle(.plain).accessibilityIdentifier("effect.\(effect.id)")
                                        .accessibilityAddTraits(model.selectedEffect == effect ? .isSelected : [])
                                }
                            } header: {
                                HStack { Text(group.title); Spacer(); Text("\(effects.count)") }
                                    .font(.system(size: 10, weight: .semibold)).foregroundStyle(.secondary)
                                    .padding(.vertical, 6)
                                    .background(Color(uiColor: .secondarySystemGroupedBackground))
                            }
                        }
                    }
                }.padding(.horizontal, 12).padding(.bottom, 12)
            }.scrollDismissesKeyboard(.interactively)
        }
    }

    private var parameterList: some View {
        ScrollView {
            VStack(spacing: 6) {
                HStack {
                    Text(model.selectedEffect.menuTitle)
                    Spacer()
                    Text(L10n.format("%d 项", model.settingsFor(model.selectedEffect).count))
                }.font(.caption).foregroundStyle(.secondary)
                ForEach(model.settingsFor(model.selectedEffect)) { spec in
                    ParameterSliderRow(spec: spec, compact: true)
                }
            }.padding(.horizontal, 12).padding(.bottom, 12)
        }.id(model.selectedEffect)
    }
    #if DEBUG
    private func runMobileAudit() async throws {
        guard ProcessInfo.processInfo.environment["OPTICS_MOBILE_AUDIT"] == "1" else { return }
        func check(_ value: Bool, _ message: String) throws {
            if !value { throw NSError(domain: "OpticsMobile", code: 1, userInfo: [NSLocalizedDescriptionKey: message]) }
        }
        func capture(_ name: String) async throws {
            try await Task.sleep(for: .seconds(1))
            print("OPTICS_MOBILE_AUDIT CAPTURE \(name)")
            fflush(stdout)
            try await Task.sleep(for: .seconds(2))
        }
        await model.prepareSelectedEffect()
        for _ in 0..<100 where model.sceneRoot?.children.count != 4 { try await Task.sleep(for: .milliseconds(50)) }
        guard let root = model.sceneRoot else { throw NSError(domain: "OpticsMobile", code: 2) }
        try check(root.children.count == 4, "Expected four geometry samples")
        try await Task.sleep(for: .seconds(1))
        model.isAnimating = true
        let sample = root.children.first!
        let before = sample.orientation.vector
        try await Task.sleep(for: .seconds(1))
        try check(simd_length(before - sample.orientation.vector) > 0.02, "Auto rotation did not advance")
        model.isAnimating = false
        try await Task.sleep(for: .milliseconds(100))
        let paused = sample.orientation.vector
        try await Task.sleep(for: .milliseconds(500))
        try check(simd_length(paused - sample.orientation.vector) < 0.00001, "Pause did not stop rotation")
        model.isAnimating = true
        try await Task.sleep(for: .milliseconds(500))
        try check(simd_length(paused - sample.orientation.vector) > 0.02, "Resume did not restart rotation")
        model.isAnimating = false
        print("OPTICS_MOBILE_AUDIT rotation: advances / pauses / resumes")
        guard let auditScene = model.auditMobileScene else { throw NSError(domain: "OpticsMobile", code: 3) }
        try await auditScene()
        try await capture("controls")
        panel = 0; showsPanel = true
        try await capture("library")
        let sampleIdentities = root.children.map { ObjectIdentifier($0) }
        model.selectedEffect = .lenticular
        await model.prepareSelectedEffect()
        try check(panel == 0 && showsPanel, "Effect selection changed the active panel")
        try check(model.sceneRoot === root && root.children.count == 4, "Drawer rebuilt the scene")
        try check(root.children.map { ObjectIdentifier($0) } == sampleIdentities,
                  "Cold material selection recreated sample entities")
        try check(root.children.allSatisfy {
            $0.isEnabled && ($0.components[ModelComponent.self]?.materials.first as? ShaderGraphMaterial)?
                .getParameter(name: "Views") != nil
        }, "Ready was reported before the selected material reached all samples")
        try await capture("library-selection")
        panel = 1
        try await capture("parameters")
        showsPanel = false
        model.previewBaseColor = .red
        try await capture("base-color")
        model.previewBaseColor = nil
        #if targetEnvironment(simulator)
        await preview.useAR()
        try check(!preview.isAR && !preview.message.isEmpty, "Unsupported AR has no fallback")
        #endif
        try await capture("ar-availability")
        preview.useVirtual()
        if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
            scene.requestGeometryUpdate(.iOS(interfaceOrientations: .landscapeRight))
        }
        showsPanel = true; panel = 0
        try await capture("landscape")
        if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
            scene.requestGeometryUpdate(.iOS(interfaceOrientations: .portrait))
        }
        showsPanel = false; model.isAnimating = true
        print("OPTICS_MOBILE_AUDIT PASS: rotation, four samples, persistent drawer selection, base color, AR fallback")
        fflush(stdout)
    }
    #endif
}
#endif
