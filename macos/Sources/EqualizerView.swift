import SwiftUI

struct EqualizerView: View {
    @Bindable var model: HeadphoneModel
    @State private var draft: EqualizerEdit?
    @State private var draftInvalidated = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.sonico) private var colors

    var body: some View {
        VStack(alignment: .leading, spacing: XMTheme.section) {
            XMPageHeading(title: "Equalizer", detail: model.snapshot.isDemo ? "Explore factory presets for this model." : "See the preset stored on your headphones.", symbol: "slider.vertical.3")
            if model.snapshot.isDemo {
                factoryPreview
            } else if model.snapshot.eqAvailable {
                XMCard(title: nil) {
                    presetRow
                    if let draft {
                        editControls(draft)
                    } else {
                        readout
                    }
                }
            } else {
                ContentUnavailableView("Equalizer unavailable", systemImage: "slider.vertical.3",
                                       description: Text("The connected device has not reported an available equalizer."))
            }
        }
        .padding(XMTheme.margin)
        .animation(reduceMotion ? nil : XMMotion.reveal, value: draft != nil)
        .onChange(of: model.snapshot.equalizerValues) { _, current in
            if let draft, draft.original != current { self.draft = nil; draftInvalidated = true }
        }
    }

    private var factoryPreview: some View {
        XMCard(title: "Factory presets", symbol: "waveform") {
            ForEach(model.snapshot.presets) { preset in
                let selected = preset.id == model.snapshot.preset
                Button { model.send(.preset(preset.id)) } label: {
                    HStack {
                        Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(selected ? colors.primary : colors.secondary)
                        Text(preset.name).font(.callout.weight(selected ? .semibold : .regular))
                        Spacer()
                    }
                    .frame(minHeight: 24)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.borderless)
                .accessibilityAddTraits(selected ? .isSelected : [])
            }
            Text("Names only. Connect your headphones to read their EQ and custom slots.")
                .font(.caption).foregroundStyle(colors.secondary)
        }
    }

    private var presetRow: some View {
        HStack {
            Label("Active preset", systemImage: "slider.vertical.3")
                .font(.headline).accessibilityAddTraits(.isHeader)
            Spacer()
            if model.snapshot.presets.isEmpty || !model.snapshot.activePresetReported {
                Text(model.snapshot.presetName).font(.callout.weight(.semibold))
            } else {
                Picker("Equalizer preset", selection: Binding(
                    get: { model.snapshot.preset }, set: { model.send(.preset($0)) }
                )) {
                    ForEach(model.snapshot.presets) { Text($0.name).tag($0.id) }
                    if !model.snapshot.presets.contains(where: { $0.id == model.snapshot.preset }) {
                        Text(model.snapshot.presetName).tag(model.snapshot.preset).disabled(true)
                    }
                }
                .labelsHidden().disabled(draft != nil || model.snapshot.applying)
            }
        }
    }

    @ViewBuilder private var readout: some View {
        if model.snapshot.bands.isEmpty {
            Text("No band values reported.").font(.callout).foregroundStyle(colors.secondary)
                .frame(maxWidth: .infinity, minHeight: 74)
        } else {
            EQResponse(bands: model.snapshot.bands, frequencies: model.snapshot.frequencies, range: model.snapshot.bandRange)
                .frame(height: 110).padding(.vertical, 8)
        }
        HStack {
            if let bass = model.snapshot.clearBass { Text("Clear Bass: \(bass)") }
            else if !model.snapshot.bands.isEmpty { Text("\(model.snapshot.bands.count) bands") }
            Spacer()
            if model.snapshot.canEditEqualizer, let values = model.snapshot.equalizerValues {
                Button("Edit Slot") { draftInvalidated = false; draft = EqualizerEdit(values) }
                    .buttonStyle(TonalButtonStyle()).disabled(model.snapshot.applying)
            }
        }.font(.callout).foregroundStyle(colors.secondary)
        if draftInvalidated {
            Text("The headphones reported a change. Reopen the editor to use their latest values.")
                .font(.caption).foregroundStyle(colors.secondary)
        } else if model.snapshot.reportedModel?.usesLegacyProtocol == true {
            Text("This model reports the active slot, but its protocol cannot safely target that slot for editing in Sonico.")
                .font(.caption).foregroundStyle(colors.secondary)
        } else if model.snapshot.presets.contains(where: \.isUserSlot) && !model.snapshot.canEditEqualizer {
            Text("Select a reported custom slot to edit it.").font(.caption).foregroundStyle(colors.secondary)
        }
    }

    @ViewBuilder private func editControls(_ editing: EqualizerEdit) -> some View {
        if let range = model.snapshot.bandRange, !editing.proposed.bands.isEmpty {
            ScrollView(.horizontal) {
                HStack(alignment: .top, spacing: 8) {
                    ForEach(editing.proposed.bands.indices, id: \.self) { index in
                        band(index, range: range, current: editing.proposed.bands[index])
                    }
                }.frame(minWidth: CGFloat(editing.proposed.bands.count) * 38)
            }
            .defaultScrollAnchor(.center, for: .alignment)
        }
        if let bass = editing.proposed.clearBass, let range = model.snapshot.clearBassRange {
            XMLevelControl(title: "Clear Bass", symbol: "waveform", value: Binding(
                get: { Double(draft?.proposed.clearBass ?? bass) },
                set: { draft?.proposed.clearBass = range.clamped(Int($0.rounded())) }
            ), range: range)
        }
        HStack {
            Button("Cancel") { draft = nil }
            Spacer()
            if !editing.proposed.bands.isEmpty, let range = model.snapshot.bandRange {
                Button("Flatten Draft") { draft?.proposed.bands = editing.proposed.bands.map { _ in Int32(range.neutral) } }
                    .buttonStyle(.bordered)
            }
            Button("Apply Changes") {
                model.send(.equalizerEdit(editing))
                draft = nil
            }
            .buttonStyle(TonalButtonStyle(prominent: true))
            .disabled(model.snapshot.applying || !editing.isValid(against: model.snapshot.equalizerValues,
                                                                  bandRange: model.snapshot.bandRange,
                                                                  bassRange: model.snapshot.clearBassRange))
        }
        Text("The draft stays in Sonico until you apply it to this headphone slot.")
            .font(.caption).foregroundStyle(colors.secondary)
    }

    private func band(_ index: Int, range: DeviceRange, current: Int32) -> some View {
        let frequency = model.snapshot.frequencies.indices.contains(index) ? model.snapshot.frequencies[index] : 0
        return VStack(spacing: 8) {
            Text(String(format: "%+d", current))
                .font(.caption.weight(.medium)).monospacedDigit().foregroundStyle(colors.primary)
            Slider(value: Binding(get: {
                guard let bands = draft?.proposed.bands, bands.indices.contains(index) else { return Double(current) }
                return Double(bands[index])
            }, set: { value in
                guard draft?.proposed.bands.indices.contains(index) == true else { return }
                draft?.proposed.bands[index] = Int32(range.clamped(Int(value.rounded())))
            }), in: range.sliderBounds, step: Double(range.step)) {
                Text(frequency > 0 ? "\(frequency) hertz" : "Band \(index + 1)")
            }
            .labelsHidden()
            .accessibilityLabel(frequency > 0 ? "\(frequency) hertz" : "Band \(index + 1)")
            .frame(width: 164, height: 24)
            .rotationEffect(.degrees(-90))
            .frame(width: 32, height: 164)
            .accessibilityValue("\(current) steps")
            Text(frequency > 0 ? frequencyLabel(frequency) : "\(index + 1)")
                .font(.caption).foregroundStyle(colors.secondary)
        }.frame(maxWidth: .infinity)
    }
}

