import AppKit

/// A small glass capsule behind a row's selected or hovered button, sliding from button to button; macOS 26 and
/// later.
final class GlassLens: NSView {
    private var hideTask: Task<Void, Never>?

    /// A hidden lens, or nil before macOS 26.
    static func make(tint: CGFloat = Config.Bar.lensTintOpacity) -> GlassLens? {
        guard #available(macOS 26, *) else { return nil }
        return GlassLens(tint: tint)
    }

    /// Puts a fainter lens behind the bar buttons in `container` that follows the pointer between them.
    static func followHover(in container: NSView) {
        let buttons = container.subviews.compactMap { $0 as? BarButton }
        guard !buttons.isEmpty, let lens = make(tint: Config.Bar.hoverLensTintOpacity) else { return }
        container.addSubview(lens, positioned: .below, relativeTo: nil)
        for button in buttons {
            button.drawsHover = false
            button.onHover = { [weak lens, weak button] isInside in
                lens?.follow(isInside ? button?.frame : nil)
            }
        }
    }

    /// Moves to the hovered button; leaving waits a moment so moving to a neighbour slides rather than blinks.
    func follow(_ target: CGRect?) {
        hideTask?.cancel()
        guard target == nil else { return move(to: target) }
        hideTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(Config.Bar.hoverLensGrace))
            guard !Task.isCancelled else { return }
            self?.move(to: nil)
        }
    }

    @available(macOS 26, *)
    private init(tint: CGFloat) {
        super.init(frame: .zero)
        let glass = NSGlassEffectView()
        glass.tintColor = NSColor.white.withAlphaComponent(tint)
        glass.cornerRadius = Config.Bar.itemHeight / 2
        glass.frame = bounds
        glass.autoresizingMask = [.width, .height]
        addSubview(glass)
        alphaValue = 0
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { nil }

    override func hitTest(_ point: NSPoint) -> NSView? { nil }

    /// Slides to a button's frame, appears there if it was hidden, or fades out for none.
    func move(to target: CGRect?, animated: Bool = true) {
        guard let target else {
            animate(animated) { $0.alphaValue = 0 }
            return
        }
        if alphaValue == 0 {
            frame = target
            animate(animated) { $0.alphaValue = 1 }
        } else {
            animate(animated) { $0.frame = target }
        }
    }

    private func animate(_ animated: Bool, _ change: @escaping (GlassLens) -> Void) {
        guard animated else { return change(self) }
        NSAnimationContext.runAnimationGroup { context in
            context.duration = Config.Bar.lensDuration
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            change(animator())
        }
    }
}
