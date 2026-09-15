import SwiftUI

struct ParameterPanelView: View {
    @Environment(AppModel.self) private var model
    @State private var showsPrinciple = true

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 6) {
                Label("参数调节", systemImage: "slider.horizontal.3")
                    .font(.headline)
                Text(L10n.format("%@ · %d 项参数", model.selectedEffect.menuTitle,
                                 model.settingsFor(model.selectedEffect).count))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding(18)
            Divider().padding(.horizontal, 18)

            ScrollViewReader { proxy in
                ScrollView(.vertical) {
                    VStack(alignment: .leading, spacing: 8) {
                        Color.clear.frame(height: 0).id("parameters.top")
                        principle
                        if model.selectedEffect.isImplemented {
                            ForEach(model.settingsFor(model.selectedEffect)) { spec in
                                ParameterSliderRow(spec: spec)
                            }
                        } else {
                            Label("此效果尚未接入，当前显示占位几何。", systemImage: "hammer.circle")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.horizontal, 14)
                    .padding(.bottom, 18)
                }
                .onChange(of: model.selectedEffect) { _, _ in
                    showsPrinciple = true
                    proxy.scrollTo("parameters.top", anchor: .top)
                }
            }
        }
        .frame(maxHeight: .infinity, alignment: .top)
        .modifier(LabPanel())
    }

    private var principle: some View {
        DisclosureGroup("效果说明", isExpanded: $showsPrinciple) {
            VStack(alignment: .leading, spacing: 10) {
                Text(model.selectedEffect.title)
                    .font(.subheadline.weight(.semibold))
                Text(model.selectedEffect.subtitle)
                Text(model.selectedEffect.mechanism)
                    .foregroundStyle(.secondary)
            }
            .font(.caption)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.top, 10)
        }
        .font(.subheadline.weight(.medium))
        .padding(14)
        .background(.white.opacity(0.045), in: RoundedRectangle(cornerRadius: 16))
        .accessibilityIdentifier("parameters.description")
    }
}

struct ParameterSliderRow: View {
    let spec: SettingSpec
    var compact = false

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(spec.label)
                    .font((compact ? Font.caption : Font.subheadline).weight(.medium))
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
                Text(valueLabel(spec.get()))
                    .font((compact ? Font.caption : Font.subheadline).monospacedDigit().weight(.semibold))
                    .foregroundStyle(.tint)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color.accentColor.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))
                    .fixedSize()
            }

            Slider(
                value: Binding(get: { spec.get() }, set: { spec.set($0) }),
                in: spec.range
            ) {
                Text(spec.label)
            }
            .controlSize(.regular)
            .frame(minHeight: compact ? 28 : 36)
            .accessibilityValue(valueLabel(spec.get()))
            .accessibilityIdentifier("parameter.\(spec.id)")

            if !compact { HStack {
                Text(valueLabel(spec.range.lowerBound))
                Spacer()
                Text(valueLabel(spec.range.upperBound))
            }
            .font(.caption2.monospacedDigit())
            .foregroundStyle(.secondary)
            .accessibilityHidden(true)
            }
        }
        .padding(compact ? 8 : 12)
        .background(
            spec.id == "intensity" ? Color.accentColor.opacity(0.09) : .white.opacity(0.045),
            in: RoundedRectangle(cornerRadius: 16)
        )
    }

    private func valueLabel(_ value: Float) -> String {
        value.formatted(.number.precision(.fractionLength(spec.id == "ior" ? 3 : 2)))
    }
}
