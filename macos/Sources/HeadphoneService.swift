import Foundation
import XMConnectBridge

/// All handles, C calls, and timer state belong exclusively to `queue`.
/// IOBluetooth callbacks remain on the main run loop inside the existing transport.
final class HeadphoneService: @unchecked Sendable {
    private let queue = DispatchQueue(label: "app.xmconnect.session", qos: .userInitiated)
    private let deliver: @MainActor @Sendable (HeadphoneSnapshot) -> Void
    private var transport: OpaquePointer?
    private var headphones: OpaquePointer?
    private var timer: DispatchSourceTimer?
    private var state = HeadphoneSnapshot()
    private var lastPublished = HeadphoneSnapshot()
    private let clock = ContinuousClock()
    private var deadline: ContinuousClock.Instant?
    private var pendingSync: UInt32 = 0
    private var discovering = false
    private var protocolVersion: UInt32 = MDR_PROTOCOL_V2
    private var batteryReported = false
    private var writeBatch = WriteBatch()

    init(deliver: @escaping @MainActor @Sendable (HeadphoneSnapshot) -> Void) {
        self.deliver = deliver
    }

    func send(_ command: HeadphoneCommand) {
        queue.async { [self] in execute(command) }
    }

    func stop() {
        queue.sync { close(); stopTimer() }
    }

    private var connection: UnsafeMutablePointer<MDRConnection>? {
        transport.map { mdrConnectionMacOSGet($0) } ?? nil
    }

    private func ensureTransport() {
        if transport == nil { transport = mdrConnectionMacOSCreate() }
    }

    private func startTimer() {
        guard timer == nil else { return }
        let source = DispatchSource.makeTimerSource(queue: queue)
        source.schedule(deadline: .now(), repeating: .milliseconds(25), leeway: .milliseconds(5))
        source.setEventHandler { [weak self] in self?.tick() }
        source.resume()
        timer = source
    }

    private func stopTimer() {
        timer?.setEventHandler {}
        timer?.cancel()
        timer = nil
    }

    private func publish() {
        guard state != lastPublished else { return }
        lastPublished = state
        let snapshot = state
        DispatchQueue.main.async { [deliver] in deliver(snapshot) }
    }

    private func close() {
        if let headphones { mdrHeadphonesDestroy(headphones) }
        headphones = nil
        // The transport destructor already disconnects and invalidates its callbacks.
        if let transport { mdrConnectionMacOSDestroy(transport) }
        transport = nil
        pendingSync = 0
        discovering = false
        deadline = nil
        writeBatch = WriteBatch()
        batteryReported = false
    }

    private func fail(_ message: String) {
        let devices = state.devices
        close()
        stopTimer()
        state = HeadphoneSnapshot()
        state.devices = devices
        state.phase = .failed
        state.error = message
        publish()
    }

    private func errorText(_ code: UInt32) -> String {
        if let headphones {
            let text = text(MDR_TEXT_LAST_ERROR, on: headphones)
            if !text.isEmpty && text != "N/A" { return text }
        }
        if let connection, let value = mdrConnectionGetLastError(connection), value.pointee != 0 {
            return String(cString: value)
        }
        return String(cString: mdrResultString(code))
    }

