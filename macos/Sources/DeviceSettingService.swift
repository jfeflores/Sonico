import XMConnectBridge

/// All calls are synchronous cache reads or staged writes on HeadphoneService's session queue.
/// libmdr still owns validation at commit time and protocol negotiation for both MDR families.
enum DeviceSettingService {
    private typealias Catalog = DeviceSettingCatalog
    private static let unsupported = UInt32(MDR_RESULT_ERROR_NOT_SUPPORTED)
    private static let invalidArgument = UInt32(MDR_RESULT_ERROR_INVALID_ARGUMENT)

    static func read(_ h: OpaquePointer) -> AdvancedDeviceSettings {
        var settings = AdvancedDeviceSettings()
        let hasAmbient = supports(MDR_FEATURE_AMBIENT_SOUND, on: h)
        let hasNoiseButton = supports(MDR_FEATURE_NOISE_CONTROL_BUTTON, on: h)
        var noise = MDRNoiseControl()
        if (hasAmbient || hasNoiseButton), mdrHeadphonesGetNoiseControl(h, MDR_PROPERTY_CURRENT, &noise) == MDR_RESULT_OK {
            if hasAmbient {
                settings.focusOnVoice = noise.focus_on_voice != MDR_FALSE
                if supports(MDR_FEATURE_ADAPTIVE_AMBIENT_SOUND, on: h) {
                    settings.adaptiveAmbient = noise.adaptive_ambient != MDR_FALSE
                    settings.adaptiveSensitivity = Catalog.discoveredChoice(noise.adaptive_sensitivity,
                        in: Catalog.adaptiveSensitivity, available: noise.adaptive_ambient != MDR_FALSE)
                }
            }
            if hasNoiseButton {
                settings.noiseButton = Catalog.discoveredChoice(noise.button_mode, in: noiseButtonOptions(on: h))
            }
        }
        var speech = MDRSpeakToChat()
        if supports(MDR_FEATURE_SPEAK_TO_CHAT, on: h),
           mdrHeadphonesGetSpeakToChat(h, MDR_PROPERTY_CURRENT, &speech) == MDR_RESULT_OK {
            settings.speechSensitivity = Catalog.discoveredChoice(speech.sensitivity, in: Catalog.speechSensitivity,
                                                                  available: speech.enabled != MDR_FALSE)
            settings.speechTimeout = Catalog.discoveredChoice(speech.timeout, in: Catalog.speechTimeout,
                                                              available: speech.enabled != MDR_FALSE)
        }

        var listening = MDRListening()
        if supports(MDR_FEATURE_LISTENING_MODE, on: h),
           mdrHeadphonesGetListening(h, MDR_PROPERTY_CURRENT, &listening) == MDR_RESULT_OK {
            for mode in Catalog.listeningModes {
                guard let status = listeningStatus(mode.id, on: h) else { continue }
                if status.available == MDR_FALSE {
                    settings.listeningNotices[mode.id] = Catalog.listeningNotice(blockers: status.blockers)
                }
                if mode.id == MDR_LISTENING_BACKGROUND_MUSIC {
                    if let blocker = backgroundMusicVoiceBlocker(on: h) {
                        settings.listeningNotices[mode.id] = blocker
                    } else if status.available != MDR_FALSE && !Catalog.backgroundRooms.contains(where: { $0.id == listening.background_room }) {
                        settings.listeningNotices[mode.id] = "The headphones haven't reported a Background Music distance."
                    }
                }
            }
            if listening.mode == MDR_LISTENING_BACKGROUND_MUSIC {
                settings.backgroundRoom = Catalog.discoveredChoice(listening.background_room, in: Catalog.backgroundRooms,
                    available: settings.listeningNotices[MDR_LISTENING_BACKGROUND_MUSIC] == nil)
            }
        }
        let backgroundMusicActive = listening.mode == MDR_LISTENING_BACKGROUND_MUSIC
        var voice = MDRVoiceAssistantSettings()
        if supports(MDR_FEATURE_VOICE_ASSISTANT, on: h),
           mdrHeadphonesGetVoiceAssistant(h, MDR_PROPERTY_CURRENT, &voice) == MDR_RESULT_OK {
            settings.voiceAssistant = assistantChoices(voice, backgroundMusicActive: backgroundMusicActive, on: h)
            if voice.available == MDR_FALSE {
                settings.voiceAssistantNotice = backgroundMusicActive
                    ? "Switch off Background Music to change the voice assistant."
                    : "The voice assistant can't be changed right now."
            } else if settings.voiceAssistant?.options.contains(where: { !$0.available && $0.id != voice.assistant }) == true {
                settings.voiceAssistantNotice = backgroundMusicActive
                    ? "Switch off Background Music to use Voice Control."
                    : "Some assistants aren't available in the current listening mode."
            }
        }

        let hasAutoPower = supports(MDR_FEATURE_AUTO_POWER_OFF, on: h)
        let hasGestures = supports(MDR_FEATURE_HEAD_GESTURE, on: h)
        var power = MDRPower()
        if (hasAutoPower || hasGestures), mdrHeadphonesGetPower(h, MDR_PROPERTY_CURRENT, &power) == MDR_RESULT_OK {
            if hasAutoPower { settings.autoPowerOff = powerChoices(power, on: h) }
            if hasGestures { settings.headGestures = power.head_gesture != MDR_FALSE }
        }
        var prompts = MDRVoiceGuidance()
        if supports(MDR_FEATURE_VOICE_GUIDANCE, on: h),
           mdrHeadphonesGetVoiceGuidance(h, MDR_PROPERTY_CURRENT, &prompts) == MDR_RESULT_OK {
            let range = voiceVolumeRange(on: h)
            let volume = Int(prompts.volume)
            settings.voiceGuidance = .init(enabled: prompts.enabled != MDR_FALSE, volume: volume,
                                           volumeRange: range.flatMap { validVolume(volume, in: $0) ? $0 : nil })
        }
        settings.assignableControls = assignmentSettings(on: h)
        return settings
    }

