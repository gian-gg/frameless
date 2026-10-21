import AppKit
import Carbon.HIToolbox

/// Keeps a screenshot frozen in place with a small Copy / Save / Close toolbar until one is chosen.
@MainActor
final class CaptureBelt {
    enum Action {
        case copy
        case save
    }

    private var window: ScreenCoverWindow?
    private var continuation: CheckedContinuation<Action?, Never>?

    /// Shows the capture on its screen, calls `onShown` once it's up; returns the chosen action, or nil when closed.
    func present(_ shot: CapturedImage, onShown: @MainActor () -> Void = {}) async -> Action? {
        guard continuation == nil,
            let screen = NSScreen.screens.first(where: { $0.displayID == shot.displayID }) ?? NSScreen.main
        else { return nil }
        return await withCheckedContinuation { continuation in
            self.continuation = continuation
            show(shot, on: screen)
            onShown()
        }
    }

    private func show(_ shot: CapturedImage, on screen: NSScreen) {
        let window = ScreenCoverWindow(screen: screen)
        let view = BeltView(shot: shot, screenOrigin: screen.frame.origin)
        view.onFinish = { [weak self] action in self?.finish(action) }
        window.contentView = view
        window.makeFirstResponder(view)
        NSApp.activate()
        window.orderFrontRegardless()
        window.makeKey()
        self.window = window
    }

    private func finish(_ action: Action?) {
        window?.orderOut(nil)
        window = nil
        continuation?.resume(returning: action)
        continuation = nil
    }
}

/// The dimmed screen with the frozen capture and its toolbar; handles the belt's keys.
private final class BeltView: NSView {
    var onFinish: (@MainActor (CaptureBelt.Action?) -> Void)?

    private let image: CGImage
    private let imageFrame: CGRect
    private var toolbar: GlassBar?
    private let sizeTag = GlassTag()

    init(shot: CapturedImage, screenOrigin: CGPoint) {
        image = shot.image
        imageFrame = shot.frame.offsetBy(dx: -screenOrigin.x, dy: -screenOrigin.y)
        super.init(frame: .zero)
        let toolbar = GlassBar(
            items: [
                .init(
                    symbol: "doc.on.doc", title: "Copy", shortcut: .text("⌘C"), toolTip: "Copy to the clipboard",
                    perform: { [weak self] in self?.onFinish?(.copy) }),
                .init(
                    symbol: "square.and.arrow.down", title: "Save", shortcut: .text("⌘S"), toolTip: "Save to Pictures",
                    perform: { [weak self] in self?.onFinish?(.save) }),
            ],
            closeToolTip: "Close (Esc)", close: { [weak self] in self?.onFinish?(nil) })
        addSubview(toolbar)
        self.toolbar = toolbar
        sizeTag.show("\(image.width) × \(image.height)")
        addSubview(sizeTag)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { nil }

    override var acceptsFirstResponder: Bool { true }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func layout() {
        super.layout()
        if let toolbar {
            toolbar.setFrameOrigin(
                ScreenGeometry.barOrigin(
                    for: toolbar.frame.size, under: imageFrame, in: bounds, gap: Config.Bar.selectionGap,
                    inset: Config.Style.barBottomOffset))
        }
        sizeTag.setFrameOrigin(
            ScreenGeometry.tagOrigin(for: sizeTag.frame.size, on: imageFrame, in: bounds, lift: Config.Style.tagLift))
    }

    override func draw(_ dirtyRect: NSRect) {
        NSColor.black.withAlphaComponent(Config.Style.dimOpacity).setFill()
        bounds.fill()
        NSColor.clear.setFill()
        imageFrame.fill(using: .copy)
        NSGraphicsContext.current?.cgContext.draw(image, in: imageFrame)
        Panel.drawSelectionFrame(imageFrame)
    }

    override func keyDown(with event: NSEvent) {
        switch Int(event.keyCode) {
        case kVK_Escape: onFinish?(nil)
        case kVK_Return, kVK_ANSI_KeypadEnter: onFinish?(.copy)
        default: super.keyDown(with: event)
        }
    }

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        guard event.modifierFlags.intersection(.deviceIndependentFlagsMask) == .command else {
            return super.performKeyEquivalent(with: event)
        }
        switch Int(event.keyCode) {
        case kVK_ANSI_C: onFinish?(.copy)
        case kVK_ANSI_S: onFinish?(.save)
        default: return super.performKeyEquivalent(with: event)
        }
        return true
    }
}
