import AppKit
import SwiftUI

struct MenuBarView: View {
    @Bindable var model: HeadphoneModel
    @Environment(\.openWindow) private var openWindow
    @Environment(\.openSettings) private var openSettings
    @Environment(\.sonico) private var colors

    var body: some View {
        let snapshot = model.snapshot
        VStack(alignment: .leading, spacing: 14) {
            deviceHeader
            if snapshot.controllable {
                quickControls
            } else if snapshot.phase.busy {
                Button("Cancel Connection") { model.send(.disconnect) }
                    .buttonStyle(.bordered)
            } else {
                Text("Pair your headphones in Bluetooth Settings, then connect them in Sonico.")
                    .font(.callout).foregroundStyle(colors.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if snapshot.deviceAlert != nil {
                Button("Review headphone confirmation", systemImage: "exclamationmark.circle") { openDeviceWindow() }
                    .buttonStyle(.bordered)
            }
            if let error = model.visibleError {
                Label(error, systemImage: "exclamationmark.triangle")
                    .font(.caption).foregroundStyle(colors.error).lineLimit(4).help(error)
            }
            Divider()
            HStack(spacing: 12) {
                Button(snapshot.controllable || snapshot.phase.busy ? "Open Sonico" : "Connect Headphones…") {
                    openDeviceWindow()
                }
                .buttonStyle(TonalButtonStyle(prominent: true))
                Spacer()
                actions
            }
        }
        .padding(16).frame(width: 356)
        .foregroundStyle(colors.text).background(colors.background)
        .onAppear { model.start() }
    }

    private var deviceHeader: some View {
        let snapshot = model.snapshot
        return HStack(spacing: 12) {
            Image(systemName: "headphones")
                .font(.title3.weight(.medium)).foregroundStyle(colors.primary)
                .frame(width: 38, height: 38)
                .background(colors.surfaceHigh, in: RoundedRectangle(cornerRadius: 12))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 3) {
                Text(snapshot.controllable || snapshot.phase.busy ? snapshot.name : "Sonico")
                    .font(.headline).lineLimit(1).accessibilityAddTraits(.isHeader)
                StatusLine(snapshot: snapshot)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            if snapshot.phase.busy {
                ProgressView().controlSize(.small).accessibilityHidden(true)
            } else if snapshot.controllable, let battery = snapshot.battery {
                BatteryReadout(level: battery).font(.callout.weight(.semibold)).fixedSize()
            }
        }
    }

    @ViewBuilder
    private var quickControls: some View {
        let snapshot = model.snapshot
        let showTransport = snapshot.playbackAvailable && !snapshot.isDemo
        if snapshot.noiseMode != nil || snapshot.eqAvailable || showTransport || snapshot.playbackMetadataAvailable || snapshot.volumeRange != nil {
            VStack(alignment: .leading, spacing: 12) {
                if snapshot.noiseMode != nil {
                    NoiseModeControl(model: model, compact: true)
                    if snapshot.noiseMode == .ambient, let range = snapshot.ambientRange {
                        XMLevelControl(title: "Ambient level", symbol: "ear", value: Binding(
                            get: { model.ambientDraft }, set: { model.setAmbient($0) }
                        ), range: range)
                    }
                }
                if snapshot.eqAvailable { equalizerRow }
                if showTransport || snapshot.playbackMetadataAvailable {
                    if snapshot.noiseMode != nil || snapshot.eqAvailable { Divider() }
                    HStack(spacing: 8) {
                        PlaybackReadout(snapshot: snapshot, compact: true)
                        Spacer(minLength: 8)
                        if showTransport { PlaybackTransport(model: model) }
                    }
                }
                if let range = snapshot.volumeRange {
                    XMLevelControl(title: "Volume", symbol: "speaker.wave.2", value: Binding(
                        get: { model.volumeDraft }, set: { model.setVolume($0) }
                    ), range: range)
                }
            }
            .padding(12)
            .background(colors.surface, in: RoundedRectangle(cornerRadius: 16))
        }
        if snapshot.applying {
            HStack(spacing: 6) {
                ProgressView().controlSize(.mini)
                Text("Sending changes…")
            }.font(.caption).foregroundStyle(colors.secondary)
        }
    }

    private var equalizerRow: some View {
        let snapshot = model.snapshot
        return HStack {
            Text("Equalizer").font(.callout).foregroundStyle(colors.secondary)
            Spacer()
            if snapshot.activePresetReported && snapshot.presets.contains(where: { $0.id == snapshot.preset }) {
                Picker("Equalizer preset", selection: Binding(get: { model.snapshot.preset }, set: { preset in
                    let current = model.snapshot
                    guard current.controllable, current.activePresetReported, current.preset != preset,
                          current.presets.contains(where: { $0.id == preset }) else { return }
                    model.send(.preset(preset))
                })) {
                    ForEach(snapshot.presets) { Text($0.name).tag($0.id) }
                }.labelsHidden().frame(maxWidth: 174).disabled(snapshot.applying)
            } else {
                Text(snapshot.activePresetReported ? snapshot.presetName : "Not reported").font(.callout)
            }
        }
    }

    private var actions: some View {
        Menu("More", systemImage: "ellipsis.circle") {
            Button("Sonico Settings…", systemImage: "gearshape") {
                NSApplication.shared.activate()
                openSettings()
            }
            if model.snapshot.controllable {
                if model.snapshot.isDemo {
                    Button("Exit Demo", systemImage: "flask") { model.leaveDemo() }
                } else {
                    Button("Disconnect", systemImage: "link.badge.minus") { model.send(.disconnect) }
                }
            }
            Divider()
            Button("Quit Sonico", systemImage: "power") { NSApplication.shared.terminate(nil) }
        }
        .fixedSize()
        .help("More Sonico actions")
    }

    private func openDeviceWindow() {
        openWindow(id: "device")
        NSApplication.shared.activate()
    }
}