    static func stage(_ change: AdvancedDeviceSettingChange, on h: OpaquePointer) -> UInt32 {
        switch change {
        case .focusOnVoice(let enabled):
            return updateNoise(on: h) { noise in
                guard supports(MDR_FEATURE_AMBIENT_SOUND, on: h), noise.mode == MDR_NOISE_MODE_AMBIENT else { return false }
                noise.focus_on_voice = mdrBool(enabled)
                return true
            }
        case .adaptiveAmbient(let enabled):
            return updateNoise(on: h) { noise in
                guard supports(MDR_FEATURE_ADAPTIVE_AMBIENT_SOUND, on: h), noise.mode == MDR_NOISE_MODE_AMBIENT else { return false }
                noise.adaptive_ambient = mdrBool(enabled)
                return true
            }
        case .adaptiveSensitivity(let id):
            return updateNoise(on: h) { noise in
                guard supports(MDR_FEATURE_ADAPTIVE_AMBIENT_SOUND, on: h), noise.mode == MDR_NOISE_MODE_AMBIENT,
                      noise.adaptive_ambient != MDR_FALSE,
                      Catalog.discoveredChoice(noise.adaptive_sensitivity, in: Catalog.adaptiveSensitivity)?.canSelect(id) == true
                else { return false }
                noise.adaptive_sensitivity = id
                return true
            }
        case .noiseButton(let id):
            return updateNoise(on: h) { noise in
                guard supports(MDR_FEATURE_NOISE_CONTROL_BUTTON, on: h),
                      Catalog.discoveredChoice(noise.button_mode, in: noiseButtonOptions(on: h))?.canSelect(id) == true
                else { return false }
                noise.button_mode = id
                return true
            }
        case .speechSensitivity(let id), .speechTimeout(let id):
            var speech = MDRSpeakToChat()
            guard supports(MDR_FEATURE_SPEAK_TO_CHAT, on: h) else { return unsupported }
            let result = mdrHeadphonesGetSpeakToChat(h, MDR_PROPERTY_DESIRED, &speech)
            guard result == MDR_RESULT_OK else { return result }
            guard speech.enabled != MDR_FALSE else { return unsupported }
            if case .speechSensitivity = change {
                guard Catalog.discoveredChoice(speech.sensitivity, in: Catalog.speechSensitivity)?.canSelect(id) == true
                else { return invalidArgument }
                speech.sensitivity = id
            } else {
                guard Catalog.discoveredChoice(speech.timeout, in: Catalog.speechTimeout)?.canSelect(id) == true
                else { return invalidArgument }
                speech.timeout = id
            }
            return mdrHeadphonesSetSpeakToChat(h, &speech)
        case .backgroundRoom(let id):
            var listening = MDRListening()
            let result = mdrHeadphonesGetListening(h, MDR_PROPERTY_DESIRED, &listening)
            guard result == MDR_RESULT_OK else { return result }
            guard listening.mode == MDR_LISTENING_BACKGROUND_MUSIC,
                  Catalog.discoveredChoice(listening.background_room, in: Catalog.backgroundRooms)?.canSelect(id) == true,
                  listeningStatus(listening.mode, on: h)?.available == MDR_TRUE,
                  backgroundMusicVoiceBlocker(on: h) == nil else { return unsupported }
            listening.background_room = id
            return mdrHeadphonesSetListening(h, &listening)
        case .autoPowerOff(let id):
            return updatePower(on: h, feature: MDR_FEATURE_AUTO_POWER_OFF) { power in
                guard powerChoices(power, on: h)?.canSelect(id) == true else { return false }
                if id == Catalog.whenRemoved {
                    power.wearing_power = MDR_WEARING_POWER_WHEN_REMOVED
                } else {
                    power.auto_power_off_minutes = id
                    if power.wearing_power != MDR_WEARING_POWER_UNAVAILABLE {
                        power.wearing_power = MDR_WEARING_POWER_DISABLED
                    }
                }
                return true
            }
        case .headGestures(let enabled):
            return updatePower(on: h, feature: MDR_FEATURE_HEAD_GESTURE) { power in
                power.head_gesture = mdrBool(enabled)
                return true
            }
        case .voiceGuidance(let enabled):
            return updateVoiceGuidance(on: h) { guidance in
                guidance.enabled = mdrBool(enabled)
                return true
            }
        case .voiceGuidanceVolume(let volume):
            return updateVoiceGuidance(on: h) { guidance in
                guard let range = voiceVolumeRange(on: h), validVolume(volume, in: range), let value = Int32(exactly: volume)
                else { return false }
                guidance.volume = value
                return true
            }
        case .voiceAssistant(let id):
            var voice = MDRVoiceAssistantSettings()
            guard supports(MDR_FEATURE_VOICE_ASSISTANT, on: h) else { return unsupported }
            let result = mdrHeadphonesGetVoiceAssistant(h, MDR_PROPERTY_DESIRED, &voice)
            guard result == MDR_RESULT_OK else { return result }
            let backgroundMusicActive = [MDR_PROPERTY_CURRENT, MDR_PROPERTY_DESIRED].contains { type in
                var listening = MDRListening()
                return mdrHeadphonesGetListening(h, type, &listening) != MDR_RESULT_OK || listening.mode == MDR_LISTENING_BACKGROUND_MUSIC
            }
            guard assistantChoices(voice, backgroundMusicActive: backgroundMusicActive, on: h)?.canSelect(id) == true
            else { return unsupported }
            return mdrHeadphonesSetVoiceAssistant(h, id)
        case .assignableControl(let location, let action):
            return stageAssignment(location: location, action: action, on: h)
        }
    }

