import CoreGraphics
import Foundation

/// Builds one tall image from frames of a scrolling area: each frame adds the rows it scrolled into view, and rows
/// that stay put between frames, such as a sticky header or footer, are kept once.
struct Stitcher {
    /// One captured frame: rows of RGBA bytes, top row first, all the same width, each with a fingerprint.
    struct Frame {
        let width: Int
        let rows: [[UInt8]]
        let fingerprints: [UInt64]
        /// Rows with more than one colour; plain rows can't tell one scroll position from another.
        let hasDetail: [Bool]

        init(width: Int, rows: [[UInt8]]) {
            self.width = width
            self.rows = rows
            fingerprints = rows.map(Self.fingerprint)
            hasDetail = rows.map(Self.hasDetail)
        }

        private static func fingerprint(_ row: [UInt8]) -> UInt64 {
            row.reduce(14_695_981_039_346_656_037) { ($0 ^ UInt64($1)) &* 1_099_511_628_211 }
        }

        private static func hasDetail(_ row: [UInt8]) -> Bool {
            guard row.count >= 8 else { return false }
            let first = row[0..<4]
            return stride(from: 4, to: row.count, by: 4).contains { row[$0..<$0 + 4] != first }
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
        guard let shift = Self.shift(from: previous, to: frame, within: middle) else { return .lost }
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

    /// How many rows the content within `rows` moved up: the shift lining up the most detailed rows, with at least
    /// a quarter of the strip overlapping and nearly all of its detailed rows agreeing.
    static func shift(from last: Frame, to new: Frame, within rows: Range<Int>) -> Int? {
        let height = rows.count
        let minimumOverlap = max(1, height / 4)
        guard height > minimumOverlap else { return nil }
        var best: (shift: Int, matches: Int)?
        for shift in 1...(height - minimumOverlap) {
            var detailed = 0
            var matches = 0
            for offset in 0..<(height - shift) {
                let newRow = rows.lowerBound + offset
                let lastRow = newRow + shift
                guard last.hasDetail[lastRow] else { continue }
                detailed += 1
                if new.fingerprints[newRow] == last.fingerprints[lastRow] { matches += 1 }
            }
            guard detailed > 0, Double(matches) >= Double(detailed) * Config.Scroll.matchShare else { continue }
            if best.map({ matches > $0.matches }) ?? true { best = (shift, matches) }
        }
        return best?.shift
    }
}
