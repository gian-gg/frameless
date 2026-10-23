import AppKit

/// A click-through glass card beside the area showing the stitched image, growing down with it up to the area's
/// height, or a hint when it's lost.
@MainActor
final class ScrollPreview {
    private var panel: NSPanel?
    /// The card's frame at its tallest: level with the area.
    private var fullFrame = CGRect.zero
    private let imageView = NSView()
    private let hint = GlassTag()

    /// Places the card to the right of the area, else to its left, else inside its right edge when neither side has
    /// room; it appears with the first image.
    func show(beside area: CGRect, on screen: CGRect) {
        let width = Config.Scroll.previewWidth
        let gap = Config.Scroll.previewGap
        let frame: CGRect
        if area.maxX + gap + width <= screen.maxX {
            frame = CGRect(x: area.maxX + gap, y: area.minY, width: width, height: area.height)
        } else if area.minX - gap - width >= screen.minX {
            frame = CGRect(x: area.minX - gap - width, y: area.minY, width: width, height: area.height)
        } else {
            frame = CGRect(x: area.maxX - gap - width, y: area.minY + gap, width: width, height: area.height - gap * 2)
        }
        fullFrame = frame
        let panel = NSPanel(
            contentRect: frame, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        panel.level = .statusBar
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.ignoresMouseEvents = true
        panel.sharingType = .none
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
        let card = GlassPanel(frame: CGRect(origin: .zero, size: frame.size))
        card.isCapsule = false
        imageView.wantsLayer = true
        imageView.layer?.contentsGravity = .top
        imageView.layer?.masksToBounds = true
        imageView.frame = card.bounds.insetBy(dx: Config.Feedback.thumbnailRim, dy: Config.Feedback.thumbnailRim)
        imageView.autoresizingMask = [.width, .height]
        card.content.addSubview(imageView)
        hint.isMonospaced = false
        hint.isHidden = true
        card.content.addSubview(hint)
        panel.contentView = card
        self.panel = panel
    }

    /// Shows the latest stitched image, shrunk to the card's width, growing the card down to fit it; once the card is
    /// full height the image is pinned to its bottom so the newest rows show.
    func update(_ image: CGImage) {
        guard let panel, let layer = imageView.layer else { return }
        let rim = Config.Feedback.thumbnailRim
        let scale = (fullFrame.width - rim * 2) / CGFloat(image.width)
        let height = min(fullFrame.height, (CGFloat(image.height) * scale + rim * 2).rounded())
        panel.setFrame(
            CGRect(x: fullFrame.minX, y: fullFrame.maxY - height, width: fullFrame.width, height: height),
            display: true)
        panel.orderFrontRegardless()
        layer.contentsGravity = .bottom
        layer.contentsScale = 1 / scale
        layer.contents = image
        hint.isHidden = true
    }

    /// A short note under the card's top edge, such as when scrolling went too far to follow.
    func showHint(_ text: String) {
        hint.show(text)
        hint.isHidden = false
        hint.setFrameOrigin(
            CGPoint(
                x: ((imageView.frame.width - hint.frame.width) / 2 + imageView.frame.minX).rounded(),
                y: imageView.frame.maxY - hint.frame.height - Config.Bar.padding))
    }

    func hide() {
        panel?.orderOut(nil)
        panel = nil
    }
}
