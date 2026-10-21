import AVFoundation
import AppKit
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
        /// Glass rim around the thumbnail's preview.
        static let thumbnailRim: CGFloat = 5
        static let thumbnailDuration: TimeInterval = 5
        static let thumbnailFadeDuration: TimeInterval = 0.2
    }

    /// The shared look: corners, dims, panels and fades used across the picker, belt and thumbnail.
    enum Style {
        /// Rounding for non-capsule surfaces such as the thumbnail; bars and tags are full capsules.
        static let cornerRadius: CGFloat = 12
        /// Dim over the screen around the active display, selection or capture.
        static let dimOpacity: CGFloat = 0.3
        static let hairlineOpacity: CGFloat = 0.14
        /// Dark tint on Liquid Glass so busy content behind it doesn't compete with its labels.
        static let glassTintOpacity: CGFloat = 0.35
        static let handleSize: CGFloat = 9
        static let tagPadding = CGSize(width: 10, height: 4)
        /// Gap between a selection's top edge and its size tag.
        static let tagLift: CGFloat = 8
        static let fadeDuration: TimeInterval = 0.12
        /// Distance from the screen's bottom edge to the hint bar and the belt.
        static let barBottomOffset: CGFloat = 56
    }

    /// Glass bars at the bottom of the screen: the picker's and the belt's.
    enum Bar {
        /// Height of one item; the capsule adds `padding` around it.
        static let itemHeight: CGFloat = 26
        /// Space inside an item on each side of its content.
        static let itemPadding: CGFloat = 10
        /// Space between an item's icon, label and shortcut.
        static let innerGap: CGFloat = 6
        static let padding: CGFloat = 4
        /// Space between the capsule and the round close button.
        static let closeGap: CGFloat = 8
        /// Space between a capture and the belt under it.
        static let selectionGap: CGFloat = 10
        static let iconSize: CGFloat = 12
        static let titleSize: CGFloat = 12
        static let shortcutSize: CGFloat = 11
    }

    /// Display and area picker.
    enum Overlay {
        static func displayTitle(_ verb: String) -> String { "Click to \(verb) this display" }
        static let cancelHint = "Cancel"
        static let windowHint = "Window"
        static let displayButton = "Display"
        static let screenHint = "Display or area"
        static let windowSymbol = "macwindow"
        static let windowLabelLength = 48
        static let displaySymbol = "display"
        static let dragSymbol = "rectangle.dashed"
        static let idleDimOpacity: CGFloat = 0.5
        static let minimumDrag: CGFloat = 4
        static let minimumWindowSize: CGFloat = 40
    }

    /// Dim around an area while it records.
    enum Outline {
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
