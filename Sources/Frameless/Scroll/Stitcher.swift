import CoreGraphics
import Foundation

/// Builds one tall image from frames of a scrolling area: each frame adds the rows it scrolled into view, and rows
/// that stay put between frames, such as a sticky header or footer, are kept once.
struct Stitcher {
    /// One captured frame: rows of RGBA bytes, top row first, all the same width, each split into strips across.
    struct Frame {
        let width: Int
        let rows: [[UInt8]]
        let fingerprints: [UInt64]
        /// A fingerprint per strip, row by row, and whether that strip has more than one colour.
        let cells: [UInt64]
        let hasDetail: [Bool]
        let strips: Int

        init(width: Int, rows: [[UInt8]]) {
            self.width = width
            self.rows = rows
            let strips = max(1, min(Config.Scroll.strips, width))
            self.strips = strips
            let bounds = (0...strips).map { $0 * width / strips * 4 }
            var cells: [UInt64] = []
            var hasDetail: [Bool] = []
            cells.reserveCapacity(rows.count * strips)
            hasDetail.reserveCapacity(rows.count * strips)
            for row in rows {
                for strip in 0..<strips {
                    let pixels = row[bounds[strip]..<bounds[strip + 1]]
                    cells.append(Self.fingerprint(pixels))
                    hasDetail.append(Self.hasDetail(pixels))
                }
            }
            self.cells = cells
            self.hasDetail = hasDetail
            fingerprints = (0..<rows.count).map { row in
                cells[row * strips..<(row + 1) * strips].reduce(0) { ($0 ^ $1) &* 1_099_511_628_211 }
            }
        }

        private static func fingerprint<Bytes: Collection<UInt8>>(_ bytes: Bytes) -> UInt64 {
            bytes.reduce(14_695_981_039_346_656_037) { ($0 ^ UInt64($1)) &* 1_099_511_628_211 }
        }

        private static func hasDetail(_ pixels: ArraySlice<UInt8>) -> Bool {
            let start = pixels.startIndex
            guard pixels.count >= 8 else { return false }
            let first = pixels[start..<start + 4]
            return stride(from: start + 4, to: pixels.endIndex, by: 4).contains { pixels[$0..<$0 + 4] != first }
        }
    }

    /// What a frame did to the image.
    enum Change: Equatable {
        case started
        case added(rows: Int)
        case unchanged
        case lost
    }

    private(set) var width = 0
    private var header: [[UInt8]] = []
    private var body: [[UInt8]] = []
    private var footer: [[UInt8]] = []
    private var previous: Frame?

    /// The stitched height in pixels.
    var height: Int { header.count + body.count + footer.count }

    /// Adds a frame, appending the rows it scrolled into view.
    mutating func add(_ frame: Frame) -> Change {
        guard let previous, previous.width == frame.width, previous.rows.count == frame.rows.count else {
            start(with: frame)
            return .started
        }
        guard frame.fingerprints != previous.fingerprints else { return .unchanged }
        let still = Self.stillRows(previous.fingerprints, frame.fingerprints)
        let middle = still.top..<(frame.rows.count - still.bottom)
        guard middle.count * Config.Scroll.minimumMovingShare >= frame.rows.count else { return .unchanged }
        guard let shift = Self.shift(from: previous, to: frame, within: middle) else { return .lost }
        guard shift > 0 else { return .unchanged }
        if header.count != still.top || footer.count != still.bottom {
            let rows = header + body + footer
            header = Array(rows.prefix(still.top))
            body = Array(rows.dropFirst(still.top).dropLast(still.bottom))
        }
        body.append(contentsOf: frame.rows[middle].suffix(shift))
        footer = Array(frame.rows.suffix(still.bottom))
        self.previous = frame
        return .added(rows: shift)
    }

    /// The stitched image, top row first.
    func image() -> CGImage? {
        let rows = header + body + footer
        guard width > 0, !rows.isEmpty,
            let provider = CGDataProvider(data: Data(rows.joined()) as CFData)
        else { return nil }
        return CGImage(
            width: width, height: rows.count, bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: width * 4,
            space: CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue), provider: provider,
            decode: nil, shouldInterpolate: false, intent: .defaultIntent)
    }

    private mutating func start(with frame: Frame) {
        width = frame.width
        header = []
        body = frame.rows
        footer = []
        previous = frame
    }

    /// How many rows at the top and at the bottom match in both frames.
    static func stillRows(_ first: [UInt64], _ second: [UInt64]) -> (top: Int, bottom: Int) {
        let count = min(first.count, second.count)
        var top = 0
        while top < count, first[top] == second[top] { top += 1 }
        var bottom = 0
        while bottom < count - top, first[count - 1 - bottom] == second[count - 1 - bottom] { bottom += 1 }
        return (top, bottom)
    }

    /// How many rows the content within `rows` moved up, or 0 if it stayed put: the shift lining up the most detailed
    /// strips, with at least a quarter of the strip overlapping, taken when most strips agree or when it clearly beats
    /// every other shift, such as while part of the page changes as it scrolls.
    static func shift(from last: Frame, to new: Frame, within rows: Range<Int>) -> Int? {
        let minimumOverlap = max(1, rows.count / 4)
        guard rows.count > minimumOverlap, last.strips == new.strips else { return nil }
        let scores = (0...(rows.count - minimumOverlap)).map { score(from: last, to: new, within: rows, shift: $0) }
        guard
            let best = scores.indices.filter({ scores[$0].detailed > 0 }).max(by: {
                scores[$0].matches < scores[$1].matches
            })
        else { return nil }
        let share = scores[best].share
        if share >= Config.Scroll.matchShare { return best }
        let rival = scores.indices.filter { abs($0 - best) > 1 }.map { scores[$0].share }.max() ?? 0
        return share >= Config.Scroll.clearMatchShare && share >= rival * 2 ? best : nil
    }

    /// How many detailed strips of `last` line up with `new` when its content is moved up by `shift` rows.
    private static func score(from last: Frame, to new: Frame, within rows: Range<Int>, shift: Int) -> Score {
        let strips = new.strips
        var score = Score()
        for offset in 0..<(rows.count - shift) {
            let newCell = (rows.lowerBound + offset) * strips
            let lastCell = newCell + shift * strips
            for strip in 0..<strips where last.hasDetail[lastCell + strip] {
                score.detailed += 1
                if new.cells[newCell + strip] == last.cells[lastCell + strip] { score.matches += 1 }
            }
        }
        return score
    }

    /// Detailed strips compared at one shift, and how many matched.
    private struct Score {
        var detailed = 0
        var matches = 0
        var share: Double { detailed > 0 ? Double(matches) / Double(detailed) : 0 }
    }
}
