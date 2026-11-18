import SwiftUI

struct OverviewView: View {
    @Bindable var model: HeadphoneModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            deviceHeader
            HStack(spacing: 12) {
                Text("Shortcuts").font(.title2.weight(.semibold)).accessibilityAddTraits(.isHeader)
                Spacer()
                Button("All device settings", systemImage: "slider.horizontal.3") { model.page = .settings }
                    .buttonStyle(.bordered).controlSize(.large)
            }
            let connectedDevices = model.snapshot.connectedDevices
            VStack(spacing: XMTheme.gap) {
                if model.snapshot.noiseMode != nil { noiseCard }
                if model.snapshot.eqAvailable {
                    XMCard(title: "Equalizer", symbol: "slider.vertical.3", action: { model.page = .equalizer }) {
                        HStack(alignment: .center, spacing: 20) {
                            Text(model.snapshot.presetName).font(.title3.weight(.semibold)).lineLimit(2)
                            Spacer(minLength: 12)
                            if !model.snapshot.bands.isEmpty {
                                EQResponse(bands: model.snapshot.bands, frequencies: model.snapshot.frequencies,
                                           range: model.snapshot.bandRange, compact: true)
                                    .frame(maxWidth: 230).frame(height: 36)
                            }
                        }
                    }
                }
                if model.snapshot.playbackAvailable || model.snapshot.volumeRange != nil {
                    PlaybackCard(model: model)
                }
                if !connectedDevices.isEmpty {
                    XMCard(title: "Connected devices", symbol: "link") {
                        VStack(alignment: .leading, spacing: 12) {
                            ForEach(connectedDevices) { device in
                                HStack(spacing: 10) {
                                    Label(device.name, systemImage: device.playing ? "speaker.wave.2.fill" : "desktopcomputer")
                                        .lineLimit(2)
                                    Spacer()
                                    if device.playing { Text("Playing").font(.caption).foregroundStyle(XMTheme.primary) }
                                }
                            }
                        }
                    }
                }
            }
            Text("Some Sony app features, including activity-based scenes and firmware updates, remain in the phone app.")
                .font(.caption).foregroundStyle(XMTheme.secondary)
        }
        .padding(22)
    }

    private var noiseCard: some View {
        XMCard(title: "Ambient Sound Control", symbol: "ear") {
            NoiseModeControl(model: model)
            if model.snapshot.noiseMode == .ambient, let range = model.snapshot.ambientRange {
                Divider().overlay(XMTheme.outline)
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
        let shell: UInt32?
    }

    private var deviceHeader: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 16) {
                Spacer()
                if model.snapshot.isDemo {
                    Menu {
                        ForEach(HeadphoneModelID.allCases, id: \.self) { variant in
                            Menu(variant.rawValue) {
                                Button("Silver") { model.enterDemo(model: variant, colorCode: 3) }
                                Button("Black") { model.enterDemo(model: variant, colorCode: 1) }
                                Button("Blue") { model.enterDemo(model: variant, colorCode: 5) }
                            }
                        }
                    } label: { Label("Preview finishes", systemImage: "swatchpalette") }
                    .menuStyle(.borderlessButton).fixedSize()
                }
                Button("Refresh device status", systemImage: "arrow.clockwise") { model.send(.sync) }
                    .labelStyle(.iconOnly).buttonStyle(.borderless).help("Refresh device status")
            }
            .frame(height: 24)
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 18) {
                    devicePortrait.frame(width: 284)
                    deviceIdentity.frame(minWidth: 206, maxWidth: .infinity, alignment: .leading)
                }
                VStack(spacing: 10) {
                    devicePortrait.frame(maxWidth: 320)
                    deviceIdentity.frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .padding(.horizontal, 22).padding(.top, 12).padding(.bottom, 18)
        .foregroundStyle(XMTheme.onHeader).tint(XMTheme.onHeader)
        .background(XMTheme.header, in: RoundedRectangle(cornerRadius: XMTheme.cardRadius))
    }

    private var devicePortrait: some View {
        Group {
            if let variant = model.snapshot.reportedModel {
                let arrival = model.arrivalID
                HeadphonePortrait(model: variant, finish: model.snapshot.finish, animateArrival: arrival != nil) {
                    if let arrival { model.consumeArrival(arrival) }
                }
                .id(PortraitKey(session: model.portraitID, model: variant, shell: model.snapshot.finish?.shell))
            } else {
                Image(systemName: "headphones")
                    .font(.system(size: 70, weight: .ultraLight))
                    .frame(maxWidth: .infinity).frame(height: 186).accessibilityHidden(true)
            }
        }
    }

    private var deviceIdentity: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(model.snapshot.name)
                .font(.system(size: 30, weight: .semibold)).lineLimit(2).minimumScaleFactor(0.75)
                .accessibilityAddTraits(.isHeader)
            if let finish = model.snapshot.finish {
                Text(finish.name).font(.callout).foregroundStyle(XMTheme.onHeader.opacity(0.78))
            }
            HStack(spacing: 10) {
                BatteryReadout(level: model.snapshot.battery).font(.callout.weight(.semibold))
                if !model.snapshot.codec.isEmpty {
                    Text(model.snapshot.codec).font(.caption.weight(.semibold))
                        .padding(.horizontal, 8).padding(.vertical, 4)
                        .background(XMTheme.onHeader.opacity(0.08), in: Capsule())
                }
            }.padding(.top, 10)
            if model.snapshot.dsee == true {
                Text(model.snapshot.dseeName).font(.caption).foregroundStyle(XMTheme.onHeader.opacity(0.78))
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

    var body: some View {
        HStack(spacing: 4) {
            ForEach(model.snapshot.availableNoiseModes) { mode in
                let selected = model.snapshot.noiseMode == mode
                Button { model.send(.noise(mode)) } label: {
                    VStack(spacing: compact ? 5 : 8) {
                        Image(systemName: mode.symbol).font(.system(size: compact ? 18 : 21, weight: .medium))
                        Text(mode.title).font(.caption.weight(.semibold))
                            .multilineTextAlignment(.center).fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxWidth: .infinity, minHeight: compact ? 56 : 66)
                    .padding(.horizontal, 4)
                    .foregroundStyle(selected ? XMTheme.onPrimary : XMTheme.secondary)
                    .background {
                        if selected {
                            RoundedRectangle(cornerRadius: 14).fill(XMTheme.primary)
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
        .background(XMTheme.background.opacity(0.72), in: RoundedRectangle(cornerRadius: 18))
        .animation(reduceMotion ? nil : XMMotion.selection, value: model.snapshot.noiseMode)
    }
}

struct XMLevelControl: View {
    let title: String
    let symbol: String
    @Binding var value: Double
    let range: DeviceRange

    var body: some View {
        HStack(spacing: 10) {
            Label(title, systemImage: symbol).foregroundStyle(XMTheme.secondary).accessibilityHidden(true)
            Slider(value: $value, in: range.sliderBounds, step: Double(range.step)) { Text(title) }
                .labelsHidden().accessibilityLabel(title)
            Text("\(Int(value))").monospacedDigit().foregroundStyle(XMTheme.text).frame(minWidth: 24, alignment: .trailing)
                .accessibilityHidden(true)
        }.font(.callout)
    }
}

struct PlaybackCard: View {
    @Bindable var model: HeadphoneModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        XMCard(title: "Playback", symbol: "music.note") {
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(model.snapshot.track.isEmpty ? "No track information" : model.snapshot.track)
                        .font(.headline).lineLimit(2)
                    if !model.snapshot.artist.isEmpty {
                        Text(model.snapshot.artist).font(.callout).foregroundStyle(XMTheme.secondary).lineLimit(2)
                    }
                }.frame(maxWidth: .infinity, alignment: .leading)
                if model.snapshot.playbackAvailable {
                    HStack(spacing: 10) {
                        Button("Previous track", systemImage: "backward.end.fill") { model.send(.playback(4)) }
                            .help("Previous track")
                        Button {
                            model.send(.playback(model.snapshot.playing ? 2 : 1))
                        } label: {
                            Image(systemName: model.snapshot.playing ? "pause.fill" : "play.fill")
                                .contentTransition(.symbolEffect(.replace))
                                .frame(width: 30, height: 30)
                                .foregroundStyle(XMTheme.onPrimary).background(XMTheme.primary, in: Circle())
                        }
                        .accessibilityLabel(model.snapshot.playing ? "Pause" : "Play")
                        .help(model.snapshot.playing ? "Pause" : "Play")
                        .animation(reduceMotion ? nil : XMMotion.press, value: model.snapshot.playing)
                        Button("Next track", systemImage: "forward.end.fill") { model.send(.playback(3)) }
                            .help("Next track")
                    }.labelStyle(.iconOnly).buttonStyle(.borderless).font(.title3).foregroundStyle(XMTheme.primary)
                }
            }
            if let range = model.snapshot.volumeRange {
                XMLevelControl(title: "Volume", symbol: "speaker.wave.2", value: Binding(
                    get: { model.volumeDraft }, set: { model.setVolume($0) }
                ), range: range)
            }
        }
    }
}
