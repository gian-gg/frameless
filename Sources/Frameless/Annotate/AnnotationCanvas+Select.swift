import AppKit

/// With no tool picked: clicking a mark selects it and dragging moves it, as one undoable step.
extension AnnotationCanvas {
    /// The marks as shown, with the selected one following the drag.
    var shownMarks: [Mark] {
        guard let index = selection, let offset = moveOffset, history.marks.indices.contains(index) else {
            return history.marks
        }
        var marks = history.marks
        marks[index] = MarkGeometry.moved(marks[index], by: offset)
        return marks
    }

    /// Whether a mark sits under a point given in window coordinates.
    func hasMark(atWindowPoint point: CGPoint) -> Bool {
        MarkGeometry.index(at: convert(point, from: nil), in: history.marks) != nil
    }

    func beginSelecting(at point: CGPoint) {
        selection = MarkGeometry.index(at: point, in: history.marks)
        moveStart = selection == nil ? nil : point
        moveOffset = nil
    }

    func dragSelection(to point: CGPoint) {
        guard let start = moveStart else { return }
        moveOffset = CGVector(dx: point.x - start.x, dy: point.y - start.y)
        NSCursor.closedHand.set()
    }

    func endSelecting() {
        defer {
            moveStart = nil
            moveOffset = nil
        }
        guard let index = selection, let offset = moveOffset, offset != .zero else { return }
        editMarks { $0[index] = MarkGeometry.moved($0[index], by: offset) }
    }

    /// A dashed outline around the selected mark.
    func drawSelection(in context: CGContext) {
        guard let index = selection, shownMarks.indices.contains(index),
            let frame = MarkGeometry.frame(of: shownMarks[index])
        else { return }
        let outset = -Config.Annotate.selectionInset
        context.saveGState()
        defer { context.restoreGState() }
        context.setShadow(offset: .zero, blur: Config.Annotate.shadowBlur * abs(context.ctm.a), color: .black)
        context.setStrokeColor(CGColor(gray: 1, alpha: 1))
        context.setLineWidth(1)
        context.setLineDash(phase: 0, lengths: Config.Annotate.selectionDash)
        context.stroke(frame.insetBy(dx: outset, dy: outset))
    }
}
