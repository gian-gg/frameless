import AppKit

/// Click-through viewfinder around the area being recorded, dimming the rest of its display.
@MainActor
final class AreaOutline {
    private var window: NSWindow?

    /// Shows the viewfinder for an area selection; whole-display selections show nothing.
    func show(_ selection: CaptureSelection) {
        hide()
        guard let area = selection.area else { return }
        let window = NSWindow(
            contentRect: selection.screenFrame, styleMask: .borderless, backing: .buffered, defer: false)
        window.setFrame(selection.screenFrame, display: false)
        window.level = .floating
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = false
        window.ignoresMouseEvents = true
        window.isReleasedWhenClosed = false
        window.sharingType = .none
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        window.contentView = ViewfinderView(area: area)
        window.orderFrontRegardless()
        self.window = window
    }

    func hide() {
        window?.orderOut(nil)
        window = nil
    }
}

/// Dims outside the area and draws corner brackets joined by a hairline.
private final class ViewfinderView: NSView {
    private let frameRect: CGRect

    init(area: CGRect) {
        frameRect = area.insetBy(dx: -Config.Outline.gap, dy: -Config.Outline.gap)
        super.init(frame: .zero)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { nil }

    override func draw(_ dirtyRect: NSRect) {
        NSColor.black.withAlphaComponent(Config.Outline.dimOpacity).setFill()
        bounds.fill()
        NSColor.clear.setFill()
        frameRect.fill(using: .copy)

        let hairline = NSBezierPath(rect: frameRect.insetBy(dx: 0.5, dy: 0.5))
        hairline.lineWidth = 1
        NSColor.white.withAlphaComponent(0.45).setStroke()
        hairline.stroke()

        NSGraphicsContext.saveGraphicsState()
        let shadow = NSShadow()
        shadow.shadowColor = NSColor.black.withAlphaComponent(0.5)
        shadow.shadowBlurRadius = 3
        shadow.set()
        let corners = cornerPath()
        corners.lineWidth = Config.Outline.cornerWidth
        corners.lineCapStyle = .round
        corners.lineJoinStyle = .round
        NSColor.white.setStroke()
        corners.stroke()
        NSGraphicsContext.restoreGraphicsState()
    }

    private func cornerPath() -> NSBezierPath {
        let rect = frameRect.insetBy(dx: Config.Outline.cornerWidth / 2, dy: Config.Outline.cornerWidth / 2)
        let length = min(Config.Outline.cornerLength, rect.width / 3, rect.height / 3)
        let path = NSBezierPath()
        let corners: [(CGPoint, CGVector)] = [
            (CGPoint(x: rect.minX, y: rect.minY), CGVector(dx: 1, dy: 1)),
            (CGPoint(x: rect.maxX, y: rect.minY), CGVector(dx: -1, dy: 1)),
            (CGPoint(x: rect.minX, y: rect.maxY), CGVector(dx: 1, dy: -1)),
            (CGPoint(x: rect.maxX, y: rect.maxY), CGVector(dx: -1, dy: -1)),
        ]
        for (corner, direction) in corners {
            path.move(to: CGPoint(x: corner.x + length * direction.dx, y: corner.y))
            path.line(to: corner)
            path.line(to: CGPoint(x: corner.x, y: corner.y + length * direction.dy))
        }
        return path
    }
}
