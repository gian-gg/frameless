import AppKit
import Carbon.HIToolbox

/// A floating bar's window, kept out of captures; takes Return and Esc without taking focus from the app beneath.
final class BarPanel: NSPanel {
    var onKey: (@MainActor (Bool) -> Void)?

    init(frame: CGRect) {
        super.init(contentRect: frame, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        level = .statusBar
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        hidesOnDeactivate = false
        sharingType = .none
        isReleasedWhenClosed = false
        animationBehavior = .none
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
    }

    override var canBecomeKey: Bool { true }

    override func keyDown(with event: NSEvent) {
        switch Int(event.keyCode) {
        case kVK_Return, kVK_ANSI_KeypadEnter: onKey?(true)
        case kVK_Escape: onKey?(false)
        default: super.keyDown(with: event)
        }
    }
}
