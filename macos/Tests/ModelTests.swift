import Foundation

@main struct ModelTests {
    @MainActor static func main() {
        var assertions = 0
        func check(_ condition: @autoclosure () -> Bool, _ message: String) {
            precondition(condition(), message)
            assertions += 1
        }
        let disconnected = HeadphoneSnapshot()
        check(!disconnected.controllable, "Disconnected snapshots must not enable controls")
        check(disconnected.battery == nil, "Never invent battery state")
        check(disconnected.bands.isEmpty, "Never invent a live EQ layout")
        check(!disconnected.isDemo, "Demo is explicit, not the default")
        check(disconnected.finish == nil && disconnected.reportedModel == nil, "Disconnected never assumes a finish or model")
        check(HeadphoneModelID(reportedName: " wh-1000xm6\n") == .xm6, "MDR model name is normalized")
        check(HeadphoneModelID(reportedName: "Not WH-1000XM6") == nil, "A similar Bluetooth name is not recognized")
        check(HeadphoneModelID.xm3.usesLegacyProtocol && HeadphoneModelID.xm4.usesLegacyProtocol, "XM3/XM4 select MDR V1")
        check(!HeadphoneModelID.xm5.usesLegacyProtocol && !HeadphoneModelID.xm6.usesLegacyProtocol, "XM5/XM6 select MDR V2")
        check(HeadphoneFinish.reported(0x13, model: .xm6)?.name == "Platinum Silver", "MDR extended silver variant")
        check(HeadphoneFinish.reported(0x15, model: .xm6)?.name == "Midnight Blue", "MDR extended blue variant")
        check(HeadphoneFinish.reported(0x00, model: .xm6) == nil && HeadphoneFinish.reported(0xff, model: .xm6) == nil,
              "Unknown finish codes do not masquerade as a known finish")
        var live = HeadphoneSnapshot()
        let lifecycle = HeadphoneModel()
        live.phase = .initializing
        lifecycle.receive(live)
        check(lifecycle.arrivalID == nil, "No reveal before recognition")
        live.phase = .ready
        lifecycle.receive(live)
        check(lifecycle.arrivalID == nil, "A ready session without known identity does not fake a 3D portrait")
        live.reportedModel = .xm6
        lifecycle.receive(live)
        let firstArrival = lifecycle.arrivalID
        let portraitIdentity = lifecycle.portraitID
        check(firstArrival != nil, "Late identity creates the arrival event")
        live.battery = 82
        lifecycle.showingConnection = true
        lifecycle.page = .equalizer
        lifecycle.receive(live)
        check(firstArrival == lifecycle.arrivalID && lifecycle.showingConnection && lifecycle.page == .equalizer,
              "Battery updates do not replay motion or dismiss the open connection controls")
        if let firstArrival { lifecycle.consumeArrival(firstArrival) }
        lifecycle.receive(live)
        check(lifecycle.arrivalID == nil, "A consumed reveal does not repeat")
        check(lifecycle.portraitID == portraitIdentity, "Consuming a reveal preserves the renderer and orbit")
        lifecycle.receive(.init())
        lifecycle.receive(live)
        check(lifecycle.arrivalID != nil && lifecycle.arrivalID != firstArrival, "Reconnect gets a new reveal")
        func luminance(_ hex: UInt32) -> Double {
            let channels = [16, 8, 0].map { shift in
                let s = Double((hex >> shift) & 255) / 255
                return s <= 0.04045 ? s / 12.92 : pow((s + 0.055) / 1.055, 2.4)
            }
            return channels[0] * 0.2126 + channels[1] * 0.7152 + channels[2] * 0.0722
        }
        func contrast(_ a: UInt32, _ b: UInt32) -> Double {
            let x = luminance(a), y = luminance(b)
            return (max(x, y) + 0.05) / (min(x, y) + 0.05)
        }
        var minText = Double.infinity, minRule = Double.infinity
        for model in HeadphoneModelID.allCases {
            for code in UInt32(0)...14 {
                let finish = HeadphoneFinish.reported(code, model: model)
                for dark in [false, true] {
                    for increased in [false, true] {
                        let p = FinishPalette(finish: finish, dark: dark, increasedContrast: increased)
                        for surface in [p.background, p.surface, p.surfaceHigh] {
                            for ink in [p.text, p.secondary, p.primary, p.error] {
                                minText = min(minText, contrast(ink, surface))
                            }
                        }
                        minText = min(minText, contrast(p.onPrimary, p.primary), contrast(p.onHeader, p.headerEdge),
                                      contrast(p.headerSecondary, p.headerEdge), contrast(p.headerSecondary, p.header))
                        minRule = min(minRule, contrast(p.outline, p.surface))
                    }
                }
            }
        }
        check(minText >= 4.5, "Palette body text must meet WCAG AA (minimum \(minText))")
        check(minRule >= 3, "Chart rules must meet 3:1 contrast (minimum \(minRule))")
        check(HeadphoneFinish.reported(6, model: .xm6)?.name == "Pink" && HeadphoneFinish.reported(8, model: .xm6)?.name == "Green",
              "Generic MDR colors do not claim a specific retail shade")
        check(HeadphoneSnapshot.demo(model: .xm6, colorCode: 6).finish?.name == "Sand Pink", "Retail finish previews are demo-only")
        print(String(format: "Palette contrast: minimum body %.2f:1, minimum graph guide %.2f:1", minText, minRule))
        let narrowOrbit = PortraitOrbit().dragged(by: CGSize(width: 32, height: -18))
        check(narrowOrbit.yaw > 0 && narrowOrbit.pitch < 0, "Drag steers yaw and pitch independently")
        let farOrbit = narrowOrbit.dragged(by: CGSize(width: 100_000, height: 100_000))
        check(abs(farOrbit.yaw) <= .pi && farOrbit.pitch == PortraitOrbit.pitchRange.upperBound,
              "Orbit wraps indefinitely while tilt remains limited")
        let inverseOrbit = narrowOrbit.stepped(-1).stepped(1)
        check(abs(inverseOrbit.yaw - narrowOrbit.yaw) < 1e-10 && inverseOrbit.pitch == narrowOrbit.pitch,
              "Accessible rotation controls are reversible and keep tilt")
        check(HeadphoneFinish.reported(1, model: .xm6)?.shell != HeadphoneFinish.reported(5, model: .xm6)?.shell,
              "Black and Midnight Blue have distinct XM6 materials")
        let now = ContinuousClock().now
        var batch = WriteBatch()
        batch.stage(at: now)
        check(!batch.mayCommit(at: now.advanced(by: .milliseconds(79))), "Slider changes wait for a quiet period")
        check(batch.mayCommit(at: now.advanced(by: .milliseconds(80))), "An isolated change commits after the quiet period")
        for offset in [60, 120, 180, 235] { batch.stage(at: now.advanced(by: .milliseconds(offset))) }
        check(batch.mayCommit(at: now.advanced(by: .milliseconds(240))), "Continuous input still commits within the batch limit")
        batch.stage(at: now, immediate: true)
        check(batch.mayCommit(at: now), "Device confirmation bypasses batching")
        let range = DeviceRange(lower: -6, upper: 6, step: 1)
        check(range.clamped(-100) == -6, "Clamp lower range")
        check(range.clamped(100) == 6, "Clamp upper range")
        check(frequencyLabel(1000) == "1k", "Frequency label in kHz")
        check(frequencyLabel(31) == "31", "Low frequency label in Hz")
        check(frequencyLabel(0) == "—", "Unknown frequency must not be invented")
        let model = HeadphoneModel(demo: true)
        check(model.snapshot.isDemo, "Demo remains labeled")
        check(model.snapshot.presetName == "Off" && model.snapshot.bands.isEmpty, "Demo defaults to Off without invented gains")
        check(model.snapshot.presets.map(\.name) == ["Off", "Heavy", "Clear", "Hard", "Soft"], "XM6 demo only shows factory choices")
        check(HeadphoneSnapshot.demo(model: .xm5, colorCode: 1).presets.map(\.name).contains("Bright"), "Legacy demo showcases legacy factory choices")
        check(model.snapshot.connectedDevices.isEmpty, "Demo does not invent paired devices")
        check(!disconnected.activePresetReported && disconnected.presetName == "Preset not reported", "Live session does not assume EQ Off")
        model.send(.noise(.cancelling))
        check(model.snapshot.noiseMode == .cancelling, "Demo noise selection")
        model.setAmbient(200)
        check(model.ambientDraft == 20 && model.snapshot.ambientLevel == 20, "Ambient slider respects the reported range")
        let actualEQ = EqualizerValues(preset: 26, bands: [1, 0, -1], clearBass: 2)
        var edit = EqualizerEdit(actualEQ)
        check(!edit.isValid(against: actualEQ, bandRange: range, bassRange: range), "An unedited slot cannot be written")
        edit.proposed.bands[0] = 3
        check(edit.isValid(against: actualEQ, bandRange: range, bassRange: range), "A deliberate in-range edit is allowed")
        let otherSlot = EqualizerValues(preset: 25, bands: actualEQ.bands, clearBass: actualEQ.clearBass)
        let queuedDraft = edit
        check(queuedDraft.isValid(against: actualEQ, bandRange: range, bassRange: range), "Apply may queue the unchanged source slot")
        check(!queuedDraft.isValid(against: otherSlot, bandRange: range, bassRange: range),
              "After Apply, a slot notification before submission invalidates the queued draft")
        var legacyEQ = HeadphoneSnapshot()
        legacyEQ.reportedModel = .xm3
        legacyEQ.eqAvailable = true
        legacyEQ.activePresetReported = true
        legacyEQ.preset = actualEQ.preset
        legacyEQ.bands = actualEQ.bands
        legacyEQ.bandRange = range
        check(legacyEQ.equalizerValues != nil && !legacyEQ.canEditEqualizer, "V1 exposes reported curves without unsafe slot editing")
        let sameSlotChanged = EqualizerValues(preset: 26, bands: [-1, 0, 1], clearBass: 2)
        check(!edit.isValid(against: sameSlotChanged, bandRange: range, bassRange: range), "Do not overwrite values changed by the phone")
        model.send(.equalizerEdit(edit))
        model.send(.preset(26))
        check(!model.snapshot.canEditEqualizer && model.snapshot.presetName == "Off", "Demo cannot accept a personal slot")
        model.send(.preset(16))
        check(model.snapshot.presetName == "Heavy" && model.snapshot.bands.isEmpty, "Factory preview does not invent gains")
        model.send(.volume(19))
        check(model.snapshot.volume == 19, "Demo volume")
        model.send(.playback(1))
        check(!model.snapshot.playing && model.snapshot.track.isEmpty, "Demo does not invent playback")
        var reporting = HeadphoneSnapshot()
        reporting.playbackMetadataAvailable = true
        reporting.track = "Fixture track"
        reporting.playbackState = .playing
        check(reporting.playbackTitle == "Fixture track", "Show device-reported metadata")
        reporting.playbackState = .stopped
        check(reporting.playbackTitle == "Nothing playing", "Do not show a stale track after stopping")
        model.send(.dsee(false))
        check(model.snapshot.dsee == false, "Demo DSEE")
        let demoPortraitID = model.portraitID
        if let arrival = model.arrivalID { model.consumeArrival(arrival) }
        model.enterDemo(model: .xm6, colorCode: 5)
        check(model.snapshot.finish?.name == "Midnight Blue" && model.portraitID == demoPortraitID && model.arrivalID == nil,
              "Same-headset finish previews keep the portrait instead of replaying its reveal")
        check(model.snapshot.dsee == false && model.snapshot.volume == 19, "A finish preview preserves demo controls")
        model.enterDemo(model: .xm5, colorCode: 1)
        check(model.snapshot.reportedModel == .xm5 && model.snapshot.finish?.name == "Black", "Demo can preview a distinct model and finish")
        model.leaveDemo()
        check(!model.snapshot.isDemo && !model.snapshot.controllable, "Leaving demo clears simulated state")
        check(model.snapshot.battery == nil && model.snapshot.equalizerValues == nil, "No demo data leaks into live state")
        testAdvancedDeviceSettings()
        var layout = ShortcutLayout()
        layout.setVisible(false, for: .connectedDevices)
        layout.move(from: IndexSet(integer: 1), to: 0, among: [.noise, .equalizer, .playback])
        let reloaded = ShortcutLayout(stored: layout.stored)
        check(reloaded.available(in: .demo).prefix(2).elementsEqual([.equalizer, .noise]), "Filtered shortcut reorder persists")
        check(!reloaded.isVisible(.connectedDevices), "Reorder preserves unavailable shortcut visibility")
        print("Sonico: \(assertions) model assertions passed. No Bluetooth operations performed.")
    }
}
