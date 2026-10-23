extension Stitcher {
    /// One captured frame: rows of BGRA bytes, top row first, all the same width, each split into strips across.
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
            var cells = [UInt64](repeating: 0, count: rows.count * strips)
            var hasDetail = [Bool](repeating: false, count: rows.count * strips)
            for (index, row) in rows.enumerated() {
                row.withUnsafeBytes { bytes in
                    for strip in 0..<strips {
                        let pixels = UnsafeRawBufferPointer(rebasing: bytes[bounds[strip]..<bounds[strip + 1]])
                        cells[index * strips + strip] = Self.fingerprint(pixels)
                        hasDetail[index * strips + strip] = Self.hasDetail(pixels)
                    }
                }
            }
            self.cells = cells
            self.hasDetail = hasDetail
            fingerprints = (0..<rows.count).map { row in
                cells[row * strips..<(row + 1) * strips].reduce(0) { ($0 ^ $1) &* 1_099_511_628_211 }
            }
        }

        /// A hash of the bytes, read a pixel at a time.
        private static func fingerprint(_ pixels: UnsafeRawBufferPointer) -> UInt64 {
            var hash: UInt64 = 14_695_981_039_346_656_037
            for offset in stride(from: 0, to: pixels.count - 3, by: 4) {
                hash =
                    (hash ^ UInt64(pixels.loadUnaligned(fromByteOffset: offset, as: UInt32.self))) &* 1_099_511_628_211
            }
            return hash
        }

        private static func hasDetail(_ pixels: UnsafeRawBufferPointer) -> Bool {
            guard pixels.count >= 8 else { return false }
            let first = pixels.loadUnaligned(as: UInt32.self)
            return stride(from: 4, to: pixels.count - 3, by: 4).contains {
                pixels.loadUnaligned(fromByteOffset: $0, as: UInt32.self) != first
            }
        }
    }
}
