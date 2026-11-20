import XMConnectBridge

/// A choice uses the reported protocol ID, not its position in the UI.
struct DeviceSettingChoice: Identifiable, Equatable, Sendable {
    let id: UInt32
    let title: String
    var available = true
}

struct DeviceSettingChoices: Equatable, Sendable {
    var selected: UInt32
    let options: [DeviceSettingChoice]
    var available = true

    func canSelect(_ id: UInt32) -> Bool {
        available && id != selected && options.contains { $0.id == id && $0.available }
    }

    var canChange: Bool { options.contains { canSelect($0.id) } }
}

struct AssignableDeviceSetting: Identifiable, Equatable, Sendable {
    let id: UInt32
    let title: String
    let choices: DeviceSettingChoices
}

struct VoiceGuidanceSettings: Equatable, Sendable {
    var enabled: Bool
    var volume: Int
    let volumeRange: DeviceRange?
}

struct AdvancedDeviceSettings: Equatable, Sendable {
    var focusOnVoice: Bool?
    var adaptiveAmbient: Bool?
    var adaptiveSensitivity: DeviceSettingChoices?
    var speechSensitivity: DeviceSettingChoices?
    var speechTimeout: DeviceSettingChoices?
    var listeningNotices: [UInt32: String] = [:]
    var backgroundRoom: DeviceSettingChoices?
    var noiseButton: DeviceSettingChoices?
    var autoPowerOff: DeviceSettingChoices?
    var headGestures: Bool?
    var voiceGuidance: VoiceGuidanceSettings?
    var voiceAssistant: DeviceSettingChoices?
    var voiceAssistantNotice: String?
    var assignableControls: [AssignableDeviceSetting] = []
}

enum AdvancedDeviceSettingChange: Sendable {
    case focusOnVoice(Bool), adaptiveAmbient(Bool), adaptiveSensitivity(UInt32)
    case speechSensitivity(UInt32), speechTimeout(UInt32), backgroundRoom(UInt32)
    case noiseButton(UInt32), autoPowerOff(UInt32), headGestures(Bool)
    case voiceGuidance(Bool), voiceGuidanceVolume(Int), voiceAssistant(UInt32)
    case assignableControl(location: UInt32, action: UInt32)
}

/// Known names also act as allowlists. Do not turn unknown C enum values into writeable options.
enum DeviceSettingCatalog {
    static let adaptiveSensitivity: [DeviceSettingChoice] = [
        .init(id: MDR_ADAPTIVE_SENSITIVITY_STANDARD, title: "Standard"),
        .init(id: MDR_ADAPTIVE_SENSITIVITY_HIGH, title: "High"),
        .init(id: MDR_ADAPTIVE_SENSITIVITY_LOW, title: "Low")
    ]
    static let speechSensitivity: [DeviceSettingChoice] = [
        .init(id: MDR_SPEECH_SENSITIVITY_AUTO, title: "Automatic"),
        .init(id: MDR_SPEECH_SENSITIVITY_HIGH, title: "High"),
        .init(id: MDR_SPEECH_SENSITIVITY_LOW, title: "Low")
    ]
    static let speechTimeout: [DeviceSettingChoice] = [
        .init(id: MDR_SPEAK_TIMEOUT_SHORT, title: "Short (about 5 sec)"),
        .init(id: MDR_SPEAK_TIMEOUT_MEDIUM, title: "Standard (about 15 sec)"),
        .init(id: MDR_SPEAK_TIMEOUT_LONG, title: "Long (about 30 sec)"),
        .init(id: MDR_SPEAK_TIMEOUT_MANUAL, title: "Don't end automatically")
    ]
    static let backgroundRooms: [DeviceSettingChoice] = [
        .init(id: MDR_ROOM_SMALL, title: "My Room"),
        .init(id: MDR_ROOM_MEDIUM, title: "Living Room"),
        .init(id: MDR_ROOM_LARGE, title: "Café")
    ]
    static let noiseButton: [DeviceSettingChoice] = [
        .init(id: MDR_NOISE_BUTTON_NONE, title: "None"),
        .init(id: MDR_NOISE_BUTTON_NOISE_AMBIENT_OFF, title: "Noise Canceling, Ambient Sound, Off"),
        .init(id: MDR_NOISE_BUTTON_NOISE_AMBIENT, title: "Noise Canceling, Ambient Sound"),
        .init(id: MDR_NOISE_BUTTON_NOISE_OFF, title: "Noise Canceling, Off"),
        .init(id: MDR_NOISE_BUTTON_AMBIENT_OFF, title: "Ambient Sound, Off")
    ]
    static let listeningModes: [(id: UInt32, title: String)] = [
        (MDR_LISTENING_STANDARD, "Standard"), (MDR_LISTENING_BACKGROUND_MUSIC, "Background Music"),
        (MDR_LISTENING_CINEMA, "Cinema"), (MDR_LISTENING_VOICE_BOOST, "Voice Boost"),
        (MDR_LISTENING_SOUND_LEAKAGE_REDUCTION, "Sound Leakage Reduction")
    ]
    static let priorities: [DeviceSettingChoice] = [
        .init(id: MDR_AUDIO_PRIORITY_QUALITY, title: "Sound quality"),
        .init(id: MDR_AUDIO_PRIORITY_STABILITY, title: "Stable connection")
    ]
    static let whenRemoved = UInt32.max

