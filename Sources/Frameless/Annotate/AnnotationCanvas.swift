import AppKit

/// The frozen capture with its marks, dimmed outside the part kept: tools draw marks, with Shift squaring boxes and
/// snapping lines to 45°, and with no tool picked marks can be selected, moved, restyled or deleted.
final class AnnotationCanvas: NSView {
    let shot: CapturedImage
    /// The part of the capture that's kept, in canvas points.
    var cropRect = CGRect.zero {
        didSet { needsDisplay = true }
    }
    var tool: AnnotationTool? {
        didSet {
            draft = nil
            if tool != nil { selection = nil }
        }
    }
    /// The mark picked with no tool, and the drag moving it.
    var selection: Int? {
        didSet { needsDisplay = true }
    }
    var moveStart: CGPoint?
    var moveOffset: CGVector? {
        didSet { needsDisplay = true }
    }
    var color = Config.Annotate.defaultColor {
        didSet { styleTextField() }
    }
    var weight = Config.Annotate.defaultWeight {
        didSet { styleTextField() }
    }
    private(set) var history = MarkHistory() {
        didSet { needsDisplay = true }
    }
    /// The field a text mark is being typed into, and where it was clicked.
    var textField: NSTextField?
    var textPoint = CGPoint.zero
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

    /// The kept part of the capture with every mark drawn on, for copying, saving or pinning.
    var result: CapturedImage? {
        guard let full = MarkRenderer.render(shot, marks: history.marks) else { return nil }
        return cropRect == bounds ? full : full.cropped(to: cropRect, of: bounds.size)
    }

    func add(_ mark: Mark) {
        history.add(mark)
    }

    /// Changes existing marks as one undoable step.
    func editMarks(_ edit: (inout [Mark]) -> Void) {
        history.change(edit)
    }

    func undo() {
        selection = nil
        history.undo()
    }

    func redo() {
        selection = nil
        history.redo()
    }

    override func draw(_ dirtyRect: NSRect) {
        guard let context = NSGraphicsContext.current?.cgContext else { return }
        context.draw(shot.image, in: bounds)
        MarkRenderer.draw(shownMarks + [draft].compactMap { $0 }, in: context, over: shot.image, size: bounds.size)
        if cropRect != bounds {
            context.addRect(bounds)
            context.addRect(cropRect)
            context.setFillColor(CGColor(gray: 0, alpha: Config.Style.dimOpacity))
            context.fillPath(using: .evenOdd)
        }
        Panel.drawSelectionFrame(cropRect)
        drawSelection(in: context)
    }

    /// Takes clicks only where they draw or grab a mark, leaving the rest to the editor's resizing.
    override func hitTest(_ point: NSPoint) -> NSView? {
        guard let hit = super.hitTest(point) else { return nil }
        guard hit === self else { return hit }
        let local = convert(point, from: superview)
        if tool != nil { return cropRect.contains(local) ? self : nil }
        return MarkGeometry.index(at: local, in: history.marks) != nil ? self : nil
    }

    // MARK: - Drawing marks

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func mouseDown(with event: NSEvent) {
        let point = location(of: event)
        guard let tool else { return beginSelecting(at: point) }
        if tool == .steps {
            return add(Mark(tool: tool, points: [point], color: color, weight: weight))
        }
        if tool == .text {
            commitText()
            return beginText(at: point)
        }
        draft = Mark(
            tool: tool, points: tool == .freehand ? [point] : [point, point], color: color, weight: weight)
    }

    override func mouseDragged(with event: NSEvent) {
        if tool == nil { return dragSelection(to: location(of: event)) }
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
            case .rectangle, .highlight, .pixelate:
                point = ScreenGeometry.squareCorner(from: start, to: point, in: cropRect)
            case .line, .arrow: point = ScreenGeometry.snappedEnd(from: start, to: point, in: cropRect)
            default: break
            }
        }
        mark.points[mark.points.count - 1] = point
        draft = mark
    }

    override func mouseUp(with event: NSEvent) {
        if tool == nil { return endSelecting() }
        guard let mark = draft else { return }
        draft = nil
        guard let rect = MarkRenderer.bounds(of: mark),
            max(rect.width, rect.height) >= Config.Annotate.minimumDrag
        else { return }
        add(mark)
    }

    /// Where the pointer is, in canvas points, kept inside the part that's kept.
    private func location(of event: NSEvent) -> CGPoint {
        let point = convert(event.locationInWindow, from: nil)
        return CGPoint(
            x: min(max(point.x, cropRect.minX), cropRect.maxX), y: min(max(point.y, cropRect.minY), cropRect.maxY))
    }
}
