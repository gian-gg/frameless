import AppKit

/// Glass capsule showing an icon and text, built like a bar item so it matches the bars; not clickable.
final class GlassLabel: GlassPanel {
    private var item: BarButton?

    /// Replaces the icon and text and resizes the capsule to fit, at the bars' height.
    func show(icon: LucideIcon, text: String) {
        item?.removeFromSuperview()
        let item = BarButton(icon: icon, title: text)
        item.isInteractive = false
        let size = CGSize(width: item.intrinsicContentSize.width, height: Config.Bar.itemHeight)
        item.frame = CGRect(origin: CGPoint(x: Config.Bar.padding, y: Config.Bar.padding), size: size)
        content.addSubview(item)
        self.item = item
        setFrameSize(CGSize(width: size.width + Config.Bar.padding * 2, height: size.height + Config.Bar.padding * 2))
    }
}
