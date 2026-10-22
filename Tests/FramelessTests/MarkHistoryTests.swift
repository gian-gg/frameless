import CoreGraphics
import Testing

@testable import Frameless

struct MarkHistoryTests {
    private func mark(_ offset: CGFloat) -> Mark {
        Mark(tool: .rectangle, points: [CGPoint(x: offset, y: 0)], color: .white)
    }

    @Test("undo takes back the last mark and redo puts it back")
    func undoesAndRedoes() {
        var history = MarkHistory()
        history.add(mark(1))
        history.add(mark(2))

        history.undo()
        #expect(history.marks == [mark(1)])
        #expect(history.canRedo)

        history.redo()
        #expect(history.marks == [mark(1), mark(2)])
        #expect(!history.canRedo)
    }

    @Test("a new mark clears what could be redone")
    func newMarkClearsRedo() {
        var history = MarkHistory()
        history.add(mark(1))
        history.undo()
        history.add(mark(2))

        #expect(!history.canRedo)
        #expect(history.marks == [mark(2)])
    }

    @Test("undo and redo with nothing to do change nothing")
    func emptyUndoRedo() {
        var history = MarkHistory()
        history.undo()
        history.redo()
        #expect(history == MarkHistory())
        #expect(!history.canUndo)
    }

    @Test("an edit to an existing mark undoes back to how it was")
    func undoesEdits() {
        var history = MarkHistory()
        history.add(mark(1))
        history.change { $0[0].points = [CGPoint(x: 9, y: 9)] }

        #expect(history.marks[0].points == [CGPoint(x: 9, y: 9)])
        history.undo()
        #expect(history.marks == [mark(1)])
        history.redo()
        #expect(history.marks[0].points == [CGPoint(x: 9, y: 9)])
    }

    @Test("an edit that changes nothing isn't an undo step")
    func ignoresEmptyEdits() {
        var history = MarkHistory()
        history.add(mark(1))
        history.change { _ in }
        history.undo()
        #expect(history.marks.isEmpty)
    }

    @Test("restyling a mark undoes back to its old colour and thickness")
    func undoesRestyle() {
        var history = MarkHistory()
        history.add(mark(1))
        history.change {
            $0[0].color = .red
            $0[0].weight = .thick
        }
        #expect(history.marks[0].color == .red && history.marks[0].weight == .thick)

        history.undo()
        #expect(history.marks == [mark(1)])
    }
}
