import AppKit

/// Shared text, symbol and pill drawing for the selection overlay.
@MainActor
enum OverlayDrawing {
    static let pillRadius: CGFloat = 10

    static func text(
        _ string: String, size: CGFloat, weight: NSFont.Weight, monospaced: Bool = false, alpha: CGFloat = 1
    ) -> NSAttributedString {
        let font =
            monospaced
            ? NSFont.monospacedDigitSystemFont(ofSize: size, weight: weight)
            : NSFont.systemFont(ofSize: size, weight: weight)
        let color = NSColor.white.withAlphaComponent(alpha)
        return NSAttributedString(string: string, attributes: [.font: font, .foregroundColor: color])
    }

    /// A white SF Symbol at the given size.
    static func symbol(
        _ name: String, pointSize: CGFloat, weight: NSFont.Weight = .regular, alpha: CGFloat = 1
    ) -> NSImage? {
        let config = NSImage.SymbolConfiguration(pointSize: pointSize, weight: weight)
            .applying(NSImage.SymbolConfiguration(paletteColors: [NSColor.white.withAlphaComponent(alpha)]))
        return NSImage(systemSymbolName: name, accessibilityDescription: nil)?.withSymbolConfiguration(config)
    }

    /// Dark translucent rounded background with a hairline edge.
    static func fillPill(_ frame: CGRect, radius: CGFloat = pillRadius) {
        let shape = NSBezierPath(roundedRect: frame, xRadius: radius, yRadius: radius)
        NSColor.black.withAlphaComponent(Config.Overlay.pillOpacity).setFill()
        shape.fill()
        NSColor.white.withAlphaComponent(0.12).setStroke()
        shape.lineWidth = 1
        shape.stroke()
    }
}

/// Centred card on the hovered display: icon, title, optional detail line and key hints.
@MainActor
struct HintCard {
    enum Glyph {
        case symbol(String)
        case key(String)
    }

    struct Hint {
        let glyph: Glyph
        let label: String
    }

    private enum Layout {
        static let padding = CGSize(width: 22, height: 16)
        static let cornerRadius: CGFloat = 14
        static let iconGap: CGFloat = 8
        static let sizeGap: CGFloat = 2
        static let dividerGap: CGFloat = 12
        static let hintSpacing: CGFloat = 18
        static let glyphGap: CGFloat = 6
        static let keyPadding = CGSize(width: 8, height: 2)
    }

    private enum RenderedGlyph {
        case symbol(NSImage?)
        case key(NSAttributedString)
    }

    private struct RenderedHint {
        let glyph: RenderedGlyph
        let label: NSAttributedString
    }

    private let icon: NSImage?
    private let title: NSAttributedString
    private let detail: NSAttributedString?
    private let hints: [RenderedHint]

    init(iconSymbol: String, title: String, detail: String?, hints: [Hint]) {
        icon = OverlayDrawing.symbol(iconSymbol, pointSize: 30, weight: .light)
        self.title = OverlayDrawing.text(title, size: 15, weight: .semibold)
        self.detail = detail.map {
            OverlayDrawing.text($0, size: 12, weight: .regular, monospaced: true, alpha: 0.6)
        }
        self.hints = hints.map { hint in
            let glyph: RenderedGlyph =
                switch hint.glyph {
                case .symbol(let name): .symbol(OverlayDrawing.symbol(name, pointSize: 13, alpha: 0.8))
                case .key(let key): .key(OverlayDrawing.text(key, size: 10, weight: .semibold, alpha: 0.8))
                }
            return RenderedHint(
                glyph: glyph, label: OverlayDrawing.text(hint.label, size: 12, weight: .regular, alpha: 0.8))
        }
    }

    /// The hovered display: click to record it, drag for an area, space for a window.
    static func display(pixelWidth: Int, pixelHeight: Int, purpose: CapturePurpose) -> HintCard {
        HintCard(
            iconSymbol: Config.Overlay.displaySymbol, title: Config.Overlay.displayTitle(purpose.verb),
            detail: "\(pixelWidth) × \(pixelHeight)",
            hints: [
                Hint(glyph: .symbol(Config.Overlay.dragSymbol), label: Config.Overlay.dragHint(purpose.verb)),
                Hint(glyph: .key("space"), label: Config.Overlay.windowHint),
                Hint(glyph: .key("esc"), label: Config.Overlay.cancelHint),
            ])
    }

