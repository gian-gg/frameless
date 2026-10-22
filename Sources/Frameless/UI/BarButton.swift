import AppKit

/// Glass bar item drawn as one centred group: icon, optional label, optional shortcut key cap.
final class BarButton: NSControl {
    /// What a key cap shows, such as "⌘C".
    enum Shortcut {
        case text(String)
    }

    private static let keyPadding = CGSize(width: 5, height: 2)
    private static let keyRadius: CGFloat = 4

    private let icon: LucideIcon
    private let title: String?
    private let shortcut: Shortcut?
    private let tipText: String?
    private let tip = HoverTip()
    private var isHovering = false {
        didSet { needsDisplay = true }
    }
    private var isPressed = false {
        didSet { needsDisplay = true }
    }

    init(icon: LucideIcon, title: String?, shortcut: Shortcut? = nil, toolTip: String? = nil) {
        self.icon = icon
        self.title = title
        self.shortcut = shortcut
        self.tipText = toolTip
        super.init(frame: .zero)
        setAccessibilityHelp(toolTip)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { nil }

    /// Off for labels: no hover, no clicks, just the drawing.
    var isInteractive = true

    /// A tool toggle: its icon is dimmed until selected.
    var isToggle = false {
        didSet { needsDisplay = true }
    }

    /// Shown with a brighter pill and a full-strength icon, for the active tool.
    var isSelected = false {
        didSet { needsDisplay = true }
    }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { isInteractive }

    override func hitTest(_ point: NSPoint) -> NSView? {
        isInteractive ? super.hitTest(point) : nil
    }

    // MARK: - Content

    private var iconImage: NSImage {
        let color: NSColor =
            isToggle && !isSelected ? .labelColor.withAlphaComponent(Config.Bar.unselectedToolOpacity) : .labelColor
        return icon.image(size: Config.Bar.iconSize, color: color)
    }

    private var titleText: NSAttributedString? {
        title.map {
            NSAttributedString(
                string: $0,
                attributes: [
                    .font: Panel.font(size: Config.Bar.titleSize, weight: .medium),
                    .foregroundColor: NSColor.labelColor,
                ])
        }
    }

    private static var keyFont: NSFont { Panel.font(size: Config.Bar.shortcutSize, weight: .medium) }

    /// The key cap's content, sized to the key font.
    private var keyContent: (size: CGSize, draw: (CGRect) -> Void)? {
        switch shortcut {
        case .text(let string):
            let text = NSAttributedString(
                string: string, attributes: [.font: Self.keyFont, .foregroundColor: NSColor.secondaryLabelColor])
            let size = text.size()
            return (size, { text.draw(at: CGPoint(x: $0.midX - size.width / 2, y: $0.midY - size.height / 2)) })
        case nil:
            return nil
        }
    }

    /// Key caps share one height, set by the key font, whatever they show.
    private var keySize: CGSize? {
        keyContent.map {
            let lineHeight = NSAttributedString(string: "M", attributes: [.font: Self.keyFont]).size().height
            return CGSize(
                width: ceil($0.size.width) + Self.keyPadding.width * 2,
                height: ceil(max(lineHeight, $0.size.height)) + Self.keyPadding.height * 2)
        }
    }

    /// Widths of the icon and, when present, the label and key cap, left to right.
    private var widths: [CGFloat] {
        [iconImage.size.width, titleText.map { ceil($0.size().width) }, keySize?.width].compactMap { $0 }
    }

    private var contentWidth: CGFloat {
        widths.reduce(0, +) + Config.Bar.innerGap * CGFloat(max(0, widths.count - 1))
    }

    /// The content plus `Config.Bar.itemPadding` each side, `Config.Bar.itemHeight` tall.
    override var intrinsicContentSize: NSSize {
        NSSize(width: ceil(contentWidth + Config.Bar.itemPadding * 2), height: Config.Bar.itemHeight)
    }

    // MARK: - Drawing

    override func draw(_ dirtyRect: NSRect) {
        if isInteractive, isPressed || isSelected || isHovering {
            let opacity = isSelected ? Config.Bar.selectedFillOpacity : isPressed ? 0.22 : 0.1
            NSColor.labelColor.withAlphaComponent(opacity).setFill()
            let radius = min(bounds.width, bounds.height) / 2
            NSBezierPath(roundedRect: bounds, xRadius: radius, yRadius: radius).fill()
        }

        var left = ((bounds.width - contentWidth) / 2).rounded()
        let image = iconImage
        image.draw(in: centered(image.size, at: left))
        left += image.size.width + Config.Bar.innerGap
        if let titleText {
            let size = titleText.size()
            titleText.draw(at: centered(size, at: left).origin)
            left += ceil(size.width) + Config.Bar.innerGap
        }
        if let keyContent, let keySize {
            let key = centered(keySize, at: left)
            NSColor.labelColor.withAlphaComponent(0.1).setFill()
            NSBezierPath(roundedRect: key, xRadius: Self.keyRadius, yRadius: Self.keyRadius).fill()
            keyContent.draw(key)
        }
    }

    /// A rect of `size` starting at `left`, centred vertically in the item.
    private func centered(_ size: CGSize, at left: CGFloat) -> CGRect {
        CGRect(x: left, y: ((bounds.height - size.height) / 2).rounded(), width: size.width, height: size.height)
    }

    // MARK: - Interaction

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        trackingAreas.forEach(removeTrackingArea)
        guard isInteractive else { return }
        addTrackingArea(
            NSTrackingArea(rect: .zero, options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect], owner: self))
    }

    override func mouseEntered(with event: NSEvent) {
        isHovering = true
        if let tipText { tip.schedule(tipText, for: self) }
    }

    override func mouseExited(with event: NSEvent) {
        isHovering = false
        tip.hide()
    }

    override func viewWillMove(toWindow newWindow: NSWindow?) {
        super.viewWillMove(toWindow: newWindow)
        if newWindow == nil { tip.hide() }
    }

    override func mouseDown(with event: NSEvent) {
        isPressed = true
        tip.hide()
    }

    override func mouseDragged(with event: NSEvent) {
        isPressed = bounds.contains(convert(event.locationInWindow, from: nil))
    }

    override func mouseUp(with event: NSEvent) {
        let inside = bounds.contains(convert(event.locationInWindow, from: nil))
        isPressed = false
        if inside { sendAction(action, to: target) }
    }
}
