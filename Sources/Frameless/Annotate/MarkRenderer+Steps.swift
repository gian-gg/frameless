import CoreGraphics
import CoreText
import Foundation

extension MarkRenderer {
    /// Each step mark paired with its number, counting up in the order the steps were placed.
    static func numberedSteps(in marks: [Mark]) -> [(mark: Mark, number: Int)] {
        marks.filter { $0.tool == .steps }.enumerated().map { (mark: $1, number: $0 + 1) }
    }

    /// A filled circle in the mark's colour at its point, with the number in black or white, whichever reads better.
    static func drawStep(_ mark: Mark, number: Int, in context: CGContext) {
        guard let center = mark.points.first else { return }
        let diameter = mark.weight.stepDiameter
        let circle = CGRect(
            x: center.x - diameter / 2, y: center.y - diameter / 2, width: diameter, height: diameter)
        context.saveGState()
        defer { context.restoreGState() }
        context.setShadow(
            offset: .zero, blur: Config.Annotate.shadowBlur * abs(context.ctm.a), color: mark.color.halo)
        context.setFillColor(mark.color.cgColor)
        context.fillEllipse(in: circle)
        context.setShadow(offset: .zero, blur: 0, color: nil)

        let font = CTFontCreateUIFontForLanguage(.emphasizedSystem, diameter * Config.Annotate.stepTextShare, nil)
        let text = NSAttributedString(
            string: "\(number)",
            attributes: [
                kCTFontAttributeName as NSAttributedString.Key: font as Any,
                kCTForegroundColorAttributeName as NSAttributedString.Key: mark.color.contrastingText,
            ])
        let line = CTLineCreateWithAttributedString(text)
        let glyphs = CTLineGetBoundsWithOptions(line, .useGlyphPathBounds)
        context.textMatrix = .identity
        context.textPosition = CGPoint(x: center.x - glyphs.midX, y: center.y - glyphs.midY)
        CTLineDraw(line, context)
    }
}
