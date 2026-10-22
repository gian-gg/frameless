/// The drawing tools in the selection editor's tool bar, each picked by a single key.
enum AnnotationTool: CaseIterable {
    case rectangle
    case line
    case arrow
    case freehand
    case highlight
    case pixelate
    case steps
    case text

    var name: String {
        switch self {
        case .rectangle: "Rectangle"
        case .line: "Line"
        case .arrow: "Arrow"
        case .freehand: "Draw"
        case .highlight: "Highlight"
        case .pixelate: "Pixelate"
        case .steps: "Steps"
        case .text: "Text"
        }
    }

    var icon: LucideIcon {
        switch self {
        case .rectangle: .square
        case .line: .slash
        case .arrow: .arrowUpRight
        case .freehand: .pencil
        case .highlight: .highlighter
        case .pixelate: .grid2x2
        case .steps: .listOrdered
        case .text: .type
        }
    }

    var key: Character {
        switch self {
        case .rectangle: "r"
        case .line: "l"
        case .arrow: "a"
        case .freehand: "d"
        case .highlight: "h"
        case .pixelate: "p"
        case .steps: "n"
        case .text: "t"
        }
    }

    /// The tool whose key this is, ignoring case.
    static func forKey(_ characters: String) -> AnnotationTool? {
        guard characters.count == 1, let key = characters.lowercased().first else { return nil }
        return allCases.first { $0.key == key }
    }
}
