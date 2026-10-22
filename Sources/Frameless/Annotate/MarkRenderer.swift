import CoreGraphics

/// Draws marks, both on screen and into the exported image, so the two always match.
enum MarkRenderer {
    /// Draws marks into a context whose units are selection points; `image` is the capture under them.
    static func draw(_ marks: [Mark], in context: CGContext, over image: CGImage, size: CGSize) {
        for mark in marks {
            draw(mark, in: context, over: image, size: size)
        }
    }

    /// The capture with its marks drawn on, at the capture's own pixel size.
    static func render(_ shot: CapturedImage, marks: [Mark]) -> CapturedImage? {
        guard !marks.isEmpty else { return shot }
        let width = shot.image.width
        let height = shot.image.height
        guard
            let context = CGContext(
                data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
                space: CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
        else { return nil }
        context.draw(shot.image, in: CGRect(x: 0, y: 0, width: width, height: height))
        context.scaleBy(x: shot.scale, y: shot.scale)
        let size = CGSize(width: CGFloat(width) / shot.scale, height: CGFloat(height) / shot.scale)
        draw(marks, in: context, over: shot.image, size: size)
        guard let image = context.makeImage() else { return nil }
        return CapturedImage(image: image, scale: shot.scale, displayID: shot.displayID)
    }

    /// Each tool draws its marks here.
    private static func draw(_ mark: Mark, in context: CGContext, over image: CGImage, size: CGSize) {
        context.saveGState()
        defer { context.restoreGState() }
        context.setStrokeColor(mark.color)
        context.setLineWidth(Config.Annotate.lineWidth)
        context.setLineJoin(.round)
        context.setLineCap(.round)
        let pixelsPerPoint = abs(context.ctm.a)
        context.setShadow(
            offset: .zero, blur: Config.Annotate.shadowBlur * pixelsPerPoint,
            color: CGColor(gray: 0, alpha: Config.Annotate.shadowOpacity))
        switch mark.tool {
        case .rectangle:
            drawRectangle(mark, in: context)
        case .line, .arrow, .freehand, .highlight, .pixelate, .steps, .text:
            break
        }
    }

    /// The rectangle spanned by a mark's first and last points.
    static func bounds(of mark: Mark) -> CGRect? {
        guard let first = mark.points.first, let last = mark.points.last else { return nil }
        return CGRect(x: first.x, y: first.y, width: last.x - first.x, height: last.y - first.y).standardized
    }

    private static func drawRectangle(_ mark: Mark, in context: CGContext) {
        guard let rect = bounds(of: mark) else { return }
        let radius = min(Config.Annotate.cornerRadius, rect.width / 2, rect.height / 2)
        context.addPath(CGPath(roundedRect: rect, cornerWidth: radius, cornerHeight: radius, transform: nil))
        context.strokePath()
    }
}
