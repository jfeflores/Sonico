import SwiftUI

struct OverviewView: View {
    @Bindable var model: HeadphoneModel
    @AppStorage("overview.shortcutLayout.v1") private var storedLayout = Data()
    @State private var editingShortcuts = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.sonico) private var colors

    var body: some View {
        let layout = ShortcutLayout(stored: storedLayout)
        let available = layout.available(in: model.snapshot)
        let visible = available.filter(layout.isVisible)
        VStack(alignment: .leading, spacing: XMTheme.section) {
            deviceHeader
            HStack(spacing: 12) {
                Text("Shortcuts").font(.title2.weight(.semibold)).accessibilityAddTraits(.isHeader)
                Spacer()
                Button("Edit Shortcuts", systemImage: "line.3.horizontal.decrease") { editingShortcuts = true }
                    .buttonStyle(.bordered)
                    .disabled(available.isEmpty)
            }
            if visible.isEmpty {
                XMCard(title: available.isEmpty ? "No shortcuts available" : "No shortcuts shown") {
                    Text(available.isEmpty ? "No shortcut controls are currently reported by your headphones."
                         : "Use Edit Shortcuts to choose what appears here.")
                        .font(.callout).foregroundStyle(colors.secondary)
                }
            } else {
                VStack(spacing: XMTheme.gap) {
                    ForEach(visible) { shortcut in shortcutCard(shortcut) }
                }
            }
            Text("Some Sony app features, including activity-based scenes and firmware updates, remain in the phone app.")
                .font(.caption).foregroundStyle(colors.secondary)
        }
        .padding(XMTheme.margin)
        .sheet(isPresented: $editingShortcuts) {
            ShortcutEditor(model: model, layout: layout) { storedLayout = $0.stored }
                .modifier(FinishAppearance(finish: model.snapshot.finish))
        }
    }

    @ViewBuilder
    private func shortcutCard(_ shortcut: OverviewShortcut) -> some View {
        let snapshot = model.snapshot
        switch shortcut {
        case .noise:
            noiseCard
        case .equalizer:
            XMCard(title: shortcut.title(for: snapshot), symbol: shortcut.symbol, action: { model.page = .equalizer }) {
                HStack(alignment: .center, spacing: 20) {
                    Text(snapshot.presetName).font(.title3.weight(.semibold)).lineLimit(2)
                    Spacer(minLength: 12)
                    if !snapshot.bands.isEmpty {
                        EQResponse(bands: snapshot.bands, frequencies: snapshot.frequencies,
                                   range: snapshot.bandRange, compact: true)
                            .frame(maxWidth: 230).frame(height: 36)
                    }
                }
            }
        case .playback:
            PlaybackCard(model: model)
        case .connectedDevices:
            XMCard(title: shortcut.title(for: snapshot), symbol: shortcut.symbol) {
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(snapshot.connectedDevices) { device in
                        HStack(spacing: 10) {
                            Label(device.name, systemImage: device.playing ? "speaker.wave.2.fill" : "desktopcomputer")
                                .lineLimit(2)
                            Spacer()
                            if device.playing { Text("Playing").font(.caption).foregroundStyle(colors.primary) }
                        }
                    }
                }
            }
        case .setting(let feature):
            XMCard(title: feature == .generalControls ? shortcut.title(for: snapshot) : nil, symbol: shortcut.symbol) {
                DeviceSettingControl(model: model, feature: feature)
            }
        }
    }

    private var noiseCard: some View {
        XMCard(title: "Ambient Sound Control", symbol: "ear") {
            NoiseModeControl(model: model)
            if model.snapshot.noiseMode == .ambient, let range = model.snapshot.ambientRange {
                Divider().overlay(colors.outline.opacity(0.45))
                XMLevelControl(title: "Ambient level", symbol: "ear", value: Binding(
                    get: { model.ambientDraft }, set: { model.setAmbient($0) }
                ), range: range)
                .transition(.opacity)
            }
        }
        .animation(reduceMotion ? nil : XMMotion.reveal, value: model.snapshot.noiseMode == .ambient)
    }

    private struct PortraitKey: Hashable {
        let session: UUID?
        let model: HeadphoneModelID
    }

    private var deviceHeader: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 12) {
                Spacer()
                if model.snapshot.isDemo {
                    Menu {
                        ForEach(HeadphoneModelID.allCases, id: \.self) { variant in
                            Menu(variant.rawValue) {
                                Button("Silver") { model.enterDemo(model: variant, colorCode: 3) }
                                Button("Black") { model.enterDemo(model: variant, colorCode: 1) }
                                Button("Blue") { model.enterDemo(model: variant, colorCode: 5) }
                                if variant == .xm6 {
                                    Button("Sand Pink") { model.enterDemo(model: variant, colorCode: 6) }
                                    Button("Olive Gray") { model.enterDemo(model: variant, colorCode: 8) }
                                }
                            }
                        }
                    } label: { Label("Preview finishes", systemImage: "swatchpalette") }
                    .menuStyle(.borderlessButton).fixedSize()
                }
                if !model.snapshot.isDemo {
                    Button("Refresh device status", systemImage: "arrow.clockwise") { model.send(.sync) }
                        .labelStyle(.iconOnly).buttonStyle(.borderless).help("Refresh device status")
                }
            }
            .frame(height: 24)
            HStack(spacing: 12) {
                devicePortrait.frame(minWidth: 210, maxWidth: 310)
                deviceIdentity.frame(minWidth: 195, maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(.horizontal, XMTheme.inset).padding(.top, 10).padding(.bottom, 12)
        .foregroundStyle(colors.onHeader).tint(colors.onHeader)
        .background {
            RoundedRectangle(cornerRadius: XMTheme.cardRadius)
                .fill(RadialGradient(colors: [colors.header, colors.headerEdge], center: .init(x: 0.29, y: 0.42),
                                     startRadius: 26, endRadius: 490))
        }
    }

    private var devicePortrait: some View {
        Group {
            if let variant = model.snapshot.reportedModel {
                let arrival = model.arrivalID
                HeadphonePortrait(model: variant, finish: model.snapshot.finish, animateArrival: arrival != nil) {
                    if let arrival { model.consumeArrival(arrival) }
                }
                .id(PortraitKey(session: model.portraitID, model: variant))
            } else {
                Image(systemName: "headphones")
                    .font(.system(size: 56, weight: .ultraLight))
                    .frame(maxWidth: .infinity).frame(height: 210).accessibilityHidden(true)
            }
        }
    }

    private var deviceIdentity: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(model.snapshot.name)
                .font(.system(size: 31, weight: .semibold)).lineLimit(1).minimumScaleFactor(0.75)
                .accessibilityAddTraits(.isHeader)
            if let finish = model.snapshot.finish {
                Label {
                    Text(finish.name)
                } icon: {
                    Circle().fill(Color(hex: finish.shell)).overlay(Circle().strokeBorder(colors.onHeader.opacity(0.44), lineWidth: 1))
                        .frame(width: 11, height: 11).accessibilityHidden(true)
                }
                .font(.callout).foregroundStyle(colors.headerSecondary)
            }
            HStack(spacing: 10) {
                BatteryReadout(level: model.snapshot.battery).font(.callout.weight(.semibold))
                if !model.snapshot.codec.isEmpty {
                    Text(model.snapshot.codec).font(.caption.weight(.semibold))
                        .padding(.horizontal, 8).padding(.vertical, 4)
                        .background(colors.onHeader.opacity(0.09), in: Capsule())
                }
            }.padding(.top, 10)
            if model.snapshot.dsee == true {
                Text(model.snapshot.dseeName).font(.caption).foregroundStyle(colors.headerSecondary)
            }
        }
    }
}

