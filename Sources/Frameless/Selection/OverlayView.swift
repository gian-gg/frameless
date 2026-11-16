import AppKit
import Carbon.HIToolbox

/// The picker's window on one screen, over the frozen screen once it's captured.
final class OverlayWindow: ScreenCoverWindow {
    let overlay: OverlayView
    private let frozen = NSView()

    init(screen: NSScreen, purpose: CapturePurpose) {
        overlay = OverlayView(scale: screen.backingScaleFactor, screenOrigin: screen.frame.origin, purpose: purpose)
        super.init(screen: screen)
        let container = NSView(frame: CGRect(origin: .zero, size: screen.frame.size))
        for view in [frozen, overlay] {
            view.frame = container.bounds
            view.autoresizingMask = [.width, .height]
            container.addSubview(view)
        }
        frozen.wantsLayer = true
        contentView = container
        makeFirstResponder(overlay)
    }

    /// Shows the frozen screen under the dim instead of the live one.
    func showFrozen(_ image: CGImage) {
        frozen.layer?.contents = image
    }
}

/// Dims the screen and reports a clicked window, a dragged area, or the display.
final class OverlayView: NSView {
    var onFinish: (@MainActor (CaptureSelection.Target) -> Void)?
    var onCancel: (@MainActor () -> Void)?
    var onMouseMoved: (@MainActor () -> Void)?

    var isHovered = false {
        didSet { refresh() }
    }
    var highlightedWindow: WindowInfo? {
        didSet { refresh() }
    }

    private let scale: CGFloat
    private let screenOrigin: CGPoint
    private let purpose: CapturePurpose
    private var bar: GlassBar?
    private let sizeTag = GlassTag()
    private var sizeTagTarget: CGRect?
    private var anchor: CGPoint?
    private var current: CGPoint?

    init(scale: CGFloat, screenOrigin: CGPoint, purpose: CapturePurpose) {
        self.scale = scale
        self.screenOrigin = screenOrigin
        self.purpose = purpose
        super.init(frame: .zero)
        sizeTag.isHidden = true
        addSubview(sizeTag)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { nil }

    override var acceptsFirstResponder: Bool { true }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    // MARK: - Events

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        trackingAreas.forEach(removeTrackingArea)
        let options: NSTrackingArea.Options = [
            .mouseEnteredAndExited, .mouseMoved, .cursorUpdate, .activeAlways, .inVisibleRect,
        ]
        addTrackingArea(NSTrackingArea(rect: .zero, options: options, owner: self))
    }

    override func cursorUpdate(with event: NSEvent) {
        NSCursor.crosshair.set()
    }

    override func mouseMoved(with event: NSEvent) {
        NSCursor.crosshair.set()
        onMouseMoved?()
    }

    override func mouseEntered(with event: NSEvent) {
        isHovered = true
        window?.makeKey()
        onMouseMoved?()
    }

    override func mouseExited(with event: NSEvent) {
        isHovered = false
    }

    override func mouseDown(with event: NSEvent) {
        anchor = convert(event.locationInWindow, from: nil)
        current = anchor
        refresh()
    }

    override func mouseDragged(with event: NSEvent) {
        current = convert(event.locationInWindow, from: nil)
        refresh()
    }

    override func mouseUp(with event: NSEvent) {
        current = convert(event.locationInWindow, from: nil)
        onFinish?(Self.target(area: draggedArea, window: highlightedWindow))
    }

    /// What a mouse release picks: a dragged area, else the highlighted window, else the display.
    static func target(area: CGRect?, window: WindowInfo?) -> CaptureSelection.Target {
        if let area { return .area(area) }
        if let window { return .window(window.id) }
        return .display
    }

    override func keyDown(with event: NSEvent) {
        switch Int(event.keyCode) {
        case kVK_Escape:
            onCancel?()
        case kVK_Return, kVK_ANSI_KeypadEnter:
            onFinish?(.display)
        default:
            super.keyDown(with: event)
        }
    }

