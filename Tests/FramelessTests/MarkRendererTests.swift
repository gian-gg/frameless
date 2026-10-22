import AppKit
import Testing

@testable import Frameless

struct MarkRendererTests {
    private func shot() throws -> CapturedImage {
        let context = try #require(
            CGContext(
                data: nil, width: 8, height: 6, bitsPerComponent: 8, bytesPerRow: 0,
                space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
        return CapturedImage(image: try #require(context.makeImage()), scale: 2, displayID: 3)
    }

    @Test("with no marks the capture comes back untouched")
    func noMarks() throws {
        let original = try shot()
        let rendered = try #require(MarkRenderer.render(original, marks: []))
        #expect(rendered.image === original.image)
    }

    @Test("with marks the result keeps the capture's pixel size, scale and display")
    func keepsGeometry() throws {
        let original = try shot()
        let mark = Mark(tool: .rectangle, points: [.zero, CGPoint(x: 2, y: 2)], color: CGColor(gray: 1, alpha: 1))
        let rendered = try #require(MarkRenderer.render(original, marks: [mark]))
        #expect(rendered.image.width == 8)
        #expect(rendered.image.height == 6)
        #expect(rendered.scale == 2)
        #expect(rendered.displayID == 3)
    }

    @Test("a rectangle is stroked along its edges and leaves its middle dark")
    func drawsRectangle() throws {
        let context = try #require(
            CGContext(
                data: nil, width: 40, height: 40, bitsPerComponent: 8, bytesPerRow: 0,
                space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
        context.setFillColor(gray: 0, alpha: 1)
        context.fill(CGRect(x: 0, y: 0, width: 40, height: 40))
        let shot = CapturedImage(image: try #require(context.makeImage()), scale: 1, displayID: 1)
        let mark = Mark(
            tool: .rectangle, points: [CGPoint(x: 10, y: 10), CGPoint(x: 30, y: 30)], color: Config.Annotate.color)

        let rendered = try #require(MarkRenderer.render(shot, marks: [mark]))
        let bitmap = NSBitmapImageRep(cgImage: rendered.image)

        let edge = try #require(bitmap.colorAt(x: 20, y: 10))
        let middle = try #require(bitmap.colorAt(x: 20, y: 20))
        #expect(edge.redComponent > 0.8 && edge.blueComponent > 0.8)
        #expect(middle.redComponent < 0.1)
    }
}
