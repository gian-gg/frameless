import CoreMedia
import ScreenCaptureKit

/// Streams frames of an area while it's scrolled, each as rows of BGRA bytes for the stitcher.
final class ScrollCapture: NSObject, SCStreamOutput {
    private var stream: SCStream?
    private let queue = DispatchQueue(label: "Frameless.ScrollCapture")
    private let onFrame: @Sendable (Stitcher.Frame) -> Void

    /// Calls `onFrame`, off the main thread, for every frame that shows something new.
    init(onFrame: @escaping @Sendable (Stitcher.Frame) -> Void) {
        self.onFrame = onFrame
    }

    /// Starts streaming the area; returns its pixels per point.
    @MainActor
    func start(_ selection: CaptureSelection) async throws -> CGFloat {
        let filter = try await CaptureSource.filter(for: selection)
        let config = SCStreamConfiguration()
        CaptureSource.applyRegion(of: filter, area: selection.area, to: config)
        config.captureResolution = .best
        config.showsCursor = false
        config.pixelFormat = kCVPixelFormatType_32BGRA
        config.minimumFrameInterval = CMTime(value: 1, timescale: Config.Scroll.framesPerSecond)
        let stream = SCStream(filter: filter, configuration: config, delegate: nil)
        try stream.addStreamOutput(self, type: .screen, sampleHandlerQueue: queue)
        try await stream.startCapture()
        self.stream = stream
        return CGFloat(filter.pointPixelScale)
    }

    @MainActor
    func stop() async {
        try? await stream?.stopCapture()
        stream = nil
    }

    func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of type: SCStreamOutputType) {
        guard type == .screen, Self.isComplete(sampleBuffer), let frame = Self.frame(from: sampleBuffer) else {
            return
        }
        onFrame(frame)
    }

    /// Whether the buffer holds a newly drawn frame rather than an idle repeat.
    private static func isComplete(_ sampleBuffer: CMSampleBuffer) -> Bool {
        guard
            let attachments = CMSampleBufferGetSampleAttachmentsArray(sampleBuffer, createIfNecessary: false)
                as? [[SCStreamFrameInfo: Any]],
            let raw = attachments.first?[.status] as? Int,
            let status = SCFrameStatus(rawValue: raw)
        else { return false }
        return status == .complete
    }

    /// The buffer's pixels as BGRA rows, top row first.
    private static func frame(from sampleBuffer: CMSampleBuffer) -> Stitcher.Frame? {
        guard let buffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return nil }
        CVPixelBufferLockBaseAddress(buffer, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(buffer, .readOnly) }
        guard let base = CVPixelBufferGetBaseAddress(buffer) else { return nil }
        let width = CVPixelBufferGetWidth(buffer)
        let height = CVPixelBufferGetHeight(buffer)
        let bytesPerRow = CVPixelBufferGetBytesPerRow(buffer)
        let rows = (0..<height).map { row in
            [UInt8](UnsafeRawBufferPointer(start: base.advanced(by: row * bytesPerRow), count: width * 4))
        }
        return Stitcher.Frame(width: width, rows: rows)
    }
}
