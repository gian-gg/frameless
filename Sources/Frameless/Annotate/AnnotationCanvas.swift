import AppKit

/// The frozen capture with its marks, laid over the selection; dragging with a tool picked draws a mark, and
/// holding Shift keeps rectangles square and lines and arrows at 45° steps.
final class AnnotationCanvas: NSView {
    let shot: CapturedImage
    var tool: AnnotationTool?
    var color = Config.Annotate.defaultColor
    private(set) var history = MarkHistory() {
        didSet { needsDisplay = true }
    }
    /// The mark being dragged out, shown live and added on release.
    private var draft: Mark? {
        didSet { needsDisplay = true }
    }

    init(shot: CapturedImage, frame: CGRect) {
        self.shot = shot
        super.init(frame: frame)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { nil }

    /// The capture with every mark drawn on, for copying, saving or pinning.
    var result: CapturedImage? {
        MarkRenderer.render(shot, marks: history.marks)
    }

    func add(_ mark: Mark) {
        history.add(mark)
    }

    func undo() {
        history.undo()
    }

    func redo() {
        history.redo()
    }

    override func draw(_ dirtyRect: NSRect) {
        guard let context = NSGraphicsContext.current?.cgContext else { return }
        context.draw(shot.image, in: bounds)
        MarkRenderer.draw(history.marks + [draft].compactMap { $0 }, in: context, over: shot.image, size: bounds.size)
    }

    // MARK: - Drawing marks

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func mouseDown(with event: NSEvent) {
        guard let tool else { return }
        let point = location(of: event)
        draft = Mark(tool: tool, points: tool == .freehand ? [point] : [point, point], color: color)
    }

    override func mouseDragged(with event: NSEvent) {
        guard var mark = draft, let start = mark.points.first, let last = mark.points.last else { return }
        var point = location(of: event)
        if mark.tool == .freehand {
            guard hypot(point.x - last.x, point.y - last.y) >= Config.Annotate.freehandSpacing else { return }
            mark.points.append(point)
            draft = mark
            return
        }
        if event.modifierFlags.contains(.shift) {
            switch mark.tool {
            case .rectangle: point = ScreenGeometry.squareCorner(from: start, to: point, in: bounds)
            case .line, .arrow: point = ScreenGeometry.snappedEnd(from: start, to: point, in: bounds)
            default: break
            }
        }
        mark.points[mark.points.count - 1] = point
        draft = mark
    }

    override func mouseUp(with event: NSEvent) {
        guard let mark = draft else { return }
        draft = nil
        guard let rect = MarkRenderer.bounds(of: mark),
            max(rect.width, rect.height) >= Config.Annotate.minimumDrag
        else { return }
        add(mark)
    }

    /// Where the pointer is, in canvas points, kept inside the canvas.
    private func location(of event: NSEvent) -> CGPoint {
        let point = convert(event.locationInWindow, from: nil)
        return CGPoint(x: min(max(point.x, 0), bounds.width), y: min(max(point.y, 0), bounds.height))
    }
}
