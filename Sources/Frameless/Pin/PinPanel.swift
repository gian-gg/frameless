import AppKit
import Carbon.HIToolbox

/// Floating window holding one pinned screenshot; drag to move, scroll to zoom, ⌥-scroll to fade,
/// right-click for the rest.
final class PinPanel: NSPanel {
    var onClose: (@MainActor () -> Void)?
    var onCloseAll: (@MainActor () -> Void)?
    var onCopy: (@MainActor () -> Void)?
    var onSave: (@MainActor () -> Void)?

    private let naturalSize: CGSize
    private var zoom: CGFloat = 1
    private let pinView: PinView

    init(shot: CapturedImage, frame: CGRect) {
        naturalSize = frame.size
        pinView = PinView(image: shot.image)
        super.init(
            contentRect: frame, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        level = .floating
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
        hidesOnDeactivate = false
        isReleasedWhenClosed = false
        sharingType = .none
        isMovableByWindowBackground = true
        animationBehavior = .none
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]

        pinView.onClose = { [weak self] in self?.onClose?() }
        pinView.onZoom = { [weak self] factor in self?.zoom(by: factor, around: NSEvent.mouseLocation) }
        pinView.onFade = { [weak self] change in self?.fade(by: change) }
        pinView.onCopy = { [weak self] in self?.onCopy?() }
        pinView.onSave = { [weak self] in self?.onSave?() }
        pinView.menu = makeMenu()
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
        setOpacity(alphaValue + change)
    }

    private func setOpacity(_ opacity: CGFloat) {
        alphaValue = min(max(opacity, Config.Pin.minOpacity), 1)
        pinView.flash("Opacity \(Int((alphaValue * 100).rounded()))%")
    }

    // MARK: - Menu

    private func makeMenu() -> NSMenu {
        let menu = NSMenu()
        menu.addItem(item("Copy", #selector(copyPin), key: "c"))
        menu.addItem(item("Save", #selector(savePin), key: "s"))
        menu.addItem(.separator())
        let zoomMenu = NSMenu()
        for percent in Config.Pin.zoomChoices {
            let choice = item("\(percent)%", #selector(chooseZoom(_:)))
            choice.tag = percent
            zoomMenu.addItem(choice)
        }
        zoomMenu.addItem(.separator())
        zoomMenu.addItem(withTitle: "Scroll to Adjust", action: nil, keyEquivalent: "")
        menu.addItem(withTitle: "Zoom", action: nil, keyEquivalent: "").submenu = zoomMenu
        let opacityMenu = NSMenu()
        for percent in Config.Pin.opacityChoices {
            let choice = item("\(percent)%", #selector(chooseOpacity(_:)))
            choice.tag = percent
            opacityMenu.addItem(choice)
        }
        opacityMenu.addItem(.separator())
        opacityMenu.addItem(withTitle: "⌥ + Scroll to Adjust", action: nil, keyEquivalent: "")
        menu.addItem(withTitle: "Opacity", action: nil, keyEquivalent: "").submenu = opacityMenu
        menu.addItem(.separator())
        menu.addItem(item("Close", #selector(closePin), key: "\u{1b}", modifiers: []))
        menu.addItem(item("Close All Pins", #selector(closeAllPins)))
        return menu
    }

    private func item(
        _ title: String, _ action: Selector, key: String = "", modifiers: NSEvent.ModifierFlags = .command
    ) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: key)
        item.keyEquivalentModifierMask = modifiers
        item.target = self
        return item
    }

    @objc private func copyPin() { onCopy?() }

    @objc private func savePin() { onSave?() }

    @objc private func chooseZoom(_ sender: NSMenuItem) {
        zoom(by: CGFloat(sender.tag) / 100 / zoom, around: CGPoint(x: frame.midX, y: frame.midY))
    }

    @objc private func chooseOpacity(_ sender: NSMenuItem) {
        setOpacity(CGFloat(sender.tag) / 100)
    }

    @objc private func closePin() { onClose?() }

    @objc private func closeAllPins() { onCloseAll?() }

    override func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        if menuItem.action == #selector(chooseOpacity(_:)) {
            menuItem.state = Int((alphaValue * 100).rounded()) == menuItem.tag ? .on : .off
        } else if menuItem.action == #selector(chooseZoom(_:)) {
            menuItem.state = Int((zoom * 100).rounded()) == menuItem.tag ? .on : .off
        }
        return true
    }
}

/// The pinned image with rounded corners, a glass close button on hover, and a tag while zooming or fading.
private final class PinView: NSView {
    var onClose: (@MainActor () -> Void)?
    var onZoom: (@MainActor (CGFloat) -> Void)?
    var onFade: (@MainActor (CGFloat) -> Void)?
    var onCopy: (@MainActor () -> Void)?
    var onSave: (@MainActor () -> Void)?

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
        let button = BarButton(icon: .close, title: nil, toolTip: "Close (Esc)")
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

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        guard window?.isKeyWindow == true,
            event.modifierFlags.intersection(.deviceIndependentFlagsMask) == .command
        else { return super.performKeyEquivalent(with: event) }
        switch Int(event.keyCode) {
        case kVK_ANSI_C: onCopy?()
        case kVK_ANSI_S: onSave?()
        default: return super.performKeyEquivalent(with: event)
        }
        return true
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
