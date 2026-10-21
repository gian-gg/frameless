import AppKit

/// Bottom-of-screen glass bar: a capsule of buttons showing their shortcuts, then a round close button.
final class GlassBar: NSView {
    /// A clickable item showing its keyboard shortcut.
    struct Item {
        let symbol: String
        let title: String
        let shortcut: BarButton.Shortcut
        let toolTip: String
        let perform: @MainActor () -> Void
    }

    private var handlers: [@MainActor () -> Void] = []

    init(items: [Item], closeToolTip: String, close: @escaping @MainActor () -> Void) {
        super.init(frame: .zero)
        let height = Config.Bar.itemHeight + Config.Bar.padding * 2
        let capsule = GlassPanel()
        var left = Config.Bar.padding
        for item in items {
            let view = button(
                symbol: item.symbol, title: item.title, shortcut: item.shortcut, toolTip: item.toolTip,
                perform: item.perform)
            let width = view.intrinsicContentSize.width
            view.frame = CGRect(x: left, y: Config.Bar.padding, width: width, height: Config.Bar.itemHeight)
            capsule.content.addSubview(view)
            left += width
        }
        capsule.frame = CGRect(x: 0, y: 0, width: left + Config.Bar.padding, height: height)
        addSubview(capsule)

        let circle = GlassPanel(
            frame: CGRect(x: capsule.frame.maxX + Config.Bar.closeGap, y: 0, width: height, height: height))
        let closeButton = button(symbol: "xmark", title: nil, shortcut: nil, toolTip: closeToolTip, perform: close)
        closeButton.frame = circle.bounds.insetBy(dx: Config.Bar.padding, dy: Config.Bar.padding)
        circle.content.addSubview(closeButton)
        addSubview(circle)

        setFrameSize(CGSize(width: circle.frame.maxX, height: height))
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { nil }

    /// Clicks on the glass between buttons stop here instead of reaching the picker behind the bar.
    override func mouseDown(with event: NSEvent) {}

    override func mouseUp(with event: NSEvent) {}

    private func button(
        symbol: String, title: String?, shortcut: BarButton.Shortcut?, toolTip: String,
        perform: @escaping @MainActor () -> Void
    ) -> BarButton {
        let button = BarButton(symbol: symbol, title: title, shortcut: shortcut, toolTip: toolTip)
        button.tag = handlers.count
        handlers.append(perform)
        button.target = self
        button.action = #selector(pressed(_:))
        return button
    }

    @objc private func pressed(_ sender: NSControl) {
        guard handlers.indices.contains(sender.tag) else { return }
        handlers[sender.tag]()
    }
}
