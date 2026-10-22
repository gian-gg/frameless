import AppKit

/// A glass capsule of style samples, such as colours or line thicknesses, with one marked as chosen.
final class SampleRow: GlassPanel {
    struct Choice {
        let sample: BarButton.Sample
        let toolTip: String
    }

    var onPick: (@MainActor (Int) -> Void)?

    init(choices: [Choice], selected: Int?) {
        super.init(frame: .zero)
        let side = Config.Bar.itemHeight
        let lens = GlassLens.make()
        if let lens { content.addSubview(lens) }
        var left = Config.Bar.padding
        for (index, choice) in choices.enumerated() {
            let button = BarButton(sample: choice.sample, toolTip: choice.toolTip)
            button.isSelected = index == selected
            button.drawsSelection = lens == nil
            button.tag = index
            button.target = self
            button.action = #selector(picked(_:))
            button.frame = CGRect(x: left, y: Config.Bar.padding, width: Config.Bar.toolWidth, height: side)
            content.addSubview(button)
            if index == selected { lens?.move(to: button.frame, animated: false) }
            left += Config.Bar.toolWidth
        }
        setFrameSize(CGSize(width: left + Config.Bar.padding, height: side + Config.Bar.padding * 2))
        GlassLens.followHover(in: content)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { nil }

    /// Clicks on the glass between samples stop here instead of reaching the editor behind.
    override func mouseDown(with event: NSEvent) {}

    override func mouseUp(with event: NSEvent) {}

    @objc private func picked(_ sender: NSControl) {
        onPick?(sender.tag)
    }
}
