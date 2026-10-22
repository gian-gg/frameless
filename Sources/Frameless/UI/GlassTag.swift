import AppKit

/// Small glass capsule holding a label, monospaced by default, such as a selection's pixel size.
final class GlassTag: GlassPanel {
    private let label = NSTextField(labelWithString: "")
    var isMonospaced = true

    override init(frame: NSRect) {
        super.init(frame: frame)
        content.addSubview(label)
    }

    /// Sets the text and resizes the capsule to fit it.
    func show(_ text: String) {
        guard label.stringValue != text else { return }
        label.stringValue = text
        label.font = Panel.font(size: 11, weight: .semibold, monospaced: isMonospaced)
        label.textColor = .labelColor
        let textSize = label.intrinsicContentSize
        let padding = Config.Style.tagPadding
        setFrameSize(
            CGSize(width: ceil(textSize.width) + padding.width * 2, height: ceil(textSize.height) + padding.height * 2))
        label.frame = CGRect(origin: CGPoint(x: padding.width, y: padding.height), size: textSize)
    }
}