struct BatteryReadout: View {
    let level: Int?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Label {
            Text(level.map { "\($0)%" } ?? "Battery unavailable")
                .monospacedDigit()
                .contentTransition(.numericText())
        } icon: {
            Image(systemName: symbol)
        }
        .accessibilityLabel(level.map { "Battery \($0) percent" } ?? "Battery unavailable")
        .animation(reduceMotion ? nil : XMMotion.reveal, value: level)
    }

    private var symbol: String {
        guard let level else { return "battery.0percent" }
        return switch level {
        case 0...12: "battery.0percent"
        case 13...37: "battery.25percent"
        case 38...62: "battery.50percent"
        case 63...87: "battery.75percent"
        case 88...100: "battery.100percent"
        default: "battery.0percent"
        }
    }
}

struct NoiseModeControl: View {
    @Bindable var model: HeadphoneModel
    var compact = false
    @Namespace private var selection
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.sonico) private var colors

    var body: some View {
        HStack(spacing: 4) {
            ForEach(model.snapshot.availableNoiseModes) { mode in
                let selected = model.snapshot.noiseMode == mode
                Button { model.send(.noise(mode)) } label: {
                    VStack(spacing: 5) {
                        Image(systemName: mode.symbol).font(.system(size: compact ? 16 : 18, weight: .medium))
                        Text(mode.title).font(.caption.weight(.semibold))
                            .multilineTextAlignment(.center).fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxWidth: .infinity, minHeight: compact ? 47 : 55)
                    .padding(.horizontal, 4)
                    .foregroundStyle(selected ? colors.onPrimary : colors.text)
                    .background {
                        if selected {
                            RoundedRectangle(cornerRadius: 14).fill(colors.primary)
                                .matchedGeometryEffect(id: "noise-selection", in: selection)
                        }
                    }
                    .contentShape(RoundedRectangle(cornerRadius: 14))
                }
                .buttonStyle(.borderless)
                .help(mode.title)
                .accessibilityLabel(mode.title)
                .accessibilityAddTraits(selected ? .isSelected : [])
            }
        }
        .padding(4)
        .background(colors.surfaceHigh, in: RoundedRectangle(cornerRadius: 18))
        .animation(reduceMotion ? nil : XMMotion.selection, value: model.snapshot.noiseMode)
    }
}

