import SwiftUI

struct ContentView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        VStack(spacing: 12) {
            OpticsSceneView()
                .frame(height: 480)

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

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    sliderSection("Soap Bubble · Thin-Film Interference", bindings: filmBindings)
                    sliderSection("CD · Diffraction Grating", bindings: gratingBindings)
                }
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

    private var filmBindings: [SliderItem] {
        [
            SliderItem(label: "Thickness scale", value: Bindable(model).thicknessScale, range: 0...1.5),
            SliderItem(label: "Thickness bias", value: Bindable(model).thicknessBias, range: 0...0.8),
            SliderItem(label: "Noise amount", value: Bindable(model).noiseAmount, range: 0...0.4),
            SliderItem(label: "Gain", value: Bindable(model).filmGain, range: 0.5...4),
            SliderItem(label: "Opacity", value: Bindable(model).filmOpacity, range: 0.3...1),
            SliderItem(label: "Film IOR (rebuilds LUT)", value: Bindable(model).soapIOR, range: 1.2...1.45),
        ]
    }

    private var gratingBindings: [SliderItem] {
        [
            SliderItem(label: "Density scale", value: Bindable(model).densityScale, range: 0.1...1),
            SliderItem(label: "Density bias", value: Bindable(model).densityBias, range: 0...0.6),
            SliderItem(label: "Gain", value: Bindable(model).gratingGain, range: 0.5...3),
            SliderItem(label: "Light azimuth", value: Bindable(model).lightAzimuthDeg, range: 0...360),
        ]
    }

    @ViewBuilder
    private func sliderSection(_ title: String, bindings: [SliderItem]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.headline)
            ForEach(bindings) { item in
                HStack {
                    Text(item.label)
                        .font(.caption)
                        .frame(width: 190, alignment: .leading)
                    Slider(value: item.value, in: item.range)
                        .frame(maxWidth: .infinity)
                    Text(item.value.wrappedValue.formatted(.number.precision(.fractionLength(2))))
                        .font(.caption.monospacedDigit())
                        .frame(width: 52, alignment: .trailing)
                }
            }
        }
    }
}

private struct SliderItem: Identifiable {
    let label: String
    let value: Binding<Float>
    let range: ClosedRange<Float>
    var id: String { label }
}
