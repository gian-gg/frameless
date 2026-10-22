import Foundation

/// User-adjustable settings persisted in UserDefaults, defaulting to Config values.
@MainActor
final class Preferences {
    private enum Key {
        static let capturesSystemAudio = "capturesSystemAudio"
        static let capturesMicrophone = "capturesMicrophone"
        static let showsCursor = "showsCursor"
        static let videoCodec = "videoCodec"
        static let frameRate = "frameRate"
        static let resolution = "resolution"
        static let playsSounds = "playsSounds"
        static func shortcut(_ action: Hotkeys.Action) -> String { "shortcut.\(action)" }
        static func saveFolder(_ purpose: CapturePurpose) -> String { "saveFolder.\(purpose)" }
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        defaults.register(defaults: [
            Key.capturesSystemAudio: Config.Recording.capturesSystemAudio,
            Key.capturesMicrophone: Config.Recording.capturesMicrophone,
            Key.showsCursor: Config.Recording.showsCursor,
            Key.videoCodec: Config.Recording.videoCodec.rawValue,
            Key.frameRate: Config.Recording.frameRate.rawValue,
            Key.resolution: Config.Recording.resolution.rawValue,
            Key.playsSounds: Config.Feedback.playsSounds,
        ])
    }

    var capturesSystemAudio: Bool {
        get { defaults.bool(forKey: Key.capturesSystemAudio) }
        set { defaults.set(newValue, forKey: Key.capturesSystemAudio) }
    }

    var capturesMicrophone: Bool {
        get { defaults.bool(forKey: Key.capturesMicrophone) }
        set { defaults.set(newValue, forKey: Key.capturesMicrophone) }
    }

    var showsCursor: Bool {
        get { defaults.bool(forKey: Key.showsCursor) }
        set { defaults.set(newValue, forKey: Key.showsCursor) }
    }

    var videoCodec: VideoCodec {
        get {
            defaults.string(forKey: Key.videoCodec).flatMap(VideoCodec.init(rawValue:)) ?? Config.Recording.videoCodec
        }
        set { defaults.set(newValue.rawValue, forKey: Key.videoCodec) }
    }

    var frameRate: FrameRate {
        get { FrameRate(rawValue: defaults.integer(forKey: Key.frameRate)) ?? Config.Recording.frameRate }
        set { defaults.set(newValue.rawValue, forKey: Key.frameRate) }
    }

    var resolution: Resolution {
        get {
            defaults.string(forKey: Key.resolution).flatMap(Resolution.init(rawValue:)) ?? Config.Recording.resolution
        }
        set { defaults.set(newValue.rawValue, forKey: Key.resolution) }
    }

    var playsSounds: Bool {
        get { defaults.bool(forKey: Key.playsSounds) }
        set { defaults.set(newValue, forKey: Key.playsSounds) }
    }

    /// An action's shortcut: the default until changed, nil once cleared.
    func shortcut(for action: Hotkeys.Action) -> Shortcut? {
        guard let data = defaults.data(forKey: Key.shortcut(action)) else {
            return Config.Shortcuts.shortcut(for: action)
        }
        do {
            return try JSONDecoder().decode(Shortcut?.self, from: data)
        } catch {
            return Config.Shortcuts.shortcut(for: action)
        }
    }

    func setShortcut(_ shortcut: Shortcut?, for action: Hotkeys.Action) {
        defaults.set(try? JSONEncoder().encode(shortcut), forKey: Key.shortcut(action))
    }

    /// The folder chosen for screenshots or recordings; nil for the default.
    func saveFolder(for purpose: CapturePurpose) -> URL? {
        defaults.string(forKey: Key.saveFolder(purpose)).map { URL(filePath: $0, directoryHint: .isDirectory) }
    }

    func setSaveFolder(_ folder: URL?, for purpose: CapturePurpose) {
        defaults.set(folder?.path(percentEncoded: false), forKey: Key.saveFolder(purpose))
    }

    var recordingOptions: RecordingOptions {
        RecordingOptions(
            capturesSystemAudio: capturesSystemAudio, capturesMicrophone: capturesMicrophone, showsCursor: showsCursor,
            videoCodec: videoCodec, frameRate: frameRate, resolution: resolution)
    }
}
