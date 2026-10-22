import CoreGraphics
import Foundation

extension MarkRenderer {
    /// Replaces the mark's area with blocks averaged from the capture's own pixels, so the content is gone rather
    /// than covered. Blocks sit on a fixed grid across the image, so resizing the area never resizes or shifts them.
    static func drawPixelate(_ mark: Mark, in context: CGContext, over image: CGImage, size: CGSize) {
        let canvas = CGRect(origin: .zero, size: size)
        guard let area = bounds(of: mark)?.intersection(canvas), !area.isNull, area.width >= 1, area.height >= 1
        else { return }
        let block = Config.Annotate.pixelateBlock
        let left = (area.minX / block).rounded(.down) * block
        let bottom = (area.minY / block).rounded(.down) * block
        let grid = CGRect(
            x: left, y: bottom, width: (area.maxX / block).rounded(.up) * block - left,
            height: (area.maxY / block).rounded(.up) * block - bottom)
        guard let blocks = blockImage(of: image, over: grid, size: size, block: block) else { return }
        context.saveGState()
        defer { context.restoreGState() }
        context.clip(to: area)
        context.interpolationQuality = .none
        context.draw(blocks, in: grid)
    }

    /// One pixel per grid block, each the exact average of the capture's pixels inside that block.
    private static func blockImage(of image: CGImage, over grid: CGRect, size: CGSize, block: CGFloat) -> CGImage? {
        let scale = CGFloat(image.width) / size.width
        let source = grid.intersection(CGRect(origin: .zero, size: size))
        let pixelRect = CGRect(
            x: source.minX * scale, y: (size.height - source.maxY) * scale, width: source.width * scale,
            height: source.height * scale
        ).integral
        let columns = Int((grid.width / block).rounded())
        let rows = Int((grid.height / block).rounded())
        guard columns > 0, rows > 0, let crop = image.cropping(to: pixelRect),
            let pixels = rgbaPixels(of: crop)
        else { return nil }
        let width = crop.width
        let height = crop.height
        var averaged = [UInt8](repeating: 0, count: columns * rows * 4)
        for row in 0..<rows {
            let top = grid.maxY - CGFloat(row + 1) * block
            let rowStart = clamp(Int(((source.maxY - top - block) * scale).rounded()), height)
            let rowEnd = clamp(Int(((source.maxY - top) * scale).rounded()), height)
            for column in 0..<columns {
                let cellLeft = grid.minX + CGFloat(column) * block - source.minX
                let start = clamp(Int((cellLeft * scale).rounded()), width)
                let end = clamp(Int(((cellLeft + block) * scale).rounded()), width)
                let average = averageColor(pixels, width: width, columns: start..<end, rows: rowStart..<rowEnd)
                let offset = (row * columns + column) * 4
                averaged.replaceSubrange(offset..<offset + 4, with: average)
            }
        }
        return makeImage(fromRGBA: averaged, width: columns, height: rows)
    }

    private static func clamp(_ value: Int, _ limit: Int) -> Int {
        min(max(value, 0), limit)
    }

    private static func averageColor(
        _ pixels: [UInt8], width: Int, columns: Range<Int>, rows: Range<Int>
    ) -> [UInt8] {
        let count = columns.count * rows.count
        guard count > 0 else { return [0, 0, 0, 0] }
        var sums = [Int](repeating: 0, count: 4)
        for row in rows {
            for column in columns {
                let offset = (row * width + column) * 4
                for channel in 0..<4 { sums[channel] += Int(pixels[offset + channel]) }
            }
        }
        return sums.map { UInt8($0 / count) }
    }

    /// The image's premultiplied RGBA bytes, top row first.
    private static func rgbaPixels(of image: CGImage) -> [UInt8]? {
        var pixels = [UInt8](repeating: 0, count: image.width * image.height * 4)
        let drawn = pixels.withUnsafeMutableBytes { buffer -> Bool in
            guard
                let context = CGContext(
                    data: buffer.baseAddress, width: image.width, height: image.height, bitsPerComponent: 8,
                    bytesPerRow: image.width * 4, space: sRGB,
                    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
            else { return false }
            context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
            return true
        }
        return drawn ? pixels : nil
    }

    private static func makeImage(fromRGBA bytes: [UInt8], width: Int, height: Int) -> CGImage? {
        guard let provider = CGDataProvider(data: Data(bytes) as CFData) else { return nil }
        return CGImage(
            width: width, height: height, bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: width * 4,
            space: sRGB, bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
            provider: provider, decode: nil, shouldInterpolate: false, intent: .defaultIntent)
    }

    private static var sRGB: CGColorSpace {
        CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB()
    }
}
