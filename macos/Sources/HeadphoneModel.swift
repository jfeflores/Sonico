import Foundation
import Observation

@MainActor @Observable
final class HeadphoneModel {
    private(set) var snapshot: HeadphoneSnapshot
    var page = AppPage.device
    var showingConnection = false
    private(set) var volumeDraft = 0.0
    private(set) var ambientDraft = 0.0
    var visibleError: String?
    private(set) var arrivalID: UUID?
    private(set) var portraitID: UUID?
    @ObservationIgnored private var service: HeadphoneService?
    @ObservationIgnored private var serviceID: UUID?

    init(demo: Bool = false) {
        snapshot = demo ? .demo : HeadphoneSnapshot()
        if demo { beginArrival() }
        synchronizeDrafts()
    }

    func start() {
        guard !snapshot.isDemo, service == nil else { return }
        let id = UUID()
        serviceID = id
        service = HeadphoneService { [weak self] state in
            guard let self, self.serviceID == id else { return }
            self.receive(state)
        }
    }

    func stop() {
        serviceID = nil
        service?.stop()
        service = nil
    }

    func receive(_ state: HeadphoneSnapshot) {
        let wasReady = snapshot.controllable
        let wasIdentified = snapshot.reportedModel != nil
        let previousError = snapshot.error
        if state != snapshot { snapshot = state }
        if state.error != previousError { visibleError = state.error }
        if !state.applying { synchronizeDrafts() }
        if state.controllable && !wasReady {
            showingConnection = false
            page = .device
        }
        if state.controllable && state.reportedModel != nil && (!wasReady || !wasIdentified) {
            beginArrival()
        } else if !state.controllable {
            arrivalID = nil
            portraitID = nil
        }
    }

    private func beginArrival() {
        let id = UUID()
        portraitID = id
        arrivalID = id
    }

    func consumeArrival(_ id: UUID) {
        if arrivalID == id { arrivalID = nil }
    }

    private func synchronizeDrafts() {
        if volumeDraft != Double(snapshot.volume) { volumeDraft = Double(snapshot.volume) }
        if ambientDraft != Double(snapshot.ambientLevel) { ambientDraft = Double(snapshot.ambientLevel) }
    }

    func send(_ command: HeadphoneCommand) {
        if snapshot.isDemo { applyDemo(command); return }
        start()
        service?.send(command)
    }

    func setVolume(_ value: Double) {
        guard let range = snapshot.volumeRange else { return }
        volumeDraft = Double(range.clamped(Int(value.rounded())))
        send(.volume(Int(volumeDraft)))
    }

    func setAmbient(_ value: Double) {
        guard let range = snapshot.ambientRange else { return }
        ambientDraft = Double(range.clamped(Int(value.rounded())))
        send(.ambient(Int(ambientDraft)))
    }

    func enterDemo(model: HeadphoneModelID = .xm6, colorCode: UInt32 = 3) {
        let preview = HeadphoneSnapshot.demo(model: model, colorCode: colorCode)
        if snapshot.isDemo && snapshot.reportedModel == model {
            // A finish audition should not reset EQ, playback, or the portrait's orbit.
            snapshot.finish = preview.finish
            return
        }
        stop()
        snapshot = preview
        beginArrival()
        visibleError = nil
        showingConnection = false
        page = .device
        synchronizeDrafts()
    }

    func leaveDemo() {
        snapshot = HeadphoneSnapshot()
        arrivalID = nil
        portraitID = nil
        visibleError = nil
        synchronizeDrafts()
    }

    private func applyDemo(_ command: HeadphoneCommand) {
        switch command {
        case .disconnect: leaveDemo(); return
        case .noise(let mode): snapshot.noiseMode = mode
        case .ambient(let value): snapshot.ambientLevel = value
        case .preset(let id):
            if snapshot.presets.contains(where: { $0.id == id && !$0.isUserSlot }) { snapshot.preset = id }
        case .volume(let value): snapshot.volume = value
        case .dsee(let value): snapshot.dsee = value
        case .speakToChat(let value): snapshot.speakToChat = value
        case .autoPause(let value): snapshot.autoPause = value
        case .priority(let value): snapshot.connectionPriority = value
        case .listening(let value): snapshot.listening = value
        case .answerAlert: snapshot.deviceAlert = nil
        case .shutdown: leaveDemo(); return
        default: break
        }
        synchronizeDrafts()
    }
}

enum AppPage: String, CaseIterable, Identifiable {
    case device = "My Device", equalizer = "Equalizer", settings = "Settings"
    var id: String { rawValue }
}
