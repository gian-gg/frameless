import CoreGraphics
import CoreText
import Foundation

/// Where marks are on the canvas: what each one covers, which one is under a point, and moving them.
enum MarkGeometry {
    /// The area a mark visibly covers, for its selection outline.
    static func frame(of mark: Mark) -> CGRect? {
        switch mark.tool {
        case .steps:
            guard let center = mark.points.first else { return nil }
            let radius = mark.weight.stepDiameter / 2
            return CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2)
        case .text:
            return textFrame(of: mark)
        case .highlight, .pixelate:
            return MarkRenderer.bounds(of: mark)
        case .rectangle, .line, .arrow, .freehand:
            let inset = -mark.weight.lineWidth / 2
            return MarkRenderer.bounds(of: mark)?.insetBy(dx: inset, dy: inset)
        }
    }

    /// Whether a point lands on the mark: inside boxes, circles and text, and close to strokes.
    static func contains(_ mark: Mark, _ point: CGPoint) -> Bool {
        let tolerance = max(Config.Annotate.hitTolerance, mark.weight.lineWidth)
        switch mark.tool {
        case .rectangle, .highlight, .pixelate, .steps, .text:
            return frame(of: mark)?.insetBy(dx: -tolerance / 2, dy: -tolerance / 2).contains(point) ?? false
        case .line, .arrow, .freehand:
            return zip(mark.points, mark.points.dropFirst()).contains { start, end in
                distance(from: point, toSegment: start, end) <= tolerance
            }
        }
    }

    /// The top-most mark under a point, as drawn: steps, then other marks, then highlights, then pixelated areas,
    /// later marks above earlier ones within each.
    static func index(at point: CGPoint, in marks: [Mark]) -> Int? {
        let layers: [Set<AnnotationTool>] = [
            [.steps], [.rectangle, .line, .arrow, .freehand, .text], [.highlight], [.pixelate],
        ]
        for layer in layers {
            if let index = marks.indices.reversed().first(where: {
                layer.contains(marks[$0].tool) && contains(marks[$0], point)
            }) {
                return index
            }
        }
        return nil
    }

    static func moved(_ mark: Mark, by offset: CGVector) -> Mark {
        var moved = mark
        moved.points = mark.points.map { CGPoint(x: $0.x + offset.dx, y: $0.y + offset.dy) }
        return moved
    }

    /// The text's typeset box, from its descenders up to its ascenders.
    private static func textFrame(of mark: Mark) -> CGRect? {
        guard let point = mark.points.first, !mark.text.isEmpty else { return nil }
        let font = MarkRenderer.textFont(for: mark.weight)
        let line = CTLineCreateWithAttributedString(
            NSAttributedString(string: mark.text, attributes: [kCTFontAttributeName as NSAttributedString.Key: font]))
        var ascent: CGFloat = 0
        var descent: CGFloat = 0
        let width = CTLineGetTypographicBounds(line, &ascent, &descent, nil)
        let baseline = MarkRenderer.textBaseline(at: point, font: font)
        return CGRect(x: baseline.x, y: baseline.y - descent, width: width, height: ascent + descent)
    }

    private static func distance(from point: CGPoint, toSegment start: CGPoint, _ end: CGPoint) -> CGFloat {
        let segment = CGVector(dx: end.x - start.x, dy: end.y - start.y)
        let lengthSquared = segment.dx * segment.dx + segment.dy * segment.dy
        guard lengthSquared > 0 else { return hypot(point.x - start.x, point.y - start.y) }
        let along = ((point.x - start.x) * segment.dx + (point.y - start.y) * segment.dy) / lengthSquared
        let clamped = min(max(along, 0), 1)
        return hypot(point.x - (start.x + clamped * segment.dx), point.y - (start.y + clamped * segment.dy))
    }
}
