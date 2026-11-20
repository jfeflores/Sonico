import SwiftUI

enum DeviceSettingFeature: String, CaseIterable {
    case speakToChat = "speak-to-chat"
    case listening
    case dsee
    case connectionPriority = "connection-priority"
    case autoPause = "auto-pause"
    case generalControls = "general-controls"

    func title(for snapshot: HeadphoneSnapshot) -> String {
        switch self {
        case .speakToChat: "Speak-to-Chat"
        case .listening: "Listening mode"
        case .dsee: snapshot.dseeName
        case .connectionPriority: "Bluetooth connection priority"
        case .autoPause: "Pause when headphones are removed"
        case .generalControls: "Headphone controls"
        }
    }

    var symbol: String {
        switch self {
        case .speakToChat: "bubble.left"
        case .listening: "waveform"
        case .dsee: "waveform.badge.plus"
        case .connectionPriority: "antenna.radiowaves.left.and.right"
        case .autoPause: "pause.circle"
        case .generalControls: "hand.tap"
        }
    }

    func isAvailable(in snapshot: HeadphoneSnapshot) -> Bool {
        switch self {
        case .speakToChat: snapshot.speakToChat != nil
        case .listening: snapshot.listening != nil && !snapshot.listeningOptions.isEmpty
        case .dsee: snapshot.dsee != nil
        case .connectionPriority: snapshot.connectionPriority != nil
        case .autoPause: snapshot.autoPause != nil
        case .generalControls:
            snapshot.generalSettings.contains { !$0.title.isEmpty && ($0.boolean != nil || $0.selection != nil) }
        }
    }
}

enum OverviewShortcut: Hashable, Identifiable {
    case noise, equalizer, playback, connectedDevices
    case setting(DeviceSettingFeature)

    static let catalog: [Self] = [.noise, .equalizer, .playback, .connectedDevices]
        + DeviceSettingFeature.allCases.map(Self.setting)

    var id: String {
        switch self {
        case .noise: "noise"
        case .equalizer: "equalizer"
        case .playback: "playback"
        case .connectedDevices: "connected-devices"
        case .setting(let feature): "setting.\(feature.rawValue)"
        }
    }

    var visibleByDefault: Bool {
        switch self {
        case .noise, .equalizer, .playback, .connectedDevices: true
        case .setting: false
        }
    }

    func title(for snapshot: HeadphoneSnapshot) -> String {
        switch self {
        case .noise: "Ambient Sound Control"
        case .equalizer: "Equalizer"
        case .playback: "Playback"
        case .connectedDevices: "Connected devices"
        case .setting(let feature): feature.title(for: snapshot)
        }
    }

    var symbol: String {
        switch self {
        case .noise: "ear"
        case .equalizer: "slider.vertical.3"
        case .playback: "music.note"
        case .connectedDevices: "link"
        case .setting(let feature): feature.symbol
        }
    }

    func isAvailable(in snapshot: HeadphoneSnapshot) -> Bool {
        switch self {
        case .noise: snapshot.noiseMode != nil
        case .equalizer: snapshot.eqAvailable
        case .playback: snapshot.playbackAvailable || snapshot.volumeRange != nil
        case .connectedDevices: !snapshot.connectedDevices.isEmpty
        case .setting(let feature): feature.isAvailable(in: snapshot)
        }
    }
}

struct ShortcutLayout: Equatable {
    private struct Entry: Codable, Equatable {
        let id: String
        var isVisible: Bool
    }

    private static let catalog = Dictionary(uniqueKeysWithValues: OverviewShortcut.catalog.map { ($0.id, $0) })
    private var entries: [Entry]

    init(stored data: Data = Data()) {
        let saved = (try? JSONDecoder().decode([Entry].self, from: data)) ?? []
        var seen = Set<String>()
        entries = saved.filter { Self.catalog[$0.id] != nil && seen.insert($0.id).inserted }
        entries += OverviewShortcut.catalog.filter { !seen.contains($0.id) }
            .map { Entry(id: $0.id, isVisible: $0.visibleByDefault) }
    }

    var stored: Data { (try? JSONEncoder().encode(entries)) ?? Data() }

    func available(in snapshot: HeadphoneSnapshot) -> [OverviewShortcut] {
        entries.compactMap { Self.catalog[$0.id] }.filter { $0.isAvailable(in: snapshot) }
    }

    func isVisible(_ shortcut: OverviewShortcut) -> Bool {
        entries.first { $0.id == shortcut.id }?.isVisible ?? shortcut.visibleByDefault
    }

    mutating func setVisible(_ visible: Bool, for shortcut: OverviewShortcut) {
        if let index = entries.firstIndex(where: { $0.id == shortcut.id }) {
            entries[index].isVisible = visible
        }
    }

    mutating func move(from source: IndexSet, to destination: Int, among available: [OverviewShortcut]) {
        // Reorder this device's shortcuts without losing positions or visibility for other devices.
        let ids = Set(available.map(\.id))
        let indices = entries.indices.filter { ids.contains(entries[$0].id) }
        guard (0...indices.count).contains(destination), source.allSatisfy(indices.indices.contains) else { return }
        var reordered = indices.map { entries[$0] }
        reordered.move(fromOffsets: source, toOffset: destination)
        for (index, entry) in zip(indices, reordered) { entries[index] = entry }
    }
}
