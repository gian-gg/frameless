import AppKit
import Carbon.HIToolbox

/// What to record: a whole display, or an area of it in the screen's local AppKit points.
struct CaptureSelection: Equatable {
    let displayID: CGDirectDisplayID
    let screenFrame: CGRect
    let area: CGRect?

    /// The area in global AppKit coordinates.
    var globalArea: CGRect? {
        area?.offsetBy(dx: screenFrame.minX, dy: screenFrame.minY)
    }
}

/// Full-screen overlay that lets the user pick a display or region.
@MainActor
final class AreaSelector {
    private var windows: [OverlayWindow] = []
    private var continuation: CheckedContinuation<CaptureSelection?, Never>?

    /// Shows the overlay on every display; nil when cancelled.
    func select() async -> CaptureSelection? {
        guard continuation == nil else { return nil }
        return await withCheckedContinuation { continuation in
            self.continuation = continuation
            showOverlays()
        }
    }

    private func showOverlays() {
        windows = NSScreen.screens.compactMap { screen in
            guard let displayID = screen.displayID else { return nil }
            let frame = screen.frame
            let window = OverlayWindow(screen: screen)
            window.overlay.onFinish = { [weak self] area in
                self?.finish(CaptureSelection(displayID: displayID, screenFrame: frame, area: area))
            }
            window.overlay.onCancel = { [weak self] in self?.finish(nil) }
            return window
        }
        guard !windows.isEmpty else { return finish(nil) }

        NSApp.activate()
        for window in windows { window.orderFrontRegardless() }
        let mouse = NSEvent.mouseLocation
        (windows.first { $0.frame.contains(mouse) } ?? windows.first)?.makeKey()
    }

    private func finish(_ selection: CaptureSelection?) {
        for window in windows { window.orderOut(nil) }
        windows = []
        continuation?.resume(returning: selection)
        continuation = nil
    }
}

extension NSScreen {
    var displayID: CGDirectDisplayID? {
        deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID
    }
}

/// Borderless, key-capable window covering one screen.
private final class OverlayWindow: NSWindow {
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
}

/// Dims the screen, tracks the drag and reports a click (nil) or a dragged rect.
private final class OverlayView: NSView {
    private static let minimumDrag: CGFloat = 4
    private static let hint = "Click a screen to record it  ·  Drag to record an area  ·  Esc to cancel"

    var onFinish: (@MainActor (CGRect?) -> Void)?
    var onCancel: (@MainActor () -> Void)?

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

    override func resetCursorRects() {
        addCursorRect(bounds, cursor: .crosshair)
    }

    private var selection: CGRect? {
        guard let anchor, let current else { return nil }
        let rect = CGRect(
            x: min(anchor.x, current.x), y: min(anchor.y, current.y),
            width: abs(current.x - anchor.x), height: abs(current.y - anchor.y))
        let clamped = rect.intersection(bounds)
        return clamped.isNull ? nil : clamped
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
        guard let rect = selection, rect.width >= Self.minimumDrag, rect.height >= Self.minimumDrag else {
            onFinish?(nil)
            return
        }
        onFinish?(rect)
    }

    override func keyDown(with event: NSEvent) {
        guard event.keyCode == UInt16(kVK_Escape) else { return super.keyDown(with: event) }
        onCancel?()
    }

    override func draw(_ dirtyRect: NSRect) {
        NSColor.black.withAlphaComponent(0.3).setFill()
        bounds.fill()

        guard let rect = selection, rect.width > 0, rect.height > 0 else {
            let badge = badgeFrame(for: text(Self.hint))
            drawBadge(text(Self.hint), in: badge.offsetBy(dx: bounds.midX - badge.midX, dy: bounds.midY - badge.midY))
            return
        }
        NSColor.clear.setFill()
        rect.fill(using: .copy)
        NSColor.white.setStroke()
        let border = NSBezierPath(rect: rect.insetBy(dx: 0.5, dy: 0.5))
        border.lineWidth = 1
        border.stroke()

        let size = ScreenGeometry.evenPixelSize(rect.size, scale: scale)
        let label = text("\(size.width) × \(size.height)")
        var badge = badgeFrame(for: label).offsetBy(dx: rect.minX, dy: rect.minY - 30)
        if badge.minY < bounds.minY { badge = badge.offsetBy(dx: 0, dy: 36) }
        drawBadge(label, in: badge)
    }

    private func text(_ string: String) -> NSAttributedString {
        NSAttributedString(
            string: string,
            attributes: [
                .font: NSFont.monospacedDigitSystemFont(ofSize: 13, weight: .medium),
                .foregroundColor: NSColor.white,
            ])
    }

    private func badgeFrame(for text: NSAttributedString) -> CGRect {
        let size = text.size()
        return CGRect(x: 0, y: 0, width: size.width + 20, height: size.height + 10)
    }

    private func drawBadge(_ text: NSAttributedString, in frame: CGRect) {
        NSColor.black.withAlphaComponent(0.7).setFill()
        NSBezierPath(roundedRect: frame, xRadius: 6, yRadius: 6).fill()
        text.draw(at: CGPoint(x: frame.minX + 10, y: frame.minY + 5))
    }
}
