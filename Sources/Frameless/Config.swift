import AVFoundation
import CoreGraphics
import Foundation

/// App-wide constants.
enum Config {
    /// Capture and encoding settings.
    enum Recording {
        static let maxFramesPerSecond: Int32 = 60
        static let fileType: AVFileType = .mp4
        static let videoCodec: AVVideoCodecType = .h264
        static let showsCursor = true
        static let capturesSystemAudio = true
    }

    /// Where recordings are saved and how they are named.
    enum Output {
        static let folderName = "Frameless"
        static let namePrefix = "Frameless"
        static let dateFormat = "yyyy-MM-dd 'at' HH.mm.ss"
        static let fileExtension = "mp4"
    }

    /// Display and area picker.
    enum Overlay {
        static let hint = "Click a screen to record it  ·  Drag to record an area  ·  Esc to cancel"
        static let dimOpacity: CGFloat = 0.3
        static let minimumDrag: CGFloat = 4
        static let badgeFontSize: CGFloat = 13
        static let badgeOpacity: CGFloat = 0.7
    }

    /// Outline around a recorded area.
    enum Outline {
        static let gap: CGFloat = 3
        static let lineWidth: CGFloat = 2
    }

    /// Menu bar item.
    enum StatusItem {
        static let symbolName = "record.circle"
        static let timerInterval: TimeInterval = 1
    }

    /// System Settings deep links.
    enum Links {
        static let screenRecordingSettings = URL(
            string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture")
    }
}