    private func execute(_ command: HeadphoneCommand) {
        switch command {
        case .disconnect:
            let devices = state.devices
            close(); stopTimer()
            state = HeadphoneSnapshot(); state.devices = devices
            publish(); return
        case .discover:
            guard !state.phase.busy, headphones == nil else { return }
            ensureTransport()
            guard connection != nil else { fail("Could not create the Bluetooth transport."); return }
            state.error = nil; state.phase = .discovering
            discovering = true; deadline = clock.now.advanced(by: .seconds(10))
            startTimer(); publish(); return
        case .connect(let device):
            guard !state.phase.busy, headphones == nil, state.devices.contains(device), let model = device.model else { return }
            close(); ensureTransport()
            let devices = state.devices
            state = HeadphoneSnapshot(); state.devices = devices; state.name = device.name
            state.phase = .connecting
            guard let connection else { fail("Could not create the Bluetooth transport."); return }
            protocolVersion = model.usesLegacyProtocol ? MDR_PROTOCOL_V1 : MDR_PROTOCOL_V2
            let result = device.id.withCString { address in
                mdrConnectionConnect(connection, address, model.usesLegacyProtocol ? MDR_SERVICE_UUID_V1 : MDR_SERVICE_UUID_V2)
            }
            guard result == MDR_RESULT_OK || result == MDR_RESULT_INPROGRESS else {
                fail(errorText(result)); return
            }
            deadline = clock.now.advanced(by: .seconds(12))
            startTimer(); publish(); return
        default: break
        }
        guard let h = headphones, state.controllable else { return }
        state.error = nil
        var result: UInt32 = UInt32(MDR_RESULT_OK)
        switch command {
        case .sync:
            pendingSync |= xmDefaultSyncFlags()
            publish()
            return
        case .noise(let mode):
            var value = MDRNoiseControl()
            result = mdrHeadphonesGetNoiseControl(h, MDR_PROPERTY_DESIRED, &value)
            if result == MDR_RESULT_OK { value.mode = mode.rawValue; result = mdrHeadphonesSetNoiseControl(h, &value) }
        case .ambient(let level):
            var value = MDRNoiseControl()
            result = mdrHeadphonesGetNoiseControl(h, MDR_PROPERTY_DESIRED, &value)
            if result == MDR_RESULT_OK { value.ambient_level = UInt32(max(0, level)); result = mdrHeadphonesSetNoiseControl(h, &value) }
        case .preset(let id): result = mdrHeadphonesSetEqualizerPreset(h, id)
        case .bands(let bands):
            result = bands.withUnsafeBufferPointer { mdrHeadphonesSetEqualizerBands(h, $0.baseAddress, UInt32($0.count)) }
        case .clearBass(let value): result = mdrHeadphonesSetEqualizerClearBass(h, Int32(value))
        case .volume(let value): result = mdrHeadphonesSetPlaybackVolume(h, UInt32(max(0, value)))
        case .playback(let action):
            var value = MDRPlaybackCommand(action: action)
            result = mdrHeadphonesSendPlaybackCommand(h, &value)
        case .dsee(let enabled): result = mdrHeadphonesSetDSEE(h, enabled ? MDR_TRUE : MDR_FALSE)
        case .speakToChat(let enabled):
            var value = MDRSpeakToChat()
            result = mdrHeadphonesGetSpeakToChat(h, MDR_PROPERTY_DESIRED, &value)
            if result == MDR_RESULT_OK { value.enabled = enabled ? MDR_TRUE : MDR_FALSE; result = mdrHeadphonesSetSpeakToChat(h, &value) }
        case .autoPause(let enabled):
            var value = MDRPower()
            result = mdrHeadphonesGetPower(h, MDR_PROPERTY_DESIRED, &value)
            if result == MDR_RESULT_OK { value.auto_pause = enabled ? MDR_TRUE : MDR_FALSE; result = mdrHeadphonesSetPower(h, &value) }
        case .priority(let priority):
            var value = MDRConnectionMode(audio_priority: priority)
            result = mdrHeadphonesSetConnectionMode(h, &value)
        case .listening(let mode):
            var value = MDRListening()
            result = mdrHeadphonesGetListening(h, MDR_PROPERTY_DESIRED, &value)
            if result == MDR_RESULT_OK { value.mode = mode; result = mdrHeadphonesSetListening(h, &value) }
        case .generalBoolean(let index, let enabled):
            var value = MDRGeneralSetting(index: index, boolean_value: enabled ? MDR_TRUE : MDR_FALSE, list_value: 0)
            result = mdrHeadphonesSetGeneralSetting(h, &value)
        case .generalList(let index, let selection):
            var value = MDRGeneralSetting(index: index, boolean_value: MDR_FALSE, list_value: selection)
            result = mdrHeadphonesSetGeneralSetting(h, &value)
        case .answerAlert(let accepted):
            result = mdrHeadphonesSetAlertResponse(h, accepted ? MDR_ALERT_ACTION_POSITIVE : MDR_ALERT_ACTION_NEGATIVE)
            if result == MDR_RESULT_OK { state.deviceAlert = nil }
        case .shutdown:
            var value = MDRPower()
            result = mdrHeadphonesGetPower(h, MDR_PROPERTY_DESIRED, &value)
            if result == MDR_RESULT_OK { value.shutdown_requested = MDR_TRUE; result = mdrHeadphonesSetPower(h, &value) }
        default: return
        }
        if result != MDR_RESULT_OK {
            state.error = "The device could not accept that change: \(String(cString: mdrResultString(result)))."
        } else {
            // Batch slider edits without starving the device during a long drag.
            if case .answerAlert = command { writeBatch.stage(at: clock.now, immediate: true) }
            else { writeBatch.stage(at: clock.now) }
        }
        state.applying = mdrHeadphonesIsDirty(h) != MDR_FALSE
        publish()
    }

