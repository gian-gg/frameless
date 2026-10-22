import CoreGraphics
import CoreText
import Foundation

extension MarkRenderer {
    /// The font text marks of this weight are set in.
    static func textFont(for weight: MarkWeight) -> CTFont {
        CTFontCreateUIFontForLanguage(.emphasizedSystem, weight.textSize, nil)
            ?? CTFontCreateWithName("Helvetica-Bold" as CFString, weight.textSize, nil)
    }

    /// Where a text's baseline starts so its capital letters sit centred on the clicked point.
    static func textBaseline(at point: CGPoint, font: CTFont) -> CGPoint {
        CGPoint(x: point.x, y: point.y - CTFontGetCapHeight(font) / 2)
    }

    /// The mark's text in its colour, its halo already set by the caller.
    static func drawText(_ mark: Mark, in context: CGContext) {
        guard let point = mark.points.first, !mark.text.isEmpty else { return }
        let font = textFont(for: mark.weight)
        let text = NSAttributedString(
            string: mark.text,
            attributes: [
                kCTFontAttributeName as NSAttributedString.Key: font,
                kCTForegroundColorAttributeName as NSAttributedString.Key: mark.color.cgColor,
            ])
        context.textMatrix = .identity
        context.textPosition = textBaseline(at: point, font: font)
        CTLineDraw(CTLineCreateWithAttributedString(text), context)
    }
}
