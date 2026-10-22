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
        let mark = Mark(tool: .rectangle, points: [.zero, CGPoint(x: 2, y: 2)], color: .white)
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
            tool: .rectangle, points: [CGPoint(x: 10, y: 10), CGPoint(x: 30, y: 30)], color: .white)

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
            tool: .line, points: [CGPoint(x: 5, y: 20), CGPoint(x: 35, y: 20)], color: .white)

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
            tool: .arrow, points: [CGPoint(x: 5, y: 20), CGPoint(x: 35, y: 20)], color: .white)

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
        let mark = Mark(tool: .freehand, points: points, color: .white)

        let rendered = try #require(MarkRenderer.render(try blackShot(), marks: [mark]))
        let bitmap = NSBitmapImageRep(cgImage: rendered.image)

        #expect(try #require(bitmap.colorAt(x: 20, y: 20)).redComponent > 0.8)
        #expect(try #require(bitmap.colorAt(x: 20, y: 5)).redComponent < 0.1)
    }

    @Test("a mark's bounds cover all its points, so a closed loop isn't mistaken for a click")
    func boundsCoverAllPoints() {
        let loop = [CGPoint(x: 10, y: 10), CGPoint(x: 30, y: 12), CGPoint(x: 20, y: 30), CGPoint(x: 10, y: 10)]
        let mark = Mark(tool: .freehand, points: loop, color: .white)
        #expect(MarkRenderer.bounds(of: mark) == CGRect(x: 10, y: 10, width: 20, height: 20))
    }

    /// A 40 × 40 mid-grey capture at 1×.
    private func greyShot() throws -> CapturedImage {
        let context = try #require(
            CGContext(
                data: nil, width: 40, height: 40, bitsPerComponent: 8, bytesPerRow: 0,
                space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
        context.setFillColor(gray: 0.6, alpha: 1)
        context.fill(CGRect(x: 0, y: 0, width: 40, height: 40))
        return CapturedImage(image: try #require(context.makeImage()), scale: 1, displayID: 1)
    }

    @Test("a highlight leaves its areas untouched, overlaps included, and darkens everything else")
    func drawsSpotlight() throws {
        let first = Mark(tool: .highlight, points: [CGPoint(x: 5, y: 5), CGPoint(x: 20, y: 20)], color: .white)
        let second = Mark(tool: .highlight, points: [CGPoint(x: 15, y: 15), CGPoint(x: 30, y: 30)], color: .white)

        let rendered = try #require(MarkRenderer.render(try greyShot(), marks: [first, second]))
        let bitmap = NSBitmapImageRep(cgImage: rendered.image)

        let inside = try #require(bitmap.colorAt(x: 10, y: 30)).redComponent
        let overlap = try #require(bitmap.colorAt(x: 17, y: 22)).redComponent
        let outside = try #require(bitmap.colorAt(x: 36, y: 4)).redComponent
        #expect(abs(inside - 0.6) < 0.05)
        #expect(abs(overlap - 0.6) < 0.05)
        #expect(outside < 0.4)
    }

    @Test("pixelating turns detail into flat blocks inside the area and leaves the outside alone")
    func pixelates() throws {
        let context = try #require(
            CGContext(
                data: nil, width: 40, height: 40, bitsPerComponent: 8, bytesPerRow: 0,
                space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
        context.setFillColor(gray: 0, alpha: 1)
        context.fill(CGRect(x: 0, y: 0, width: 40, height: 40))
        context.setFillColor(gray: 1, alpha: 1)
        for column in stride(from: 0, to: 40, by: 2) {
            context.fill(CGRect(x: column, y: 0, width: 1, height: 40))
        }
        let shot = CapturedImage(image: try #require(context.makeImage()), scale: 1, displayID: 1)
        let mark = Mark(tool: .pixelate, points: [CGPoint(x: 8, y: 8), CGPoint(x: 32, y: 32)], color: .white)

        let rendered = try #require(MarkRenderer.render(shot, marks: [mark]))
        let bitmap = NSBitmapImageRep(cgImage: rendered.image)

        let left = try #require(bitmap.colorAt(x: 10, y: 20)).redComponent
        let right = try #require(bitmap.colorAt(x: 11, y: 20)).redComponent
        #expect(abs(left - right) < 0.05)
        #expect(left > 0.2 && left < 0.8)
        #expect(try #require(bitmap.colorAt(x: 2, y: 20)).redComponent > 0.9)
        #expect(try #require(bitmap.colorAt(x: 3, y: 20)).redComponent < 0.1)
    }

    @Test("pixelated blocks stay the same size and place however big the area is")
    func pixelateGridIsFixed() throws {
        let context = try #require(
            CGContext(
                data: nil, width: 60, height: 60, bitsPerComponent: 8, bytesPerRow: 0,
                space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
        for column in 0..<60 {
            context.setFillColor(gray: CGFloat(column) / 60, alpha: 1)
            context.fill(CGRect(x: column, y: 0, width: 1, height: 60))
        }
        let shot = CapturedImage(image: try #require(context.makeImage()), scale: 1, displayID: 1)
        let small = Mark(tool: .pixelate, points: [CGPoint(x: 13, y: 13), CGPoint(x: 30, y: 30)], color: .white)
        let large = Mark(tool: .pixelate, points: [CGPoint(x: 2, y: 2), CGPoint(x: 58, y: 58)], color: .white)

        let fromSmall = NSBitmapImageRep(cgImage: try #require(MarkRenderer.render(shot, marks: [small])).image)
        let fromLarge = NSBitmapImageRep(cgImage: try #require(MarkRenderer.render(shot, marks: [large])).image)

        let smallColor = try #require(fromSmall.colorAt(x: 26, y: 40)).redComponent
        let largeColor = try #require(fromLarge.colorAt(x: 26, y: 40)).redComponent
        #expect(abs(smallColor - largeColor) < 0.02)
    }
}
