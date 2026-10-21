import AppKit
import ScreenCaptureKit
import UniformTypeIdentifiers

/// Captures a still image of a selection, saves it as a PNG and copies it to the clipboard.
@MainActor
enum Screenshotter {
    enum ScreenshotError: LocalizedError {
        case unwritable

        var errorDescription: String? { "The screenshot couldn't be saved." }
    }

    /// Captures the display, area or window at full pixel resolution without the cursor; returns the saved file.
    static func capture(_ selection: CaptureSelection) async throws -> URL {
        let config = SCStreamConfiguration()
        let filter: SCContentFilter
        if case .window(let windowID) = selection.target {
            let window = try await CaptureSource.windowOnDisplay(windowID)
            filter = window.filter
            let scale = CGFloat(filter.pointPixelScale)
            config.sourceRect = window.rect
            config.width = Int((window.rect.width * scale).rounded())
            config.height = Int((window.rect.height * scale).rounded())
        } else {
            filter = try await CaptureSource.filter(for: selection)
            CaptureSource.applyRegion(of: filter, area: selection.area, to: config)
        }
        let scale = CGFloat(filter.pointPixelScale)
        config.captureResolution = .best
        config.showsCursor = false

        let image = try await SCScreenshotManager.captureImage(contentFilter: filter, configuration: config)
        let name = OutputFile.name(for: .now, fileExtension: Config.Output.screenshotExtension)
        let url = try directory().appending(path: name)
        try writePNG(image, scale: scale, to: url)
        copy(image, scale: scale)
        return url
    }

    /// `~/Pictures/Frameless`, created if missing.
    static func directory() throws -> URL {
        try OutputFile.directory(in: .picturesDirectory)
    }

    /// Writes a PNG tagged with the display's DPI so it opens at its on-screen size.
    static func writePNG(_ image: CGImage, scale: CGFloat, to url: URL) throws {
        guard
            let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil)
        else { throw ScreenshotError.unwritable }
        let dpi = 72 * scale
        let properties = [kCGImagePropertyDPIWidth: dpi, kCGImagePropertyDPIHeight: dpi] as CFDictionary
        CGImageDestinationAddImage(destination, image, properties)
        guard CGImageDestinationFinalize(destination) else { throw ScreenshotError.unwritable }
    }

    /// Puts the image itself on the clipboard, sized in points.
    private static func copy(_ image: CGImage, scale: CGFloat) {
        let size = CGSize(width: CGFloat(image.width) / scale, height: CGFloat(image.height) / scale)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.writeObjects([NSImage(cgImage: image, size: size)])
    }
}
