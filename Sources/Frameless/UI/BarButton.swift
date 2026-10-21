import AppKit

/// Glass bar item drawn as one centred group: icon, optional label, optional shortcut key cap.
final class BarButton: NSControl {
    /// What a key cap shows: text such as "⌘C", or an SF Symbol such as "space".
    enum Shortcut {
        case text(String)
        case symbol(String)
    }

    private static let keyPadding = CGSize(width: 5, height: 2)
    private static let keyRadius: CGFloat = 4

    private let symbol: String
    private let title: String?
    private let shortcut: Shortcut?
    private var isHovering = false {
        didSet { needsDisplay = true }
    }
    private var isPressed = false {
        didSet { needsDisplay = true }
    }

    init(symbol: String, title: String?, shortcut: Shortcut? = nil, toolTip: String? = nil) {
        self.symbol = symbol
        self.title = title
        self.shortcut = shortcut
        super.init(frame: .zero)
        self.toolTip = toolTip
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { nil }

    /// Off for labels: no hover, no clicks, just the drawing.
    var isInteractive = true

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { isInteractive }

    override func hitTest(_ point: NSPoint) -> NSView? {
        isInteractive ? super.hitTest(point) : nil
    }

    // MARK: - Content

    private var icon: NSImage? {
        let config = NSImage.SymbolConfiguration(pointSize: Config.Bar.iconSize, weight: .medium)
            .applying(NSImage.SymbolConfiguration(paletteColors: [.labelColor]))
        return NSImage(systemSymbolName: symbol, accessibilityDescription: nil)?.withSymbolConfiguration(config)
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

    /// The key cap's content: text or a symbol, both sized to the key font.
    private var keyContent: (size: CGSize, draw: (CGRect) -> Void)? {
        switch shortcut {
        case .text(let string):
            let text = NSAttributedString(
                string: string, attributes: [.font: Self.keyFont, .foregroundColor: NSColor.secondaryLabelColor])
            let size = text.size()
            return (size, { text.draw(at: CGPoint(x: $0.midX - size.width / 2, y: $0.midY - size.height / 2)) })
        case .symbol(let name):
            let config = NSImage.SymbolConfiguration(pointSize: Config.Bar.shortcutSize, weight: .medium)
                .applying(NSImage.SymbolConfiguration(paletteColors: [.secondaryLabelColor]))
            guard
                let image = NSImage(systemSymbolName: name, accessibilityDescription: nil)?
                    .withSymbolConfiguration(config)
            else { return nil }
            let size = image.size
            return (
                size,
                {
                    image.draw(
                        in: CGRect(
                            x: $0.midX - size.width / 2, y: $0.midY - size.height / 2, width: size.width,
                            height: size.height))
                }
            )
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

    /// Widths of the icon, label and key cap that are present, left to right.
    private var widths: [CGFloat] {
        [icon?.size.width, titleText.map { ceil($0.size().width) }, keySize?.width].compactMap { $0 }
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
        if isInteractive, isPressed || isHovering {
            NSColor.labelColor.withAlphaComponent(isPressed ? 0.22 : 0.1).setFill()
            let radius = min(bounds.width, bounds.height) / 2
            NSBezierPath(roundedRect: bounds, xRadius: radius, yRadius: radius).fill()
        }

        var left = ((bounds.width - contentWidth) / 2).rounded()
        if let icon {
            icon.draw(in: centered(icon.size, at: left))
            left += icon.size.width + Config.Bar.innerGap
        }
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
    }

    override func mouseExited(with event: NSEvent) {
        isHovering = false
    }

    override func mouseDown(with event: NSEvent) {
        isPressed = true
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
