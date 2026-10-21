/// Frame rate caps offered in Preferences.
enum FrameRate: Int, CaseIterable, Sendable {
    case fps30 = 30
    case fps60 = 60

    var title: String { "\(rawValue) fps" }
}
