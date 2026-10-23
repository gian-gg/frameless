import AppKit

/// A click-through glass card beside the area showing the stitched image as it grows, or a hint when it's lost.
@MainActor
final class ScrollPreview {
    private var panel: NSPanel?
    private let imageView = NSView()
    private let hint = GlassTag()

    /// Shows the card to the right of the area, or to its left when there's no room.
    func show(beside area: CGRect, on screen: CGRect) {
        let width = Config.Scroll.previewWidth
        let gap = Config.Scroll.previewGap
        let left = area.maxX + gap + width <= screen.maxX ? area.maxX + gap : area.minX - gap - width
        let frame = CGRect(x: left, y: area.minY, width: width, height: area.height)
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
        card.content.addSubview(imageView)
        hint.isMonospaced = false
        hint.isHidden = true
        card.content.addSubview(hint)
        panel.contentView = card
        panel.orderFrontRegardless()
        self.panel = panel
    }

    /// Shows the latest stitched image, shrunk to the card's width and pinned to its bottom so the newest rows show.
    func update(_ image: CGImage) {
        guard let layer = imageView.layer else { return }
        layer.contentsGravity = .bottom
        let scale = imageView.bounds.width / CGFloat(image.width)
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