    private func tick() {
        guard let connection else { return }
        let timedOut = deadline.map { clock.now >= $0 } ?? false
        if discovering {
            var list: UnsafeMutablePointer<MDRDeviceInfo>?
            var count: Int32 = 0
            let result = mdrConnectionGetDevicesList(connection, &list, &count)
            if result == MDR_RESULT_OK {
                defer { _ = mdrConnectionFreeDevicesList(connection, &list) }
                state.devices = (0..<max(0, Int(count))).compactMap { index -> PairedHeadphone? in
                    guard let list else { return nil }
                    var value = list[index]
                    let name = withUnsafeBytes(of: &value.szDeviceName) { String(decoding: $0.prefix { $0 != 0 }, as: UTF8.self) }
                    let id = withUnsafeBytes(of: &value.szDeviceMacAddress) { String(decoding: $0.prefix { $0 != 0 }, as: UTF8.self) }
                    guard HeadphoneModelID(reportedName: name) != nil, !id.isEmpty else { return nil }
                    return PairedHeadphone(id: id, name: name)
                }.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
                discovering = false; deadline = nil; state.phase = .disconnected; stopTimer(); publish()
            } else if result != MDR_RESULT_INPROGRESS || timedOut {
                fail("Could not read paired headphones. Check Bluetooth permission and pair your WH-1000X headphones in System Settings.")
            }
            return
        }
        if state.phase == .connecting {
            let result = mdrConnectionPoll(connection, 0)
            if result == MDR_RESULT_OK {
                let created = mdrHeadphonesCreate(MDR_ABI_VERSION, connection, protocolVersion, &headphones)
                guard created == MDR_RESULT_OK, let headphones else { fail(errorText(created)); return }
                state.phase = .initializing
                deadline = clock.now.advanced(by: .seconds(90))
                let initResult = mdrHeadphonesRequestInit(headphones, xmDefaultInitFlags())
                guard initResult == MDR_RESULT_OK else { fail(errorText(initResult)); return }
                publish()
            } else if (result != MDR_RESULT_INPROGRESS && result != MDR_RESULT_ERROR_TIMEOUT) || timedOut {
                fail(timedOut ? "Connection timed out. Turn on the headphones and check Bluetooth permissions." : errorText(result))
            }
            return
        }
        guard let h = headphones else { return }
        if state.phase == .initializing && timedOut {
            fail("Reading device settings timed out. Disconnect the phone's control app, then try again.")
            return
        }
        var receivedEvent = false
        // Bounded work; no blocking poll and no busy-loop on transport write readiness.
        for _ in 0..<8 {
            var event: UInt32 = MDR_EVENT_NONE
            let result = mdrHeadphonesPoll(h, &event)
            guard result == MDR_RESULT_OK else { fail(errorText(result)); return }
            if event == MDR_EVENT_NONE { break }
            receivedEvent = true
            if event == MDR_EVENT_INITIALIZE_COMPLETE {
                state.phase = .ready; deadline = nil; pendingSync |= xmDefaultSyncFlags()
            }
            if event == MDR_EVENT_BATTERY_CHANGED { batteryReported = true }
            if event == MDR_EVENT_NEED_SYNC {
                var flags: UInt32 = 0
                if mdrHeadphonesGetSync(h, &flags) == MDR_RESULT_OK { pendingSync |= flags }
            }
            if event == MDR_EVENT_ALERT { state.deviceAlert = text(MDR_TEXT_LAST_ALERT, on: h) }
        }
        if mdrHeadphonesIsReady(h) != MDR_FALSE {
            if mdrHeadphonesIsDirty(h) != MDR_FALSE && writeBatch.mayCommit(at: clock.now) {
                let result = mdrHeadphonesRequestCommit(h)
                guard result == MDR_RESULT_OK else { fail(errorText(result)); return }
                writeBatch = WriteBatch()
            } else if mdrHeadphonesIsDirty(h) == MDR_FALSE && pendingSync != 0 {
                let flags = pendingSync; pendingSync = 0
                let result = mdrHeadphonesRequestSync(h, flags)
                guard result == MDR_RESULT_OK else { fail(errorText(result)); return }
            }
        }
        let applying = mdrHeadphonesIsDirty(h) != MDR_FALSE
        guard receivedEvent || applying != state.applying else { return }
        state.applying = applying
        if receivedEvent && state.phase == .ready { readSnapshot(h) }
        // No timestamp in the value: duplicate notifications should not redraw the UI.
        publish()
    }

