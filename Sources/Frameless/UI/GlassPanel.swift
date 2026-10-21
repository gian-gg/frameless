import AppKit

/// Liquid Glass surface on macOS 26, frosted glass before; a capsule unless `isCapsule` is off.
/// Subclasses add their views to `content`.
class GlassPanel: NSView {
    let content = NSView()
    var isCapsule = true {
        didSet { needsLayout = true }
    }

    private let background: NSView

    override init(frame: NSRect) {
        content.autoresizingMask = [.width, .height]
        background = Self.background(holding: content)
        super.init(frame: frame)
        appearance = NSAppearance(named: .darkAqua)
        content.frame = bounds
        background.frame = bounds
        background.autoresizingMask = [.width, .height]
        addSubview(background)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { nil }

    override func layout() {
        super.layout()
        let radius = isCapsule ? bounds.height / 2 : Config.Style.cornerRadius
        if #available(macOS 26, *), let glass = background as? NSGlassEffectView {
            glass.cornerRadius = radius
        } else {
            background.layer?.cornerRadius = radius
        }
    }

    private static func background(holding content: NSView) -> NSView {
        if #available(macOS 26, *) {
            let glass = NSGlassEffectView()
            glass.tintColor = NSColor.black.withAlphaComponent(Config.Style.glassTintOpacity)
            glass.contentView = content
            return glass
        }
        let frosted = NSVisualEffectView()
        frosted.material = .hudWindow
        frosted.blendingMode = .behindWindow
        frosted.state = .active
        frosted.wantsLayer = true
        frosted.layer?.masksToBounds = true
        frosted.layer?.borderWidth = 1
        frosted.layer?.borderColor = NSColor.white.withAlphaComponent(Config.Style.hairlineOpacity).cgColor
        frosted.addSubview(content)
        return frosted
    }
}
