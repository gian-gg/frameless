import CoreGraphics

/// How thick a mark's lines are drawn.
enum MarkWeight: String, CaseIterable {
    case thin
    case medium
    case thick

    var name: String { rawValue.capitalized }

    /// The point size of a text mark.
    var textSize: CGFloat {
        switch self {
        case .thin: 16
        case .medium: 22
        case .thick: 32
        }
    }

    /// How wide a numbered step's circle is.
    var stepDiameter: CGFloat {
        switch self {
        case .thin: 18
        case .medium: 24
        case .thick: 32
        }
    }

    var lineWidth: CGFloat {
        switch self {
        case .thin: 2
        case .medium: 3
        case .thick: 5
        }
    }
}
