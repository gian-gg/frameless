import CoreGraphics

/// Maximum output sizes offered in Preferences; Original keeps the source's pixels.
enum Resolution: String, CaseIterable, Sendable {
    case original
    case p1440
    case p1080
    case p720

    var title: String {
        switch self {
        case .original: "Original"
        case .p1440: "1440p"
        case .p1080: "1080p"
        case .p720: "720p"
        }
    }

    /// Landscape box the output must fit in, or nil for no limit.
    var maxSize: CGSize? {
        switch self {
        case .original: nil
        case .p1440: CGSize(width: 2560, height: 1440)
        case .p1080: CGSize(width: 1920, height: 1080)
        case .p720: CGSize(width: 1280, height: 720)
        }
    }
}
