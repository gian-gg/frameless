import CoreGraphics
import Foundation
import ImageIO
import Testing

@testable import Frameless

@MainActor
struct ScreenshotterTests {
    @Test("writes a PNG tagged with the display's DPI")
    func writesRetinaPNG() throws {
        let context = try #require(
            CGContext(
                data: nil, width: 4, height: 2, bitsPerComponent: 8, bytesPerRow: 0,
                space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
        let image = try #require(context.makeImage())
        let url = FileManager.default.temporaryDirectory.appending(path: "ScreenshotterTests.\(UUID().uuidString).png")
        defer { try? FileManager.default.removeItem(at: url) }

        try Screenshotter.writePNG(image, scale: 2, to: url)

        let source = try #require(CGImageSourceCreateWithURL(url as CFURL, nil))
        #expect(CGImageSourceGetType(source) as String? == "public.png")
        let properties = try #require(CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any])
        #expect(properties[kCGImagePropertyPixelWidth] as? Int == 4)
        #expect(properties[kCGImagePropertyDPIWidth] as? Double == 144)
    }

    @Test("saves a capture as a PNG inside Frameless/ under the base folder")
    func savesIntoFramelessFolder() throws {
        let context = try #require(
            CGContext(
                data: nil, width: 4, height: 2, bitsPerComponent: 8, bytesPerRow: 0,
                space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
        let shot = CapturedImage(
            image: try #require(context.makeImage()), scale: 1, frame: CGRect(x: 0, y: 0, width: 4, height: 2),
            displayID: 1)
        let base = FileManager.default.temporaryDirectory.appending(path: "ScreenshotterTests.\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: base) }

        let url = try Screenshotter.save(shot, in: base)

        #expect(url.deletingLastPathComponent().lastPathComponent == Config.Output.folderName)
        #expect(url.pathExtension == "png")
        #expect(FileManager.default.fileExists(atPath: url.path(percentEncoded: false)))
    }
}
