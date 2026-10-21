import AppKit

/// What to record, on which display.
struct CaptureSelection: Equatable {
    enum Target: Equatable {
        case display
        /// An area in the screen's local AppKit points.
        case area(CGRect)
        case window(CGWindowID)
    }

    let displayID: CGDirectDisplayID
    let screenFrame: CGRect
    let target: Target

    var area: CGRect? {
        guard case .area(let rect) = target else { return nil }
        return rect
    }
}

/// Full-screen overlay that lets the user pick a display, an area or a window.
@MainActor
final class AreaSelector {
    private var windows: [OverlayWindow] = []
    private var windowList = WindowList(windows: [])
    private var mode = OverlayView.Mode.screen
    private var continuation: CheckedContinuation<CaptureSelection?, Never>?

    /// Shows the overlay on every display; nil when cancelled.
    func select(for purpose: CapturePurpose) async -> CaptureSelection? {
        guard continuation == nil else { return nil }
        return await withCheckedContinuation { continuation in
            self.continuation = continuation
            showOverlays(for: purpose)
        }
    }

    private func showOverlays(for purpose: CapturePurpose) {
        windowList = WindowList.snapshot()
        mode = .screen
        windows = NSScreen.screens.compactMap { screen in
            guard let displayID = screen.displayID else { return nil }
            let frame = screen.frame
            let window = OverlayWindow(screen: screen, purpose: purpose)
            window.overlay.onFinish = { [weak self] target in
                self?.finish(CaptureSelection(displayID: displayID, screenFrame: frame, target: target))
            }
            window.overlay.onCancel = { [weak self] in self?.finish(nil) }
            window.overlay.onToggleMode = { [weak self] in self?.toggleMode() }
            window.overlay.onMouseMoved = { [weak self] in self?.updateHighlightedWindow() }
            return window
        }
        guard !windows.isEmpty else { return finish(nil) }

        let mouse = NSEvent.mouseLocation
        let hovered = windows.first { $0.frame.contains(mouse) } ?? windows[0]
        hovered.overlay.isHovered = true
        for window in windows { window.fadeIn() }
        hovered.makeKey()
    }

    private func toggleMode() {
        mode = mode == .screen ? .window : .screen
        for window in windows { window.overlay.mode = mode }
        updateHighlightedWindow()
    }

    /// Highlights the window under the cursor on every screen it spans.
    private func updateHighlightedWindow() {
        let highlighted = mode == .window ? windowList.window(at: NSEvent.mouseLocation) : nil
        for window in windows where window.overlay.highlightedWindow != highlighted {
            window.overlay.highlightedWindow = highlighted
        }
    }

    /// Hands back the selection; on a pick the overlay stays up, frozen, until `dismiss()`.
    private func finish(_ selection: CaptureSelection?) {
        guard let continuation else { return }
        if selection == nil {
            dismiss()
        } else {
            for window in windows { window.ignoresMouseEvents = true }
        }
        continuation.resume(returning: selection)
        self.continuation = nil
    }

    /// Removes the overlay; called once whatever follows the selection is on screen.
    func dismiss() {
        for window in windows { window.orderOut(nil) }
        windows = []
    }
}
