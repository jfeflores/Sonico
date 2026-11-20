import SwiftUI

struct DeviceSettingsView: View {
    @Bindable var model: HeadphoneModel
    @State private var noiseOpen = false
    @State private var soundOpen = true
    @State private var connectionOpen = false
    @State private var controlsOpen = false
    @State private var powerOpen = false
    @State private var powerConfirmation = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.sonico) private var colors

    private var advanced: AdvancedDeviceSettings { model.snapshot.advancedSettings }

    var body: some View {
        VStack(alignment: .leading, spacing: XMTheme.gap) {
            XMPageHeading(title: "Settings", detail: "Manage sound, connections, and headphone controls.", symbol: "slider.horizontal.3")
                .padding(.bottom, 8)
            if model.snapshot.noiseMode != nil || model.snapshot.speakToChat != nil {
                settingGroup("Noise Canceling / Ambient Sound", symbol: "person.wave.2", expanded: $noiseOpen) {
                    noiseControls
                }
            }
            settingGroup("Sound Quality / Volume", symbol: "waveform", expanded: $soundOpen) {
                if DeviceSettingFeature.listening.isAvailable(in: model.snapshot) {
                    VStack(alignment: .leading, spacing: 8) {
                        DeviceSettingControl(model: model, feature: .listening)
                        advancedChoice("Background Music distance", choices: advanced.backgroundRoom, change: AdvancedDeviceSettingChange.backgroundRoom)
                    }
                }
                Button { model.page = .equalizer } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 5) {
                            Text("Equalizer").foregroundStyle(colors.text)
                            Text(model.snapshot.presetName).font(.callout).foregroundStyle(colors.secondary)
                        }
                        Spacer()
                        Image(systemName: "chevron.right").foregroundStyle(colors.secondary)
                    }
                }.buttonStyle(.plain).disabled(!model.snapshot.eqAvailable)
                DeviceSettingControl(model: model, feature: .dsee)
                if let range = model.snapshot.volumeRange {
                    XMLevelControl(title: "Volume", symbol: "speaker.wave.2", value: Binding(
                        get: { model.volumeDraft }, set: { model.setVolume($0) }
                    ), range: range)
                }
                Text("Find Your Equalizer, 360 Reality Audio setup, and spatial optimization are managed in Sony's phone app.")
                    .font(.caption).foregroundStyle(colors.secondary)
            }
            settingGroup("Connection", symbol: "link", expanded: $connectionOpen) {
                if model.snapshot.connectionPriority != nil {
                    VStack(alignment: .leading, spacing: 8) {
                        DeviceSettingControl(model: model, feature: .connectionPriority)
                        DeviceSettingNote("Changing connection priority can interrupt playback. Available codecs also depend on your Mac.")
                    }
                }
                if let automatic = model.snapshot.automaticSourceSwitch {
                    Toggle("Automatically switch playback source", isOn: Binding(get: { automatic }, set: {
                        model.send(.automaticSourceSwitch($0))
                    }))
                    .disabled(model.snapshot.applying)
                }
                ForEach(model.snapshot.pairedDevices) { device in
                    HStack {
                        Label(device.name, systemImage: device.playing ? "speaker.wave.2" : "desktopcomputer")
                        Spacer()
                        if model.snapshot.canSelectPlaybackSource && device.connected && !device.playing {
                            Button("Use for Playback") { model.send(.selectPlaybackSource(device.id)) }
                                .buttonStyle(.bordered).disabled(model.snapshot.applying)
                        } else {
                            Text(device.playing && device.connected ? "Playback source" : device.connected ? "Connected" : "Paired")
                                .foregroundStyle(colors.secondary).font(.callout)
                        }
                    }
                }
                Text("Manage pairing in Bluetooth Settings.")
                    .font(.caption).foregroundStyle(colors.secondary)
            }
            if hasControls {
                settingGroup("Controls", symbol: "hand.tap", expanded: $controlsOpen) {
                    DeviceSettingControl(model: model, feature: .autoPause)
                    DeviceSettingControl(model: model, feature: .generalControls)
                    advancedChoice("Noise control button cycle", choices: advanced.noiseButton, change: AdvancedDeviceSettingChange.noiseButton)
                    if let enabled = advanced.headGestures {
                        advancedToggle("Head gestures", enabled: enabled, change: AdvancedDeviceSettingChange.headGestures)
                    }
                    ForEach(advanced.assignableControls) { control in
                        advancedChoice(control.title, choices: control.choices) { .assignableControl(location: control.id, action: $0) }
                    }
                    if let assistant = advanced.voiceAssistant {
                        VStack(alignment: .leading, spacing: 8) {
                            advancedChoice("Voice assistant", choices: assistant, change: AdvancedDeviceSettingChange.voiceAssistant)
                                .disabled(model.snapshot.applying)
                            if let notice = advanced.voiceAssistantNotice { DeviceSettingNote(notice) }
                        }
                    }
                }
            }
            if advanced.autoPowerOff != nil || advanced.voiceGuidance != nil {
                settingGroup("Power and voice guidance", symbol: "power", expanded: $powerOpen) {
                    if let choices = advanced.autoPowerOff {
                        VStack(alignment: .leading, spacing: 8) {
                            advancedChoice("Automatic power off", choices: choices, change: AdvancedDeviceSettingChange.autoPowerOff)
                            DeviceSettingNote("Timed options start when the Bluetooth connection is lost.")
                        }
                    }
                    if let guidance = advanced.voiceGuidance {
                        VStack(alignment: .leading, spacing: 8) {
                            advancedToggle("Voice guidance", enabled: guidance.enabled, change: AdvancedDeviceSettingChange.voiceGuidance)
                            if let range = guidance.volumeRange {
                                Picker("Voice guidance volume", selection: Binding(get: { guidance.volume }, set: {
                                    model.send(.advancedSetting(.voiceGuidanceVolume($0)))
                                })) {
                                    ForEach(Array(stride(from: range.lower, through: range.upper, by: range.step)), id: \.self) { level in
                                        Text(level == 0 ? "Standard" : (level > 0 ? "+\(level)" : "\(level)")).tag(level)
                                    }
                                }
                                .pickerStyle(.menu)
                                .disabled(!model.snapshot.controllable)
                            }
                        }
                    }
                }
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
        .padding(XMTheme.margin)
        .alert("Turn off your headphones?", isPresented: $powerConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Turn Off", role: .destructive) { model.send(.shutdown) }
        } message: { Text("Playback and the Bluetooth connection will end.") }
    }

    @ViewBuilder private var noiseControls: some View {
        if model.snapshot.noiseMode != nil {
            NoiseModeControl(model: model).padding(.vertical, 8)
        }
        if model.snapshot.noiseMode == .ambient {
            if let range = model.snapshot.ambientRange {
                XMLevelControl(title: "Ambient level", symbol: "ear", value: Binding(
                    get: { model.ambientDraft }, set: { model.setAmbient($0) }
                ), range: range)
            }
            if let enabled = advanced.focusOnVoice {
                advancedToggle("Focus on voice", enabled: enabled, change: AdvancedDeviceSettingChange.focusOnVoice)
            }
            if let enabled = advanced.adaptiveAmbient {
                VStack(alignment: .leading, spacing: 8) {
                    advancedToggle("Auto ambient sound", enabled: enabled, change: AdvancedDeviceSettingChange.adaptiveAmbient)
                    advancedChoice("Ambient sensitivity", choices: advanced.adaptiveSensitivity, change: AdvancedDeviceSettingChange.adaptiveSensitivity)
                }
            }
        }
        if model.snapshot.speakToChat != nil {
            if model.snapshot.noiseMode != nil { Divider() }
            VStack(alignment: .leading, spacing: 8) {
                DeviceSettingControl(model: model, feature: .speakToChat)
                advancedChoice("Speech detection sensitivity", choices: advanced.speechSensitivity, change: AdvancedDeviceSettingChange.speechSensitivity)
                advancedChoice("Speak-to-Chat timeout", choices: advanced.speechTimeout, change: AdvancedDeviceSettingChange.speechTimeout)
            }
        }
    }

    private var hasControls: Bool {
        model.snapshot.autoPause != nil || !model.snapshot.generalSettings.isEmpty || advanced.noiseButton != nil
            || advanced.headGestures != nil || !advanced.assignableControls.isEmpty || advanced.voiceAssistant != nil
    }

    private func advancedToggle(_ title: String, enabled: Bool, change: @escaping (Bool) -> AdvancedDeviceSettingChange) -> some View {
        Toggle(title, isOn: Binding(get: { enabled }, set: { model.send(.advancedSetting(change($0))) }))
            .disabled(!model.snapshot.controllable)
    }

    @ViewBuilder private func advancedChoice(_ title: String, choices: DeviceSettingChoices?,
                                              change: @escaping (UInt32) -> AdvancedDeviceSettingChange) -> some View {
        if let choices {
            DeviceSettingPicker(title: title, choices: choices) { model.send(.advancedSetting(change($0))) }
                .disabled(!model.snapshot.controllable)
        }
    }

    private func settingGroup<Content: View>(_ title: String, symbol: String, expanded: Binding<Bool>, @ViewBuilder content: @escaping () -> Content) -> some View {
        DisclosureGroup(isExpanded: expanded) {
            VStack(alignment: .leading, spacing: 16, content: content)
                .frame(maxWidth: .infinity, alignment: .leading).padding(.top, 16).padding(.bottom, 4)
        } label: {
            Label(title, systemImage: symbol).font(.headline).foregroundStyle(colors.primary)
        }
        .padding(XMTheme.inset)
        .background(colors.surface, in: RoundedRectangle(cornerRadius: XMTheme.cardRadius))
        .animation(reduceMotion ? nil : XMMotion.reveal, value: expanded.wrappedValue)
    }
}

