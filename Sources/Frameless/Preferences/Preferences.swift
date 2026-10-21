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

    var recordingOptions: RecordingOptions {
        RecordingOptions(
            capturesSystemAudio: capturesSystemAudio, capturesMicrophone: capturesMicrophone, showsCursor: showsCursor,
            videoCodec: videoCodec, frameRate: frameRate)
    }
}