    static func stageListening(_ id: UInt32, on h: OpaquePointer) -> UInt32 {
        var listening = MDRListening()
        let result = mdrHeadphonesGetListening(h, MDR_PROPERTY_DESIRED, &listening)
        guard result == MDR_RESULT_OK else { return result }
        guard listeningStatus(id, on: h)?.available == MDR_TRUE else { return unsupported }
        if id == MDR_LISTENING_BACKGROUND_MUSIC {
            guard backgroundMusicVoiceBlocker(on: h) == nil, Catalog.backgroundRooms.contains(where: { $0.id == listening.background_room })
            else { return unsupported }
        }
        listening.mode = id
        return mdrHeadphonesSetListening(h, &listening)
    }

    private static func listeningStatus(_ id: UInt32, on h: OpaquePointer) -> MDRListeningStatus? {
        var status = MDRListeningStatus()
        return mdrHeadphonesGetListeningStatus(h, id, &status) == MDR_RESULT_OK ? status : nil
    }

    private static func backgroundMusicVoiceBlocker(on h: OpaquePointer) -> String? {
        guard supports(MDR_FEATURE_VOICE_ASSISTANT, on: h) else { return nil }
        var current = MDRVoiceAssistantSettings(), desired = MDRVoiceAssistantSettings()
        guard mdrHeadphonesGetVoiceAssistant(h, MDR_PROPERTY_CURRENT, &current) == MDR_RESULT_OK,
              mdrHeadphonesGetVoiceAssistant(h, MDR_PROPERTY_DESIRED, &desired) == MDR_RESULT_OK,
              current.assistant != MDR_VOICE_ASSISTANT_UNKNOWN, desired.assistant != MDR_VOICE_ASSISTANT_UNKNOWN else {
            return "The headphones haven't reported their voice assistant setting."
        }
        return Catalog.permitsBackgroundMusic(current: current.assistant, desired: desired.assistant)
            ? nil : "Turn off Voice Control before using Background Music."
    }

