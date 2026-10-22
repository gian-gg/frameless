import CoreGraphics
import Testing

@testable import Frameless

struct MarkGeometryTests {
    private let box = Mark(tool: .rectangle, points: [CGPoint(x: 10, y: 10), CGPoint(x: 50, y: 40)], color: .white)
    private let line = Mark(tool: .line, points: [CGPoint(x: 0, y: 0), CGPoint(x: 100, y: 0)], color: .white)

    @Test("boxes are picked anywhere inside, lines only near the stroke")
    func picksByShape() {
        #expect(MarkGeometry.contains(box, CGPoint(x: 30, y: 25)))
        #expect(MarkGeometry.contains(line, CGPoint(x: 50, y: 4)))
        #expect(!MarkGeometry.contains(line, CGPoint(x: 50, y: 20)))
    }

    @Test("the top-most mark wins, with steps above everything and highlights below")
    func picksTopMost() {
        let highlight = Mark(tool: .highlight, points: [.zero, CGPoint(x: 100, y: 100)], color: .white)
        let step = Mark(tool: .steps, points: [CGPoint(x: 30, y: 25)], color: .red)
        let marks = [step, highlight, box]

        #expect(MarkGeometry.index(at: CGPoint(x: 30, y: 25), in: marks) == 0)
        #expect(MarkGeometry.index(at: CGPoint(x: 45, y: 35), in: marks) == 2)
        #expect(MarkGeometry.index(at: CGPoint(x: 90, y: 90), in: marks) == 1)
        #expect(MarkGeometry.index(at: CGPoint(x: 200, y: 200), in: marks) == nil)
    }

    @Test("moving shifts every point by the offset")
    func moves() {
        let moved = MarkGeometry.moved(box, by: CGVector(dx: 5, dy: -3))
        #expect(moved.points == [CGPoint(x: 15, y: 7), CGPoint(x: 55, y: 37)])
    }
}
