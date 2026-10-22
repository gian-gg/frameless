import AppKit

/// The colours a mark can be drawn in, each with a halo that keeps it visible on any screenshot.
enum MarkColor: String, CaseIterable {
    case white
    case black
    case red
    case yellow
    case green
    case blue

    var name: String { rawValue.capitalized }

    var cgColor: CGColor {
        switch self {
        case .white: CGColor(gray: 1, alpha: 1)
        case .black: CGColor(gray: 0, alpha: 1)
        case .red: CGColor(srgbRed: 1, green: 0.27, blue: 0.23, alpha: 1)
        case .yellow: CGColor(srgbRed: 1, green: 0.84, blue: 0.04, alpha: 1)
        case .green: CGColor(srgbRed: 0.2, green: 0.84, blue: 0.29, alpha: 1)
        case .blue: CGColor(srgbRed: 0.04, green: 0.52, blue: 1, alpha: 1)
        }
    }

    /// Black on the light colours and white on the rest, for text drawn on top.
    var contrastingText: CGColor {
        CGColor(gray: self == .white || self == .yellow ? 0 : 1, alpha: 1)
    }

    var nsColor: NSColor { NSColor(cgColor: cgColor) ?? .white }

    /// A light halo behind black and a dark one behind the bright colours.
    var halo: CGColor {
        CGColor(gray: self == .black ? 1 : 0, alpha: Config.Annotate.shadowOpacity)
    }
}
