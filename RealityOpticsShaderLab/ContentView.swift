import SwiftUI

struct ContentView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        VStack(spacing: 0) {
            header
            effectCards
            OpticsSceneView()
                .frame(height: 380)
            statusBar
            Divider().padding(.horizontal, 24)
            ScrollView {
                effectDetails
                    .padding(.horizontal, 24)
                    .padding(.top, 14)
                    .padding(.bottom, 24)
            }
        }
        .task {
            do {
                try await model.buildAll()
            } catch {
                model.report(error: "Error: \(error.localizedDescription)")
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            Text("Reality Optics Shader Lab")
                .font(.title3.bold())
            Text("波动光学效果库")
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
        }
        .padding(.horizontal, 24)
        .padding(.top, 18)
        .padding(.bottom, 10)
    }

    // MARK: - Effect cards

    private var effectCards: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(OpticsEffect.allCases) { effect in
                    effectCard(effect)
                }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 8)
        }
    }

    private func effectCard(_ effect: OpticsEffect) -> some View {
        let selected = effect == model.selectedEffect
        return Button {
            model.selectedEffect = effect
        } label: {
            VStack(spacing: 6) {
                Image(systemName: effect.iconName)
                    .font(.system(size: 24))
                    .foregroundStyle(selected ? AnyShapeStyle(.tint) : AnyShapeStyle(.secondary))
                    .frame(height: 28)
                Text(effect.menuTitle)
                    .font(.caption2)
                    .fontWeight(selected ? .semibold : .regular)
                    .foregroundStyle(selected ? .primary : .secondary)
                readinessDot(effect)
            }
            .frame(width: 86, height: 88)
            .background {
                RoundedRectangle(cornerRadius: 14)
                    .fill(selected ? AnyShapeStyle(.selection) : AnyShapeStyle(.quaternary))
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(effect.menuTitle)
    }

    /// Green = runnable shader, orange = planned-only.
    private func readinessDot(_ effect: OpticsEffect) -> some View {
        Circle()
            .fill(effect.isImplemented ? AnyShapeStyle(.green) : AnyShapeStyle(.orange))
            .frame(width: 5, height: 5)
    }

    // MARK: - Status bar

    private var statusBar: some View {
        HStack(spacing: 10) {
            Button {
                model.isAnimating.toggle()
            } label: {
                Label(
                    model.isAnimating ? "Pause" : "Play",
                    systemImage: model.isAnimating ? "pause.circle.fill" : "play.circle.fill"
                )
                .labelStyle(.titleAndIcon)
            }
            .buttonStyle(.bordered)

            if model.statusMessage == "Ready" {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            } else {
                Image(systemName: "hourglass.circle")
                    .foregroundStyle(.secondary)
            }
            Text(model.statusMessage)
                .font(.caption.monospaced())
                .lineLimit(1)
                .truncationMode(.middle)
            Spacer()
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 10)
    }

    // MARK: - Effect details + settings

    @ViewBuilder
    private var effectDetails: some View {
        let effect = model.selectedEffect
        VStack(alignment: .leading, spacing: 14) {
            infoCard(effect)
            if effect.isImplemented {
                settingsCard(effect)
            } else {
                plannedNote
            }
        }
    }

    private func infoCard(_ effect: OpticsEffect) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(effect.title)
                .font(.headline)
            Text(effect.subtitle)
                .font(.subheadline)
            Text("实现要点：" + effect.mechanism)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 14).fill(.quaternary.opacity(0.5)))
    }

    private func settingsCard(_ effect: OpticsEffect) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Parameters", systemImage: "slider.horizontal.3")
                .font(.subheadline.bold())
            ForEach(model.settingsFor(effect)) { spec in
                sliderRow(spec)
            }
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 14).fill(.quaternary.opacity(0.5)))
    }

    private var plannedNote: some View {
        Label("此效果的物理内核与材质图尚未接入，场景中为占位几何。", systemImage: "hammer.circle")
            .font(.caption)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .background(RoundedRectangle(cornerRadius: 14).fill(.quaternary.opacity(0.5)))
    }

    private func sliderRow(_ spec: SettingSpec) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text(spec.label)
                    .font(.caption)
                Spacer()
                Text(spec.get().formatted(.number.precision(.fractionLength(2))))
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            Slider(
                value: Binding(get: { spec.get() }, set: { spec.set($0) }),
                in: spec.range
            )
        }
        .id(spec.id)
    }
}
