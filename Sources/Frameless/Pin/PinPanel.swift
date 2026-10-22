import AppKit
import Carbon.HIToolbox

/// Floating window holding one pinned screenshot; drag to move, scroll or pinch to zoom, ⌥-scroll to fade.
final class PinPanel: NSPanel {
    var onClose: (@MainActor () -> Void)?

    private let naturalSize: CGSize
    private var zoom: CGFloat = 1
    private let pinView: PinView

    init(image: CGImage, frame: CGRect) {
        naturalSize = frame.size
        pinView = PinView(image: image)
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

        pinView.onClose = { [weak self] in self?.onClose?() }
        pinView.onZoom = { [weak self] factor in self?.zoom(by: factor, around: NSEvent.mouseLocation) }
        pinView.onFade = { [weak self] change in self?.fade(by: change) }
        contentView = pinView
        makeFirstResponder(pinView)
    }

    override var canBecomeKey: Bool { true }

    /// Scales the pin within the zoom limits, keeping the point under the pointer still.
    func zoom(by factor: CGFloat, around anchor: CGPoint) {
        let newZoom = min(max(zoom * factor, Config.Pin.minZoom), Config.Pin.maxZoom)
        guard newZoom != zoom else { return }
        zoom = newZoom
        let size = CGSize(
            width: (naturalSize.width * zoom).rounded(), height: (naturalSize.height * zoom).rounded())
        setFrame(ScreenGeometry.zoomedFrame(frame, to: size, around: anchor), display: true)
        pinView.flash("\(Int((zoom * 100).rounded()))%")
    }

    /// Changes the pin's opacity within its limits.
    func fade(by change: CGFloat) {
        alphaValue = min(max(alphaValue + change, Config.Pin.minOpacity), 1)
        pinView.flash("Opacity \(Int((alphaValue * 100).rounded()))%")
    }
}

/// The pinned image with rounded corners, a glass close button on hover, and a tag while zooming or fading.
private final class PinView: NSView {
    var onClose: (@MainActor () -> Void)?
    var onZoom: (@MainActor (CGFloat) -> Void)?
    var onFade: (@MainActor (CGFloat) -> Void)?

    private let valueTag = GlassTag()
    private var hideTagTask: Task<Void, Never>?

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
        valueTag.isHidden = true
        addSubview(valueTag)
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
        valueTag.setFrameOrigin(
            CGPoint(
                x: ((bounds.width - valueTag.frame.width) / 2).rounded(),
                y: bounds.height - inset - valueTag.frame.height))
    }

    /// Shows the tag with `text` until a moment after the last call.
    func flash(_ text: String) {
        valueTag.show(text)
        valueTag.isHidden = false
        needsLayout = true
        hideTagTask?.cancel()
        hideTagTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(Config.Pin.tagDuration))
            guard !Task.isCancelled else { return }
            self?.valueTag.isHidden = true
        }
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

    // MARK: - Zoom and fade

    override func scrollWheel(with event: NSEvent) {
        let step = event.hasPreciseScrollingDeltas ? 0.01 : 0.1
        let delta = event.scrollingDeltaY * step
        if event.modifierFlags.contains(.option) {
            onFade?(delta / 2)
        } else {
            onZoom?(exp(delta))
        }
    }

    override func magnify(with event: NSEvent) {
        onZoom?(1 + event.magnification)
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
