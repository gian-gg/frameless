import AppKit
import Testing

@testable import Frameless

@MainActor
struct LucideIconTests {
    @Test("every icon draws something", arguments: LucideIcon.allCases)
    func drawsIcon(_ icon: LucideIcon) throws {
        let side = 28
        let rep = try #require(
            NSBitmapImageRep(
                bitmapDataPlanes: nil, pixelsWide: side, pixelsHigh: side, bitsPerSample: 8, samplesPerPixel: 4,
                hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0))
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
        icon.image(size: CGFloat(side), color: .white).draw(in: CGRect(x: 0, y: 0, width: side, height: side))
        NSGraphicsContext.restoreGraphicsState()

        let painted = (0..<side * side).contains { rep.colorAt(x: $0 % side, y: $0 / side)?.alphaComponent ?? 0 > 0.5 }
        #expect(painted)
    }
}