/// The same capability-backed controls appear in Settings and any pinned shortcut.
struct DeviceSettingControl: View {
    let model: HeadphoneModel
    let feature: DeviceSettingFeature

    private var snapshot: HeadphoneSnapshot { model.snapshot }
    private var title: String { feature.title(for: snapshot) }

    var body: some View {
        if feature.isAvailable(in: snapshot) {
            control.disabled(!snapshot.controllable)
        }
    }

    @ViewBuilder private var control: some View {
        switch feature {
        case .speakToChat:
            if let enabled = snapshot.speakToChat {
                Toggle(title, isOn: Binding(get: { enabled }, set: { model.send(.speakToChat($0)) }))
            }
        case .listening:
            if let selected = snapshot.listening {
                let notices = snapshot.advancedSettings.listeningNotices
                let choices = DeviceSettingChoices(selected: selected, options: snapshot.listeningOptions.map {
                    DeviceSettingChoice(id: $0.id, title: $0.name, available: $0.available && notices[$0.id] == nil)
                })
                VStack(alignment: .leading, spacing: 6) {
                    DeviceSettingPicker(title: title, choices: choices) { model.send(.listening($0)) }
                        .disabled(snapshot.applying)
                    ForEach(choices.options.filter { notices[$0.id] != nil }) { option in
                        if let notice = notices[option.id] { DeviceSettingNote("\(option.title): \(notice)") }
                    }
                }
            }
        case .dsee:
            if let enabled = snapshot.dsee {
                Toggle(title, isOn: Binding(get: { enabled }, set: { model.send(.dsee($0)) }))
            }
        case .connectionPriority:
            if let selected = snapshot.connectionPriority {
                DeviceSettingPicker(title: title, choices: .init(selected: selected, options: DeviceSettingCatalog.priorities)) {
                    model.send(.priority($0))
                }
            }
        case .autoPause:
            if let enabled = snapshot.autoPause {
                Toggle(title, isOn: Binding(get: { enabled }, set: { model.send(.autoPause($0)) }))
            }
        case .generalControls:
            VStack(alignment: .leading, spacing: 12) {
                ForEach(snapshot.generalSettings.filter { !$0.title.isEmpty && ($0.boolean != nil || $0.selection != nil) }) { setting in
                    VStack(alignment: .leading, spacing: 6) {
                        if let enabled = setting.boolean {
                            Toggle(setting.title, isOn: Binding(get: { enabled }, set: { model.send(.generalBoolean(setting.id, $0)) }))
                                .disabled(!setting.writable)
                        } else if let selected = setting.selection {
                            let options = setting.options.enumerated().compactMap { index, label in
                                label.isEmpty ? nil : DeviceSettingChoice(id: UInt32(index), title: label)
                            }
                            DeviceSettingPicker(title: setting.title, choices: .init(selected: selected, options: options, available: setting.writable)) {
                                model.send(.generalList(setting.id, $0))
                            }
                        }
                        if !setting.summary.isEmpty { DeviceSettingNote(setting.summary) }
                    }
                }
            }
        }
    }
}

private struct DeviceSettingPicker: View {
    let title: String
    let choices: DeviceSettingChoices
    let select: (UInt32) -> Void

    var body: some View {
        Picker(title, selection: Binding(get: { choices.selected }, set: { id in
            guard choices.canSelect(id) else { return }
            select(id)
        })) {
            if !choices.options.contains(where: { $0.id == choices.selected }) {
                Text("Not reported").tag(choices.selected).disabled(true)
            }
            ForEach(choices.options) { option in
                Text(option.title).tag(option.id).disabled(!option.available)
            }
        }
        .pickerStyle(.menu)
        .disabled(!choices.canChange)
    }
}

private struct DeviceSettingNote: View {
    let text: String
    @Environment(\.sonico) private var colors

    init(_ text: String) { self.text = text }

    var body: some View {
        Text(text).font(.caption).foregroundStyle(colors.secondary).fixedSize(horizontal: false, vertical: true)
    }
}
