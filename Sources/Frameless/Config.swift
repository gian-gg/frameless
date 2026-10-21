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
        static let capturesMicrophone = false
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
        static let displayTitle = "Click to record this display"
        static let dragHint = "Drag to record an area"
        static let cancelHint = "Cancel"
        static let displaySymbol = "display"
        static let dragSymbol = "rectangle.dashed"
        static let hoverDimOpacity: CGFloat = 0.25
        static let idleDimOpacity: CGFloat = 0.5
        static let pillOpacity: CGFloat = 0.75
        static let minimumDrag: CGFloat = 4
        static let fadeDuration: TimeInterval = 0.12
    }

    /// Viewfinder around a recorded area.
    enum Outline {
        static let gap: CGFloat = 4
        static let cornerLength: CGFloat = 18
        static let cornerWidth: CGFloat = 3
        static let dimOpacity: CGFloat = 0.2
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
        static let microphoneSettings = URL(
            string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone")
    }
}
