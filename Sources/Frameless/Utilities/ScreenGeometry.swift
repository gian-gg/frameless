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

    /// Which part of a selection a drag grabs: a corner, an edge, or the inside to move it.
    enum ResizeHandle: Equatable, CaseIterable {
        case topLeft, top, topRight, right, bottomRight, bottom, bottomLeft, left, move
    }

    /// The handle under a point: corners first, then edges, then the inside; nil outside the rect.
    static func handle(at point: CGPoint, of rect: CGRect, tolerance: CGFloat) -> ResizeHandle? {
        let nearLeft = abs(point.x - rect.minX) <= tolerance
        let nearRight = abs(point.x - rect.maxX) <= tolerance
        let nearBottom = abs(point.y - rect.minY) <= tolerance
        let nearTop = abs(point.y - rect.maxY) <= tolerance
        let withinX = point.x >= rect.minX - tolerance && point.x <= rect.maxX + tolerance
        let withinY = point.y >= rect.minY - tolerance && point.y <= rect.maxY + tolerance
        switch (nearLeft, nearRight, nearBottom, nearTop) {
        case (true, _, _, true): return .topLeft
        case (_, true, _, true): return .topRight
        case (true, _, true, _): return .bottomLeft
        case (_, true, true, _): return .bottomRight
        case (true, _, _, _) where withinY: return .left
        case (_, true, _, _) where withinY: return .right
        case (_, _, true, _) where withinX: return .bottom
        case (_, _, _, true) where withinX: return .top
        default: return rect.contains(point) ? .move : nil
        }
    }

    /// Applies a drag to a rect through a handle (AppKit, y up), keeping it at least `minimum` and inside `bounds`.
    static func resize(
        _ rect: CGRect, with handle: ResizeHandle, by delta: CGVector, in bounds: CGRect, minimum: CGFloat
    ) -> CGRect {
        if handle == .move {
            let left = min(max(rect.minX + delta.dx, bounds.minX), bounds.maxX - rect.width)
            let bottom = min(max(rect.minY + delta.dy, bounds.minY), bounds.maxY - rect.height)
            return CGRect(x: left, y: bottom, width: rect.width, height: rect.height)
        }
        var minX = rect.minX
        var maxX = rect.maxX
        var minY = rect.minY
        var maxY = rect.maxY
        if [.left, .topLeft, .bottomLeft].contains(handle) {
            minX = min(max(minX + delta.dx, bounds.minX), maxX - minimum)
        }
        if [.right, .topRight, .bottomRight].contains(handle) {
            maxX = max(min(maxX + delta.dx, bounds.maxX), minX + minimum)
        }
        if [.bottom, .bottomLeft, .bottomRight].contains(handle) {
            minY = min(max(minY + delta.dy, bounds.minY), maxY - minimum)
        }
        if [.top, .topLeft, .topRight].contains(handle) {
            maxY = max(min(maxY + delta.dy, bounds.maxY), minY + minimum)
        }
        return CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
    }

    /// Where a bar goes for a rect: `gap` under it, lined up with its right edge, or `inset` inside its bottom when
    /// there's no room; kept on screen.
    static func barOrigin(
        for size: CGSize, under rect: CGRect, in bounds: CGRect, gap: CGFloat, inset: CGFloat
    ) -> CGPoint {
        var top = rect.minY - gap - size.height
        if top < bounds.minY + gap {
            top = max(rect.minY, bounds.minY) + inset
        }
        let left = min(max(rect.maxX - size.width, bounds.minX + gap), bounds.maxX - gap - size.width)
        return CGPoint(x: left.rounded(), y: top.rounded())
    }

    /// Where a tag sits for a rect: above its top-left corner, or tucked inside when that would leave the screen.
    static func tagOrigin(for size: CGSize, on rect: CGRect, in bounds: CGRect, lift: CGFloat) -> CGPoint {
        var origin = CGPoint(x: rect.minX, y: rect.maxY + lift)
        if origin.y + size.height > bounds.maxY {
            origin = CGPoint(x: rect.minX + lift, y: rect.maxY - size.height - lift)
        }
        origin.x = min(max(origin.x, bounds.minX), bounds.maxX - size.width)
        return CGPoint(x: origin.x.rounded(), y: origin.y.rounded())
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

    /// The corner opposite `start` for a square towards `end`: the longer side wins, shrunk to fit `bounds`.
    static func squareCorner(from start: CGPoint, to end: CGPoint, in bounds: CGRect) -> CGPoint {
        let horizontal: CGFloat = end.x < start.x ? -1 : 1
        let vertical: CGFloat = end.y < start.y ? -1 : 1
        let room = min(
            horizontal < 0 ? start.x - bounds.minX : bounds.maxX - start.x,
            vertical < 0 ? start.y - bounds.minY : bounds.maxY - start.y)
        let side = min(max(abs(end.x - start.x), abs(end.y - start.y)), room)
        return CGPoint(x: start.x + horizontal * side, y: start.y + vertical * side)
    }

    /// A frame resized to `size` while the point under `anchor` stays put.
    static func zoomedFrame(_ frame: CGRect, to size: CGSize, around anchor: CGPoint) -> CGRect {
        guard frame.width > 0, frame.height > 0 else { return CGRect(origin: frame.origin, size: size) }
        let ratio = CGSize(width: size.width / frame.width, height: size.height / frame.height)
        let origin = CGPoint(
            x: anchor.x - (anchor.x - frame.minX) * ratio.width, y: anchor.y - (anchor.y - frame.minY) * ratio.height)
        return CGRect(origin: CGPoint(x: origin.x.rounded(), y: origin.y.rounded()), size: size)
    }

    /// Pixel dimensions for a point size, rounded down to even numbers for H.264.
    static func evenPixelSize(_ size: CGSize, scale: CGFloat) -> (width: Int, height: Int) {
        func even(_ points: CGFloat) -> Int { max(2, Int(points * scale) / 2 * 2) }
        return (even(size.width), even(size.height))
    }
}
