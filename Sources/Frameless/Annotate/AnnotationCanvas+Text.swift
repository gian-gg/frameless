import AppKit

/// Typing a text mark in place: a borderless field styled like the finished mark, turned into one on Return.
extension AnnotationCanvas: NSTextFieldDelegate {
    var isEditingText: Bool { textField != nil }

    func beginText(at point: CGPoint) {
        let font = MarkRenderer.textFont(for: weight) as NSFont
        let field = NSTextField(string: "")
        field.isBordered = false
        field.drawsBackground = false
        field.focusRingType = .none
        field.usesSingleLineMode = true
        field.font = font
        field.textColor = color.nsColor
        field.delegate = self
        let halo = NSShadow()
        halo.shadowBlurRadius = Config.Annotate.shadowBlur
        halo.shadowColor = NSColor(cgColor: color.halo)
        field.shadow = halo
        textField = field
        textPoint = point
        addSubview(field)
        placeTextField()
        window?.makeFirstResponder(field)
    }

    /// Turns what's been typed into a mark, if anything, and hands the keys back to the editor.
    func commitText() {
        guard let field = textField else { return }
        let text = field.stringValue.trimmingCharacters(in: .whitespaces)
        endText()
        if !text.isEmpty {
            add(Mark(tool: .text, points: [textPoint], color: color, weight: weight, text: text))
        }
    }

    func cancelText() {
        endText()
    }

    private func endText() {
        textField?.removeFromSuperview()
        textField = nil
        window?.makeFirstResponder(superview)
    }

    /// Sizes the field to the text being typed and lines its baseline up with where the finished mark will sit.
    private func placeTextField() {
        guard let field = textField, let font = field.font else { return }
        field.sizeToFit()
        let typed = field.currentEditor()?.string ?? field.stringValue
        let width = NSAttributedString(string: typed, attributes: [.font: font]).size().width
        let padding = Config.Annotate.textFieldInset * 2 + font.pointSize
        field.setFrameSize(CGSize(width: ceil(width + padding), height: field.frame.height))
        let baseline = MarkRenderer.textBaseline(at: textPoint, font: font as CTFont)
        let inset = Config.Annotate.textFieldInset
        field.setFrameOrigin(
            CGPoint(x: baseline.x - inset, y: baseline.y - (field.frame.height - field.firstBaselineOffsetFromTop)))
    }

    func controlTextDidChange(_ notification: Notification) {
        placeTextField()
    }

    func control(_ control: NSControl, textView: NSTextView, doCommandBy selector: Selector) -> Bool {
        switch selector {
        case #selector(NSResponder.insertNewline(_:)):
            commitText()
        case #selector(NSResponder.cancelOperation(_:)):
            cancelText()
        default:
            return false
        }
        return true
    }
}
