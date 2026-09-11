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
            Label("\(OpticsEffect.allCases.count) 种光学效果", systemImage: "square.grid.2x2")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 6)
    }

    private var preview: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 5) {
                    Text("实时预览")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(model.selectedEffect.menuTitle)
                        .font(.title2.bold())
                }
                Spacer()
                Image(systemName: model.selectedEffect.iconName)
                    .font(.title2)
                    .foregroundStyle(.tint)
                    .accessibilityHidden(true)
            }
            .padding(22)

            OpticsSceneView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .overlay {
                    if model.isLoadingSelected {
                        if model.statusMessage.contains("失败") {
                            Button("重新加载") { Task { await model.prepareSelectedEffect() } }
                        } else {
                            ProgressView("正在准备\(model.selectedEffect.menuTitle)…")
                        }
                    }
                }

            VStack(spacing: 14) {
                Text("调整右侧参数，观察色彩与纹理的变化")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                Button {
                    model.isAnimating.toggle()
                } label: {
                    Label(
                        model.isAnimating ? "暂停旋转" : "继续旋转",
                        systemImage: model.isAnimating ? "pause.fill" : "play.fill"
                    )
                    .font(.subheadline.weight(.semibold))
                    .frame(minWidth: 126, minHeight: 28)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
                .accessibilityIdentifier("preview.animation")

                HStack(alignment: .top, spacing: 7) {
                    Image(systemName: model.statusMessage == "Ready" ? "checkmark.circle.fill" : "info.circle")
                        .foregroundStyle(model.statusMessage == "Ready" ? .green : .secondary)
                    Text(model.statusMessage == "Ready" ? "渲染就绪" : model.statusMessage)
                        .textSelection(.enabled)
                }
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 22)
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
