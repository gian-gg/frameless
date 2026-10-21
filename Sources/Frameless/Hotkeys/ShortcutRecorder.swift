import AppKit
import Carbon.HIToolbox

/// Waits for the next key combination on a dimmed screen with a glass prompt, for assigning a shortcut.
@MainActor
final class ShortcutRecorder {
    enum Outcome {
        case set(Shortcut)
        case clear
        case cancel
    }

    private var window: ScreenCoverWindow?
    private var continuation: CheckedContinuation<Outcome, Never>?

    /// Shows the prompt on the screen under the pointer and returns what the user did.
    /// `reasonToReject` explains why a combination can't be used, or returns nil to accept it.
    func record(for actionName: String, reasonToReject: @escaping @MainActor (Shortcut) -> String?) async -> Outcome {
        guard continuation == nil else { return .cancel }
        let mouse = NSEvent.mouseLocation
        guard let screen = NSScreen.screens.first(where: { $0.frame.contains(mouse) }) ?? NSScreen.main else {
            return .cancel
        }
        return await withCheckedContinuation { continuation in
            self.continuation = continuation
            let window = ScreenCoverWindow(screen: screen)
            let view = ShortcutRecorderView(actionName: actionName, reasonToReject: reasonToReject)
            view.onFinish = { [weak self] outcome in self?.finish(outcome) }
            window.contentView = view
            window.makeFirstResponder(view)
            NSApp.activate()
            window.fadeIn()
            window.makeKey()
            self.window = window
        }
    }

    private func finish(_ outcome: Outcome) {
        window?.orderOut(nil)
        window = nil
        continuation?.resume(returning: outcome)
        continuation = nil
    }
}

/// Dim with a centred glass prompt; turns the next accepted key combination into a shortcut.
private final class ShortcutRecorderView: NSView {
    var onFinish: (@MainActor (ShortcutRecorder.Outcome) -> Void)?

    private let prompt = GlassTag()
    private let reasonToReject: @MainActor (Shortcut) -> String?

    init(actionName: String, reasonToReject: @escaping @MainActor (Shortcut) -> String?) {
        self.reasonToReject = reasonToReject
        super.init(frame: .zero)
        prompt.show("Press a shortcut for \(actionName)   ⌫ Clear   esc Cancel")
        addSubview(prompt)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { nil }

    override var acceptsFirstResponder: Bool { true }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func layout() {
        super.layout()
        let size = prompt.frame.size
        prompt.setFrameOrigin(
            CGPoint(x: (bounds.midX - size.width / 2).rounded(), y: (bounds.midY - size.height / 2).rounded()))
    }

    override func draw(_ dirtyRect: NSRect) {
        NSColor.black.withAlphaComponent(Config.Style.dimOpacity).setFill()
        bounds.fill()
    }

    override func mouseDown(with event: NSEvent) {
        onFinish?(.cancel)
    }

    override func keyDown(with event: NSEvent) {
        handle(event)
    }

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        handle(event)
        return true
    }

    /// Esc cancels and Delete clears when pressed alone; a rejected combination shows why and keeps listening.
    private func handle(_ event: NSEvent) {
        let modifiers = Shortcut.Modifiers(event.modifierFlags)
        let keyCode = Int(event.keyCode)
        if modifiers.isEmpty, keyCode == kVK_Escape { return onFinish?(.cancel) ?? () }
        if modifiers.isEmpty, keyCode == kVK_Delete || keyCode == kVK_ForwardDelete {
            return onFinish?(.clear) ?? ()
        }
        let shortcut = Shortcut(keyCode: UInt32(event.keyCode), modifiers: modifiers)
        if let reason = reasonToReject(shortcut) {
            prompt.show("\(reason). Try another   esc Cancel")
            needsLayout = true
            return
        }
        onFinish?(.set(shortcut))
    }
}
