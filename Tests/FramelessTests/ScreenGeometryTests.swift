import CoreGraphics
import Testing

@testable import Frameless

struct ScreenGeometryTests {
    @Test(
        "rounds pixel sizes down to even numbers",
        arguments: [
            (CGSize(width: 1512, height: 982), 2.0, 3024, 1964),
            (CGSize(width: 1920, height: 1080), 1.0, 1920, 1080),
            (CGSize(width: 301, height: 201), 1.0, 300, 200),
            (CGSize(width: 0.4, height: 0.4), 1.0, 2, 2),
        ])
    func evenPixelSize(points: CGSize, scale: CGFloat, width: Int, height: Int) {
        let size = ScreenGeometry.evenPixelSize(points, scale: scale)
        #expect(size.width == width)
        #expect(size.height == height)
    }
}