    private func text(_ key: UInt32, index: UInt32 = 0, on h: OpaquePointer) -> String {
        var size: UInt32 = 0
        guard mdrHeadphonesGetText(h, key, index, nil, &size) == MDR_RESULT_OK, size > 0, size < 65_536 else { return "" }
        var buffer = [CChar](repeating: 0, count: Int(size))
        let result = buffer.withUnsafeMutableBufferPointer { mdrHeadphonesGetText(h, key, index, $0.baseAddress, &size) }
        guard result == MDR_RESULT_OK else { return "" }
        return String(decoding: buffer.prefix { $0 != 0 }.map { UInt8(bitPattern: $0) }, as: UTF8.self)
    }

    private func feature(_ key: UInt32, _ h: OpaquePointer) -> Bool {
        var value: UInt32 = MDR_AVAILABILITY_UNKNOWN
        return mdrHeadphonesGetFeature(h, key, &value) == MDR_RESULT_OK && value == MDR_AVAILABILITY_AVAILABLE
    }

    private func value(_ key: UInt32, index: UInt32 = 0, _ h: OpaquePointer) -> Int? {
        var result: Int32 = 0
        return mdrHeadphonesGetValue(h, key, index, &result) == MDR_RESULT_OK ? Int(result) : nil
    }

    private func range(_ lo: UInt32, _ hi: UInt32, _ step: UInt32, index: UInt32 = 0, _ h: OpaquePointer) -> DeviceRange? {
        guard let lower = value(lo, index: index, h), let upper = value(hi, index: index, h),
              let increment = value(step, index: index, h), lower < upper, increment > 0 else { return nil }
        return DeviceRange(lower: lower, upper: upper, step: increment)
    }

