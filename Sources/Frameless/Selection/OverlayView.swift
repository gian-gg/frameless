import AppKit
import Carbon.HIToolbox

/// Borderless, key-capable window covering one screen.
final class OverlayWindow: NSWindow {
    let overlay: OverlayView

    init(screen: NSScreen) {
        overlay = OverlayView(scale: screen.backingScaleFactor, screenOrigin: screen.frame.origin)
        super.init(contentRect: screen.frame, styleMask: .borderless, backing: .buffered, defer: false)
        setFrame(screen.frame, display: false)
        level = .screenSaver
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        ignoresMouseEvents = false
        isReleasedWhenClosed = false
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        contentView = overlay
        makeFirstResponder(overlay)
    }

    override var canBecomeKey: Bool { true }

    /// Orders the window in and fades it from transparent.
    func fadeIn() {
        alphaValue = 0
        orderFrontRegardless()
        NSAnimationContext.runAnimationGroup { context in
            context.duration = Config.Overlay.fadeDuration
            animator().alphaValue = 1
        }
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

    private enum Layout {
        static let labelPadding = CGSize(width: 10, height: 4)
        static let labelGap: CGFloat = 6
        static let hoverBorderWidth: CGFloat = 4
    }

    var onFinish: (@MainActor (CaptureSelection.Target) -> Void)?
    var onCancel: (@MainActor () -> Void)?
    var onToggleMode: (@MainActor () -> Void)?
    var onMouseMoved: (@MainActor () -> Void)?

    var isHovered = false {
        didSet { needsDisplay = true }
    }
    var mode = Mode.screen {
        didSet {
            anchor = nil
            current = nil
            needsDisplay = true
        }
    }
    var highlightedWindow: WindowInfo? {
        didSet { needsDisplay = true }
    }

    private let scale: CGFloat
    private let screenOrigin: CGPoint
    private var anchor: CGPoint?
    private var current: CGPoint?

    init(scale: CGFloat, screenOrigin: CGPoint) {
        self.scale = scale
        self.screenOrigin = screenOrigin
        super.init(frame: .zero)
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
        needsDisplay = true
    }

    override func mouseDragged(with event: NSEvent) {
        guard mode == .screen else { return }
        current = convert(event.locationInWindow, from: nil)
        needsDisplay = true
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
        case kVK_Space where !event.isARepeat:
            onToggleMode?()
        default:
            super.keyDown(with: event)
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
        NSColor.black.withAlphaComponent(Config.Overlay.hoverDimOpacity).setFill()
        bounds.fill()

        let inset = Layout.hoverBorderWidth / 2
        let border = NSBezierPath(rect: bounds.insetBy(dx: inset, dy: inset))
        border.lineWidth = Layout.hoverBorderWidth
        NSColor.white.withAlphaComponent(0.7).setStroke()
        border.stroke()

        let size = ScreenGeometry.evenPixelSize(bounds.size, scale: scale)
        HintCard.display(pixelWidth: size.width, pixelHeight: size.height).draw(centeredIn: bounds)
    }

    private func drawSelection(_ rect: CGRect) {
        NSColor.black.withAlphaComponent(Config.Overlay.hoverDimOpacity).setFill()
        bounds.fill()
        reveal(rect)
        let size = ScreenGeometry.evenPixelSize(rect.size, scale: scale)
        drawLabel("\(size.width) × \(size.height)", above: rect)
    }

    private func drawWindowMode() {
        NSColor.black.withAlphaComponent(Config.Overlay.hoverDimOpacity).setFill()
        bounds.fill()

        guard let highlightedWindow else {
            if isHovered { HintCard.windowMode().draw(centeredIn: bounds) }
            return
        }
        let local = highlightedWindow.frame.offsetBy(dx: -screenOrigin.x, dy: -screenOrigin.y).intersection(bounds)
        guard !local.isNull, !local.isEmpty else { return }
        reveal(local)
        let size = ScreenGeometry.evenPixelSize(highlightedWindow.frame.size, scale: scale)
        drawLabel("\(highlightedWindow.displayName)   \(size.width) × \(size.height)", above: local)
    }

    /// Clears the dim over a rect and outlines it in white on a dark hairline.
    private func reveal(_ rect: CGRect) {
        NSColor.clear.setFill()
        rect.fill(using: .copy)

        let outer = NSBezierPath(rect: rect.insetBy(dx: -0.5, dy: -0.5))
        outer.lineWidth = 1
        NSColor.black.withAlphaComponent(0.4).setStroke()
        outer.stroke()
        let inner = NSBezierPath(rect: rect.insetBy(dx: 0.5, dy: 0.5))
        inner.lineWidth = 1
        NSColor.white.setStroke()
        inner.stroke()
    }

    /// Draws a pill label above a rect's top-left corner, or inside it at the top edge of the screen.
    private func drawLabel(_ string: String, above rect: CGRect) {
        let label = OverlayDrawing.text(string, size: 12, weight: .medium, monospaced: true)
        let textSize = label.size()
        let pill = CGSize(
            width: ceil(textSize.width) + Layout.labelPadding.width * 2,
            height: ceil(textSize.height) + Layout.labelPadding.height * 2)
        var origin = CGPoint(x: rect.minX, y: rect.maxY + Layout.labelGap)
        if origin.y + pill.height > bounds.maxY {
            origin.y = rect.maxY - pill.height - Layout.labelGap
            origin.x += Layout.labelGap
        }
        origin.x = min(max(origin.x, bounds.minX), bounds.maxX - pill.width)
        OverlayDrawing.fillPill(CGRect(origin: origin, size: pill))
        label.draw(at: CGPoint(x: origin.x + Layout.labelPadding.width, y: origin.y + Layout.labelPadding.height))
    }
}
