import CoreGraphics

/// How thick a mark's lines are drawn.
enum MarkWeight: String, CaseIterable {
    case thin
    case medium
    case thick

    var name: String { rawValue.capitalized }

    var lineWidth: CGFloat {
        switch self {
        case .thin: 2
        case .medium: 3
        case .thick: 5
        }
    }
}