    private func readSnapshot(_ h: OpaquePointer) {
        let modelName = text(MDR_TEXT_MODEL_NAME, on: h)
        if !modelName.isEmpty { state.name = modelName }
        // Use the MDR identity reply, not the user-changeable Bluetooth display name.
        state.reportedModel = HeadphoneModelID(reportedName: modelName)
        state.firmware = text(MDR_TEXT_FIRMWARE_VERSION, on: h)
        var model = MDRModel()
        if mdrHeadphonesGetModel(h, &model) == MDR_RESULT_OK {
            state.codec = [1: "SBC", 2: "AAC", 3: "LDAC", 4: "aptX", 5: "aptX HD", 6: "LC3"][Int(model.audio_codec)] ?? ""
            state.finish = HeadphoneFinish.reported(model.model_color, model: state.reportedModel)
        }
        if batteryReported {
            var batteries = [MDRBattery](repeating: MDRBattery(), count: 4)
            var count: UInt32 = 4
            let result = batteries.withUnsafeMutableBufferPointer { mdrHeadphonesGetBatteries(h, $0.baseAddress, &count) }
            state.battery = result == MDR_RESULT_OK
                ? batteries.prefix(Int(min(count, 4))).first { $0.part == MDR_BATTERY_MAIN && $0.level_percent <= 100 }.map { Int($0.level_percent) }
                : nil
        }
        state.supportsNC = feature(MDR_FEATURE_NOISE_CANCELLING, h)
        state.supportsAmbient = feature(MDR_FEATURE_AMBIENT_SOUND, h)
        var noise = MDRNoiseControl()
        if (state.supportsNC || state.supportsAmbient), mdrHeadphonesGetNoiseControl(h, MDR_PROPERTY_CURRENT, &noise) == MDR_RESULT_OK {
            state.noiseMode = NoiseMode(rawValue: noise.mode)
            state.ambientLevel = Int(noise.ambient_level)
        }
        state.ambientRange = range(MDR_VALUE_AMBIENT_LEVEL_MIN, MDR_VALUE_AMBIENT_LEVEL_MAX, MDR_VALUE_AMBIENT_LEVEL_STEP, h)
        var eq = MDREqualizer()
        if mdrHeadphonesGetEqualizer(h, MDR_PROPERTY_CURRENT, &eq) == MDR_RESULT_OK {
            state.eqAvailable = eq.available != MDR_FALSE && feature(MDR_FEATURE_EQUALIZER, h)
            state.preset = eq.preset
            state.dsee = eq.dsee_available != MDR_FALSE && feature(MDR_FEATURE_DSEE, h) ? eq.dsee_enabled != MDR_FALSE : nil
            state.dseeName = [1: "DSEE", 2: "DSEE HX", 3: "DSEE Extreme", 4: "DSEE Ultimate"][Int(eq.dsee_type)] ?? "DSEE"
            var bands = [Int32](repeating: 0, count: Int(min(eq.band_count, 32)))
            var count = UInt32(bands.count)
            if count > 0 {
                let result = bands.withUnsafeMutableBufferPointer { mdrHeadphonesGetEqualizerBands(h, MDR_PROPERTY_CURRENT, $0.baseAddress, &count) }
                if result == MDR_RESULT_OK {
                    state.bands = Array(bands.prefix(Int(min(count, UInt32(bands.count)))))
                    state.frequencies = state.bands.indices.map { value(MDR_VALUE_EQUALIZER_BAND_FREQUENCY, index: UInt32($0), h) ?? 0 }
                }
            }
            state.bandRange = range(MDR_VALUE_EQUALIZER_BAND_MIN, MDR_VALUE_EQUALIZER_BAND_MAX, MDR_VALUE_EQUALIZER_BAND_STEP, index: eq.band_count, h)
            state.clearBassRange = range(MDR_VALUE_EQUALIZER_CLEAR_BASS_MIN, MDR_VALUE_EQUALIZER_CLEAR_BASS_MAX, MDR_VALUE_EQUALIZER_CLEAR_BASS_STEP, h)
            state.clearBass = state.clearBassRange == nil ? nil : Int(eq.clear_bass)
            var countPresets: UInt32 = 0
            if mdrHeadphonesGetEqualizerPresets(h, nil, &countPresets) == MDR_RESULT_OK, countPresets > 0, countPresets <= 256 {
                var ids = [UInt32](repeating: 0, count: Int(countPresets))
                let result = ids.withUnsafeMutableBufferPointer { mdrHeadphonesGetEqualizerPresets(h, $0.baseAddress, &countPresets) }
                if result == MDR_RESULT_OK {
                    state.presets = ids.prefix(Int(min(countPresets, UInt32(ids.count)))).enumerated().compactMap { index, id in
                        guard id != MDR_EQ_UNKNOWN else { return nil }
                        let name = text(MDR_TEXT_EQUALIZER_PRESET_NAME, index: UInt32(index), on: h)
                        return EqualizerPreset(id: id, name: name.isEmpty ? "Preset \(id)" : name)
                    }
                }
            }
        }
        var playback = MDRPlayback()
        if mdrHeadphonesGetPlayback(h, MDR_PROPERTY_CURRENT, &playback) == MDR_RESULT_OK {
            state.volume = Int(playback.volume)
            state.playing = playback.status == MDR_PLAYBACK_PLAYING
        }
        state.playbackAvailable = feature(MDR_FEATURE_PLAYBACK_CONTROL, h)
        state.volumeRange = feature(MDR_FEATURE_PLAYBACK_VOLUME, h) ? range(MDR_VALUE_PLAYBACK_VOLUME_MIN, MDR_VALUE_PLAYBACK_VOLUME_MAX, MDR_VALUE_PLAYBACK_VOLUME_STEP, h) : nil
        state.track = text(MDR_TEXT_TRACK_TITLE, on: h)
        state.artist = text(MDR_TEXT_TRACK_ARTIST, on: h)
        state.album = text(MDR_TEXT_TRACK_ALBUM, on: h)
        var speak = MDRSpeakToChat()
        state.speakToChat = feature(MDR_FEATURE_SPEAK_TO_CHAT, h) && mdrHeadphonesGetSpeakToChat(h, MDR_PROPERTY_CURRENT, &speak) == MDR_RESULT_OK ? speak.enabled != MDR_FALSE : nil
        var power = MDRPower()
        state.canShutdown = feature(MDR_FEATURE_SHUTDOWN, h)
        state.autoPause = feature(MDR_FEATURE_AUTO_PAUSE, h) && mdrHeadphonesGetPower(h, MDR_PROPERTY_CURRENT, &power) == MDR_RESULT_OK ? power.auto_pause != MDR_FALSE : nil
        var priority = MDRConnectionMode()
        state.connectionPriority = feature(MDR_FEATURE_CONNECTION_MODE, h) && mdrHeadphonesGetConnectionMode(h, MDR_PROPERTY_CURRENT, &priority) == MDR_RESULT_OK ? priority.audio_priority : nil
        var listening = MDRListening()
        if feature(MDR_FEATURE_LISTENING_MODE, h), mdrHeadphonesGetListening(h, MDR_PROPERTY_CURRENT, &listening) == MDR_RESULT_OK {
            state.listening = listening.mode
            let options: [(UInt32, String)] = [(0, "Standard"), (1, "Background Music"), (2, "Cinema"), (3, "Voice Boost"), (4, "Sound Leakage Reduction")]
            state.listeningOptions = options.compactMap { id, name in
                let requiredFeatures: [UInt32: UInt32] = [1: MDR_FEATURE_LISTENING_BACKGROUND_MUSIC, 2: MDR_FEATURE_LISTENING_CINEMA,
                                                        3: MDR_FEATURE_LISTENING_VOICE_BOOST, 4: MDR_FEATURE_LISTENING_SOUND_LEAKAGE_REDUCTION]
                if let required = requiredFeatures[id], !feature(required, h) { return nil }
                var status = MDRListeningStatus()
                guard mdrHeadphonesGetListeningStatus(h, id, &status) == MDR_RESULT_OK else { return nil }
                return ListeningOption(id: id, name: name, available: status.available != MDR_FALSE)
            }
        }
        readPairedDevices(h)
        readGeneralSettings(h)
    }

