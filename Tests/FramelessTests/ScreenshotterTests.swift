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
}
