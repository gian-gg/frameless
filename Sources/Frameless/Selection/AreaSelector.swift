import AppKit

/// What to record, on which display.
struct CaptureSelection: Equatable {
    enum Target: Equatable {
        case display
        /// An area in the screen's local AppKit points.
        case area(CGRect)
    }

    let displayID: CGDirectDisplayID
    let screenFrame: CGRect
    let target: Target

    var area: CGRect? {
        guard case .area(let rect) = target else { return nil }
        return rect
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
                let target = area.map(CaptureSelection.Target.area) ?? .display
                self?.finish(CaptureSelection(displayID: displayID, screenFrame: frame, target: target))
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
