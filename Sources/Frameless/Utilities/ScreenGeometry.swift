import CoreGraphics

/// Conversions from AppKit overlay space to ScreenCaptureKit display space and pixel sizes.
enum ScreenGeometry {
    struct CaptureArea: Equatable {
        let sourceRect: CGRect
        let width: Int
        let height: Int
    }

    /// Flips a screen-local, bottom-left-origin rect to top-left display points, clamped and pixel-aligned.
    static func captureArea(fromLocal rect: CGRect, screenSize: CGSize, scale: CGFloat) -> CaptureArea? {
        let clamped = rect.intersection(CGRect(origin: .zero, size: screenSize))
        guard !clamped.isNull, clamped.width > 0, clamped.height > 0 else { return nil }
        let size = evenPixelSize(clamped.size, scale: scale)
        let originX = (clamped.minX * scale).rounded(.down) / scale
        let originY = ((screenSize.height - clamped.maxY) * scale).rounded(.down) / scale
        let sourceRect = CGRect(
            x: originX, y: originY, width: CGFloat(size.width) / scale, height: CGFloat(size.height) / scale)
        return CaptureArea(sourceRect: sourceRect, width: size.width, height: size.height)
    }

    /// Pixel dimensions for a point size, rounded down to even numbers for H.264.
    static func evenPixelSize(_ size: CGSize, scale: CGFloat) -> (width: Int, height: Int) {
        func even(_ points: CGFloat) -> Int { max(2, Int(points * scale) / 2 * 2) }
        return (even(size.width), even(size.height))
    }
}