    private static func assistantChoices(_ voice: MDRVoiceAssistantSettings, backgroundMusicActive: Bool,
                                         on h: OpaquePointer) -> DeviceSettingChoices? {
        let options = readArray(of: MDRVoiceAssistantOption()) { mdrHeadphonesGetVoiceAssistantOptions(h, $0, $1) }
        guard !options.isEmpty else { return nil }
        return Catalog.voiceAssistantChoices(selected: voice.assistant, available: voice.available != MDR_FALSE,
            backgroundMusicActive: backgroundMusicActive, reported: options.map { ($0.assistant, $0.available != MDR_FALSE) })
    }

    private static func noiseButtonOptions(on h: OpaquePointer) -> [DeviceSettingChoice] {
        let noise = supports(MDR_FEATURE_NOISE_CANCELLING, on: h)
        let ambient = supports(MDR_FEATURE_AMBIENT_SOUND, on: h)
        return Catalog.noiseButton.filter { option in
            switch option.id {
            case MDR_NOISE_BUTTON_NOISE_AMBIENT_OFF, MDR_NOISE_BUTTON_NOISE_AMBIENT: noise && ambient
            case MDR_NOISE_BUTTON_NOISE_OFF: noise
            case MDR_NOISE_BUTTON_AMBIENT_OFF: ambient
            default: true
            }
        }
    }

    private static func powerChoices(_ power: MDRPower, on h: OpaquePointer) -> DeviceSettingChoices? {
        guard let count = value(MDR_VALUE_AUTO_POWER_OFF_OPTION_COUNT, on: h), (0...32).contains(count) else { return nil }
        let minutes = (0..<UInt32(count)).compactMap { index in
            value(MDR_VALUE_AUTO_POWER_OFF_OPTION, index: index, on: h).flatMap(UInt32.init(exactly:))
        }
        return Catalog.powerChoices(minutes: minutes, selectedMinutes: power.auto_power_off_minutes, wearing: power.wearing_power)
    }

    private static func voiceVolumeRange(on h: OpaquePointer) -> DeviceRange? {
        guard supports(MDR_FEATURE_VOICE_GUIDANCE_VOLUME, on: h),
              let lower = value(MDR_VALUE_VOICE_GUIDANCE_VOLUME_MIN, on: h),
              let upper = value(MDR_VALUE_VOICE_GUIDANCE_VOLUME_MAX, on: h),
              let step = value(MDR_VALUE_VOICE_GUIDANCE_VOLUME_STEP, on: h),
              lower < upper, step > 0, step <= upper - lower else { return nil }
        return DeviceRange(lower: lower, upper: upper, step: step)
    }

    private static func validVolume(_ volume: Int, in range: DeviceRange) -> Bool {
        (range.lower...range.upper).contains(volume) && (volume - range.lower) % range.step == 0
    }

    private static func assignmentSettings(on h: OpaquePointer) -> [AssignableDeviceSetting] {
        let controls = assignableControls(MDR_PROPERTY_CURRENT, on: h)
        guard validLocations(controls) else { return [] }
        return controls.compactMap { control in
            guard let title = Catalog.assignableLocation(control.location, type: control.type),
                  let choices = assignmentChoices(control, on: h) else { return nil }
            return .init(id: control.location, title: title, choices: choices)
        }
    }

    private static func assignableControls(_ type: UInt32, on h: OpaquePointer) -> [MDRAssignableControl] {
        guard supports(MDR_FEATURE_ASSIGNABLE_CONTROLS, on: h) else { return [] }
        return readArray(of: MDRAssignableControl()) { mdrHeadphonesGetAssignableControls(h, type, $0, $1) }
    }

