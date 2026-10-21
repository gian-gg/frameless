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

    /// A window's frame relative to a display, clipped to it; both in Core Graphics global points.
    static func windowRect(_ window: CGRect, onDisplay display: CGRect) -> CGRect? {
        let visible = window.intersection(display)
        guard !visible.isNull, visible.width > 0, visible.height > 0 else { return nil }
        return visible.offsetBy(dx: -display.minX, dy: -display.minY)
    }

    /// Flips a Core Graphics global rect (top-left of the primary display) to AppKit global (bottom-left).
    static func appKitRect(fromCG rect: CGRect, primaryScreenHeight: CGFloat) -> CGRect {
        CGRect(x: rect.minX, y: primaryScreenHeight - rect.maxY, width: rect.width, height: rect.height)
    }

    /// Shrinks a pixel size to fit a box (turned upright for tall sources), keeping its shape; never enlarges.
    static func fitted(_ size: (width: Int, height: Int), within box: CGSize?) -> (width: Int, height: Int) {
        guard let box else { return size }
        let limit = size.height > size.width ? CGSize(width: box.height, height: box.width) : box
        let factor = min(limit.width / CGFloat(size.width), limit.height / CGFloat(size.height))
        guard factor < 1 else { return size }
        func even(_ pixels: Int) -> Int { max(2, Int((CGFloat(pixels) * factor).rounded()) / 2 * 2) }
        return (even(size.width), even(size.height))
    }

    /// Pixel dimensions for a point size, rounded down to even numbers for H.264.
    static func evenPixelSize(_ size: CGSize, scale: CGFloat) -> (width: Int, height: Int) {
        func even(_ points: CGFloat) -> Int { max(2, Int(points * scale) / 2 * 2) }
        return (even(size.width), even(size.height))
    }
}