    /// Window mode with no window under the cursor.
    static func windowMode(purpose: CapturePurpose) -> HintCard {
        HintCard(
            iconSymbol: Config.Overlay.windowSymbol, title: Config.Overlay.windowTitle(purpose.verb), detail: nil,
            hints: [
                Hint(glyph: .key("space"), label: Config.Overlay.screenHint),
                Hint(glyph: .key("esc"), label: Config.Overlay.cancelHint),
            ])
    }

    func draw(centeredIn bounds: CGRect) {
        let iconSize = icon?.size ?? .zero
        let row = hintRowSize()
        let detailHeight = detail.map { Layout.sizeGap + $0.size().height } ?? 0
        let contentWidth = max(title.size().width, detail?.size().width ?? 0, row.width)
        let contentHeight =
            iconSize.height + Layout.iconGap + title.size().height + detailHeight
            + Layout.dividerGap * 2 + 1 + row.height
        let card = CGRect(
            x: bounds.midX - contentWidth / 2 - Layout.padding.width,
            y: bounds.midY - contentHeight / 2 - Layout.padding.height,
            width: contentWidth + Layout.padding.width * 2,
            height: contentHeight + Layout.padding.height * 2
        ).integral
        OverlayDrawing.fillPill(card, radius: Layout.cornerRadius)

        var top = card.maxY - Layout.padding.height
        if let icon {
            top -= iconSize.height
            icon.draw(in: CGRect(origin: CGPoint(x: card.midX - iconSize.width / 2, y: top), size: iconSize))
        }
        top = drawCentered(title, below: top - Layout.iconGap, centerX: card.midX)
        if let detail {
            top = drawCentered(detail, below: top - Layout.sizeGap, centerX: card.midX)
        }

        top -= Layout.dividerGap
        NSColor.white.withAlphaComponent(0.12).setFill()
        CGRect(x: card.minX + Layout.padding.width, y: top - 1, width: card.width - Layout.padding.width * 2, height: 1)
            .fill()
        top -= 1 + Layout.dividerGap

        drawHintRow(row, top: top, centerX: card.midX)
    }

    private func drawCentered(_ text: NSAttributedString, below top: CGFloat, centerX: CGFloat) -> CGFloat {
        let size = text.size()
        text.draw(at: CGPoint(x: centerX - size.width / 2, y: top - size.height))
        return top - size.height
    }

    private func glyphSize(_ glyph: RenderedGlyph) -> CGSize {
        switch glyph {
        case .symbol(let image):
            return image?.size ?? .zero
        case .key(let text):
            let size = text.size()
            return CGSize(
                width: ceil(size.width) + Layout.keyPadding.width, height: ceil(size.height) + Layout.keyPadding.height)
        }
    }

    private func hintRowSize() -> CGSize {
        let widths = hints.map { glyphSize($0.glyph).width + Layout.glyphGap + $0.label.size().width }
        let heights = hints.flatMap { [glyphSize($0.glyph).height, $0.label.size().height] }
        let spacing = Layout.hintSpacing * CGFloat(max(0, hints.count - 1))
        return CGSize(width: widths.reduce(0, +) + spacing, height: heights.max() ?? 0)
    }

    private func drawHintRow(_ row: CGSize, top: CGFloat, centerX: CGFloat) {
        let midY = top - row.height / 2
        var left = centerX - row.width / 2
        for hint in hints {
            let glyph = glyphSize(hint.glyph)
            drawGlyph(
                hint.glyph, in: CGRect(x: left, y: midY - glyph.height / 2, width: glyph.width, height: glyph.height))
            left += glyph.width + Layout.glyphGap
            let label = hint.label.size()
            hint.label.draw(at: CGPoint(x: left, y: midY - label.height / 2))
            left += label.width + Layout.hintSpacing
        }
    }

    private func drawGlyph(_ glyph: RenderedGlyph, in frame: CGRect) {
        switch glyph {
        case .symbol(let image):
            image?.draw(in: frame)
        case .key(let text):
            let box = NSBezierPath(roundedRect: frame.insetBy(dx: 0.5, dy: 0.5), xRadius: 4, yRadius: 4)
            box.lineWidth = 1
            NSColor.white.withAlphaComponent(0.5).setStroke()
            box.stroke()
            let size = text.size()
            text.draw(at: CGPoint(x: frame.midX - size.width / 2, y: frame.midY - size.height / 2))
        }
    }
}
