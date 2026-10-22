import Foundation

/// What a capture is for, which sets the overlay's wording and where it's saved by default.
enum CapturePurpose: CaseIterable {
    case screenshot
    case recording

    var verb: String {
        switch self {
        case .screenshot: "capture"
        case .recording: "record"
        }
    }

    /// The folder that holds `Frameless/` when no save folder is chosen.
    var defaultSaveBase: URL {
        switch self {
        case .screenshot: .picturesDirectory
        case .recording: .moviesDirectory
        }
    }
}
