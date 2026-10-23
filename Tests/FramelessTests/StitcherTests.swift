import Testing

@testable import Frameless

struct StitcherTests {
    private let width = 6

    /// A detailed row unique to `index`.
    private func row(_ index: Int) -> [UInt8] {
        (0..<width).flatMap { column in [UInt8((index * 7 + column) % 256), UInt8(index % 251), UInt8(column), 255] }
    }

    private func page(_ height: Int) -> [[UInt8]] {
        (0..<height).map(row)
    }

    private func frame(_ rows: [[UInt8]]) -> Stitcher.Frame {
        Stitcher.Frame(width: width, rows: rows)
    }

    @Test("frames scrolled down a page stitch back into the page")
    func stitchesScroll() {
        let tall = page(100)
        var stitcher = Stitcher()
        for top in [0, 12, 25, 41, 60] {
            _ = stitcher.add(frame(Array(tall[top..<top + 30])))
        }
        #expect(stitcher.height == 90)
        #expect(stitcher.add(frame(Array(tall[70..<100]))) == .added(rows: 10))
        #expect(stitcher.height == 100)
    }

    @Test("a sticky header and footer are kept once while the middle scrolls")
    func keepsStickyRows() {
        let header = (1000..<1003).map(row)
        let footer = (2000..<2002).map(row)
        let content = page(60)
        var stitcher = Stitcher()
        for top in [0, 10, 20] {
            _ = stitcher.add(frame(header + Array(content[top..<top + 20]) + footer))
        }
        #expect(stitcher.height == 3 + 40 + 2)
    }

    @Test("the same frame again changes nothing")
    func ignoresRepeats() {
        var stitcher = Stitcher()
        let still = frame(page(20))
        #expect(stitcher.add(still) == .started)
        #expect(stitcher.add(still) == .unchanged)
        #expect(stitcher.height == 20)
    }

    @Test("a frame that doesn't overlap the last is reported lost and not added")
    func reportsLost() {
        var stitcher = Stitcher()
        _ = stitcher.add(frame(page(20)))
        #expect(stitcher.add(frame((500..<520).map(row))) == .lost)
        #expect(stitcher.height == 20)
    }

    @Test("a blank band doesn't fool the match into a too-small scroll")
    func ignoresBlankRows() {
        let blank = [UInt8](repeating: 200, count: width * 4)
        let tall = page(10) + Array(repeating: blank, count: 10) + (10..<50).map(row)
        var stitcher = Stitcher()
        _ = stitcher.add(frame(Array(tall[0..<40])))
        #expect(stitcher.add(frame(Array(tall[20..<60]))) == .added(rows: 20))
    }

    @Test("an overlap with nothing but blank rows is reported lost rather than guessed")
    func blankOverlapIsLost() {
        let blank = [UInt8](repeating: 200, count: width * 4)
        let tall = page(10) + Array(repeating: blank, count: 30) + (10..<40).map(row)
        var stitcher = Stitcher()
        _ = stitcher.add(frame(Array(tall[0..<40])))
        #expect(stitcher.add(frame(Array(tall[20..<60]))) == .lost)
    }
}
