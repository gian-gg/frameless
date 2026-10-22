import AppKit

/// After picking, keeps the selection on screen to resize or move until it's confirmed: Copy, Save or Pin for a
/// screenshot, Record for a recording. Nothing is captured until then.
@MainActor
final class SelectionEditor {
    enum Action {
        case copy
        case save
        case pin
        case record
    }

    /// The chosen action and the selection as it was when it was chosen.
    struct Choice {
        let action: Action
        let selection: CaptureSelection
    }

    private var window: ScreenCoverWindow?
    private var continuation: CheckedContinuation<Choice?, Never>?

    /// Shows the selection on its screen, calls `onShown` once it's up; returns the choice, or nil when closed.
    func present(
        _ selection: CaptureSelection, for purpose: CapturePurpose, onShown: @MainActor () -> Void = {}
    ) async -> Choice? {
        guard continuation == nil,
            let screen = NSScreen.screens.first(where: { $0.displayID == selection.displayID })
        else { return nil }
        return await withCheckedContinuation { continuation in
            self.continuation = continuation
            show(selection, for: purpose, on: screen)
            onShown()
        }
    }

    private func show(_ selection: CaptureSelection, for purpose: CapturePurpose, on screen: NSScreen) {
        let window = ScreenCoverWindow(screen: screen)
        let view = SelectionEditorView(selection: selection, purpose: purpose, scale: screen.backingScaleFactor)
        view.onFinish = { [weak self] choice in self?.finish(choice) }
        window.contentView = view
        window.makeFirstResponder(view)
        window.orderFrontRegardless()
        window.makeKey()
        self.window = window
    }

    private func finish(_ choice: Choice?) {
        window?.orderOut(nil)
        window = nil
        continuation?.resume(returning: choice)
        continuation = nil
    }
}
