import AppKit

/// Click-through outline drawn just outside the area being recorded.
@MainActor
final class AreaOutline {
    private var window: NSWindow?

    /// Shows the outline around a rect in global AppKit coordinates.
    func show(around rect: CGRect) {
        hide()
        let window = NSWindow(
            contentRect: rect.insetBy(dx: -Config.Outline.gap, dy: -Config.Outline.gap), styleMask: .borderless,
            backing: .buffered,
            defer: false)
        window.level = .statusBar
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = false
        window.ignoresMouseEvents = true
        window.isReleasedWhenClosed = false
        window.sharingType = .none
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        window.contentView = OutlineView()
        window.orderFrontRegardless()
        self.window = window
    }

    func hide() {
        window?.orderOut(nil)
        window = nil
    }
}

/// Strokes a thin red border along its bounds.
private final class OutlineView: NSView {
    override func draw(_ dirtyRect: NSRect) {
        NSColor.systemRed.withAlphaComponent(0.9).setStroke()
        let path = NSBezierPath(
            rect: bounds.insetBy(dx: Config.Outline.lineWidth / 2, dy: Config.Outline.lineWidth / 2))
        path.lineWidth = Config.Outline.lineWidth
        path.stroke()
    }
}
