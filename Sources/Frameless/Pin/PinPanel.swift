import AppKit
import Carbon.HIToolbox

/// Floating window holding one pinned screenshot; drag anywhere to move it.
final class PinPanel: NSPanel {
    var onClose: (@MainActor () -> Void)?

    init(image: CGImage, frame: CGRect) {
        super.init(
            contentRect: frame, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        level = .floating
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
        hidesOnDeactivate = false
        isReleasedWhenClosed = false
        isMovableByWindowBackground = true
        animationBehavior = .none
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]

        let view = PinView(image: image)
        view.onClose = { [weak self] in self?.onClose?() }
        contentView = view
        makeFirstResponder(view)
    }

    override var canBecomeKey: Bool { true }
}

/// The pinned image with rounded corners, and a glass close button on hover; Esc closes it too.
private final class PinView: NSView {
    var onClose: (@MainActor () -> Void)?

    private let closeControl = GlassPanel(
        frame: CGRect(x: 0, y: 0, width: Config.Pin.closeSize, height: Config.Pin.closeSize))

    init(image: CGImage) {
        super.init(frame: .zero)
        wantsLayer = true
        layer?.contents = image
        layer?.contentsGravity = .resize
        layer?.cornerRadius = Config.Pin.cornerRadius
        layer?.masksToBounds = true
        layer?.borderWidth = 1
        layer?.borderColor = NSColor.white.withAlphaComponent(Config.Style.hairlineOpacity).cgColor
        addCloseButton()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { nil }

    override var acceptsFirstResponder: Bool { true }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override var mouseDownCanMoveWindow: Bool { true }

    /// Glass circle with ×, matching the thumbnail's; shown on hover in the top-left corner.
    private func addCloseButton() {
        let button = BarButton(symbol: "xmark", title: nil, toolTip: "Close (Esc)")
        button.target = self
        button.action = #selector(close)
        button.frame = closeControl.bounds
        button.autoresizingMask = [.width, .height]
        closeControl.content.addSubview(button)
        closeControl.isHidden = true
        closeControl.autoresizingMask = [.maxXMargin, .minYMargin]
        addSubview(closeControl)
    }

    override func layout() {
        super.layout()
        let inset = Config.Pin.closeInset
        closeControl.setFrameOrigin(CGPoint(x: inset, y: bounds.height - inset - closeControl.frame.height))
    }

    @objc private func close() {
        onClose?()
    }

    override func keyDown(with event: NSEvent) {
        if Int(event.keyCode) == kVK_Escape {
            onClose?()
        } else {
            super.keyDown(with: event)
        }
    }

    // MARK: - Hover

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        trackingAreas.forEach(removeTrackingArea)
        addTrackingArea(
            NSTrackingArea(
                rect: .zero, options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect], owner: self))
    }

    override func mouseEntered(with event: NSEvent) {
        closeControl.isHidden = false
    }

    override func mouseExited(with event: NSEvent) {
        closeControl.isHidden = true
    }
}
