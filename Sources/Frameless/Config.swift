import AVFoundation
import AppKit
import Carbon.HIToolbox
import CoreGraphics
import Foundation

/// App-wide constants.
enum Config {
    /// Default global shortcuts, beside macOS's own ⇧⌘3/4/5.
    enum Shortcuts {
        static let screenshot = Shortcut(keyCode: UInt32(kVK_ANSI_2), modifiers: [.shift, .command])
        static let record = Shortcut(keyCode: UInt32(kVK_ANSI_6), modifiers: [.shift, .command])

        static func shortcut(for action: Hotkeys.Action) -> Shortcut {
            switch action {
            case .screenshot: screenshot
            case .record: record
            }
        }
    }

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
        /// Glass circles on the thumbnail: the play badge and the hover close button.
        static let badgeSize: CGFloat = 36
        static let closeSize: CGFloat = 24
        static let thumbnailDuration: TimeInterval = 5
        static let thumbnailFadeDuration: TimeInterval = 0.2
    }

    /// Marks drawn on a frozen screenshot.
    enum Annotate {
        static let defaultColor = MarkColor.white
        /// A soft halo behind each mark, dark or light against its colour.
        static let shadowBlur: CGFloat = 2
        static let shadowOpacity: CGFloat = 0.5
        static let defaultWeight = MarkWeight.medium
        /// How close a click must be to a line to pick it, and the selection outline's gap and dash.
        static let hitTolerance: CGFloat = 6
        static let selectionInset: CGFloat = 4
        static let selectionDash: [CGFloat] = [4, 3]
        /// The gap a text field leaves before its first letter.
        static let textFieldInset: CGFloat = 2
        /// A step's number as a share of its circle's width.
        static let stepTextShare: CGFloat = 0.55
        /// The size of a pixelated block, in points, on a grid fixed to the image.
        static let pixelateBlock: CGFloat = 12
        /// How dark the capture gets outside highlighted areas, and the light edge and soft shadow around each area.
        static let spotlightDim: CGFloat = 0.4
        static let spotlightEdgeWidth: CGFloat = 1
        static let spotlightEdgeOpacity: CGFloat = 0.4
        static let spotlightShadowBlur: CGFloat = 10
        static let spotlightShadowOpacity: CGFloat = 0.6
        static let cornerRadius: CGFloat = 3
        /// An arrowhead's arms: this many line widths long, at most this share of the arrow, at this angle.
        static let arrowHeadWidths: CGFloat = 4
        static let arrowHeadShare: CGFloat = 0.4
        static let arrowHeadAngle: CGFloat = .pi / 6
        /// Drags shorter than this, in points, are clicks and leave no mark.
        static let minimumDrag: CGFloat = 3
        /// The least distance between recorded points of a freehand stroke.
        static let freehandSpacing: CGFloat = 2
    }

    /// Scrolling screenshots stitched from frames.
    enum Scroll {
        /// The strips each row is split into across, and the share of detailed strips that must line up.
        static let strips = 8
        static let matchShare = 0.6
        /// A weaker share that still counts when no other shift comes within half of it.
        static let clearMatchShare = 0.25
        static let framesPerSecond: Int32 = 30
        /// A frame counts as scrolled only when at least 1 in this many of its rows changed.
        static let minimumMovingShare = 3
        /// The tallest a stitched image may grow, in pixels.
        static let maxHeight = 20_000
        /// The live preview beside the area: its width and gap.
        static let previewWidth: CGFloat = 140
        static let previewGap: CGFloat = 12
    }

    /// Screenshots pinned on screen.
    enum Pin {
        static let cornerRadius: CGFloat = 6
        static let closeSize: CGFloat = 24
        /// Gap between the pin's top-left corner and its close button.
        static let closeInset: CGFloat = 6
        static let minZoom: CGFloat = 0.25
        static let maxZoom: CGFloat = 4
        static let minOpacity: CGFloat = 0.2
        /// Zoom and opacity presets in the pin's right-click menu, in percent.
        static let zoomChoices = [200, 100, 50]
        static let opacityChoices = [100, 75, 50]
        /// How long the zoom or opacity tag stays up after the last change.
        static let tagDuration: TimeInterval = 1
    }

    /// The shared look: corners, dims, panels and fades used across the picker, selection editor and thumbnail.
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
        /// Distance from the screen's bottom edge to the picker's bar.
        static let barBottomOffset: CGFloat = 56
    }

    /// Glass bars at the bottom of the screen: the picker's and the selection editor's.
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
        /// Space between a selection and the editor's bar under it.
        static let selectionGap: CGFloat = 16
        static let iconSize: CGFloat = 14
        /// Width of each icon-only tool button.
        static let toolWidth: CGFloat = 32
        static let swatchRingOpacity: CGFloat = 0.5
        /// The glass lens behind a selected button: its tint and how long it takes to slide.
        static let lensTintOpacity: CGFloat = 0.12
        static let lensDuration: TimeInterval = 0.25
        /// The fainter lens under the hovered button, and how long it lingers after the pointer leaves.
        static let hoverLensTintOpacity: CGFloat = 0.06
        static let hoverLensGrace: TimeInterval = 0.06
        /// Gap between a style button and its row of choices above it.
        static let styleRowGap: CGFloat = 8
        /// Tool icons are dimmed to this until selected; the selected one sits on this brighter pill.
        static let unselectedToolOpacity: CGFloat = 0.7
        static let selectedFillOpacity: CGFloat = 0.3
        static let titleSize: CGFloat = 12
        static let shortcutSize: CGFloat = 11
        /// How long a button is hovered before its tooltip shows, and its gap from the button.
        static let tipDelay: TimeInterval = 0.5
        static let tipGap: CGFloat = 10
    }

    /// Display and area picker.
    enum Overlay {
        static func displayTitle(_ verb: String) -> String { "Click to \(verb) this display" }
        static let cancelHint = "Cancel"
        static let windowHint = "Window"
        static let displayButton = "Display"
        static let screenHint = "Display or area"
        static let windowIcon = LucideIcon.appWindow
        static let windowLabelLength = 48
        static let displayIcon = LucideIcon.monitor
        static let dragIcon = LucideIcon.squareDashed
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
