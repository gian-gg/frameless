import AppKit
import Carbon.HIToolbox

/// What to record: a whole display.
struct CaptureSelection: Equatable {
    let displayID: CGDirectDisplayID
}

/// Full-screen overlay that lets the user pick a display.
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
            let window = OverlayWindow(screen: screen)
            window.overlay.onFinish = { [weak self] in
                self?.finish(CaptureSelection(displayID: displayID))
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
    let overlay = OverlayView()

    init(screen: NSScreen) {
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

/// Dims the screen and reports a click on it.
private final class OverlayView: NSView {
    private static let hint = "Click a screen to record it  ·  Esc to cancel"

    var onFinish: (@MainActor () -> Void)?
    var onCancel: (@MainActor () -> Void)?

    override var acceptsFirstResponder: Bool { true }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func resetCursorRects() {
        addCursorRect(bounds, cursor: .crosshair)
    }

    override func mouseUp(with event: NSEvent) {
        onFinish?()
    }

    override func keyDown(with event: NSEvent) {
        guard event.keyCode == UInt16(kVK_Escape) else { return super.keyDown(with: event) }
        onCancel?()
    }

    override func draw(_ dirtyRect: NSRect) {
        NSColor.black.withAlphaComponent(0.3).setFill()
        bounds.fill()

        let hint = NSAttributedString(
            string: Self.hint,
            attributes: [
                .font: NSFont.monospacedDigitSystemFont(ofSize: 13, weight: .medium),
                .foregroundColor: NSColor.white,
            ])
        let size = hint.size()
        let badge = CGRect(
            x: bounds.midX - size.width / 2 - 10, y: bounds.midY - size.height / 2 - 5,
            width: size.width + 20, height: size.height + 10)
        NSColor.black.withAlphaComponent(0.7).setFill()
        NSBezierPath(roundedRect: badge, xRadius: 6, yRadius: 6).fill()
        hint.draw(at: CGPoint(x: badge.minX + 10, y: badge.minY + 5))
    }
}
