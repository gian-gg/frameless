import AppKit

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
        let mouse = NSEvent.mouseLocation
        let hovered = windows.first { $0.frame.contains(mouse) } ?? windows[0]
        hovered.overlay.isHovered = true
        for window in windows { window.fadeIn() }
        hovered.makeKey()
    }

    private func finish(_ selection: CaptureSelection?) {
        for window in windows { window.orderOut(nil) }
        windows = []
        continuation?.resume(returning: selection)
        continuation = nil
    }
}
