/// User-chosen capture settings, snapshotted when a recording starts.
struct RecordingOptions: Equatable, Sendable {
    var capturesSystemAudio = Config.Recording.capturesSystemAudio
    var showsCursor = Config.Recording.showsCursor
}
