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

    /// A 40 × 40 black capture at 1×.
    private func blackShot() throws -> CapturedImage {
        let context = try #require(
            CGContext(
                data: nil, width: 40, height: 40, bitsPerComponent: 8, bytesPerRow: 0,
                space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
        context.setFillColor(gray: 0, alpha: 1)
        context.fill(CGRect(x: 0, y: 0, width: 40, height: 40))
        return CapturedImage(image: try #require(context.makeImage()), scale: 1, displayID: 1)
    }

    @Test("a rectangle is stroked along its edges and leaves its middle dark")
    func drawsRectangle() throws {
        let shot = try blackShot()
        let mark = Mark(
            tool: .rectangle, points: [CGPoint(x: 10, y: 10), CGPoint(x: 30, y: 30)], color: Config.Annotate.color)

        let rendered = try #require(MarkRenderer.render(shot, marks: [mark]))
        let bitmap = NSBitmapImageRep(cgImage: rendered.image)

        let edge = try #require(bitmap.colorAt(x: 20, y: 10))
        let middle = try #require(bitmap.colorAt(x: 20, y: 20))
        #expect(edge.redComponent > 0.8 && edge.blueComponent > 0.8)
        #expect(middle.redComponent < 0.1)
    }

    @Test("a line is drawn between its two points and nowhere else")
    func drawsLine() throws {
        let mark = Mark(
            tool: .line, points: [CGPoint(x: 5, y: 20), CGPoint(x: 35, y: 20)], color: Config.Annotate.color)

        let rendered = try #require(MarkRenderer.render(try blackShot(), marks: [mark]))
        let bitmap = NSBitmapImageRep(cgImage: rendered.image)

        let onLine = try #require(bitmap.colorAt(x: 20, y: 20))
        let offLine = try #require(bitmap.colorAt(x: 20, y: 5))
        #expect(onLine.redComponent > 0.8)
        #expect(offLine.redComponent < 0.1)
    }

    @Test("an arrow draws its line and two arms back from its end")
    func drawsArrow() throws {
        let mark = Mark(
            tool: .arrow, points: [CGPoint(x: 5, y: 20), CGPoint(x: 35, y: 20)], color: Config.Annotate.color)

        let rendered = try #require(MarkRenderer.render(try blackShot(), marks: [mark]))
        let bitmap = NSBitmapImageRep(cgImage: rendered.image)

        let line = try #require(bitmap.colorAt(x: 15, y: 20))
        let upperArm = try #require(bitmap.colorAt(x: 30, y: 17))
        let lowerArm = try #require(bitmap.colorAt(x: 30, y: 23))
        let behindStart = try #require(bitmap.colorAt(x: 10, y: 26))
        #expect(line.redComponent > 0.8)
        #expect(upperArm.redComponent > 0.5)
        #expect(lowerArm.redComponent > 0.5)
        #expect(behindStart.redComponent < 0.1)
    }

    @Test("a freehand stroke is drawn through its points")
    func drawsFreehand() throws {
        let points = stride(from: 5, through: 35, by: 3).map { CGPoint(x: CGFloat($0), y: 20) }
        let mark = Mark(tool: .freehand, points: points, color: Config.Annotate.color)

        let rendered = try #require(MarkRenderer.render(try blackShot(), marks: [mark]))
        let bitmap = NSBitmapImageRep(cgImage: rendered.image)

        #expect(try #require(bitmap.colorAt(x: 20, y: 20)).redComponent > 0.8)
        #expect(try #require(bitmap.colorAt(x: 20, y: 5)).redComponent < 0.1)
    }

    @Test("a mark's bounds cover all its points, so a closed loop isn't mistaken for a click")
    func boundsCoverAllPoints() {
        let loop = [CGPoint(x: 10, y: 10), CGPoint(x: 30, y: 12), CGPoint(x: 20, y: 30), CGPoint(x: 10, y: 10)]
        let mark = Mark(tool: .freehand, points: loop, color: Config.Annotate.color)
        #expect(MarkRenderer.bounds(of: mark) == CGRect(x: 10, y: 10, width: 20, height: 20))
    }
}
