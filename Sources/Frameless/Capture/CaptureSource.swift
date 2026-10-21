import ScreenCaptureKit

/// Turns a selection into a ScreenCaptureKit filter, shared by recordings and screenshots.
@MainActor
enum CaptureSource {
    enum CaptureError: LocalizedError {
        case noDisplay
        case noWindow

        var errorDescription: String? {
            switch self {
            case .noDisplay: "That display is no longer connected."
            case .noWindow: "That window is no longer open."
            }
        }
    }

    /// A single-window filter, or the selection's display minus Frameless's own windows.
    static func filter(for selection: CaptureSelection) async throws -> SCContentFilter {
        let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
        if case .window(let windowID) = selection.target {
            guard let window = content.windows.first(where: { $0.windowID == windowID }) else {
                throw CaptureError.noWindow
            }
            return SCContentFilter(desktopIndependentWindow: window)
        }
        guard let display = content.displays.first(where: { $0.displayID == selection.displayID }) else {
            throw CaptureError.noDisplay
        }
        let ownApps = content.applications.filter { $0.bundleIdentifier == Bundle.main.bundleIdentifier }
        return SCContentFilter(display: display, excludingApplications: ownApps, exceptingWindows: [])
    }

    /// Crops the configuration to the selection's area, if any, and sizes it to the source's real pixels.
    static func applyRegion(of filter: SCContentFilter, area: CGRect?, to config: SCStreamConfiguration) {
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
    }
}
