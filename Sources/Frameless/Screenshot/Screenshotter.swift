import AppKit
import ScreenCaptureKit
import UniformTypeIdentifiers

/// A still capture held in memory until it's copied or saved.
struct CapturedImage {
    let image: CGImage
    /// Pixels per point of the display it came from.
    let scale: CGFloat
    let displayID: CGDirectDisplayID

    /// The part inside `rect`, given in points from the bottom-left of an image `size` points big, as its own copy.
    func cropped(to rect: CGRect, of size: CGSize) -> CapturedImage? {
        let pixels = CGRect(
            x: rect.minX * scale, y: (size.height - rect.maxY) * scale, width: rect.width * scale,
            height: rect.height * scale
        ).integral.intersection(CGRect(x: 0, y: 0, width: image.width, height: image.height))
        guard !pixels.isNull, pixels.width >= 1, pixels.height >= 1, let crop = image.cropping(to: pixels),
            let context = CGContext(
                data: nil, width: crop.width, height: crop.height, bitsPerComponent: 8, bytesPerRow: 0,
                space: image.colorSpace ?? CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
        else { return nil }
        context.draw(crop, in: CGRect(x: 0, y: 0, width: crop.width, height: crop.height))
        guard let copy = context.makeImage() else { return nil }
        return CapturedImage(image: copy, scale: scale, displayID: displayID)
    }
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

    /// A whole display at full pixel resolution, without the cursor or Frameless's own windows.
    static func captureDisplay(_ id: CGDirectDisplayID, in content: SCShareableContent) async throws -> CapturedImage {
        guard let display = content.displays.first(where: { $0.displayID == id }) else {
            throw CaptureSource.CaptureError.noDisplay
        }
        let ownApps = content.applications.filter { $0.bundleIdentifier == Bundle.main.bundleIdentifier }
        let filter = SCContentFilter(display: display, excludingApplications: ownApps, exceptingWindows: [])
        let scale = CGFloat(filter.pointPixelScale)
        let config = stillConfiguration()
        config.width = Int((filter.contentRect.width * scale).rounded())
        config.height = Int((filter.contentRect.height * scale).rounded())
        let image = try await SCScreenshotManager.captureImage(contentFilter: filter, configuration: config)
        return CapturedImage(image: image, scale: scale, displayID: id)
    }

    /// One window on its own at its exact size, without its shadow or anything over it.
    static func captureWindow(_ id: CGWindowID, in content: SCShareableContent) async throws -> CapturedImage {
        let window = try CaptureSource.windowOnDisplay(id, in: content)
        let scale = CGFloat(window.filter.pointPixelScale)
        let config = stillConfiguration()
        config.sourceRect = window.rect
        config.width = Int((window.rect.width * scale).rounded())
        config.height = Int((window.rect.height * scale).rounded())
        let image = try await SCScreenshotManager.captureImage(contentFilter: window.filter, configuration: config)
        return CapturedImage(image: image, scale: scale, displayID: window.displayID)
    }

    private static func stillConfiguration() -> SCStreamConfiguration {
        let config = SCStreamConfiguration()
        config.captureResolution = .best
        config.showsCursor = false
        return config
    }

    /// The editor's annotated capture when there is one, otherwise a fresh capture of the chosen selection.
    static func image(for choice: SelectionEditor.Choice) async throws -> CapturedImage {
        if let image = choice.image { return image }
        return try await captureImage(choice.selection)
    }

    /// Writes the capture as a timestamped PNG into the folder.
    static func save(_ shot: CapturedImage, in folder: URL) throws -> URL {
        let name = OutputFile.name(for: .now, fileExtension: Config.Output.screenshotExtension)
        let url = folder.appending(path: name)
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
