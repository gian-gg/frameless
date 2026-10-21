import Foundation

/// User-adjustable settings persisted in UserDefaults, defaulting to Config values.
@MainActor
final class Preferences {
    private enum Key {
        static let capturesSystemAudio = "capturesSystemAudio"
        static let capturesMicrophone = "capturesMicrophone"
        static let showsCursor = "showsCursor"
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        defaults.register(defaults: [
            Key.capturesSystemAudio: Config.Recording.capturesSystemAudio,
            Key.capturesMicrophone: Config.Recording.capturesMicrophone,
            Key.showsCursor: Config.Recording.showsCursor,
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

    var recordingOptions: RecordingOptions {
        RecordingOptions(
            capturesSystemAudio: capturesSystemAudio, capturesMicrophone: capturesMicrophone, showsCursor: showsCursor)
    }
}
