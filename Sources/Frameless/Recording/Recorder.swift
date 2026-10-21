import ScreenCaptureKit

/// Records a display or an area of it, with system audio, to disk via SCRecordingOutput.
@MainActor
final class Recorder: NSObject {
    enum RecorderError: Error {
        case noDisplay
        case notRecording
    }

    var onUnexpectedStop: (@MainActor (Error) -> Void)?

    private var stream: SCStream?
    private var outputURL: URL?
    private var isStopping = false
    private var finishResult: Result<Void, Error>?
    private var finishContinuation: CheckedContinuation<Void, Error>?

    func start(_ selection: CaptureSelection, options: RecordingOptions, to url: URL) async throws {
        let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
        guard let display = content.displays.first(where: { $0.displayID == selection.displayID }) else {
            throw RecorderError.noDisplay
        }
        let ownApps = content.applications.filter { $0.bundleIdentifier == Bundle.main.bundleIdentifier }
        let filter = SCContentFilter(display: display, excludingApplications: ownApps, exceptingWindows: [])
        let config = Self.configuration(for: filter, area: selection.area, options: options)

        let stream = SCStream(filter: filter, configuration: config, delegate: self)
        let output = SCRecordingOutput(configuration: Self.outputConfiguration(to: url), delegate: self)
        try stream.addRecordingOutput(output)

        finishResult = nil
        try await stream.startCapture()
        self.stream = stream
        outputURL = url
    }

    func stop() async throws -> URL {
        guard let stream, let outputURL else { throw RecorderError.notRecording }
        isStopping = true
        defer {
            isStopping = false
            finishResult = nil
            self.stream = nil
            self.outputURL = nil
        }
        try await stream.stopCapture()
        try await waitForFinish()
        return outputURL
    }

    private static func configuration(
        for filter: SCContentFilter, area: CGRect?, options: RecordingOptions
    ) -> SCStreamConfiguration {
        let config = SCStreamConfiguration()
        let scale = CGFloat(filter.pointPixelScale)
        let screenSize = filter.contentRect.size
        if let area, let capture = ScreenGeometry.captureArea(fromLocal: area, screenSize: screenSize, scale: scale) {
            config.sourceRect = capture.sourceRect
            config.width = capture.width
            config.height = capture.height
        } else {
            let size = ScreenGeometry.evenPixelSize(screenSize, scale: scale)
            config.width = size.width
            config.height = size.height
        }
        config.captureResolution = .best
        config.minimumFrameInterval = CMTime(value: 1, timescale: Config.Recording.maxFramesPerSecond)
        config.showsCursor = options.showsCursor
        config.capturesAudio = options.capturesSystemAudio
        config.captureMicrophone = options.capturesMicrophone
        config.excludesCurrentProcessAudio = true
        return config
    }

    private static func outputConfiguration(to url: URL) -> SCRecordingOutputConfiguration {
        let config = SCRecordingOutputConfiguration()
        config.outputURL = url
        config.outputFileType = Config.Recording.fileType
        config.videoCodecType = Config.Recording.videoCodec
        return config
    }

    private func waitForFinish() async throws {
        if let finishResult {
            return try finishResult.get()
        }
        try await withCheckedThrowingContinuation { finishContinuation = $0 }
    }

    private func finish(_ result: Result<Void, Error>) {
        guard let continuation = finishContinuation else {
            finishResult = result
            return
        }
        finishContinuation = nil
        continuation.resume(with: result)
    }

    private func fail(_ error: Error) {
        if isStopping {
            finish(.failure(error))
            return
        }
        guard stream != nil else { return }
        stream = nil
        outputURL = nil
        onUnexpectedStop?(error)
    }
}

extension Recorder: SCStreamDelegate, SCRecordingOutputDelegate {
    nonisolated func stream(_ stream: SCStream, didStopWithError error: Error) {
        Task { @MainActor in self.fail(error) }
    }

    nonisolated func recordingOutputDidFinishRecording(_ recordingOutput: SCRecordingOutput) {
        Task { @MainActor in self.finish(.success(())) }
    }

    nonisolated func recordingOutput(_ recordingOutput: SCRecordingOutput, didFailWithError error: Error) {
        Task { @MainActor in self.fail(error) }
    }
}
