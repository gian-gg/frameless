import AppKit

/// A small glass capsule behind the selected button in a row, sliding from button to button; macOS 26 and later.
final class GlassLens: NSView {
    /// A hidden lens, or nil before macOS 26.
    static func make() -> GlassLens? {
        guard #available(macOS 26, *) else { return nil }
        return GlassLens(tint: Config.Bar.lensTintOpacity)
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