    private func readPairedDevices(_ h: OpaquePointer) {
        var count: UInt32 = 0
        guard mdrHeadphonesGetPairedDevices(h, nil, &count) == MDR_RESULT_OK, count > 0, count <= 64 else {
            state.pairedDevices = []; return
        }
        var devices = [MDRPairedDevice](repeating: MDRPairedDevice(), count: Int(count))
        let result = devices.withUnsafeMutableBufferPointer { mdrHeadphonesGetPairedDevices(h, $0.baseAddress, &count) }
        guard result == MDR_RESULT_OK else { return }
        state.pairedDevices = devices.prefix(Int(min(count, UInt32(devices.count)))).enumerated().map { index, device in
            let name = text(MDR_TEXT_PAIRED_DEVICE_NAME, index: UInt32(index), on: h)
            return ConnectedDevice(id: text(MDR_TEXT_PAIRED_DEVICE_ID, index: UInt32(index), on: h),
                                   name: name.isEmpty ? "Paired device" : name,
                                   connected: device.connected != MDR_FALSE, playing: device.playback_device != MDR_FALSE)
        }
    }

    private func readGeneralSettings(_ h: OpaquePointer) {
        var count: UInt32 = 0
        guard mdrHeadphonesGetGeneralSettingInfo(h, nil, &count) == MDR_RESULT_OK, count > 0, count <= 256 else { return }
        var infos = [MDRGeneralSettingInfo](repeating: MDRGeneralSettingInfo(), count: Int(count))
        let result = infos.withUnsafeMutableBufferPointer { mdrHeadphonesGetGeneralSettingInfo(h, $0.baseAddress, &count) }
        guard result == MDR_RESULT_OK else { return }
        state.generalSettings = infos.prefix(Int(min(count, UInt32(infos.count)))).compactMap { info in
            var setting = MDRGeneralSetting()
            guard mdrHeadphonesGetGeneralSetting(h, MDR_PROPERTY_CURRENT, info.index, &setting) == MDR_RESULT_OK else { return nil }
            let title = text(MDR_TEXT_GENERAL_SETTING_SUBJECT, index: info.index, on: h)
            let options = (0..<min(info.option_count, 128)).map { option in
                let index = (option << 8) | (info.index & 0xff)
                let label = text(MDR_TEXT_GENERAL_SETTING_OPTION_SUBJECT, index: index, on: h)
                return value(MDR_VALUE_GENERAL_SETTING_OPTION_TEXT_IS_KEY, index: index, h) == 1
                    ? label.replacingOccurrences(of: "_", with: " ").capitalized : label
            }
            return GeneralSetting(id: info.index,
                                  title: info.text_is_key != MDR_FALSE ? title.replacingOccurrences(of: "_", with: " ").capitalized : title,
                                  summary: info.text_is_key != MDR_FALSE ? "" : text(MDR_TEXT_GENERAL_SETTING_SUMMARY, index: info.index, on: h),
                                  writable: info.writable != MDR_FALSE,
                                  boolean: info.type == MDR_GENERAL_SETTING_BOOLEAN ? setting.boolean_value != MDR_FALSE : nil,
                                  selection: info.type == MDR_GENERAL_SETTING_LIST ? setting.list_value : nil, options: options)
        }
    }
}
