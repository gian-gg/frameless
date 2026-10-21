import AppKit
import Carbon.HIToolbox

/// Waits for the next key combination on a dimmed screen with the picker's bar and a message, to assign a shortcut.
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

/// Dim with the picker's bottom bar (Clear and ×) and a message above it; turns the next accepted key
/// combination into a shortcut.
private final class ShortcutRecorderView: NSView {
    var onFinish: (@MainActor (ShortcutRecorder.Outcome) -> Void)?

    private static let promptSymbol = "keyboard"
    private static let warningSymbol = "exclamationmark.triangle"

    private let message = GlassLabel()
    private var bar: GlassBar?
    private let actionName: String
    private var isWarning = false
    private let reasonToReject: @MainActor (Shortcut) -> String?

    init(actionName: String, reasonToReject: @escaping @MainActor (Shortcut) -> String?) {
        self.actionName = actionName
        self.reasonToReject = reasonToReject
        super.init(frame: .zero)
        showPrompt()
        addSubview(message)
        let bar = GlassBar(
            items: [
                .init(
                    symbol: "eraser", title: "Clear", shortcut: .text("⌫"), toolTip: "Remove this shortcut",
                    perform: { [weak self] in self?.onFinish?(.clear) })
            ],
            closeToolTip: "Cancel (Esc)", close: { [weak self] in self?.onFinish?(.cancel) })
        addSubview(bar)
        self.bar = bar
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { nil }

    override var acceptsFirstResponder: Bool { true }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    /// The bar at the picker's bottom-centre spot, the message centred just above it.
    override func layout() {
        super.layout()
        guard let bar else { return }
        bar.setFrameOrigin(
            CGPoint(x: (bounds.midX - bar.frame.width / 2).rounded(), y: bounds.minY + Config.Style.barBottomOffset))
        message.setFrameOrigin(
            CGPoint(
                x: (bounds.midX - message.frame.width / 2).rounded(), y: bar.frame.maxY + Config.Bar.selectionGap))
    }

    override func draw(_ dirtyRect: NSRect) {
        NSColor.black.withAlphaComponent(Config.Style.dimOpacity).setFill()
        bounds.fill()
    }

    override func mouseDown(with event: NSEvent) {
        onFinish?(.cancel)
    }

    private func showMessage(symbol: String, text: String) {
        isWarning = symbol == Self.warningSymbol
        message.show(symbol: symbol, text: text)
        needsLayout = true
    }

    private func showPrompt() {
        showMessage(symbol: Self.promptSymbol, text: "Press a shortcut for \(actionName)")
    }

    /// Shows the modifiers as they're held; on release, back to the prompt unless a warning is showing.
    override func flagsChanged(with event: NSEvent) {
        let modifiers = Shortcut.Modifiers(event.modifierFlags)
        if modifiers.isEmpty {
            if !isWarning { showPrompt() }
        } else {
            showMessage(symbol: Self.promptSymbol, text: "\(modifiers.symbols)…")
        }
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
            showMessage(symbol: Self.warningSymbol, text: "\(reason). Try another")
            return
        }
        onFinish?(.set(shortcut))
    }
}
