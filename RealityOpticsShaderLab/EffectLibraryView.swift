import SwiftUI

struct EffectLibraryView: View {
    @Environment(AppModel.self) private var model
    @State private var searchText = ""
    private let columns = [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)]

    var body: some View {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        return VStack(alignment: .leading, spacing: 0) {
            HStack {
                Label("效果库", systemImage: "square.grid.2x2")
                    .font(.headline)
                Spacer()
                Text("\(OpticsEffect.allCases.count)")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            .padding(18)

            TextField("搜索效果", text: $searchText)
                .textFieldStyle(.roundedBorder)
                .padding(.horizontal, 12)
                .padding(.bottom, 12)
                .accessibilityIdentifier("effects.search")

            ScrollViewReader { proxy in
                ScrollView(.vertical) {
                    LazyVGrid(columns: columns, spacing: 8, pinnedViews: [.sectionHeaders]) {
                        ForEach(OpticsEffectGroup.allCases) { group in
                            let effects = group.effects.filter {
                                query.isEmpty || $0.title.localizedCaseInsensitiveContains(query)
                                    || $0.rawValue.localizedCaseInsensitiveContains(query)
                                    || group.title.localizedCaseInsensitiveContains(query)
                            }
                            if !effects.isEmpty {
                                Section {
                                    ForEach(effects) { effect in
                                        effectCard(effect).id(effect.id)
                                    }
                                } header: {
                                    HStack {
                                        Text(group.title)
                                        Spacer()
                                        Text("\(effects.count)").monospacedDigit()
                                    }
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.secondary)
                                    .padding(.vertical, 9)
                                    .padding(.horizontal, 8)
                                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10))
                                }
                            }
                        }
                        if !query.isEmpty && !OpticsEffect.allCases.contains(where: {
                            $0.title.localizedCaseInsensitiveContains(query)
                                || $0.rawValue.localizedCaseInsensitiveContains(query)
                                || $0.group.title.localizedCaseInsensitiveContains(query)
                        }) {
                            Text("没有匹配的效果").font(.subheadline).foregroundStyle(.secondary).padding()
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.bottom, 14)
                }
                .onChange(of: model.selectedEffect) { _, effect in
                    proxy.scrollTo(effect.id)
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
