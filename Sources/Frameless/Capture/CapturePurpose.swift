/// What the picker is choosing for, which sets the overlay's wording.
enum CapturePurpose {
    case screenshot
    case recording

    var verb: String {
        switch self {
        case .screenshot: "capture"
        case .recording: "record"
        }
    }
}
