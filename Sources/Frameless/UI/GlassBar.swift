import AppKit

/// Bottom-of-screen glass bar: an optional capsule of tools, a capsule of buttons, then a round close button.
/// At most one tool is selected; picking it again clears it.
final class GlassBar: NSView {
    /// An icon-only toggle in the tools' capsule.
    struct Tool {
        let icon: LucideIcon
        let toolTip: String
    }

    /// A clickable item, with a key cap when it has a shortcut to show.
    struct Item {
        let icon: LucideIcon
        let title: String
        let shortcut: BarButton.Shortcut?
        let toolTip: String
        let perform: @MainActor () -> Void
    }

    var onSelectTool: (@MainActor (Int?) -> Void)?

    private var handlers: [@MainActor () -> Void] = []
    private var toolButtons: [BarButton] = []
    private(set) var selectedTool: Int?

    init(tools: [Tool] = [], items: [Item], closeToolTip: String, close: @escaping @MainActor () -> Void) {
        super.init(frame: .zero)
        let height = Config.Bar.itemHeight + Config.Bar.padding * 2
        var capsuleLeft: CGFloat = 0
        if !tools.isEmpty {
            let toolCapsule = toolCapsule(for: tools, height: height)
            addSubview(toolCapsule)
            capsuleLeft = toolCapsule.frame.maxX + Config.Bar.closeGap
        }
        let capsule = GlassPanel()
        var left = Config.Bar.padding
        for item in items {
            let view = button(
                icon: item.icon, title: item.title, shortcut: item.shortcut, toolTip: item.toolTip,
                perform: item.perform)
            let width = view.intrinsicContentSize.width
            view.frame = CGRect(x: left, y: Config.Bar.padding, width: width, height: Config.Bar.itemHeight)
            capsule.content.addSubview(view)
            left += width
        }
        capsule.frame = CGRect(x: capsuleLeft, y: 0, width: left + Config.Bar.padding, height: height)
        addSubview(capsule)

        let circle = GlassPanel(
            frame: CGRect(x: capsule.frame.maxX + Config.Bar.closeGap, y: 0, width: height, height: height))
        let closeButton = button(icon: .close, title: nil, shortcut: nil, toolTip: closeToolTip, perform: close)
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
        icon: LucideIcon, title: String?, shortcut: BarButton.Shortcut?, toolTip: String,
        perform: @escaping @MainActor () -> Void
    ) -> BarButton {
        let button = BarButton(icon: icon, title: title, shortcut: shortcut, toolTip: toolTip)
        button.tag = handlers.count
        handlers.append(perform)
        button.target = self
        button.action = #selector(pressed(_:))
        return button
    }

    /// Marks one tool as selected, or none.
    func selectTool(_ index: Int?) {
        selectedTool = index
        for (buttonIndex, button) in toolButtons.enumerated() {
            button.isSelected = buttonIndex == index
        }
    }

    /// The tools' own capsule, left of the main capsule.
    private func toolCapsule(for tools: [Tool], height: CGFloat) -> GlassPanel {
        let capsule = GlassPanel()
        var left = Config.Bar.padding
        for (index, tool) in tools.enumerated() {
            let button = BarButton(icon: tool.icon, title: nil, toolTip: tool.toolTip)
            button.isToggle = true
            button.tag = index
            button.target = self
            button.action = #selector(toolPressed(_:))
            button.frame = CGRect(
                x: left, y: Config.Bar.padding, width: Config.Bar.toolWidth, height: Config.Bar.itemHeight)
            capsule.content.addSubview(button)
            toolButtons.append(button)
            left += Config.Bar.toolWidth
        }
        capsule.frame = CGRect(x: 0, y: 0, width: left + Config.Bar.padding, height: height)
        return capsule
    }

    @objc private func toolPressed(_ sender: NSControl) {
        let index = sender.tag == selectedTool ? nil : sender.tag
        selectTool(index)
        onSelectTool?(index)
    }

    @objc private func pressed(_ sender: NSControl) {
        guard handlers.indices.contains(sender.tag) else { return }
        handlers[sender.tag]()
    }
}
