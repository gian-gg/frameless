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
}
