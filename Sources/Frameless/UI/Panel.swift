import AppKit

/// Shared HUD pieces: fonts and the selection frame.
@MainActor
enum Panel {
    /// A font for glass surfaces; colour comes from the label colours so the glass keeps it legible.
    static func font(size: CGFloat, weight: NSFont.Weight, monospaced: Bool = false) -> NSFont {
        monospaced
            ? NSFont.monospacedDigitSystemFont(ofSize: size, weight: weight)
            : NSFont.systemFont(ofSize: size, weight: weight)
    }

    /// Soft white line just outside a rect, with round handles on its corners.
    static func drawSelectionFrame(_ rect: CGRect) {
        NSGraphicsContext.saveGraphicsState()
        let shadow = NSShadow()
        shadow.shadowColor = NSColor.black.withAlphaComponent(0.35)
        shadow.shadowBlurRadius = 4
        shadow.set()

        let line = NSBezierPath(rect: rect.insetBy(dx: -0.75, dy: -0.75))
        line.lineWidth = 1.5
        NSColor.white.withAlphaComponent(0.9).setStroke()
        line.stroke()

        let handle = Config.Style.handleSize
        let corners = [
            CGPoint(x: rect.minX, y: rect.minY), CGPoint(x: rect.maxX, y: rect.minY),
            CGPoint(x: rect.minX, y: rect.maxY), CGPoint(x: rect.maxX, y: rect.maxY),
        ]
        NSColor.white.setFill()
        for corner in corners {
            NSBezierPath(
                ovalIn: CGRect(x: corner.x - handle / 2, y: corner.y - handle / 2, width: handle, height: handle)
            ).fill()
        }
        NSGraphicsContext.restoreGraphicsState()
    }
}
