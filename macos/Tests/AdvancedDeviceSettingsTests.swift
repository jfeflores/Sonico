import XMConnectBridge

/// Runs without a transport or an MDR handle. Fixture values model API reports, not device defaults.
func testAdvancedDeviceSettings() {
    let empty = AdvancedDeviceSettings()
    precondition(empty.adaptiveAmbient == nil && empty.speechTimeout == nil && empty.voiceAssistant == nil)
    precondition(empty.autoPowerOff == nil && empty.assignableControls.isEmpty)
    precondition(HeadphoneSnapshot.demo.advancedSettings == empty, "Demo does not invent advanced capabilities")

    let xm3Power = DeviceSettingCatalog.powerChoices(minutes: [5, 30, 60, 180, 0], selectedMinutes: 30,
                                                      wearing: MDR_WEARING_POWER_UNAVAILABLE)!
    precondition(xm3Power.options.map(\.id) == [5, 30, 60, 180, 0], "Keep the legacy options in device order")
    precondition(!xm3Power.canSelect(15), "Do not let V2's 15-minute option leak into V1")
    precondition(!xm3Power.canSelect(DeviceSettingCatalog.whenRemoved) && !xm3Power.canSelect(30))

    let wearingPower = DeviceSettingCatalog.powerChoices(minutes: [15, 0, 15, 200], selectedMinutes: 0,
                                                         wearing: MDR_WEARING_POWER_WHEN_REMOVED)!
    precondition(wearingPower.options.map(\.id) == [15, 0, DeviceSettingCatalog.whenRemoved])
    precondition(wearingPower.selected == DeviceSettingCatalog.whenRemoved && wearingPower.canSelect(0),
                 "Turning off when removed and never turning off are different options")
    precondition(DeviceSettingCatalog.powerChoices(minutes: [], selectedMinutes: 0, wearing: MDR_WEARING_POWER_UNAVAILABLE) == nil)

    let sony = MDR_VOICE_ASSISTANT_SONY_VOICE_CONTROL
    let off = MDR_VOICE_ASSISTANT_NONE
    let reported = [(off, true), (sony, true), (MDR_VOICE_ASSISTANT_GOOGLE_ASSISTANT, true), (MDR_VOICE_ASSISTANT_UNKNOWN, true)]
    let assistant = DeviceSettingCatalog.voiceAssistantChoices(selected: off, available: true,
                                                              backgroundMusicActive: false, reported: reported)!
    precondition(assistant.options.map(\.id) == [off, sony] && assistant.canSelect(sony))
    let backgroundMusic = DeviceSettingCatalog.voiceAssistantChoices(selected: off, available: true,
                                                                    backgroundMusicActive: true, reported: reported)!
    precondition(!backgroundMusic.canSelect(sony), "Block Voice Control while Background Music is active")
    let blockedAssistant = DeviceSettingCatalog.voiceAssistantChoices(selected: off, available: false,
                                                                     backgroundMusicActive: false, reported: reported)!
    precondition(!blockedAssistant.canChange, "An unavailable feature overrides any per-option availability")
    let excludedAssistant = DeviceSettingCatalog.voiceAssistantChoices(selected: off, available: true,
                                                                      backgroundMusicActive: false, reported: [(off, true), (sony, false)])!
    precondition(!excludedAssistant.canSelect(sony), "Honor per-option exclusions even without a known conflict")
    precondition(!DeviceSettingCatalog.permitsBackgroundMusic(current: sony, desired: off), "Wait for confirmation before enabling BGM")
    precondition(!DeviceSettingCatalog.permitsBackgroundMusic(current: off, desired: sony), "Block concurrent activation requests")
    precondition(DeviceSettingCatalog.permitsBackgroundMusic(current: off, desired: off))
    precondition(!DeviceSettingCatalog.listeningNotice(blockers: 0).isEmpty, "Supply a fallback explanation without inventing a blocker")

    let currentAction = MDR_ASSIGNABLE_PLAYBACK
    let assignable = DeviceSettingCatalog.assignableChoices(selected: currentAction,
        reported: [MDR_ASSIGNABLE_UNKNOWN, currentAction, MDR_ASSIGNABLE_VOLUME, MDR_ASSIGNABLE_VOLUME, MDR_ASSIGNABLE_GOOGLE_ASSISTANT])!
    precondition(assignable.options.map(\.id) == [currentAction, MDR_ASSIGNABLE_VOLUME])
    precondition(assignable.canSelect(MDR_ASSIGNABLE_VOLUME) && !assignable.canSelect(MDR_ASSIGNABLE_NOISE_CONTROL))
    let google = DeviceSettingCatalog.assignableChoices(selected: MDR_ASSIGNABLE_GOOGLE_ASSISTANT,
                                                        reported: [MDR_ASSIGNABLE_GOOGLE_ASSISTANT, currentAction])!
    precondition(google.selected == MDR_ASSIGNABLE_GOOGLE_ASSISTANT && google.options.count == 2 && google.canSelect(currentAction),
                 "A configured Google Assistant remains visible and can be replaced, not enabled anew")

    precondition(DeviceSettingCatalog.discoveredChoice(MDR_SPEECH_SENSITIVITY_UNKNOWN, in: DeviceSettingCatalog.speechSensitivity) == nil)
    precondition(DeviceSettingCatalog.discoveredChoice(MDR_ROOM_UNKNOWN, in: DeviceSettingCatalog.backgroundRooms) == nil)
    let adaptive = DeviceSettingCatalog.discoveredChoice(MDR_ADAPTIVE_SENSITIVITY_STANDARD,
                                                          in: DeviceSettingCatalog.adaptiveSensitivity, available: false)!
    precondition(!adaptive.canSelect(MDR_ADAPTIVE_SENSITIVITY_HIGH), "Adaptive sensitivity is not writable with Auto Ambient Sound off")
}