    /// The dragged rect once it's big enough to count as an area rather than a click.
    private var draggedArea: CGRect? {
        let minimum = Config.Overlay.minimumDrag
        guard let rect = selection, rect.width >= minimum, rect.height >= minimum else { return nil }
        return rect
    }

    private var selection: CGRect? {
        guard let anchor, let current else { return nil }
        let rect = CGRect(
            x: min(anchor.x, current.x), y: min(anchor.y, current.y),
            width: abs(current.x - anchor.x), height: abs(current.y - anchor.y))
        let clamped = rect.intersection(bounds)
        return clamped.isNull || clamped.isEmpty ? nil : clamped
    }

    // MARK: - Hint bar

    /// Redraws and updates the size tag and the hint bar, shown on the hovered screen while nothing is dragged.
    private func refresh() {
        needsDisplay = true
        needsLayout = true
        updateTag()
        let showsBar = isHovered && draggedArea == nil
        if showsBar, bar == nil { buildBar() }
        bar?.isHidden = !showsBar
    }

    /// Builds the bottom bar: the display button naming its key in its tooltip, and Cancel.
    private func buildBar() {
        let size = ScreenGeometry.evenPixelSize(bounds.size, scale: scale)
        let display = GlassBar.Item(
            icon: Config.Overlay.displayIcon, title: Config.Overlay.displayButton, shortcut: nil,
            toolTip: "\(Config.Overlay.displayTitle(purpose.verb)), \(size.width) × \(size.height) (↩)",
            perform: { [weak self] in self?.onFinish?(.display) })
        let bar = GlassBar(
            items: [display], closeToolTip: "\(Config.Overlay.cancelHint) (Esc)",
            close: { [weak self] in self?.onCancel?() })
        addSubview(bar)
        self.bar = bar
    }

    /// Shows the pixel size for a drag, or the name and size of the highlighted window.
    private func updateTag() {
        if let rect = draggedArea {
            let size = ScreenGeometry.evenPixelSize(rect.size, scale: scale)
            sizeTag.show("\(size.width) × \(size.height)")
            sizeTagTarget = rect
        } else if let window = highlightedWindow, let local = visibleFrame(of: window) {
            let size = ScreenGeometry.evenPixelSize(window.frame.size, scale: scale)
            sizeTag.show("\(window.displayName)   \(size.width) × \(size.height)")
            sizeTagTarget = local
        } else {
            sizeTagTarget = nil
        }
        sizeTag.isHidden = sizeTagTarget == nil
    }

    private func visibleFrame(of window: WindowInfo) -> CGRect? {
        let local = window.frame.offsetBy(dx: -screenOrigin.x, dy: -screenOrigin.y).intersection(bounds)
        return local.isNull || local.isEmpty ? nil : local
    }

    override func layout() {
        super.layout()
        if let bar {
            bar.setFrameOrigin(
                CGPoint(
                    x: (bounds.midX - bar.frame.width / 2).rounded(), y: bounds.minY + Config.Style.barBottomOffset))
        }
        if let sizeTagTarget {
            sizeTag.setFrameOrigin(
                ScreenGeometry.tagOrigin(
                    for: sizeTag.frame.size, on: sizeTagTarget, in: bounds, lift: Config.Style.tagLift))
        }
    }

    // MARK: - Drawing

    /// Reveals the dragged area, else the highlighted window, over the dim.
    override func draw(_ dirtyRect: NSRect) {
        let revealed = draggedArea ?? highlightedWindow.flatMap(visibleFrame(of:))
        let opacity = revealed != nil || isHovered ? Config.Style.dimOpacity : Config.Overlay.idleDimOpacity
        NSColor.black.withAlphaComponent(opacity).setFill()
        bounds.fill()
        if let revealed { reveal(revealed) }
    }

    /// Clears the dim over a rect and frames it with the soft line and round handles.
    private func reveal(_ rect: CGRect) {
        NSColor.clear.setFill()
        rect.fill(using: .copy)
        Panel.drawSelectionFrame(rect)
    }
}
