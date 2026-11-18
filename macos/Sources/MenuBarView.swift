import AppKit
import SwiftUI

struct MenuBarView: View {
    @Bindable var model: HeadphoneModel
    @Environment(\.openWindow) private var openWindow
    @Environment(\.openSettings) private var openSettings

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                Image(systemName: "headphones").font(.title2).foregroundStyle(XMTheme.primary)
                VStack(alignment: .leading, spacing: 3) {
                    Text(model.snapshot.name).font(.headline)
                    StatusLine(snapshot: model.snapshot)
                }
                Spacer()
                if let battery = model.snapshot.battery {
                    BatteryReadout(level: battery).font(.callout.weight(.semibold))
                }
            }
            if model.snapshot.controllable {
                Divider()
                if model.snapshot.noiseMode != nil { NoiseModeControl(model: model, compact: true) }
                if model.snapshot.noiseMode == .ambient, let range = model.snapshot.ambientRange {
                    XMLevelControl(title: "Ambient level", symbol: "ear", value: Binding(
                        get: { model.ambientDraft }, set: { model.setAmbient($0) }
                    ), range: range)
                }
                if model.snapshot.eqAvailable {
                    HStack {
                        Text("Equalizer").foregroundStyle(XMTheme.secondary)
                        Spacer()
                        if !model.snapshot.presets.isEmpty {
                            Picker("Equalizer preset", selection: Binding(get: { model.snapshot.preset }, set: { model.send(.preset($0)) })) {
                                ForEach(model.snapshot.presets) { Text($0.name).tag($0.id) }
                            }.labelsHidden().frame(maxWidth: 180)
                        } else { Text(model.snapshot.presetName) }
                    }
                }
                if let range = model.snapshot.volumeRange {
                    XMLevelControl(title: "Volume", symbol: "speaker.wave.2", value: Binding(
                        get: { model.volumeDraft }, set: { model.setVolume($0) }
                    ), range: range)
                }
                if model.snapshot.applying { Text("Sending changes…").font(.caption).foregroundStyle(XMTheme.secondary) }
            } else {
                Text("Open the app to connect your paired WH-1000X headphones.")
                    .font(.callout).foregroundStyle(XMTheme.secondary)
            }
            if model.snapshot.deviceAlert != nil {
                Button("Review headphone confirmation", systemImage: "exclamationmark.circle") { openDeviceWindow() }
                    .buttonStyle(.borderless)
            }
            if let error = model.visibleError {
                Text(error).font(.caption).foregroundStyle(XMTheme.error).fixedSize(horizontal: false, vertical: true)
            }
            Divider()
            HStack {
                Button("Open App") { openDeviceWindow() }.buttonStyle(TonalButtonStyle(prominent: true))
                Spacer()
                Button("Settings", systemImage: "gearshape") { openSettings() }
                    .labelStyle(.iconOnly).buttonStyle(.plain).help("App settings")
                Button("Quit", systemImage: "power") { NSApplication.shared.terminate(nil) }
                    .labelStyle(.iconOnly).buttonStyle(.plain).help("Quit Project XMConnect")
            }
            if model.snapshot.controllable {
                Button(model.snapshot.isDemo ? "Exit Demo" : "Disconnect") { model.send(.disconnect) }
                    .font(.callout).buttonStyle(.plain).foregroundStyle(XMTheme.secondary)
            }
        }
        .padding(20).frame(width: 350)
        .foregroundStyle(XMTheme.text).background(XMTheme.background)
        .preferredColorScheme(.dark).tint(XMTheme.primary)
        .onAppear { model.start() }
    }

    private func openDeviceWindow() {
        openWindow(id: "device")
        NSApplication.shared.activate(ignoringOtherApps: true)
    }
}