    private static func validLocations(_ controls: [MDRAssignableControl]) -> Bool {
        Set(controls.map(\.location)).count == controls.count && controls.allSatisfy {
            $0.location != MDR_ASSIGNABLE_ACTION_KEY_UNKNOWN && $0.type != MDR_ASSIGNABLE_ACTION_KEY_TYPE_UNKNOWN &&
            $0.action != MDR_ASSIGNABLE_UNKNOWN
        }
    }

    private static func assignmentChoices(_ control: MDRAssignableControl, on h: OpaquePointer) -> DeviceSettingChoices? {
        let actions = readArray(of: UInt32(0)) { mdrHeadphonesGetAssignableControlActions(h, control.location, $0, $1) }
        return Catalog.assignableChoices(selected: control.action, reported: actions)
    }

    private static func stageAssignment(location: UInt32, action: UInt32, on h: OpaquePointer) -> UInt32 {
        var controls = assignableControls(MDR_PROPERTY_DESIRED, on: h)
        guard validLocations(controls), let index = controls.firstIndex(where: { $0.location == location }),
              Catalog.assignableLocation(location, type: controls[index].type) != nil,
              assignmentChoices(controls[index], on: h)?.canSelect(action) == true else { return unsupported }
        // The C ABI takes the complete array, so preserve other keys and other staged edits.
        controls[index].action = action
        return controls.withUnsafeBufferPointer { mdrHeadphonesSetAssignableControls(h, $0.baseAddress, UInt32($0.count)) }
    }

    private static func updateNoise(on h: OpaquePointer, _ edit: (inout MDRNoiseControl) -> Bool) -> UInt32 {
        var noise = MDRNoiseControl()
        let result = mdrHeadphonesGetNoiseControl(h, MDR_PROPERTY_DESIRED, &noise)
        guard result == MDR_RESULT_OK else { return result }
        guard edit(&noise) else { return unsupported }
        return mdrHeadphonesSetNoiseControl(h, &noise)
    }

    private static func updatePower(on h: OpaquePointer, feature: UInt32, _ edit: (inout MDRPower) -> Bool) -> UInt32 {
        guard supports(feature, on: h) else { return unsupported }
        var power = MDRPower()
        let result = mdrHeadphonesGetPower(h, MDR_PROPERTY_DESIRED, &power)
        guard result == MDR_RESULT_OK else { return result }
        guard edit(&power) else { return unsupported }
        return mdrHeadphonesSetPower(h, &power)
    }

    private static func updateVoiceGuidance(on h: OpaquePointer, _ edit: (inout MDRVoiceGuidance) -> Bool) -> UInt32 {
        guard supports(MDR_FEATURE_VOICE_GUIDANCE, on: h) else { return unsupported }
        var guidance = MDRVoiceGuidance()
        let result = mdrHeadphonesGetVoiceGuidance(h, MDR_PROPERTY_DESIRED, &guidance)
        guard result == MDR_RESULT_OK else { return result }
        guard edit(&guidance) else { return invalidArgument }
        return mdrHeadphonesSetVoiceGuidance(h, &guidance)
    }

    private static func mdrBool(_ value: Bool) -> UInt32 { value ? MDR_TRUE : MDR_FALSE }

    private static func supports(_ feature: UInt32, on h: OpaquePointer) -> Bool {
        var available = MDR_AVAILABILITY_UNKNOWN
        return mdrHeadphonesGetFeature(h, feature, &available) == MDR_RESULT_OK && available == MDR_AVAILABILITY_AVAILABLE
    }

    private static func value(_ key: UInt32, index: UInt32 = 0, on h: OpaquePointer) -> Int? {
        var value: Int32 = 0
        return mdrHeadphonesGetValue(h, key, index, &value) == MDR_RESULT_OK ? Int(value) : nil
    }

    private static func readArray<T>(of element: T, _ read: (UnsafeMutablePointer<T>?, UnsafeMutablePointer<UInt32>) -> UInt32) -> [T] {
        var count: UInt32 = 0
        guard read(nil, &count) == MDR_RESULT_OK, (1...128).contains(count) else { return [] }
        let capacity = count
        var values = Array(repeating: element, count: Int(count))
        let result = values.withUnsafeMutableBufferPointer { read($0.baseAddress, &count) }
        guard result == MDR_RESULT_OK, count <= capacity else { return [] }
        return Array(values.prefix(Int(count)))
    }
}
