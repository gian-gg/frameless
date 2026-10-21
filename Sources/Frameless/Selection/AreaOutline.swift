import AppKit

/// Click-through frame around the area being recorded, dimming the rest of its display.
@MainActor
final class AreaOutline {
    private var window: NSWindow?

    /// Shows the viewfinder for an area selection; whole-display selections show nothing.
    func show(_ selection: CaptureSelection) {
        hide()
        guard let area = selection.area else { return }
        let window = NSWindow(
            contentRect: selection.screenFrame, styleMask: .borderless, backing: .buffered, defer: false)
        window.setFrame(selection.screenFrame, display: false)
        window.level = .floating
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = false
        window.ignoresMouseEvents = true
        window.isReleasedWhenClosed = false
        window.sharingType = .none
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        window.contentView = ViewfinderView(area: area)
        window.orderFrontRegardless()
        self.window = window
    }

    func hide() {
        window?.orderOut(nil)
        window = nil
    }
}

/// Dims outside the area and frames it like the picker's selection: soft line and round handles.
private final class ViewfinderView: NSView {
    private let area: CGRect

    init(area: CGRect) {
        self.area = area
        super.init(frame: .zero)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { nil }

    override func draw(_ dirtyRect: NSRect) {
        NSColor.black.withAlphaComponent(Config.Outline.dimOpacity).setFill()
        bounds.fill()
        NSColor.clear.setFill()
        area.fill(using: .copy)
        Panel.drawSelectionFrame(area)
    }
}
