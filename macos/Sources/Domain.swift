import Foundation

struct PairedHeadphone: Identifiable, Equatable, Sendable {
    let id: String
    let name: String
    var model: HeadphoneModelID? { HeadphoneModelID(reportedName: name) }
}

enum HeadphoneModelID: String, CaseIterable, Sendable {
    case xm3 = "WH-1000XM3", xm4 = "WH-1000XM4", xm5 = "WH-1000XM5", xm6 = "WH-1000XM6"

    init?(reportedName: String) {
        let name = reportedName.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        // Match a full model identifier, not an arbitrary Bluetooth name containing it.
        guard let model = Self(rawValue: name) else { return nil }
        self = model
    }

    var usesLegacyProtocol: Bool { self == .xm3 || self == .xm4 }
}

struct HeadphoneFinish: Equatable, Sendable {
    let name: String
    let shell: UInt32
    let cushion: UInt32

    static let unreported = Self(name: "", shell: 0x777C80, cushion: 0x494D50)
    static func reported(_ code: UInt32, model: HeadphoneModelID?) -> Self? {
        // Both MDR families define 0x11...0x1E as variants of 0x01...0x0E.
        let base = (0x11...0x1E).contains(code) ? code - 0x10 : code
        if model == .xm6 {
            // Calibrated against the three reference finishes; the device still selects the finish.
            switch base {
            case 1: return Self(name: "Black", shell: 0x27282B, cushion: 0x212224)
            case 3: return Self(name: "Platinum Silver", shell: 0xC7C8BA, cushion: 0xB8B9AD)
            case 5: return Self(name: "Midnight Blue", shell: 0x263447, cushion: 0x202C3C)
            default: break
            }
        }
        switch base {
        case 1: return Self(name: "Black", shell: 0x34373C, cushion: 0x222428)
        case 2: return Self(name: "White", shell: 0xE2E1DB, cushion: 0xC5C4BB)
        case 3: return Self(name: model == .xm5 || model == .xm6 ? "Platinum Silver" : "Silver", shell: 0xC5C5BD, cushion: 0xA4A59C)
        case 4: return Self(name: "Red", shell: 0x9E444A, cushion: 0x632C33)
        case 5: return Self(name: model == .xm5 || model == .xm6 ? "Midnight Blue" : "Blue", shell: 0x343F56, cushion: 0x252F42)
        case 6: return Self(name: "Pink", shell: 0xC9AAA9, cushion: 0xAC8D8D)
        case 7: return Self(name: "Yellow", shell: 0xC6A151, cushion: 0xA28342)
        case 8: return Self(name: "Green", shell: 0x778367, cushion: 0x505B48)
        case 9: return Self(name: "Gray", shell: 0x777B7A, cushion: 0x555958)
        case 10: return Self(name: "Gold", shell: 0xB89B69, cushion: 0x8D7757)
        case 11: return Self(name: "Cream", shell: 0xD7C6AD, cushion: 0xB5A38D)
        case 12: return Self(name: "Orange", shell: 0xBD794F, cushion: 0x935D3D)
        case 13: return Self(name: "Brown", shell: 0x836B58, cushion: 0x604D3D)
        case 14: return Self(name: "Violet", shell: 0x827294, cushion: 0x5E536D)
        default: return nil
        }
    }
}

struct DeviceRange: Equatable, Sendable {
    let lower: Int
    let upper: Int
    let step: Int
    var sliderBounds: ClosedRange<Double> { Double(lower)...Double(max(lower + 1, upper)) }
    func clamped(_ value: Int) -> Int { min(upper, max(lower, value)) }
}

enum ConnectionPhase: Equatable, Sendable {
    case disconnected, discovering, connecting, initializing, ready, failed
    var label: String {
        switch self {
        case .disconnected: "Not connected"
        case .discovering: "Finding paired headphones…"
        case .connecting: "Connecting…"
        case .initializing: "Reading device settings…"
        case .ready: "Connected"
        case .failed: "Connection needs attention"
        }
    }
    var busy: Bool { self == .discovering || self == .connecting || self == .initializing }
}

enum NoiseMode: UInt32, CaseIterable, Identifiable, Sendable {
    case off = 0, cancelling = 1, ambient = 2
    var id: UInt32 { rawValue }
    var title: String {
        switch self { case .off: "Off"; case .cancelling: "Noise Canceling"; case .ambient: "Ambient Sound" }
    }
    var symbol: String {
        switch self { case .off: "circle"; case .cancelling: "person.crop.circle.badge.minus"; case .ambient: "person.wave.2" }
    }
}

struct EqualizerPreset: Identifiable, Equatable, Sendable {
    let id: UInt32
    let name: String
}

struct ConnectedDevice: Identifiable, Equatable, Sendable {
    let id: String
    let name: String
    let connected: Bool
    let playing: Bool
}

struct GeneralSetting: Identifiable, Equatable, Sendable {
    let id: UInt32
    let title: String
    let summary: String
    let writable: Bool
    let boolean: Bool?
    let selection: UInt32?
    let options: [String]
}

struct ListeningOption: Identifiable, Equatable, Sendable {
    let id: UInt32
    let name: String
    let available: Bool
}