struct XMLevelControl: View {
    let title: String
    let symbol: String
    @Binding var value: Double
    let range: DeviceRange
    @Environment(\.sonico) private var colors

    var body: some View {
        HStack(spacing: 10) {
            Label(title, systemImage: symbol).foregroundStyle(colors.secondary).accessibilityHidden(true)
            Slider(value: $value, in: range.sliderBounds, step: Double(range.step)) { Text(title) }
                .labelsHidden().accessibilityLabel(title)
            Text("\(Int(value))").monospacedDigit().foregroundStyle(colors.text).frame(minWidth: 24, alignment: .trailing)
                .accessibilityHidden(true)
        }.font(.callout)
    }
}

struct PlaybackCard: View {
    @Bindable var model: HeadphoneModel
    @Environment(\.sonico) private var colors

    var body: some View {
        XMCard(title: "Playback", symbol: "music.note") {
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    PlaybackReadout(snapshot: model.snapshot)
                }.frame(maxWidth: .infinity, alignment: .leading)
                if model.snapshot.playbackAvailable && !model.snapshot.isDemo { PlaybackTransport(model: model) }
            }
            if let range = model.snapshot.volumeRange {
                XMLevelControl(title: "Volume", symbol: "speaker.wave.2", value: Binding(
                    get: { model.volumeDraft }, set: { model.setVolume($0) }
                ), range: range)
            }
        }
    }
}

struct PlaybackReadout: View {
    let snapshot: HeadphoneSnapshot
    var compact = false
    @Environment(\.sonico) private var colors

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(snapshot.playbackTitle)
                .font(compact ? .callout.weight(.semibold) : .headline).lineLimit(compact ? 1 : 2)
            let detail = [snapshot.artist, snapshot.album].filter { !$0.isEmpty }.joined(separator: " · ")
            if !detail.isEmpty && snapshot.playbackState != .stopped {
                Text(detail).font(.caption).foregroundStyle(colors.secondary).lineLimit(1)
            } else if let source = snapshot.playbackDeviceName, snapshot.playbackState != .stopped {
                Text(source).font(.caption).foregroundStyle(colors.secondary).lineLimit(1)
            }
        }
    }
}

struct PlaybackTransport: View {
    let model: HeadphoneModel
    @Environment(\.sonico) private var colors
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let playing = model.snapshot.playing
        let action = playing ? "Pause" : "Play"
        HStack(spacing: 10) {
            Button("Previous track", systemImage: "backward.end.fill") { model.send(.playback(4)) }
                .help("Previous track")
            Button {
                model.send(.playback(model.snapshot.playing ? 2 : 1))
            } label: {
                Image(systemName: playing ? "pause.fill" : "play.fill")
                    .contentTransition(reduceMotion ? .identity : .symbolEffect(.replace))
                    .frame(width: 30, height: 30)
                    .foregroundStyle(colors.onPrimary).background(colors.primary, in: Circle())
            }
            .accessibilityLabel(action)
            .help(action)
            .animation(reduceMotion ? nil : XMMotion.press, value: playing)
            Button("Next track", systemImage: "forward.end.fill") { model.send(.playback(3)) }
                .help("Next track")
        }
        .labelStyle(.iconOnly).buttonStyle(.borderless).font(.title3).foregroundStyle(colors.primary)
    }
}
