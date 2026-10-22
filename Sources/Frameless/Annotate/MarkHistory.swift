/// The marks drawn so far, with undo and redo: each change keeps the marks as they were before it, and a new change
/// clears what can be redone.
struct MarkHistory: Equatable {
    private(set) var marks: [Mark] = []
    private var past: [[Mark]] = []
    private var future: [[Mark]] = []

    var canUndo: Bool { !past.isEmpty }
    var canRedo: Bool { !future.isEmpty }

    mutating func add(_ mark: Mark) {
        change { $0.append(mark) }
    }

    /// Applies an edit to the marks as one undoable step; an edit that changes nothing isn't recorded.
    mutating func change(_ edit: (inout [Mark]) -> Void) {
        var next = marks
        edit(&next)
        guard next != marks else { return }
        past.append(marks)
        marks = next
        future.removeAll()
    }

    mutating func undo() {
        guard let previous = past.popLast() else { return }
        future.append(marks)
        marks = previous
    }

    mutating func redo() {
        guard let next = future.popLast() else { return }
        past.append(marks)
        marks = next
    }
}
