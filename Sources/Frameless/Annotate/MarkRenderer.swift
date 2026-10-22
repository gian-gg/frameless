import CoreGraphics

/// Draws marks, both on screen and into the exported image, so the two always match.
enum MarkRenderer {
    /// Draws marks into a context whose units are selection points; `image` is the capture under them.
    /// Highlights go first, as one darkened layer, so every other mark sits above it.
    static func draw(_ marks: [Mark], in context: CGContext, over image: CGImage, size: CGSize) {
        let highlights = marks.filter { $0.tool == .highlight }
        if !highlights.isEmpty {
            drawSpotlight(highlights, in: context, size: size)
        }
        for mark in marks where mark.tool != .highlight {
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
        context.setStrokeColor(mark.color.cgColor)
        context.setLineWidth(mark.weight.lineWidth)
        context.setLineJoin(.round)
        context.setLineCap(.round)
        let pixelsPerPoint = abs(context.ctm.a)
        context.setShadow(
            offset: .zero, blur: Config.Annotate.shadowBlur * pixelsPerPoint,
            color: mark.color.halo)
        switch mark.tool {
        case .rectangle:
            drawRectangle(mark, in: context)
        case .line:
            drawLine(mark, in: context)
        case .arrow:
            drawArrow(mark, in: context)
        case .freehand:
            drawFreehand(mark, in: context)
        case .highlight, .pixelate, .steps, .text:
            break
        }
    }

    /// The smallest rectangle around all of a mark's points.
    static func bounds(of mark: Mark) -> CGRect? {
        guard let first = mark.points.first else { return nil }
        return mark.points.reduce(CGRect(origin: first, size: .zero)) { $0.union(CGRect(origin: $1, size: .zero)) }
    }

    private static func drawLine(_ mark: Mark, in context: CGContext) {
        guard let first = mark.points.first, let last = mark.points.last else { return }
        context.move(to: first)
        context.addLine(to: last)
        context.strokePath()
    }

    /// A line with an open head of two arms at its end, stroked as one path so they share a halo.
    private static func drawArrow(_ mark: Mark, in context: CGContext) {
        guard let start = mark.points.first, let end = mark.points.last else { return }
        let length = hypot(end.x - start.x, end.y - start.y)
        guard length > 0 else { return }
        let headLength = min(
            mark.weight.lineWidth * Config.Annotate.arrowHeadWidths, length * Config.Annotate.arrowHeadShare)
        let angle = atan2(end.y - start.y, end.x - start.x)
        context.move(to: start)
        context.addLine(to: end)
        for side: CGFloat in [-1, 1] {
            let armAngle = angle + .pi + side * Config.Annotate.arrowHeadAngle
            context.move(to: end)
            context.addLine(to: CGPoint(x: end.x + cos(armAngle) * headLength, y: end.y + sin(armAngle) * headLength))
        }
        context.strokePath()
    }

    /// Darkens everything outside the highlighted areas, cutting each area out of one dark sheet so overlaps stay
    /// bright, then lifts each area with a soft shadow and a light edge.
    private static func drawSpotlight(_ marks: [Mark], in context: CGContext, size: CGSize) {
        let areas = marks.compactMap(spotlightPath(for:))
        context.saveGState()
        defer { context.restoreGState() }
        context.beginTransparencyLayer(auxiliaryInfo: nil)
        context.setFillColor(CGColor(gray: 0, alpha: Config.Annotate.spotlightDim))
        context.fill(CGRect(origin: .zero, size: size))
        context.setShadow(
            offset: .zero, blur: Config.Annotate.spotlightShadowBlur * abs(context.ctm.a),
            color: CGColor(gray: 0, alpha: Config.Annotate.spotlightShadowOpacity))
        context.setStrokeColor(CGColor(gray: 0, alpha: 1))
        context.setLineWidth(Config.Annotate.spotlightEdgeWidth)
        for area in areas {
            context.addPath(area)
            context.strokePath()
        }
        context.setShadow(offset: .zero, blur: 0, color: nil)
        context.setBlendMode(.clear)
        for area in areas {
            context.addPath(area)
            context.fillPath()
        }
        context.endTransparencyLayer()
        context.setStrokeColor(CGColor(gray: 1, alpha: Config.Annotate.spotlightEdgeOpacity))
        context.setLineWidth(Config.Annotate.spotlightEdgeWidth)
        for area in areas {
            context.addPath(area)
            context.strokePath()
        }
    }

    private static func spotlightPath(for mark: Mark) -> CGPath? {
        guard let rect = bounds(of: mark) else { return nil }
        let radius = min(Config.Annotate.cornerRadius, rect.width / 2, rect.height / 2)
        return CGPath(roundedRect: rect, cornerWidth: radius, cornerHeight: radius, transform: nil)
    }

    /// A smooth curve through the stroke: each point bends the path towards it on the way to the next midpoint.
    private static func drawFreehand(_ mark: Mark, in context: CGContext) {
        guard let first = mark.points.first, let last = mark.points.last else { return }
        context.move(to: first)
        for (previous, point) in zip(mark.points, mark.points.dropFirst()) {
            let middle = CGPoint(x: (previous.x + point.x) / 2, y: (previous.y + point.y) / 2)
            context.addQuadCurve(to: middle, control: previous)
        }
        context.addLine(to: last)
        context.strokePath()
    }

    private static func drawRectangle(_ mark: Mark, in context: CGContext) {
        guard let rect = bounds(of: mark) else { return }
        let radius = min(Config.Annotate.cornerRadius, rect.width / 2, rect.height / 2)
        context.addPath(CGPath(roundedRect: rect, cornerWidth: radius, cornerHeight: radius, transform: nil))
        context.strokePath()
    }
}
