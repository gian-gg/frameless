import AVFoundation
import CoreGraphics
import Foundation

/// App-wide constants.
enum Config {
    /// Capture and encoding settings.
    enum Recording {
        static let frameRate = FrameRate.fps60
        static let resolution = Resolution.original
        static let fileType: AVFileType = .mp4
        static let videoCodec = VideoCodec.h264
        static let showsCursor = true
        static let capturesSystemAudio = true
        static let capturesMicrophone = false
        static let finishTimeout: TimeInterval = 5
    }

    /// Where recordings are saved and how they are named.
    enum Output {
        static let folderName = "Frameless"
        static let namePrefix = "Frameless"
        static let dateFormat = "yyyy-MM-dd 'at' HH.mm.ss"
        static let recordingExtension = "mp4"
        static let screenshotExtension = "png"
    }

    /// Sounds and other confirmation after a capture.
    enum Feedback {
        static let playsSounds = true
        static let soundsDirectory =
            "/System/Library/Components/CoreAudio.component/Contents/SharedSupport/SystemSounds/system"
        static let thumbnailSize = CGSize(width: 200, height: 140)
        static let thumbnailMargin: CGFloat = 16
        static let thumbnailDuration: TimeInterval = 5
        static let thumbnailFadeDuration: TimeInterval = 0.2
    }

    /// Copy / Save toolbar shown after a screenshot.
    enum Belt {
        static let gap: CGFloat = 8
        static let buttonSize = CGSize(width: 34, height: 28)
        static let padding: CGFloat = 4
        static let separatorGap: CGFloat = 6
        static let iconSize: CGFloat = 14
        static let cornerRadius: CGFloat = 0
    }

    /// Display and area picker.
    enum Overlay {
        static func displayTitle(_ verb: String) -> String { "Click to \(verb) this display" }
        static func dragHint(_ verb: String) -> String { "Drag to \(verb) an area" }
        static let cancelHint = "Cancel"
        static let windowHint = "Window"
        static func windowTitle(_ verb: String) -> String { "Click a window to \(verb) it" }
        static let screenHint = "Display or area"
        static let windowSymbol = "macwindow"
        static let windowLabelLength = 48
        static let displaySymbol = "display"
        static let dragSymbol = "rectangle.dashed"
        static let hoverDimOpacity: CGFloat = 0.25
        static let idleDimOpacity: CGFloat = 0.5
        static let pillOpacity: CGFloat = 0.75
        static let minimumDrag: CGFloat = 4
        static let minimumWindowSize: CGFloat = 40
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
        static let recordingSymbolName = "record.circle.fill"
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
