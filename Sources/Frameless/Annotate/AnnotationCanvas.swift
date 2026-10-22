import AppKit

/// The frozen capture with its marks, laid over the selection; the editor's tools draw into it.
final class AnnotationCanvas: NSView {
    let shot: CapturedImage
    private(set) var history = MarkHistory() {
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
        MarkRenderer.draw(history.marks, in: context, over: shot.image, size: bounds.size)
    }
}
