import AppKit
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

    @Test("saves a capture as a PNG straight into the folder")
    func savesIntoFolder() throws {
        let context = try #require(
            CGContext(
                data: nil, width: 4, height: 2, bitsPerComponent: 8, bytesPerRow: 0,
                space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
        let shot = CapturedImage(image: try #require(context.makeImage()), scale: 1, displayID: 1)
        let folder = FileManager.default.temporaryDirectory.appending(path: "ScreenshotterTests.\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }

        let url = try Screenshotter.save(shot, in: folder)

        #expect(url.deletingLastPathComponent().standardizedFileURL == folder.standardizedFileURL)
        #expect(url.pathExtension == "png")
        #expect(FileManager.default.fileExists(atPath: url.path(percentEncoded: false)))
    }

    @Test("cropping keeps the points asked for, at full pixel resolution")
    func cropsInPoints() throws {
        let context = try #require(
            CGContext(
                data: nil, width: 40, height: 20, bitsPerComponent: 8, bytesPerRow: 0,
                space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
        context.setFillColor(red: 1, green: 0, blue: 0, alpha: 1)
        context.fill(CGRect(x: 0, y: 0, width: 20, height: 20))
        context.setFillColor(red: 0, green: 0, blue: 1, alpha: 1)
        context.fill(CGRect(x: 20, y: 0, width: 20, height: 20))
        let shot = CapturedImage(image: try #require(context.makeImage()), scale: 2, displayID: 1)

        let crop = try #require(
            shot.cropped(to: CGRect(x: 10, y: 0, width: 10, height: 5), of: CGSize(width: 20, height: 10)))

        #expect(crop.image.width == 20 && crop.image.height == 10)
        let color = try #require(NSBitmapImageRep(cgImage: crop.image).colorAt(x: 10, y: 5))
        #expect(color.blueComponent > 0.9 && color.redComponent < 0.1)
    }
}
