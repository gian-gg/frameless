import AppKit

/// A glass tooltip drawn inside the button's own window.
@MainActor
final class HoverTip {
    private let tag = GlassTag()
    private var showTask: Task<Void, Never>?

    init() {
        tag.isMonospaced = false
    }

    /// Shows `text` above the view after a short hover, or below it when there's no room above.
    func schedule(_ text: String, for view: NSView) {
        hide()
        showTask = Task { [weak self, weak view] in
            try? await Task.sleep(for: .seconds(Config.Bar.tipDelay))
            guard !Task.isCancelled, let self, let view else { return }
            self.show(text, for: view)
        }
    }

    func hide() {
        showTask?.cancel()
        showTask = nil
        tag.removeFromSuperview()
    }

    private func show(_ text: String, for view: NSView) {
        guard let root = view.window?.contentView else { return }
        tag.show(text)
        let frame = view.convert(view.bounds, to: root)
        let size = tag.frame.size
        let above = frame.maxY + Config.Bar.tipGap
        let bottom = above + size.height <= root.bounds.maxY ? above : frame.minY - Config.Bar.tipGap - size.height
        let left = min(max(frame.midX - size.width / 2, root.bounds.minX), root.bounds.maxX - size.width)
        tag.setFrameOrigin(CGPoint(x: left.rounded(), y: bottom.rounded()))
        root.addSubview(tag)
    }
}
