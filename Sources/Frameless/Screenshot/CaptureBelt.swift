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

    /// Shows the capture on its screen; returns the chosen action, or nil when closed.
    func present(_ shot: CapturedImage) async -> Action? {
        guard continuation == nil,
            let screen = NSScreen.screens.first(where: { $0.displayID == shot.displayID }) ?? NSScreen.main
        else { return nil }
        return await withCheckedContinuation { continuation in
            self.continuation = continuation
            show(shot, on: screen)
        }
    }

    private func show(_ shot: CapturedImage, on screen: NSScreen) {
        let window = ScreenCoverWindow(screen: screen)
        let view = BeltView(shot: shot, screenOrigin: screen.frame.origin)
        view.onFinish = { [weak self] action in self?.finish(action) }
        window.contentView = view
        window.makeFirstResponder(view)
        NSApp.activate()
        window.fadeIn()
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
    private let toolbar = BeltToolbar()

    init(shot: CapturedImage, screenOrigin: CGPoint) {
        image = shot.image
        imageFrame = shot.frame.offsetBy(dx: -screenOrigin.x, dy: -screenOrigin.y)
        super.init(frame: .zero)
        toolbar.onAction = { [weak self] action in self?.onFinish?(action) }
        addSubview(toolbar)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { nil }

    override var acceptsFirstResponder: Bool { true }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func layout() {
        super.layout()
        let size = BeltToolbar.size
        let origin = ScreenGeometry.toolbarOrigin(for: size, below: imageFrame, in: bounds, gap: Config.Belt.gap)
        toolbar.frame = CGRect(origin: origin, size: size)
    }

    override func draw(_ dirtyRect: NSRect) {
        NSColor.black.withAlphaComponent(Config.Overlay.hoverDimOpacity).setFill()
        bounds.fill()
        NSColor.clear.setFill()
        imageFrame.fill(using: .copy)
        NSGraphicsContext.current?.cgContext.draw(image, in: imageFrame)
        OverlayDrawing.strokeSelection(imageFrame)
        OverlayDrawing.drawLabel(
            "\(image.width) × \(image.height)", above: imageFrame, in: bounds, radius: Config.Belt.cornerRadius)
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

/// Square-cornered bar with Copy and Save, a divider, and Close.
private final class BeltToolbar: NSView {
    private struct Item {
        let symbol: String
        let tip: String
        let action: CaptureBelt.Action?
    }

    private static let actions = [
        Item(symbol: "doc.on.doc", tip: "Copy (⌘C)", action: .copy),
        Item(symbol: "square.and.arrow.down", tip: "Save (⌘S)", action: .save),
    ]
    private static let close = Item(symbol: "xmark", tip: "Close (Esc)", action: nil)

    static var size: CGSize {
        let buttons = CGFloat(actions.count + 1) * Config.Belt.buttonSize.width
        let divider = Config.Belt.separatorGap * 2 + 1
        return CGSize(
            width: buttons + divider + Config.Belt.padding * 2,
            height: Config.Belt.buttonSize.height + Config.Belt.padding * 2)
    }

    var onAction: (@MainActor (CaptureBelt.Action?) -> Void)?

    private var dividerX: CGFloat = 0

    init() {
        super.init(frame: .zero)
        var left = Config.Belt.padding
        for item in Self.actions {
            addButton(item, at: left)
            left += Config.Belt.buttonSize.width
        }
        dividerX = left + Config.Belt.separatorGap
        addButton(Self.close, at: dividerX + 1 + Config.Belt.separatorGap)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { nil }

    private func addButton(_ item: Item, at left: CGFloat) {
        let button = NSButton(
            image: OverlayDrawing.symbol(item.symbol, pointSize: Config.Belt.iconSize) ?? NSImage(),
            target: self, action: #selector(pressed(_:)))
        button.isBordered = false
        button.toolTip = item.tip
        button.tag = Self.actions.firstIndex { $0.symbol == item.symbol } ?? -1
        button.frame = CGRect(origin: CGPoint(x: left, y: Config.Belt.padding), size: Config.Belt.buttonSize)
        addSubview(button)
    }

    @objc private func pressed(_ sender: NSButton) {
        onAction?(Self.actions.indices.contains(sender.tag) ? Self.actions[sender.tag].action : nil)
    }

    override func draw(_ dirtyRect: NSRect) {
        OverlayDrawing.fillPill(bounds.insetBy(dx: 0.5, dy: 0.5), radius: Config.Belt.cornerRadius)
        NSColor.white.withAlphaComponent(0.15).setFill()
        CGRect(x: dividerX, y: Config.Belt.padding + 4, width: 1, height: Config.Belt.buttonSize.height - 8).fill()
    }
}
