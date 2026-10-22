/// The marks drawn so far, with undo and redo; drawing a new mark clears what can be redone.
struct MarkHistory: Equatable {
    private(set) var marks: [Mark] = []
    private var undone: [Mark] = []

    var canUndo: Bool { !marks.isEmpty }
    var canRedo: Bool { !undone.isEmpty }

    mutating func add(_ mark: Mark) {
        marks.append(mark)
        undone.removeAll()
    }

    mutating func undo() {
        guard let mark = marks.popLast() else { return }
        undone.append(mark)
    }

    mutating func redo() {
        guard let mark = undone.popLast() else { return }
        marks.append(mark)
    }
}
