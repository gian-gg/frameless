/// User-chosen capture settings, snapshotted when a recording starts.
struct RecordingOptions: Equatable, Sendable {
    var capturesSystemAudio = Config.Recording.capturesSystemAudio
    var capturesMicrophone = Config.Recording.capturesMicrophone
    var showsCursor = Config.Recording.showsCursor
    var videoCodec = Config.Recording.videoCodec
    var frameRate = Config.Recording.frameRate
}
