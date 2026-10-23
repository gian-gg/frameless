import CoreGraphics
import Foundation

/// Builds one tall image from frames of a scrolling area: each frame adds the rows it scrolled into view, and rows
/// that stay put between frames, such as a sticky header or footer, are kept once.
struct Stitcher {
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
        var bytes = Data(capacity: height * width * 4)
        for rows in [header, body, footer] {
            for row in rows { bytes.append(contentsOf: row) }
        }
        return Self.makeImage(width: width, height: height, bytes: bytes)
    }

    /// A small copy of the stitched image about `targetWidth` pixels wide, sampling every few pixels, for showing
    /// while it grows.
    func preview(width targetWidth: Int) -> CGImage? {
        let step = max(1, width / max(1, targetWidth))
        let columns = width / step
        let rows = stride(from: 0, to: height, by: step)
        var bytes = Data(capacity: rows.underestimatedCount * columns * 4)
        for index in rows {
            let row = self.row(at: index)
            for column in 0..<columns { bytes.append(contentsOf: row[column * step * 4..<column * step * 4 + 4]) }
        }
        return Self.makeImage(width: columns, height: bytes.count / max(1, columns * 4), bytes: bytes)
    }

    private func row(at index: Int) -> [UInt8] {
        if index < header.count { return header[index] }
        if index < header.count + body.count { return body[index - header.count] }
        return footer[index - header.count - body.count]
    }

    /// An image from BGRA rows, as the screen hands them over.
    private static func makeImage(width: Int, height: Int, bytes: Data) -> CGImage? {
        guard width > 0, height > 0, let provider = CGDataProvider(data: bytes as CFData) else { return nil }
        return CGImage(
            width: width, height: height, bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: width * 4,
            space: CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGBitmapInfo(
                rawValue: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue),
            provider: provider, decode: nil, shouldInterpolate: false, intent: .defaultIntent)
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
