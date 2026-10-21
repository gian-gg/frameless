import CoreGraphics
import Testing

@testable import Frameless

struct ScreenGeometryTests {
    private let screen = CGSize(width: 1000, height: 800)

    @Test("flips a bottom-left rect to top-left display points")
    func flipsToTopLeft() {
        let area = ScreenGeometry.captureArea(
            fromLocal: CGRect(x: 100, y: 100, width: 200, height: 100), screenSize: screen, scale: 1)
        #expect(area == .init(sourceRect: CGRect(x: 100, y: 600, width: 200, height: 100), width: 200, height: 100))
    }

    @Test("clamps a rect that hangs off the screen edge")
    func clampsToScreen() {
        let area = ScreenGeometry.captureArea(
            fromLocal: CGRect(x: -50, y: 700, width: 200, height: 200), screenSize: screen, scale: 1)
        #expect(area == .init(sourceRect: CGRect(x: 0, y: 0, width: 150, height: 100), width: 150, height: 100))
    }

    @Test("flips a Core Graphics global rect to AppKit global")
    func flipsCoreGraphicsRect() {
        let rect = ScreenGeometry.appKitRect(
            fromCG: CGRect(x: -300, y: -200, width: 400, height: 100), primaryScreenHeight: 1080)
        #expect(rect == CGRect(x: -300, y: 1180, width: 400, height: 100))
    }

    @Test("returns nil for a rect entirely off the screen")
    func offScreenIsNil() {
        let area = ScreenGeometry.captureArea(
            fromLocal: CGRect(x: 1200, y: 0, width: 100, height: 100), screenSize: screen, scale: 1)
        #expect(area == nil)
    }

    @Test("aligns to whole pixels and even dimensions on Retina")
    func alignsOnRetina() {
        let area = ScreenGeometry.captureArea(
            fromLocal: CGRect(x: 10.25, y: 0, width: 100.75, height: 50.3), screenSize: screen, scale: 2)
        #expect(area?.width == 200)
        #expect(area?.height == 100)
        #expect(area?.sourceRect == CGRect(x: 10, y: 749.5, width: 100, height: 50))
    }

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
