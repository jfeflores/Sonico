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
        check(model.snapshot.bands.count == 10, "Ten-band demo matches reference structure")
        check(model.snapshot.connectedDevices.count == 2, "Overview only lists connected multipoint devices")
        model.send(.noise(.cancelling))
        check(model.snapshot.noiseMode == .cancelling, "Demo noise selection")
        model.setAmbient(200)
        check(model.ambientDraft == 20 && model.snapshot.ambientLevel == 20, "Ambient slider respects the reported range")
        model.setClearBass(4)
        check(model.clearBassDraft == 0 && model.snapshot.clearBass == nil, "Clear Bass cannot change without a reported range")
        model.setBand(0, 99)
        check(model.snapshot.bands[0] == 6, "EQ edits clamp to the reported range")
        model.setBand(99, 2)
        check(model.snapshot.bands.count == 10, "Invalid band index is ignored")
        model.resetEqualizer()
        check(model.snapshot.bands.allSatisfy { $0 == 0 }, "Flat reset uses all bands")
        model.send(.volume(19))
        check(model.snapshot.volume == 19, "Demo volume")
        model.send(.playback(1))
        check(model.snapshot.playing, "Demo play")
        model.send(.playback(2))
        check(!model.snapshot.playing, "Demo pause")
        model.send(.dsee(false))
        check(model.snapshot.dsee == false, "Demo DSEE")
        model.enterDemo(model: .xm5, colorCode: 1)
        check(model.snapshot.reportedModel == .xm5 && model.snapshot.finish?.name == "Black", "Demo can preview a distinct model and finish")
        model.leaveDemo()
        check(!model.snapshot.isDemo && !model.snapshot.controllable, "Leaving demo clears simulated state")
        check(model.snapshot.battery == nil && model.eqDraft.isEmpty, "No demo data leaks into live state")
        print("Project XMConnect: \(assertions) model assertions passed. No Bluetooth operations performed.")
    }
}
