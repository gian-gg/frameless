import CoreGraphics

/// How thick a mark's lines are drawn.
enum MarkWeight: String, CaseIterable {
    case thin
    case medium
    case thick

    var name: String { rawValue.capitalized }

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
