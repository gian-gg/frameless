import CoreGraphics
import Foundation
import Testing

@testable import Frameless

@MainActor
struct ThumbnailTests {
    @Test(
        "fits the preview in its box without enlarging",
        arguments: zip(
            [CGSize(width: 1512, height: 982), CGSize(width: 400, height: 1000), CGSize(width: 100, height: 50)],
            [CGSize(width: 200, height: 130), CGSize(width: 56, height: 140), CGSize(width: 100, height: 50)]))
    func fitsPreview(size: CGSize, expected: CGSize) {
        #expect(CaptureThumbnail.fittedSize(size, within: CGSize(width: 200, height: 140)) == expected)
    }

    @Test("reads a screenshot back at thumbnail size")
    func readsImageThumbnail() throws {
        let context = try #require(
            CGContext(
                data: nil, width: 800, height: 400, bitsPerComponent: 8, bytesPerRow: 0,
                space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
        let image = try #require(context.makeImage())
        let url = FileManager.default.temporaryDirectory.appending(path: "ThumbnailTests.\(UUID().uuidString).png")
        defer { try? FileManager.default.removeItem(at: url) }
        try Screenshotter.writePNG(image, scale: 2, to: url)

        let thumbnail = try #require(ThumbnailImage.imageThumbnail(from: url, maxPixelSize: 200))
        #expect(thumbnail.width == 200)
        #expect(thumbnail.height == 100)
    }
}
