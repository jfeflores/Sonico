import SwiftUI

struct EqualizerView: View {
    @Bindable var model: HeadphoneModel
    @State private var editing = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(alignment: .leading, spacing: 28) {
            XMPageHeading(title: "Equalizer", detail: "Choose a preset or tune your custom bands.", symbol: "slider.vertical.3")
            if model.snapshot.eqAvailable {
                XMCard(title: nil) {
                    HStack {
                        Label("Preset", systemImage: "slider.vertical.3")
                            .font(.headline).accessibilityAddTraits(.isHeader)
                        Spacer()
                        if model.snapshot.presets.isEmpty {
                            Text(model.snapshot.presetName).font(.callout.weight(.semibold))
                        } else {
                            Picker("Equalizer preset", selection: Binding(
                                get: { model.snapshot.preset }, set: { model.send(.preset($0)) }
                            )) {
                                ForEach(model.snapshot.presets) { Text($0.name).tag($0.id) }
                            }.labelsHidden().fixedSize()
                        }
                    }
                    if !editing || !canEdit {
                        if model.snapshot.bands.isEmpty {
                            Text("No band values reported yet.")
                                .font(.callout).foregroundStyle(XMTheme.secondary).frame(maxWidth: .infinity, minHeight: 92)
                        } else {
                            EQResponse(bands: model.snapshot.bands, frequencies: model.snapshot.frequencies, range: model.snapshot.bandRange)
                                .frame(height: 110).padding(.vertical, 8)
                        }
                    } else if let range = model.snapshot.bandRange {
                        ScrollView(.horizontal) {
                            HStack(alignment: .top, spacing: 8) {
                                ForEach(model.eqDraft.indices, id: \.self) { index in band(index, range: range) }
                            }.frame(minWidth: CGFloat(model.eqDraft.count) * 36)
                        }
                        .defaultScrollAnchor(.center, for: .alignment)
                        .transition(.opacity)
                    }
                    HStack {
                        Text(model.snapshot.bands.isEmpty ? "Band count unavailable" : "\(model.snapshot.bands.count)-band equalizer")
                            .font(.callout).foregroundStyle(XMTheme.secondary)
                        Spacer()
                        if editing && canEdit {
                            Button("Reset to Flat") { model.resetEqualizer() }.buttonStyle(.bordered)
                        }
                        if canEdit {
                            Button(editing ? "Done" : "Edit Bands") { editing.toggle() }.buttonStyle(TonalButtonStyle())
                        }
                    }
                    if !model.snapshot.canEditEqualizer {
                        Text("Choose a Custom preset to edit the bands.").font(.caption).foregroundStyle(XMTheme.secondary)
                    } else if editing && canEdit {
                        Text("Values are device steps, not measured acoustic gain.")
                            .font(.caption).foregroundStyle(XMTheme.secondary)
                    }
                }
                if model.snapshot.clearBass != nil, let range = model.snapshot.clearBassRange {
                    XMCard(title: nil) {
                        XMLevelControl(title: "Clear Bass", symbol: "waveform", value: Binding(
                            get: { model.clearBassDraft }, set: { model.setClearBass($0) }
                        ), range: range)
                    }
                }
                if !model.snapshot.isDemo {
                    Text("The reported preset and values update when the headphones respond.")
                        .font(.caption).foregroundStyle(XMTheme.secondary)
                }
            } else {
                ContentUnavailableView("Equalizer unavailable", systemImage: "slider.vertical.3",
                                       description: Text("The connected device has not reported an available equalizer."))
            }
        }
        .padding(24)
        .animation(reduceMotion ? nil : XMMotion.reveal, value: editing)
        .onChange(of: model.snapshot.preset) { _, _ in editing = false }
    }

    private var canEdit: Bool { model.snapshot.canEditEqualizer && model.snapshot.bandRange != nil && !model.eqDraft.isEmpty }

    private func band(_ index: Int, range: DeviceRange) -> some View {
        let frequency = model.snapshot.frequencies.indices.contains(index) ? model.snapshot.frequencies[index] : 0
        let current = model.eqDraft[index]
        return VStack(spacing: 8) {
            Text(String(format: "%+d", current))
                .font(.caption.weight(.medium)).monospacedDigit().foregroundStyle(XMTheme.primary)
            Slider(value: Binding(get: { model.eqDraft.indices.contains(index) ? Double(model.eqDraft[index]) : Double(current) }, set: { model.setBand(index, $0) }),
                   in: range.sliderBounds, step: Double(range.step)) {
                Text(frequency > 0 ? "\(frequency) hertz" : "Band \(index + 1)")
            }
            .labelsHidden()
            .accessibilityLabel(frequency > 0 ? "\(frequency) hertz" : "Band \(index + 1)")
            .frame(width: 176, height: 24)
            .rotationEffect(.degrees(-90))
            .frame(width: 32, height: 176)
            .accessibilityValue("\(current) steps")
            Text(frequency > 0 ? frequencyLabel(frequency) : "\(index + 1)")
                .font(.caption).foregroundStyle(XMTheme.secondary)
        }.frame(maxWidth: .infinity)
    }
}

struct EQResponse: View {
    let bands: [Int32]
    let frequencies: [Int]
    let range: DeviceRange?
    var compact = false

    var body: some View {
        VStack(spacing: 8) {
            GeometryReader { geometry in
                let lo = Double(range?.lower ?? -6)
                let hi = Double(range?.upper ?? 6)
                let span = max(1, hi - lo)
                ZStack {
                    ForEach(gridLevels(lower: lo, upper: hi), id: \.self) { value in
                        Path { path in
                            let y = geometry.size.height * (1 - (value - lo) / span)
                            path.move(to: CGPoint(x: 0, y: y))
                            path.addLine(to: CGPoint(x: geometry.size.width, y: y))
                        }.stroke(XMTheme.secondary.opacity(value == 0 ? 0.6 : 0.2), lineWidth: 1)
                    }
                    ForEach(bands.indices, id: \.self) { index in
                        Capsule().fill(XMTheme.primary)
                            .frame(width: min(22, geometry.size.width / CGFloat(max(bands.count, 1)) * 0.6), height: 3)
                            .position(x: geometry.size.width * (CGFloat(index) + 0.5) / CGFloat(max(bands.count, 1)),
                                      y: geometry.size.height * (1 - (min(hi, max(lo, Double(bands[index]))) - lo) / span))
                    }
                }
            }
            if !compact {
                HStack(spacing: 0) {
                    ForEach(bands.indices, id: \.self) { index in
                        Text(frequencies.indices.contains(index) ? frequencyLabel(frequencies[index]) : "\(index + 1)")
                            .font(.caption2).foregroundStyle(XMTheme.secondary).frame(maxWidth: .infinity)
                    }
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Equalizer response")
        .accessibilityValue(bands.enumerated().map { index, value in
            let frequency = frequencies.indices.contains(index) ? frequencies[index] : 0
            let label = frequency > 0 ? "\(frequency) hertz" : "Band \(index + 1)"
            return "\(label): \(value) steps"
        }.joined(separator: ", "))
    }

    private func gridLevels(lower: Double, upper: Double) -> [Double] {
        if compact { return lower <= 0 && upper >= 0 ? [0] : [] }
        return lower < 0 && upper > 0 ? [lower, 0, upper] : [lower, upper]
    }
}