    static func powerChoices(minutes: [UInt32], selectedMinutes: UInt32, wearing: UInt32) -> DeviceSettingChoices? {
        let names: [UInt32: String] = [0: "Do not turn off", 5: "After 5 minutes", 15: "After 15 minutes",
                                        30: "After 30 minutes", 60: "After 1 hour", 180: "After 3 hours"]
        var seen = Set<UInt32>()
        var options = minutes.compactMap { id in
            names[id].flatMap { seen.insert(id).inserted ? DeviceSettingChoice(id: id, title: $0) : nil }
        }
        if wearing == MDR_WEARING_POWER_WHEN_REMOVED || wearing == MDR_WEARING_POWER_DISABLED {
            options.append(.init(id: whenRemoved, title: "When removed"))
        }
        guard !options.isEmpty else { return nil }
        let selected = wearing == MDR_WEARING_POWER_WHEN_REMOVED ? whenRemoved : selectedMinutes
        return .init(selected: selected, options: options)
    }

    static func listeningNotice(blockers: UInt32) -> String {
        var reasons: [String] = []
        // Headphones.h defines these MDRListeningBlocker bit positions; Clang doesn't import the shift macros.
        if blockers & (1 << 0) != 0 { reasons.append("Unavailable during a call.") }
        if blockers & (1 << 1) != 0 { reasons.append("Unavailable with LE Audio.") }
        if blockers & (1 << 2) != 0 { reasons.append("Unavailable with the current voice assistant.") }
        if blockers & (1 << 3) != 0 { reasons.append("Unavailable with the current listening mode.") }
        if reasons.isEmpty || blockers & (1 << 4) != 0 {
            reasons.append("The headphones report this mode as unavailable.")
        }
        return reasons.joined(separator: " ")
    }

    static func voiceAssistantChoices(selected: UInt32, available: Bool, backgroundMusicActive: Bool,
                                      reported: [(id: UInt32, available: Bool)]) -> DeviceSettingChoices? {
        let names: [UInt32: String] = [
            MDR_VOICE_ASSISTANT_NONE: "Off", MDR_VOICE_ASSISTANT_VOICE_RECOGNITION: "Device voice assistant",
            MDR_VOICE_ASSISTANT_GOOGLE_ASSISTANT: "Google Assistant", MDR_VOICE_ASSISTANT_AMAZON_ALEXA: "Amazon Alexa",
            MDR_VOICE_ASSISTANT_TENCENT_XIAOWEI: "Tencent Xiaowei", MDR_VOICE_ASSISTANT_SONY_VOICE_CONTROL: "Voice Control",
            MDR_VOICE_ASSISTANT_OTHER_DEVICE: "In use on another device"
        ]
        var seen = Set<UInt32>()
        var options = reported.compactMap { option -> DeviceSettingChoice? in
            // As in the SDL client: display a configured Google Assistant, but don't offer it for activation.
            guard option.id != MDR_VOICE_ASSISTANT_GOOGLE_ASSISTANT || selected == option.id,
                  option.id != MDR_VOICE_ASSISTANT_OTHER_DEVICE,
                  let title = names[option.id], seen.insert(option.id).inserted else { return nil }
            let conflicts = option.id == MDR_VOICE_ASSISTANT_SONY_VOICE_CONTROL && backgroundMusicActive
            return .init(id: option.id, title: title, available: option.available && !conflicts)
        }
        if selected == MDR_VOICE_ASSISTANT_OTHER_DEVICE {
            options.append(.init(id: selected, title: "In use on another device", available: false))
        }
        return options.isEmpty ? nil : .init(selected: selected, options: options, available: available)
    }

