import AppKit
import ScreenCaptureKit
import UniformTypeIdentifiers

/// A still capture held in memory until it's copied or saved.
struct CapturedImage {
    let image: CGImage
    /// Pixels per point of the display it came from.
    let scale: CGFloat
    let displayID: CGDirectDisplayID
}

/// Captures a still image of a selection, and saves or copies it on request.
@MainActor
enum Screenshotter {
    enum ScreenshotError: LocalizedError {
        case unwritable

        var errorDescription: String? { "The screenshot couldn't be saved." }
    }

    /// Captures the display, area or window at full pixel resolution without the cursor.
    static func captureImage(_ selection: CaptureSelection) async throws -> CapturedImage {
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
        config.captureResolution = .best
        config.showsCursor = false

        let image = try await SCScreenshotManager.captureImage(contentFilter: filter, configuration: config)
        return CapturedImage(image: image, scale: CGFloat(filter.pointPixelScale), displayID: selection.displayID)
    }

    /// Writes the capture as a PNG into `<base>/Frameless`, `~/Pictures/Frameless` by default.
    static func save(_ shot: CapturedImage, in base: URL = .picturesDirectory) throws -> URL {
        let name = OutputFile.name(for: .now, fileExtension: Config.Output.screenshotExtension)
        let url = try OutputFile.directory(in: base).appending(path: name)
        try writePNG(shot.image, scale: shot.scale, to: url)
        return url
    }

    /// Puts the image itself on the clipboard, sized in points.
    static func copy(_ shot: CapturedImage) {
        let size = CGSize(
            width: CGFloat(shot.image.width) / shot.scale, height: CGFloat(shot.image.height) / shot.scale)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.writeObjects([NSImage(cgImage: shot.image, size: size)])
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
}
