import AppKit
import Carbon.HIToolbox

/// Borderless, key-capable window covering one screen.
final class OverlayWindow: NSWindow {
    let overlay: OverlayView

    init(screen: NSScreen) {
        overlay = OverlayView(scale: screen.backingScaleFactor)
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

/// Dims the screen, highlights it on hover and reports a click (nil) or a dragged rect.
final class OverlayView: NSView {
    private enum Layout {
        static let labelPadding = CGSize(width: 10, height: 4)
        static let sizeLabelGap: CGFloat = 6
        static let hoverBorderWidth: CGFloat = 4
    }

    var onFinish: (@MainActor (CGRect?) -> Void)?
    var onCancel: (@MainActor () -> Void)?
    var isHovered = false {
        didSet { needsDisplay = true }
    }

    private let scale: CGFloat
    private var anchor: CGPoint?
    private var current: CGPoint?

    init(scale: CGFloat) {
        self.scale = scale
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
    }

    override func mouseEntered(with event: NSEvent) {
        isHovered = true
        window?.makeKey()
    }

    override func mouseExited(with event: NSEvent) {
        isHovered = false
    }

    override func mouseDown(with event: NSEvent) {
        anchor = convert(event.locationInWindow, from: nil)
        current = anchor
        needsDisplay = true
    }

    override func mouseDragged(with event: NSEvent) {
        current = convert(event.locationInWindow, from: nil)
        needsDisplay = true
    }

    override func mouseUp(with event: NSEvent) {
        current = convert(event.locationInWindow, from: nil)
        let minimum = Config.Overlay.minimumDrag
        guard let rect = selection, rect.width >= minimum, rect.height >= minimum else {
            onFinish?(nil)
            return
        }
        onFinish?(rect)
    }

    override func keyDown(with event: NSEvent) {
        guard event.keyCode == UInt16(kVK_Escape) else { return super.keyDown(with: event) }
        onCancel?()
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
        if let rect = selection {
            drawSelection(rect)
        } else if isHovered {
            drawHoveredDisplay()
        } else {
            NSColor.black.withAlphaComponent(Config.Overlay.idleDimOpacity).setFill()
            bounds.fill()
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
        DisplayHintCard(pixelWidth: size.width, pixelHeight: size.height).draw(centeredIn: bounds)
    }

    private func drawSelection(_ rect: CGRect) {
        NSColor.black.withAlphaComponent(Config.Overlay.hoverDimOpacity).setFill()
        bounds.fill()
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

        let size = ScreenGeometry.evenPixelSize(rect.size, scale: scale)
        let label = OverlayDrawing.text("\(size.width) × \(size.height)", size: 12, weight: .medium, monospaced: true)
        let textSize = label.size()
        let pill = CGSize(
            width: ceil(textSize.width) + Layout.labelPadding.width * 2,
            height: ceil(textSize.height) + Layout.labelPadding.height * 2)
        var origin = CGPoint(x: rect.minX, y: rect.maxY + Layout.sizeLabelGap)
        if origin.y + pill.height > bounds.maxY {
            origin.y = rect.maxY - pill.height - Layout.sizeLabelGap
            origin.x += Layout.sizeLabelGap
        }
        origin.x = min(max(origin.x, bounds.minX), bounds.maxX - pill.width)
        OverlayDrawing.fillPill(CGRect(origin: origin, size: pill))
        label.draw(at: CGPoint(x: origin.x + Layout.labelPadding.width, y: origin.y + Layout.labelPadding.height))
    }
}