struct EQResponse: View {
    let bands: [Int32]
    let frequencies: [Int]
    let range: DeviceRange?
    var compact = false
    @Environment(\.sonico) private var colors

    var body: some View {
        VStack(spacing: 8) {
            Canvas { context, size in
                let lo = Double(range?.lower ?? -6), hi = Double(range?.upper ?? 6)
                let span = max(1, hi - lo)
                let column = size.width / CGFloat(max(bands.count, 1))
                func y(_ value: Double) -> CGFloat {
                    2 + max(0, size.height - 4) * (hi - min(hi, max(lo, value))) / span
                }
                for value in gridLevels(lower: lo, upper: hi) {
                    let rule = Path { path in
                        path.move(to: CGPoint(x: 0, y: y(value)))
                        path.addLine(to: CGPoint(x: size.width, y: y(value)))
                    }
                    context.stroke(rule, with: .color(colors.outline), lineWidth: value == 0 ? 1.5 : 1)
                }
                let width = min(compact ? 13 : 18, column * 0.45)
                let baseline = y(0)
                for (i, band) in bands.enumerated() {
                    let value = y(Double(band)), x = column * (CGFloat(i) + 0.5)
                    let bar = CGRect(x: x - width / 2, y: min(value, baseline) - 1.5,
                                     width: width, height: abs(value - baseline) + 3)
                    context.fill(Path(roundedRect: bar, cornerRadius: 2.5), with: .color(colors.primary))
                }
            }
            if !compact {
                HStack(spacing: 0) {
                    ForEach(bands.indices, id: \.self) { index in
                        Text(frequencies.indices.contains(index) ? frequencyLabel(frequencies[index]) : "\(index + 1)")
                            .font(.caption2).foregroundStyle(colors.secondary).frame(maxWidth: .infinity)
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
