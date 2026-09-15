import SwiftUI

struct ContentView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        VStack(spacing: 18) {
            header
            HStack(alignment: .top, spacing: 16) {
                EffectLibraryView()
                    .frame(width: 242)
                preview
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                ParameterPanelView()
                    .frame(width: 330)
            }
            .frame(maxHeight: .infinity)
        }
        .padding(20)
        .frame(minWidth: 1060, minHeight: 680)
        .task(id: model.selectedEffect) {
            await model.prepareSelectedEffect()
        }
        #if DEBUG
        .task {
            do {
                try await model.runShaderAuditIfRequested()
                try await model.runPerformanceAuditIfRequested()
                try await model.runPreviewAuditIfRequested()
            } catch {
                model.report(error: "Error: \(error.localizedDescription)")
                print("OPTICS_AUDIT FAIL: \(error.localizedDescription)")
                fflush(stdout)
            }
        }
        #endif
    }

    private var header: some View {
        HStack(spacing: 12) {
            Image(systemName: "waveform.path")
                .font(.title2)
                .foregroundStyle(.tint)
                .frame(width: 44, height: 44)
                .background(Color.accentColor.opacity(0.12), in: RoundedRectangle(cornerRadius: 14))
            VStack(alignment: .leading, spacing: 3) {
                Text("Reality Optics Shader Lab")
                    .font(.title3.bold())
                Text("波动光学 · 结构色实验室")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Label(L10n.format("%d 种光学效果", OpticsEffect.allCases.count), systemImage: "square.grid.2x2")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 6)
    }

    private var preview: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Label(model.selectedEffect.menuTitle, systemImage: model.selectedEffect.iconName)
                    .font(.headline)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
                Spacer(minLength: 4)
                Label(L10n.text(model.statusMessage == "Ready" ? "渲染就绪" : "准备中"), systemImage:
                        model.statusMessage == "Ready" ? "checkmark.circle.fill" : "info.circle")
                    .font(.caption)
                    .foregroundStyle(model.statusMessage == "Ready" ? .green : .secondary)
                    .fixedSize()
                Button {
                    model.isAnimating.toggle()
                } label: {
                    Label(L10n.text(model.isAnimating ? "暂停旋转" : "继续旋转"),
                          systemImage: model.isAnimating ? "pause.fill" : "play.fill")
                        .font(.subheadline.weight(.semibold))
                        .frame(minHeight: 28)
                }
                .buttonStyle(.bordered)
                .fixedSize()
                .accessibilityIdentifier("preview.animation")
            }
            .padding(18)

            OpticsSceneView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.bottom, 12)
                .overlay {
                    if model.isLoadingSelected {
                        if model.statusMessage.contains("失败") || model.statusMessage.contains("Failed") {
                            Button("重新加载") { Task { await model.prepareSelectedEffect() } }
                        } else {
                            ProgressView(L10n.format("正在准备%@…", model.selectedEffect.menuTitle))
                        }
                    }
                }

            Label(L10n.text("球体 / 平面 · 尺子 / 光盘"), systemImage: "square.grid.2x2")
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
                .padding(.bottom, 10)

            VStack(spacing: 12) {
                PreviewControlsView()

                if model.statusMessage != "Ready" {
                    Text(model.statusMessage)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 16)
        }
        .background {
            RoundedRectangle(cornerRadius: 24)
                .fill(.black.opacity(0.12))
                .overlay {
                    RoundedRectangle(cornerRadius: 24)
                        .strokeBorder(.white.opacity(0.1), lineWidth: 1)
                }
        }
    }
}

/// A quiet surface within the system's glass window; avoid stacking glass effects.
struct LabPanel: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(.white.opacity(0.055), in: RoundedRectangle(cornerRadius: 24))
            .overlay {
                RoundedRectangle(cornerRadius: 24)
                    .strokeBorder(.white.opacity(0.1), lineWidth: 1)
                    .allowsHitTesting(false)
            }
    }
}