struct HeadphoneSnapshot: Equatable, Sendable {
    var phase = ConnectionPhase.disconnected
    var devices: [PairedHeadphone] = []
    var name = "Headphones"
    var reportedModel: HeadphoneModelID?
    var finish: HeadphoneFinish?
    var battery: Int?
    var firmware = ""
    var codec = ""
    var noiseMode: NoiseMode?
    var supportsNC = false
    var supportsAmbient = false
    var ambientLevel = 0
    var ambientRange: DeviceRange?
    var eqAvailable = false
    var preset: UInt32 = 0
    var presets: [EqualizerPreset] = []
    var bands: [Int32] = []
    var frequencies: [Int] = []
    var bandRange: DeviceRange?
    var clearBass: Int?
    var clearBassRange: DeviceRange?
    var dsee: Bool?
    var dseeName = "DSEE"
    var speakToChat: Bool?
    var autoPause: Bool?
    var canShutdown = false
    var connectionPriority: UInt32?
    var listening: UInt32?
    var listeningOptions: [ListeningOption] = []
    var volume = 0
    var volumeRange: DeviceRange?
    var playbackAvailable = false
    var playing = false
    var track = ""
    var artist = ""
    var album = ""
    var pairedDevices: [ConnectedDevice] = []
    var generalSettings: [GeneralSetting] = []
    var error: String?
    var deviceAlert: String?
    var applying = false
    var isDemo = false

    var controllable: Bool { phase == .ready }
    var connectedDevices: [ConnectedDevice] { pairedDevices.filter(\.connected) }
    var presetName: String { presets.first { $0.id == preset }?.name ?? "Device preset" }
    var canEditEqualizer: Bool { eqAvailable && (24...29).contains(preset) }
    var status: String { isDemo ? "Demo · No headphone connection" : phase.label }
    var availableNoiseModes: [NoiseMode] {
        [NoiseMode.cancelling, .ambient, .off].filter { $0 == .off || ($0 == .cancelling && supportsNC) || ($0 == .ambient && supportsAmbient) }
    }

    static var demo: Self { demo(model: .xm6, colorCode: 3) }

    static func demo(model: HeadphoneModelID, colorCode: UInt32) -> Self {
        var s = Self()
        s.phase = .ready
        s.isDemo = true
        s.name = model.rawValue
        s.reportedModel = model
        s.finish = HeadphoneFinish.reported(colorCode, model: model)
        s.battery = 93
        s.codec = "AAC"
        s.firmware = "Illustrative — not read from a device"
        s.noiseMode = .ambient
        s.supportsNC = true
        s.supportsAmbient = true
        s.ambientLevel = 12
        s.ambientRange = DeviceRange(lower: 1, upper: 20, step: 1)
        s.eqAvailable = true
        s.preset = 26
        s.presets = [EqualizerPreset(id: 0, name: "Off"), EqualizerPreset(id: 16, name: "Heavy"),
                     EqualizerPreset(id: 17, name: "Clear"), EqualizerPreset(id: 18, name: "Hard"),
                     EqualizerPreset(id: 19, name: "Soft"), EqualizerPreset(id: 25, name: "Custom 1"),
                     EqualizerPreset(id: 26, name: "Custom 2")]
        s.bands = [1, 1, -2, -2, -1, 0, -1, 0, 4, 2]
        s.frequencies = [31, 63, 125, 250, 500, 1000, 2000, 4000, 8000, 16000]
        s.bandRange = DeviceRange(lower: -6, upper: 6, step: 1)
        s.dsee = true
        s.dseeName = "DSEE Extreme"
        s.speakToChat = false
        s.autoPause = true
        s.canShutdown = true
        s.connectionPriority = 1
        s.listening = 0
        s.listeningOptions = [ListeningOption(id: 0, name: "Standard", available: true),
                              ListeningOption(id: 1, name: "Background Music", available: true),
                              ListeningOption(id: 2, name: "Cinema", available: true)]
        s.volume = 15
        s.volumeRange = DeviceRange(lower: 0, upper: 30, step: 1)
        s.playbackAvailable = true
        s.playing = false
        s.track = "Your music, your space"
        s.artist = "Illustrative playback · Demo mode"
        s.pairedDevices = [ConnectedDevice(id: "demo-phone", name: "Example iPhone", connected: true, playing: false),
                           ConnectedDevice(id: "demo-mac", name: "Example Mac", connected: true, playing: true)]
        return s
    }
}

/// A short quiet period batches repeated slider input; the upper bound prevents starvation.
struct WriteBatch {
    private var quietUntil: ContinuousClock.Instant?
    private var commitBy: ContinuousClock.Instant?

    mutating func stage(at now: ContinuousClock.Instant, immediate: Bool = false) {
        quietUntil = immediate ? now : now.advanced(by: .milliseconds(80))
        if immediate { commitBy = now }
        else if commitBy == nil { commitBy = now.advanced(by: .milliseconds(240)) }
    }

    func mayCommit(at now: ContinuousClock.Instant) -> Bool {
        (quietUntil.map { now >= $0 } ?? true) || (commitBy.map { now >= $0 } ?? false)
    }
}

enum HeadphoneCommand: Sendable {
    case discover, connect(PairedHeadphone), disconnect, sync
    case noise(NoiseMode), ambient(Int), preset(UInt32), bands([Int32]), clearBass(Int)
    case volume(Int), playback(UInt32), dsee(Bool), speakToChat(Bool), autoPause(Bool)
    case priority(UInt32), listening(UInt32), generalBoolean(UInt32, Bool), generalList(UInt32, UInt32)
    case answerAlert(Bool), shutdown
}

func frequencyLabel(_ frequency: Int) -> String {
    guard frequency > 0 else { return "—" }
    return frequency >= 1000 ? "\(frequency / 1000)k" : "\(frequency)"
}
