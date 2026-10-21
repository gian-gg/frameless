import AVFoundation

/// Video codec choices offered in Preferences.
enum VideoCodec: String, CaseIterable, Sendable {
    case h264
    case hevc

    var title: String {
        switch self {
        case .h264: "H.264 (compatible)"
        case .hevc: "HEVC (smaller files)"
        }
    }

    var codecType: AVVideoCodecType {
        switch self {
        case .h264: .h264
        case .hevc: .hevc
        }
    }
}
