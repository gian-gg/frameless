import AppKit
import Carbon.HIToolbox

/// The picker's window on one screen.
final class OverlayWindow: ScreenCoverWindow {
    let overlay: OverlayView

    init(screen: NSScreen, purpose: CapturePurpose) {
        overlay = OverlayView(scale: screen.backingScaleFactor, screenOrigin: screen.frame.origin, purpose: purpose)
        super.init(screen: screen)
        contentView = overlay
        makeFirstResponder(overlay)
    }
}

/// Dims the screen and reports a display click, a dragged area, or a picked window.
final class OverlayView: NSView {
    enum Mode {
        /// Click a display or drag an area.
        case screen
        /// Click the highlighted window.
        case window
    }

    var onFinish: (@MainActor (CaptureSelection.Target) -> Void)?
    var onCancel: (@MainActor () -> Void)?
    var onToggleMode: (@MainActor () -> Void)?
    var onMouseMoved: (@MainActor () -> Void)?

    var isHovered = false {
        didSet { refresh() }
    }
    var mode = Mode.screen {
        didSet {
            anchor = nil
            current = nil
            refresh()
        }
    }
    var highlightedWindow: WindowInfo? {
        didSet { refresh() }
    }

    private let scale: CGFloat
    private let screenOrigin: CGPoint
    private let purpose: CapturePurpose
    private var bar: GlassBar?
    private var barMode: Mode?
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
        guard mode == .screen else { return }
        anchor = convert(event.locationInWindow, from: nil)
        current = anchor
        refresh()
    }

    override func mouseDragged(with event: NSEvent) {
        guard mode == .screen else { return }
        current = convert(event.locationInWindow, from: nil)
        refresh()
    }

    override func mouseUp(with event: NSEvent) {
        guard mode == .screen else {
            if let highlightedWindow { onFinish?(.window(highlightedWindow.id)) }
            return
        }
        current = convert(event.locationInWindow, from: nil)
        let minimum = Config.Overlay.minimumDrag
        guard let rect = selection, rect.width >= minimum, rect.height >= minimum else {
            onFinish?(.display)
            return
        }
        onFinish?(.area(rect))
    }

    override func keyDown(with event: NSEvent) {
        switch Int(event.keyCode) {
        case kVK_Escape:
            onCancel?()
        case kVK_Return, kVK_ANSI_KeypadEnter:
            confirm()
        case kVK_Space where !event.isARepeat:
            onToggleMode?()
        default:
            super.keyDown(with: event)
        }
    }

    /// Return: the hovered display, or the highlighted window in window mode.
    private func confirm() {
        switch mode {
        case .screen: onFinish?(.display)
        case .window: if let highlightedWindow { onFinish?(.window(highlightedWindow.id)) }
        }
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
        let showsBar = isHovered && selection == nil
        if showsBar, barMode != mode { rebuildBar() }
        bar?.isHidden = !showsBar
    }

    /// Rebuilds the bottom bar for the current mode: buttons naming their keys in tooltips, and Cancel.
    private func rebuildBar() {
        bar?.removeFromSuperview()
        let size = ScreenGeometry.evenPixelSize(bounds.size, scale: scale)
        let display = GlassBar.Item(
            icon: Config.Overlay.displayIcon, title: Config.Overlay.displayButton, shortcut: nil,
            toolTip: "\(Config.Overlay.displayTitle(purpose.verb)), \(size.width) × \(size.height) (↩)",
            perform: { [weak self] in self?.onFinish?(.display) })
        let items: [GlassBar.Item] =
            switch mode {
            case .screen:
                [
                    display,
                    .init(
                        icon: Config.Overlay.windowIcon, title: Config.Overlay.windowHint, shortcut: nil,
                        toolTip: "Pick a window (Space)", perform: { [weak self] in self?.onToggleMode?() }),
                ]
            case .window:
                [
                    .init(
                        icon: Config.Overlay.dragIcon, title: Config.Overlay.screenHint, shortcut: nil,
                        toolTip: "Back to display or area (Space)", perform: { [weak self] in self?.onToggleMode?() })
                ]
            }
        let bar = GlassBar(
            items: items, closeToolTip: "\(Config.Overlay.cancelHint) (Esc)",
            close: { [weak self] in self?.onCancel?() })
        addSubview(bar)
        self.bar = bar
        barMode = mode
    }

    /// Shows the pixel size for a drag, or the name and size of the highlighted window.
    private func updateTag() {
        if mode == .screen, let rect = selection {
            let size = ScreenGeometry.evenPixelSize(rect.size, scale: scale)
            sizeTag.show("\(size.width) × \(size.height)")
            sizeTagTarget = rect
        } else if mode == .window, let window = highlightedWindow, let local = visibleFrame(of: window) {
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

    override func draw(_ dirtyRect: NSRect) {
        switch mode {
        case .window:
            drawWindowMode()
        case .screen:
            if let rect = selection {
                drawSelection(rect)
            } else if isHovered {
                drawHoveredDisplay()
            } else {
                NSColor.black.withAlphaComponent(Config.Overlay.idleDimOpacity).setFill()
                bounds.fill()
            }
        }
    }

    private func drawHoveredDisplay() {
        NSColor.black.withAlphaComponent(Config.Style.dimOpacity).setFill()
        bounds.fill()
    }

    private func drawSelection(_ rect: CGRect) {
        NSColor.black.withAlphaComponent(Config.Style.dimOpacity).setFill()
        bounds.fill()
        reveal(rect)
    }

    private func drawWindowMode() {
        NSColor.black.withAlphaComponent(Config.Style.dimOpacity).setFill()
        bounds.fill()
        guard let highlightedWindow, let local = visibleFrame(of: highlightedWindow) else { return }
        reveal(local)
    }

    /// Clears the dim over a rect and frames it with the soft line and round handles.
    private func reveal(_ rect: CGRect) {
        NSColor.clear.setFill()
        rect.fill(using: .copy)
        Panel.drawSelectionFrame(rect)
    }
}
