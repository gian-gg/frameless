import CoreGraphics

/// Pixel sizes for ScreenCaptureKit output.
enum ScreenGeometry {
    /// Pixel dimensions for a point size, rounded down to even numbers for H.264.
    static func evenPixelSize(_ size: CGSize, scale: CGFloat) -> (width: Int, height: Int) {
        func even(_ points: CGFloat) -> Int { max(2, Int(points * scale) / 2 * 2) }
        return (even(size.width), even(size.height))
    }
}
