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

    @Test(
        "finds the handle under the pointer: corners, edges, inside, or nothing",
        arguments: zip(
            [
                CGPoint(x: 100, y: 500), CGPoint(x: 502, y: 298), CGPoint(x: 300, y: 503), CGPoint(x: 97, y: 400),
                CGPoint(x: 300, y: 400), CGPoint(x: 700, y: 400),
            ],
            [ScreenGeometry.ResizeHandle.topLeft, .bottomRight, .top, .left, .move, nil]))
    func handleAtPoint(point: CGPoint, expected: ScreenGeometry.ResizeHandle?) {
        let rect = CGRect(x: 100, y: 300, width: 400, height: 200)
        #expect(ScreenGeometry.handle(at: point, of: rect, tolerance: 6) == expected)
    }

    @Test("resizes from an edge or corner and moves from the inside")
    func resizesAndMoves() {
        let rect = CGRect(x: 100, y: 300, width: 400, height: 200)
        let bounds = CGRect(x: 0, y: 0, width: 1000, height: 800)
        let resize = { (handle: ScreenGeometry.ResizeHandle, deltaX: CGFloat, deltaY: CGFloat) in
            ScreenGeometry.resize(rect, with: handle, by: CGVector(dx: deltaX, dy: deltaY), in: bounds, minimum: 10)
        }
        #expect(resize(.right, 50, 99) == CGRect(x: 100, y: 300, width: 450, height: 200))
        #expect(resize(.topLeft, -20, 30) == CGRect(x: 80, y: 300, width: 420, height: 230))
        #expect(resize(.bottom, 0, 40) == CGRect(x: 100, y: 340, width: 400, height: 160))
        #expect(resize(.move, 25, -10) == CGRect(x: 125, y: 290, width: 400, height: 200))
    }

    @Test("keeps a resized selection at least the minimum size and on screen")
    func clampsResize() {
        let rect = CGRect(x: 100, y: 300, width: 400, height: 200)
        let bounds = CGRect(x: 0, y: 0, width: 1000, height: 800)
        let shrunk = ScreenGeometry.resize(rect, with: .left, by: CGVector(dx: 900, dy: 0), in: bounds, minimum: 10)
        #expect(shrunk == CGRect(x: 490, y: 300, width: 10, height: 200))
        let grown = ScreenGeometry.resize(
            rect, with: .topRight, by: CGVector(dx: 900, dy: 900), in: bounds, minimum: 10)
        #expect(grown == CGRect(x: 100, y: 300, width: 900, height: 500))
        let moved = ScreenGeometry.resize(rect, with: .move, by: CGVector(dx: -500, dy: 0), in: bounds, minimum: 10)
        #expect(moved == CGRect(x: 0, y: 300, width: 400, height: 200))
    }

    @Test(
        "puts the bar under the capture's right edge, inside its bottom when there's no room, and keeps it on screen",
        arguments: zip(
            [
                CGRect(x: 100, y: 300, width: 400, height: 200),
                CGRect(x: 100, y: 20, width: 400, height: 200),
                CGRect(x: 0, y: 0, width: 1000, height: 800),
                CGRect(x: 0, y: 300, width: 50, height: 100),
            ],
            [
                CGPoint(x: 380, y: 250),
                CGPoint(x: 380, y: 76),
                CGPoint(x: 870, y: 56),
                CGPoint(x: 10, y: 250),
            ]))
    func barPlacement(rect: CGRect, expected: CGPoint) {
        let origin = ScreenGeometry.barOrigin(
            for: CGSize(width: 120, height: 40), under: rect, in: CGRect(x: 0, y: 0, width: 1000, height: 800),
            gap: 10, inset: 56)
        #expect(origin == expected)
    }

    @Test(
        "puts the tag above the top-left corner, inside at the top edge, and keeps it on screen",
        arguments: zip(
            [
                CGRect(x: 100, y: 300, width: 400, height: 200),
                CGRect(x: 100, y: 600, width: 400, height: 200),
                CGRect(x: 950, y: 300, width: 40, height: 40),
            ],
            [CGPoint(x: 100, y: 508), CGPoint(x: 108, y: 772), CGPoint(x: 880, y: 348)]))
    func tagPlacement(rect: CGRect, expected: CGPoint) {
        let origin = ScreenGeometry.tagOrigin(
            for: CGSize(width: 120, height: 20), on: rect, in: CGRect(x: 0, y: 0, width: 1000, height: 800), lift: 8)
        #expect(origin == expected)
    }

    @Test("places a window relative to its display and clips it to the display")
    func windowRectOnDisplay() {
        let display = CGRect(x: 1920, y: -200, width: 1512, height: 982)
        #expect(
            ScreenGeometry.windowRect(CGRect(x: 2000, y: -100, width: 800, height: 600), onDisplay: display)
                == CGRect(x: 80, y: 100, width: 800, height: 600))
        #expect(
            ScreenGeometry.windowRect(CGRect(x: 3000, y: 500, width: 800, height: 600), onDisplay: display)
                == CGRect(x: 1080, y: 700, width: 432, height: 282))
        #expect(ScreenGeometry.windowRect(CGRect(x: 0, y: 0, width: 800, height: 600), onDisplay: display) == nil)
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
        "fits a pixel size within a resolution box, keeping its shape",
        arguments: zip(
            [
                ((3024, 1964), CGSize(width: 1920, height: 1080)),
                ((1000, 2000), CGSize(width: 1920, height: 1080)),
                ((900, 600), CGSize(width: 1920, height: 1080)),
                ((1920, 1080), CGSize(width: 1920, height: 1080)),
                ((3024, 1964), nil),
            ] as [((Int, Int), CGSize?)],
            [(1662, 1080), (960, 1920), (900, 600), (1920, 1080), (3024, 1964)]))
    func fitsWithinBox(input: ((Int, Int), CGSize?), expected: (Int, Int)) {
        let size = ScreenGeometry.fitted(input.0, within: input.1)
        #expect(size.width == expected.0)
        #expect(size.height == expected.1)
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

    @Test("zooming keeps the point under the pointer still")
    func zoomsAroundAnchor() {
        let frame = CGRect(x: 100, y: 100, width: 200, height: 100)
        let zoomed = ScreenGeometry.zoomedFrame(
            frame, to: CGSize(width: 400, height: 200), around: CGPoint(x: 150, y: 125))
        #expect(zoomed == CGRect(x: 50, y: 75, width: 400, height: 200))
    }

    @Test("zooming around the centre grows evenly on every side")
    func zoomsAroundCentre() {
        let frame = CGRect(x: 100, y: 100, width: 200, height: 100)
        let zoomed = ScreenGeometry.zoomedFrame(
            frame, to: CGSize(width: 100, height: 50), around: CGPoint(x: 200, y: 150))
        #expect(zoomed == CGRect(x: 150, y: 125, width: 100, height: 50))
    }

    @Test(
        "a square takes the longer side in the drag's direction and fits inside the bounds",
        arguments: zip(
            [CGPoint(x: 60, y: 30), CGPoint(x: 20, y: 80), CGPoint(x: 0, y: 40), CGPoint(x: 100, y: 100)],
            [CGPoint(x: 60, y: 20), CGPoint(x: 0, y: 80), CGPoint(x: 0, y: 80), CGPoint(x: 80, y: 80)]))
    func squaresDrag(end: CGPoint, expected: CGPoint) {
        let corner = ScreenGeometry.squareCorner(
            from: CGPoint(x: 40, y: 40), to: end, in: CGRect(x: 0, y: 0, width: 80, height: 100))
        #expect(corner == expected)
    }
}
