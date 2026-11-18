import SwiftUI

struct DeviceSettingsView: View {
    @Bindable var model: HeadphoneModel
    @State private var noiseOpen = false
    @State private var soundOpen = true
    @State private var connectionOpen = false
    @State private var controlsOpen = false
    @State private var powerConfirmation = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            XMPageHeading(title: "All device settings", detail: "Manage sound, connections, and headphone controls.", symbol: "slider.horizontal.3")
            settingGroup("Noise Canceling / Ambient Sound", symbol: "person.wave.2", expanded: $noiseOpen) {
                if model.snapshot.noiseMode != nil {
                    NoiseModeControl(model: model).padding(.vertical, 8)
                }
                if model.snapshot.noiseMode == .ambient, let range = model.snapshot.ambientRange {
                    XMLevelControl(title: "Ambient level", symbol: "ear", value: Binding(
                        get: { model.ambientDraft }, set: { model.setAmbient($0) }
                    ), range: range)
                }
                if let enabled = model.snapshot.speakToChat {
                    Toggle("Speak-to-Chat", isOn: Binding(get: { enabled }, set: { model.send(.speakToChat($0)) }))
                }
            }
            settingGroup("Sound Quality / Volume", symbol: "waveform", expanded: $soundOpen) {
                if let listening = model.snapshot.listening {
                    Picker("Listening mode", selection: Binding(get: { listening }, set: { model.send(.listening($0)) })) {
                        ForEach(model.snapshot.listeningOptions) { option in
                            Text(option.name).tag(option.id).disabled(!option.available)
                        }
                    }
                }
                Button { model.page = .equalizer } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 5) {
                            Text("Equalizer").foregroundStyle(XMTheme.text)
                            Text(model.snapshot.presetName).font(.callout).foregroundStyle(XMTheme.secondary)
                        }
                        Spacer()
                        Image(systemName: "chevron.right").foregroundStyle(XMTheme.secondary)
                    }
                }.buttonStyle(.plain).disabled(!model.snapshot.eqAvailable)
                if let enabled = model.snapshot.dsee {
                    Toggle(model.snapshot.dseeName, isOn: Binding(get: { enabled }, set: { model.send(.dsee($0)) }))
                }
                if let range = model.snapshot.volumeRange {
                    XMLevelControl(title: "Volume", symbol: "speaker.wave.2", value: Binding(
                        get: { model.volumeDraft }, set: { model.setVolume($0) }
                    ), range: range)
                }
                Text("Find Your Equalizer, 360 Reality Audio setup, and spatial optimization are managed in Sony's phone app.")
                    .font(.caption).foregroundStyle(XMTheme.secondary)
            }
            settingGroup("Connection", symbol: "link", expanded: $connectionOpen) {
                if let priority = model.snapshot.connectionPriority {
                    Picker("Bluetooth connection priority", selection: Binding(get: { priority }, set: { model.send(.priority($0)) })) {
                        Text("Sound quality").tag(UInt32(1))
                        Text("Stable connection").tag(UInt32(2))
                    }
                    Text("Changing connection settings may interrupt playback. Codec availability also depends on your Mac.")
                        .font(.caption).foregroundStyle(XMTheme.secondary)
                }
                ForEach(model.snapshot.pairedDevices) { device in
                    HStack {
                        Label(device.name, systemImage: device.playing ? "speaker.wave.2" : "desktopcomputer")
                        Spacer()
                        Text(device.connected ? "Connected" : "Paired").foregroundStyle(XMTheme.secondary).font(.callout)
                    }
                }
                Text("Device switching and pairing management will be added after hardware validation.")
                    .font(.caption).foregroundStyle(XMTheme.secondary)
            }
            settingGroup("Controls", symbol: "hand.tap", expanded: $controlsOpen) {
                if let enabled = model.snapshot.autoPause {
                    Toggle("Pause when headphones are removed", isOn: Binding(get: { enabled }, set: { model.send(.autoPause($0)) }))
                }
                ForEach(model.snapshot.generalSettings) { setting in
                    VStack(alignment: .leading, spacing: 6) {
                        if let boolean = setting.boolean {
                            Toggle(setting.title, isOn: Binding(get: { boolean }, set: { model.send(.generalBoolean(setting.id, $0)) }))
                                .disabled(!setting.writable)
                        } else if let selected = setting.selection, !setting.options.isEmpty {
                            Picker(setting.title, selection: Binding(get: { selected }, set: { model.send(.generalList(setting.id, $0)) })) {
                                ForEach(setting.options.indices, id: \.self) { index in
                                    Text(setting.options[index]).tag(UInt32(index))
                                }
                            }.disabled(!setting.writable)
                        }
                        if !setting.summary.isEmpty { Text(setting.summary).font(.caption).foregroundStyle(XMTheme.secondary) }
                    }
                }
                Text("Only controls reported by the headphones are shown.").font(.caption).foregroundStyle(XMTheme.secondary)
            }
            VStack(alignment: .leading, spacing: 12) {
                LabeledContent("Model", value: model.snapshot.name)
                LabeledContent("Firmware", value: model.snapshot.firmware.isEmpty ? "Not reported" : model.snapshot.firmware)
                Divider()
                HStack {
                    Button("Disconnect") { model.send(.disconnect) }.buttonStyle(TonalButtonStyle())
                    Spacer()
                    if model.snapshot.canShutdown {
                        Button("Turn Off Headphones", systemImage: "power") { powerConfirmation = true }
                            .buttonStyle(TonalButtonStyle())
                    }
                }
            }.font(.callout).padding(.top, 12)
        }
        .padding(24)
        .alert("Turn off your headphones?", isPresented: $powerConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Turn Off", role: .destructive) { model.send(.shutdown) }
        } message: { Text("Playback and the Bluetooth connection will end.") }
    }

    private func settingGroup<Content: View>(_ title: String, symbol: String, expanded: Binding<Bool>, @ViewBuilder content: @escaping () -> Content) -> some View {
        DisclosureGroup(isExpanded: expanded) {
            VStack(alignment: .leading, spacing: 22, content: content)
                .frame(maxWidth: .infinity, alignment: .leading).padding(.top, 22).padding(.bottom, 8)
        } label: {
            Label(title, systemImage: symbol).font(.headline).foregroundStyle(XMTheme.primary)
        }
        .padding(XMTheme.inset)
        .background(XMTheme.surface, in: RoundedRectangle(cornerRadius: XMTheme.cardRadius))
        .animation(reduceMotion ? nil : XMMotion.reveal, value: expanded.wrappedValue)
    }
}
