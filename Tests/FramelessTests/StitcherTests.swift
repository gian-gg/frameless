import Testing

@testable import Frameless

struct StitcherTests {
    private let width = 16

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

    @Test("a small changing strip, such as a blinking cursor, isn't taken for a scroll")
    func ignoresSmallChanges() {
        var rows = page(30)
        var stitcher = Stitcher()
        _ = stitcher.add(frame(rows))
        rows[14] = row(999)
        rows[15] = row(998)
        #expect(stitcher.add(frame(rows)) == .unchanged)
        #expect(stitcher.height == 30)
    }

    @Test("a frame whose content moved but has one strip animating still stitches")
    func toleratesAnimatedStrip() {
        let tall = page(60)
        var stitcher = Stitcher()
        _ = stitcher.add(frame(Array(tall[0..<30])))
        let moved = tall[10..<40].enumerated().map { index, row in
            var row = row
            row[0] = UInt8(index * 13 % 256)
            row[4] = UInt8(index * 29 % 256)
            return row
        }
        #expect(stitcher.add(frame(moved)) == .added(rows: 10))
        #expect(stitcher.height == 40)
    }

    @Test("an animation in place, with nothing scrolled, adds nothing")
    func ignoresAnimationInPlace() {
        let rows = page(30)
        var stitcher = Stitcher()
        _ = stitcher.add(frame(rows))
        let animated = rows.enumerated().map { index, row in
            var row = row
            row[0] = UInt8(index * 13 % 256 + 1)
            return row
        }
        #expect(stitcher.add(frame(animated)) == .unchanged)
        #expect(stitcher.height == 30)
    }

    @Test("a frame with most of its content changed still stitches when one shift clearly lines up")
    func acceptsClearWinner() {
        let tall = page(60)
        var stitcher = Stitcher()
        _ = stitcher.add(frame(Array(tall[0..<30])))
        let changed = tall[10..<40].enumerated().map { index, row in
            var row = row
            for byte in 0..<40 { row[byte] = UInt8((index * 31 + byte * 17) % 256) }
            return row
        }
        #expect(stitcher.add(frame(changed)) == .added(rows: 10))
    }
}