    static func permitsBackgroundMusic(current: UInt32, desired: UInt32) -> Bool {
        // Wait for confirmation when leaving Voice Control; reject a pending activation too.
        current != MDR_VOICE_ASSISTANT_SONY_VOICE_CONTROL && desired != MDR_VOICE_ASSISTANT_SONY_VOICE_CONTROL
    }

    static func assignableLocation(_ location: UInt32, type: UInt32) -> String? {
        switch location {
        case MDR_ASSIGNABLE_ACTION_KEY_CUSTOM: return "Custom button"
        case MDR_ASSIGNABLE_ACTION_KEY_C: return "C button"
        case MDR_ASSIGNABLE_ACTION_KEY_NC_AMB, MDR_ASSIGNABLE_ACTION_KEY_NC_AMBIENT: return "Noise control button"
        case MDR_ASSIGNABLE_ACTION_KEY_LEFT, MDR_ASSIGNABLE_ACTION_KEY_RIGHT:
            let side = location == MDR_ASSIGNABLE_ACTION_KEY_LEFT ? "Left" : "Right"
            switch type {
            case MDR_ASSIGNABLE_ACTION_KEY_TYPE_TOUCH_SENSOR: return "\(side) touch sensor"
            case MDR_ASSIGNABLE_ACTION_KEY_TYPE_BUTTON: return "\(side) button"
            case MDR_ASSIGNABLE_ACTION_KEY_TYPE_FACE_TAP: return "\(side) tap control"
            default: return nil
            }
        default: return nil
        }
    }

    static func assignableChoices(selected: UInt32, reported: [UInt32]) -> DeviceSettingChoices? {
        let names: [UInt32: String] = [
            MDR_ASSIGNABLE_NONE: "None", MDR_ASSIGNABLE_PLAYBACK: "Playback", MDR_ASSIGNABLE_NOISE_CONTROL: "Noise control",
            MDR_ASSIGNABLE_NOISE_CONTROL_QUICK_ACCESS: "Noise control / Quick Access", MDR_ASSIGNABLE_TRACK_CONTROL: "Track control",
            MDR_ASSIGNABLE_VOICE_RECOGNITION: "Device voice assistant", MDR_ASSIGNABLE_GOOGLE_ASSISTANT: "Google Assistant",
            MDR_ASSIGNABLE_AMAZON_ALEXA: "Amazon Alexa", MDR_ASSIGNABLE_TENCENT_XIAOWEI: "Tencent Xiaowei",
            MDR_ASSIGNABLE_QUICK_ACCESS: "Quick Access", MDR_ASSIGNABLE_VOLUME: "Volume",
            MDR_ASSIGNABLE_PLAYBACK_VOICE_ASSISTANT_LIMITATION: "Playback (voice assistant limitation)",
            MDR_ASSIGNABLE_TEAMS: "Microsoft Teams", MDR_ASSIGNABLE_GOOGLE_ASSISTANT_BT_CLASSIC_CAUTION: "Google Assistant",
            MDR_ASSIGNABLE_NOISE_CONTROL_MIC: "Noise control / Microphone",
            MDR_ASSIGNABLE_LISTENING_MODE_QUICK_ACCESS: "Listening mode / Quick Access",
            MDR_ASSIGNABLE_NOISE_CONTROL_LISTENING_MODE: "Noise control / Listening mode",
            MDR_ASSIGNABLE_CHAT_MIX: "Chat mix", MDR_ASSIGNABLE_CUSTOM1: "Custom 1", MDR_ASSIGNABLE_CUSTOM2: "Custom 2"
        ]
        var seen = Set<UInt32>()
        let options = reported.compactMap { id -> DeviceSettingChoice? in
            let google = id == MDR_ASSIGNABLE_GOOGLE_ASSISTANT || id == MDR_ASSIGNABLE_GOOGLE_ASSISTANT_BT_CLASSIC_CAUTION
            guard let title = names[id], (!google || selected == id), seen.insert(id).inserted else { return nil }
            return .init(id: id, title: title, available: !google)
        }
        return options.isEmpty ? nil : .init(selected: selected, options: options)
    }

    static func discoveredChoice(_ selected: UInt32, in documentedOptions: [DeviceSettingChoice],
                                 available: Bool = true) -> DeviceSettingChoices? {
        guard documentedOptions.contains(where: { $0.id == selected }) else { return nil }
        return .init(selected: selected, options: documentedOptions, available: available)
    }
}
