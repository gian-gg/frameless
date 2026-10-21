import ScreenCaptureKit

/// Records a display, an area of it, or a single window, with audio, to disk via SCRecordingOutput.
@MainActor
final class Recorder: NSObject {
    enum RecorderError: LocalizedError {
        case noDisplay
        case noWindow
        case notRecording
        case alreadyStopping
        case unfinished

        var errorDescription: String? {
            switch self {
            case .noDisplay: "That display is no longer connected."
            case .noWindow: "That window is no longer open."
            case .notRecording: "Nothing is being recorded."
            case .alreadyStopping: "The recording is already being saved."
            case .unfinished: "The recording file couldn't be finished."
            }
        }
    }

    private enum State {
        case idle
        case recording(SCStream, URL)
        case stopping
    }

    /// How a recording that macOS stopped on its own turned out.
    enum EarlyEnd {
        case saved(URL)
        case failed(Error)
    }

    var onEndedEarly: (@MainActor (EarlyEnd) -> Void)?

    private var state = State.idle
    private var finished = FinishSignal()

    func start(_ selection: CaptureSelection, options: RecordingOptions, to url: URL) async throws {
        let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
        let filter = try Self.filter(for: selection, in: content)
        let config = Self.configuration(for: filter, area: selection.area, options: options)

        let stream = SCStream(filter: filter, configuration: config, delegate: self)
        let output = SCRecordingOutput(
            configuration: Self.outputConfiguration(to: url, codec: options.videoCodec), delegate: self)
        try stream.addRecordingOutput(output)

        finished = FinishSignal()
        try await stream.startCapture()
        state = .recording(stream, url)
    }

    func stop() async throws -> URL {
        switch state {
        case .idle:
            throw RecorderError.notRecording
        case .stopping:
            throw RecorderError.alreadyStopping
        case .recording(let stream, let url):
            state = .stopping
            defer { state = .idle }
            try await stream.stopCapture()
            try await waitForFinish()
            return url
        }
    }

    /// A single-window filter, or the selection's display minus Frameless's own windows.
    private static func filter(
        for selection: CaptureSelection, in content: SCShareableContent
    ) throws -> SCContentFilter {
        if case .window(let windowID) = selection.target {
            guard let window = content.windows.first(where: { $0.windowID == windowID }) else {
                throw RecorderError.noWindow
            }
            return SCContentFilter(desktopIndependentWindow: window)
        }
        guard let display = content.displays.first(where: { $0.displayID == selection.displayID }) else {
            throw RecorderError.noDisplay
        }
        let ownApps = content.applications.filter { $0.bundleIdentifier == Bundle.main.bundleIdentifier }
        return SCContentFilter(display: display, excludingApplications: ownApps, exceptingWindows: [])
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
        let output = ScreenGeometry.fitted((config.width, config.height), within: options.resolution.maxSize)
        config.width = output.width
        config.height = output.height
        config.captureResolution = .best
        config.minimumFrameInterval = CMTime(value: 1, timescale: Int32(options.frameRate.rawValue))
        config.showsCursor = options.showsCursor
        config.capturesAudio = options.capturesSystemAudio
        config.captureMicrophone = options.capturesMicrophone
        config.excludesCurrentProcessAudio = true
        return config
    }

    private static func outputConfiguration(to url: URL, codec: VideoCodec) -> SCRecordingOutputConfiguration {
        let config = SCRecordingOutputConfiguration()
        config.outputURL = url
        config.outputFileType = Config.Recording.fileType
        config.videoCodecType = codec.codecType
        return config
    }

    /// Waits for the file to be finished, failing after `Config.Recording.finishTimeout`.
    private func waitForFinish() async throws {
        try await finished.wait(
            timeout: .seconds(Config.Recording.finishTimeout), timeoutError: RecorderError.unfinished)
    }

    /// The stream ended without being asked to: keep the file if it can still be finished.
    private func streamStopped() {
        guard case .recording(_, let url) = state else { return }
        state = .stopping
        Task {
            defer { state = .idle }
            do {
                try await waitForFinish()
                onEndedEarly?(.saved(url))
            } catch {
                try? FileManager.default.removeItem(at: url)
                onEndedEarly?(.failed(error))
            }
        }
    }

    /// The file couldn't be written: stop capturing and drop the partial file.
    private func outputFailed(_ error: Error) {
        guard case .recording(let stream, let url) = state else {
            finished.finish(.failure(error))
            return
        }
        state = .stopping
        Task {
            defer { state = .idle }
            try? await stream.stopCapture()
            try? FileManager.default.removeItem(at: url)
            onEndedEarly?(.failed(error))
        }
    }
}

extension Recorder: SCStreamDelegate, SCRecordingOutputDelegate {
    nonisolated func stream(_ stream: SCStream, didStopWithError error: Error) {
        Task { @MainActor in self.streamStopped() }
    }

    nonisolated func recordingOutputDidFinishRecording(_ recordingOutput: SCRecordingOutput) {
        Task { @MainActor in self.finished.finish(.success(())) }
    }

    nonisolated func recordingOutput(_ recordingOutput: SCRecordingOutput, didFailWithError error: Error) {
        Task { @MainActor in self.outputFailed(error) }
    }
}
