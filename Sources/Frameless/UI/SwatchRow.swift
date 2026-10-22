import AppKit

/// A glass capsule of colour swatches with one marked as chosen; picking one reports its index.
final class SwatchRow: GlassPanel {
    struct Swatch {
        let color: NSColor
        let toolTip: String
    }

    var onPick: (@MainActor (Int) -> Void)?

    init(swatches: [Swatch], selected: Int?) {
        super.init(frame: .zero)
        let side = Config.Bar.itemHeight
        var left = Config.Bar.padding
        for (index, swatch) in swatches.enumerated() {
            let button = BarButton(swatch: swatch.color, toolTip: swatch.toolTip)
            button.isSelected = index == selected
            button.tag = index
            button.target = self
            button.action = #selector(picked(_:))
            button.frame = CGRect(x: left, y: Config.Bar.padding, width: Config.Bar.toolWidth, height: side)
            content.addSubview(button)
            left += Config.Bar.toolWidth
        }
        setFrameSize(CGSize(width: left + Config.Bar.padding, height: side + Config.Bar.padding * 2))
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { nil }

    /// Clicks on the glass between swatches stop here instead of reaching the editor behind.
    override func mouseDown(with event: NSEvent) {}

    override func mouseUp(with event: NSEvent) {}

    @objc private func picked(_ sender: NSControl) {
        onPick?(sender.tag)
    }
}
