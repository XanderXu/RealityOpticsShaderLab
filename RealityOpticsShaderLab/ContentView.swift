import SwiftUI

struct ContentView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        VStack(spacing: 10) {
            effectPicker
            OpticsSceneView()
                .frame(height: 430)
            statusBar
            ScrollView {
                effectDetails
                    .padding(.horizontal, 24)
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

    private var effectPicker: some View {
        Picker("Shader", selection: Bindable(model).selectedEffect) {
            ForEach(OpticsEffect.allCases) { effect in
                Text(effect.menuTitle + (effect.isImplemented ? "" : " ·soon"))
                    .tag(effect)
            }
        }
        .pickerStyle(.menu)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 24)
    }

    private var statusBar: some View {
        HStack {
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

            Image(systemName: "sparkles")
            Text(model.statusMessage)
                .font(.footnote.monospaced())
                .lineLimit(1)
                .truncationMode(.middle)
            Spacer()
        }
        .padding(.horizontal, 24)
    }

    @ViewBuilder
    private var effectDetails: some View {
        let effect = model.selectedEffect
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                Text(effect.title)
                    .font(.headline)
                if !effect.isImplemented {
                    Text("Coming soon")
                        .font(.caption2.bold())
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Capsule().fill(.quaternary))
                }
            }

            Text(effect.subtitle)
                .font(.subheadline)
            Text("实现要点：" + effect.mechanism)
                .font(.caption)
                .foregroundStyle(.secondary)

            if effect.isImplemented {
                let specs = model.settingsFor(effect)
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(specs) { spec in
                        sliderRow(spec)
                    }
                }
                .padding(.top, 4)
            } else {
                Label("此效果的物理内核与材质图尚未接入，场景中为占位几何；选择器与说明先行，便于规划。",
                      systemImage: "hammer.circle")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.top, 4)
            }
        }
    }

    private func sliderRow(_ spec: SettingSpec) -> some View {
        HStack {
            Text(spec.label)
                .font(.caption)
                .frame(width: 190, alignment: .leading)
            Slider(
                value: Binding(get: { spec.get() }, set: { spec.set($0) }),
                in: spec.range
            )
            .frame(maxWidth: .infinity)
            Text(spec.get().formatted(.number.precision(.fractionLength(2))))
                .font(.caption.monospacedDigit())
                .frame(width: 52, alignment: .trailing)
        }
        .id(spec.id)
    }
}
