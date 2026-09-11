import SwiftUI

struct EffectLibraryView: View {
    @Environment(AppModel.self) private var model
    private let columns = [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Label("效果库", systemImage: "square.grid.2x2")
                    .font(.headline)
                Spacer()
                Text("\(OpticsEffect.allCases.count)")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            .padding(18)

            ScrollViewReader { proxy in
                ScrollView(.vertical) {
                    LazyVGrid(columns: columns, spacing: 8) {
                        ForEach(OpticsEffect.allCases) { effect in
                            effectCard(effect)
                                .id(effect.id)
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.bottom, 14)
                }
                .onAppear {
                    proxy.scrollTo(model.selectedEffect.id)
                }
            }
        }
        .frame(maxHeight: .infinity, alignment: .top)
        .modifier(LabPanel())
    }

    private func effectCard(_ effect: OpticsEffect) -> some View {
        let selected = effect == model.selectedEffect
        return Button {
            model.selectedEffect = effect
        } label: {
            VStack(spacing: 8) {
                Image(systemName: effect.iconName)
                    .font(.system(size: 23, weight: .medium))
                    .frame(height: 26)
                    .foregroundStyle(selected ? Color.accentColor : .primary.opacity(0.8))
                Text(effect.menuTitle)
                    .font(.system(size: 13, weight: selected ? .semibold : .medium))
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, minHeight: 74)
            .padding(.horizontal, 5)
            .background(
                selected ? Color.accentColor.opacity(0.2) : .white.opacity(0.045),
                in: RoundedRectangle(cornerRadius: 16)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(selected ? Color.accentColor.opacity(0.8) : .clear, lineWidth: 1.5)
            }
            .overlay(alignment: .topTrailing) {
                if selected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.tint)
                        .padding(7)
                }
            }
            .contentShape(RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(.plain)
        .hoverEffect(.highlight)
        .accessibilityLabel(effect.menuTitle)
        .accessibilityAddTraits(selected ? [.isSelected] : [])
        .accessibilityIdentifier("effect.\(effect.id)")
    }
}
