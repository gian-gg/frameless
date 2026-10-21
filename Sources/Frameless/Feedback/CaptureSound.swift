import AppKit

/// macOS's own capture sounds, played when a screenshot is taken or a recording starts or is saved.
@MainActor
enum CaptureSound: CaseIterable {
    case screenshot
    case recordingStarted
    case recordingSaved

    private static var loaded: [CaptureSound: NSSound] = [:]

    private var fileName: String {
        switch self {
        case .screenshot: "Screen Capture.aif"
        case .recordingStarted: "begin_record.caf"
        case .recordingSaved: "end_record.caf"
        }
    }

    var url: URL {
        URL(filePath: Config.Feedback.soundsDirectory).appending(path: fileName)
    }

    /// Plays the sound; loads it once and keeps it for later plays.
    func play() {
        if Self.loaded[self] == nil {
            Self.loaded[self] = NSSound(contentsOf: url, byReference: true)
        }
        Self.loaded[self]?.stop()
        Self.loaded[self]?.play()
    }
}
