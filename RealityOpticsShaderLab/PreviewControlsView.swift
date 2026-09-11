import SwiftUI

struct PreviewControlsView: View {
    @Environment(AppModel.self) private var model
    @State private var showsPalette = false

    var body: some View {
        VStack(spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text(model.previewGroup.title).font(.subheadline.weight(.semibold))
                    Text("同一材质 · 双模型对比").font(.caption2).foregroundStyle(.secondary)
                }
                Spacer(minLength: 8)
                Toggle("第二组", isOn: Binding(
                    get: { model.previewGroup == .instruments },
                    set: { model.previewGroup = $0 ? .instruments : .basic }
                ))
                .font(.subheadline)
                .fixedSize()
                .accessibilityIdentifier("preview.secondGroup")
            }

            HStack {
                Label("材质基础色", systemImage: "paintpalette")
                    .font(.subheadline)
                Spacer(minLength: 8)
                Button { showsPalette = true } label: {
                    HStack(spacing: 8) {
                        swatch(model.previewBaseColor)
                            .frame(width: 22, height: 22)
                        Text(model.previewBaseColor?.title ?? "原始效果")
                            .font(.subheadline.weight(.medium))
                        Image(systemName: "chevron.down").font(.caption2.bold())
                    }
                    .frame(minHeight: 28)
                }
                .buttonStyle(.bordered)
                .accessibilityIdentifier("preview.baseColor")
                // Keep the palette below the samples: 3D geometry projects in
                // front of the window plane and could obscure an upward popover.
                .popover(isPresented: $showsPalette, attachmentAnchor: .rect(.bounds), arrowEdge: .top) { palette }
            }

            if model.previewBaseColor != nil {
                HStack(spacing: 10) {
                    Text("底色占比").font(.caption)
                    Slider(value: Binding(get: { model.previewBaseAmount }, set: { model.setPreviewBaseAmount($0) }), in: 0...1) {
                        Text("底色占比")
                    }
                    .frame(minHeight: 44)
                    .accessibilityIdentifier("preview.baseAmount")
                    Text(model.previewBaseAmount.formatted(.percent.precision(.fractionLength(0))))
                        .font(.caption.monospacedDigit())
                        .frame(width: 38, alignment: .trailing)
                }
            }
        }
        .padding(16)
        .background(.white.opacity(0.045), in: RoundedRectangle(cornerRadius: 18))
    }

    private var palette: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("材质基础色").font(.headline)
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 5), spacing: 10) {
                colorButton(nil)
                ForEach(PreviewColor.allCases) { color in colorButton(color) }
            }
            Text("选择底色后，可调节混合占比；100% 用于检查纯底色。")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(22)
        .frame(width: 400)
    }

    private func colorButton(_ color: PreviewColor?) -> some View {
        Button {
            model.previewBaseColor = color
            showsPalette = false
        } label: {
            VStack(spacing: 7) {
                swatch(color)
                    .frame(width: 36, height: 36)
                    .overlay {
                        if model.previewBaseColor == color {
                            Image(systemName: "checkmark")
                                .font(.caption.bold())
                                .foregroundStyle(color?.contrastingColor ?? .white)
                        }
                    }
                Text(color?.title ?? "原始")
                    .font(.caption2)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, minHeight: 64)
            .padding(.vertical, 4)
            .background(model.previewBaseColor == color ? Color.accentColor.opacity(0.18) : .clear,
                        in: RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(color?.title ?? "原始效果")
        .accessibilityAddTraits(model.previewBaseColor == color ? .isSelected : [])
        .accessibilityIdentifier("preview.color.\(color?.rawValue ?? "original")")
    }

    private func swatch(_ color: PreviewColor?) -> some View {
        Circle()
            .fill(color?.color ?? Color(white: 0.25))
            .overlay {
                if color == nil {
                    Image(systemName: "sparkles").font(.caption).foregroundStyle(.white)
                }
            }
            .overlay(Circle().strokeBorder(.white.opacity(0.4), lineWidth: 1))
            .accessibilityHidden(true)
    }
}
