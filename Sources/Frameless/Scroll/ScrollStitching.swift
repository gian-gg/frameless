import CoreGraphics
import Foundation

/// The stitcher, fed on the capture's queue so the main thread stays free, handing back a small preview now and then.
final class ScrollStitching: @unchecked Sendable {
    /// What the preview should show after a frame.
    enum Update {
        case image(CGImage)
        case lost
    }

    private let lock = NSLock()
    private var stitcher = Stitcher()
    private var lastPreview = Date.distantPast

    /// Adds a frame; gives a preview at most every so often while the image grows, or word that scrolling was lost.
    func add(_ frame: Stitcher.Frame) -> Update? {
        lock.withLock {
            guard stitcher.height < Config.Scroll.maxHeight else { return nil }
            switch stitcher.add(frame) {
            case .started, .added:
                let now = Date()
                guard now.timeIntervalSince(lastPreview) >= Config.Scroll.previewInterval else { return nil }
                lastPreview = now
                return stitcher.preview(width: Config.Scroll.previewPixels).map(Update.image)
            case .lost:
                return .lost
            case .unchanged:
                return nil
            }
        }
    }

    /// The full stitched image.
    func image() -> CGImage? {
        lock.withLock { stitcher.image() }
    }
}
