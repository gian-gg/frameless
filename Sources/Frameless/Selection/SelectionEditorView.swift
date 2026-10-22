import AppKit
import Carbon.HIToolbox

/// The dimmed screen with the live selection, its size tag and the bar; resizes, moves, and handles the keys.
final class SelectionEditorView: NSView {
    private static let grabTolerance: CGFloat = 8

    var onFinish: (@MainActor (SelectionEditor.Choice?) -> Void)?
    /// The colour new marks are drawn in, shown in the colour button.
    var markColor = Config.Annotate.defaultColor {
        didSet {
            toolbar?.setStyle(.color(markColor.nsColor), at: Style.color.rawValue)
            canvas?.color = markColor
        }
    }
    var onMarkColorChange: (@MainActor (MarkColor) -> Void)?
    /// How thick new marks are drawn, shown in the thickness button.
    var markWeight = Config.Annotate.defaultWeight {
        didSet {
            toolbar?.setStyle(.stroke(markWeight.lineWidth), at: Style.weight.rawValue)
            canvas?.weight = markWeight
        }
    }
    var onMarkWeightChange: (@MainActor (MarkWeight) -> Void)?

    private let selection: CaptureSelection
    let purpose: CapturePurpose
    private let scale: CGFloat
    /// The selection in this screen's local points; fixed for a window, editable otherwise.
    var rect: CGRect
    var toolbar: GlassBar?
    private let sizeTag = GlassTag()
    var drag: Drag?
    var tool: AnnotationTool?
    /// The capture taken when a tool is first picked, shown in place of the live screen from then on.
    var canvas: AnnotationCanvas?
    var isFreezing = false
    /// The style whose row of choices is open, and that row.
    var openStyle: Style?
    var styleRow: SampleRow?

    /// The style buttons, in bar order.
    enum Style: Int, CaseIterable {
        case color
        case weight
    }

    /// A resize or move in progress: what was grabbed, and where the pointer and selection started.
    struct Drag {
        let handle: ScreenGeometry.ResizeHandle
        let start: CGPoint
        let startRect: CGRect
    }

    init(selection: CaptureSelection, purpose: CapturePurpose, scale: CGFloat) {
        self.selection = selection
        self.purpose = purpose
        self.scale = scale
        rect = Self.localRect(for: selection)
        super.init(frame: .zero)
        let toolbar = GlassBar(
            tools: purpose == .screenshot ? Self.tools : [], styles: purpose == .screenshot ? styleButtons() : [],
            items: barItems(),
            closeToolTip: "Close (Esc)",
            close: { [weak self] in self?.onFinish?(nil) })
        toolbar.onSelectTool = { [weak self] index in self?.pick(index.map { AnnotationTool.allCases[$0] }) }
        addSubview(toolbar)
        self.toolbar = toolbar
        addSubview(sizeTag)
        updateTag()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { nil }

    override var acceptsFirstResponder: Bool { true }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    private var isWindow: Bool {
        if case .window = selection.target { return true }
        return false
    }

    /// Areas and displays can be resized and moved until the capture is frozen.
    private var isResizable: Bool {
        !isWindow && canvas == nil && !isFreezing
    }

    private static func localRect(for selection: CaptureSelection) -> CGRect {
        let screenBounds = CGRect(origin: .zero, size: selection.screenFrame.size)
        switch selection.target {
        case .display:
            return screenBounds
        case .area(let area):
            return area
        case .window(let id):
            let frame = WindowList.snapshot().windows.first { $0.id == id }?.frame ?? selection.screenFrame
            let local = frame.offsetBy(dx: -selection.screenFrame.minX, dy: -selection.screenFrame.minY)
            return local.intersection(screenBounds)
        }
    }

    /// The selection to capture: the window unchanged, the whole display while untouched, else the area.
    var finalSelection: CaptureSelection {
        if isWindow { return selection }
        let isWholeScreen = rect == CGRect(origin: .zero, size: selection.screenFrame.size)
        return CaptureSelection(
            displayID: selection.displayID, screenFrame: selection.screenFrame,
            target: isWholeScreen ? .display : .area(rect))
    }

    /// Copy, Save and Pin for a screenshot; Record for a recording.
    private func barItems() -> [GlassBar.Item] {
        switch purpose {
        case .screenshot:
            [
                .init(
                    icon: .copy, title: nil, shortcut: nil, toolTip: "Copy to the clipboard (⌘C)",
                    perform: { [weak self] in self?.choose(.copy) }),
                .init(
                    icon: .download, title: nil, shortcut: nil, toolTip: "Save (⌘S)",
                    perform: { [weak self] in self?.choose(.save) }),
                .init(
                    icon: .pin, title: nil, shortcut: nil, toolTip: "Pin on screen (⌘P)",
                    perform: { [weak self] in self?.choose(.pin) }),
            ]
        case .recording:
            [
                .init(
                    icon: .circleDot, title: "Record", shortcut: nil, toolTip: "Start recording (↩)",
                    perform: { [weak self] in self?.choose(.record) })
            ]
        }
    }

    private func choose(_ action: SelectionEditor.Action) {
        canvas?.commitText()
        onFinish?(SelectionEditor.Choice(action: action, selection: finalSelection, image: canvas?.result))
    }

    private func updateTag() {
        let size = ScreenGeometry.evenPixelSize(rect.size, scale: scale)
        sizeTag.show("\(size.width) × \(size.height)")
        needsLayout = true
        needsDisplay = true
    }

    override func layout() {
        super.layout()
        if let toolbar {
            toolbar.setFrameOrigin(
                ScreenGeometry.barOrigin(
                    for: toolbar.frame.size, under: rect, in: bounds, gap: Config.Bar.selectionGap,
                    inset: Config.Style.barBottomOffset, centred: isWindow || rect == bounds))
        }
        placeStyleRow()
        sizeTag.setFrameOrigin(
            ScreenGeometry.tagOrigin(for: sizeTag.frame.size, on: rect, in: bounds, lift: Config.Style.tagLift))
    }

    override func draw(_ dirtyRect: NSRect) {
        NSColor.black.withAlphaComponent(Config.Style.dimOpacity).setFill()
        bounds.fill()
        NSColor.clear.setFill()
        rect.fill(using: .copy)
        Panel.drawSelectionFrame(rect)
    }

    // MARK: - Resize and move

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        trackingAreas.forEach(removeTrackingArea)
        addTrackingArea(
            NSTrackingArea(rect: .zero, options: [.mouseMoved, .activeAlways, .inVisibleRect], owner: self))
    }

    private func handle(at event: NSEvent) -> ScreenGeometry.ResizeHandle? {
        guard isResizable else { return nil }
        let point = convert(event.locationInWindow, from: nil)
        return ScreenGeometry.handle(at: point, of: rect, tolerance: Self.grabTolerance)
    }

    override func mouseMoved(with event: NSEvent) {
        if let canvas, canvas.frame.contains(convert(event.locationInWindow, from: nil)) {
            if canvas.tool != nil {
                NSCursor.crosshair.set()
            } else if canvas.hasMark(atWindowPoint: event.locationInWindow) {
                NSCursor.openHand.set()
            } else {
                NSCursor.arrow.set()
            }
        } else {
            Self.cursor(for: handle(at: event)).set()
        }
    }

    override func mouseDown(with event: NSEvent) {
        guard let handle = handle(at: event) else { return }
        drag = Drag(handle: handle, start: convert(event.locationInWindow, from: nil), startRect: rect)
        if handle == .move { NSCursor.closedHand.set() }
    }

    override func mouseDragged(with event: NSEvent) {
        guard let drag else { return }
        let point = convert(event.locationInWindow, from: nil)
        rect =
            ScreenGeometry.resize(
                drag.startRect, with: drag.handle, by: CGVector(dx: point.x - drag.start.x, dy: point.y - drag.start.y),
                in: bounds, minimum: Config.Overlay.minimumDrag
            ).integral
        updateTag()
    }

    override func mouseUp(with event: NSEvent) {
        drag = nil
        Self.cursor(for: handle(at: event)).set()
    }

    private static func cursor(for handle: ScreenGeometry.ResizeHandle?) -> NSCursor {
        let position: NSCursor.FrameResizePosition
        switch handle {
        case .topLeft: position = .topLeft
        case .top: position = .top
        case .topRight: position = .topRight
        case .right: position = .right
        case .bottomRight: position = .bottomRight
        case .bottom: position = .bottom
        case .bottomLeft: position = .bottomLeft
        case .left: position = .left
        case .move: return .openHand
        case nil: return .arrow
        }
        return .frameResize(position: position, directions: .all)
    }

    // MARK: - Keys

    override func keyDown(with event: NSEvent) {
        switch Int(event.keyCode) {
        case kVK_Escape:
            if styleRow != nil {
                hideStyleRow()
            } else if tool != nil, canvas != nil {
                pick(nil)
            } else if canvas?.selection != nil {
                canvas?.selection = nil
            } else {
                onFinish?(nil)
            }
        case kVK_Return, kVK_ANSI_KeypadEnter: choose(purpose == .screenshot ? .copy : .record)
        case kVK_Delete, kVK_ForwardDelete:
            if canvas?.deleteSelection() != true { super.keyDown(with: event) }
        default:
            guard let tool = tool(for: event) else { return super.keyDown(with: event) }
            pick(self.tool == tool ? nil : tool)
        }
    }

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        let modifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask).subtracting(.capsLock)
        guard purpose == .screenshot else { return super.performKeyEquivalent(with: event) }
        if canvas?.isEditingText == true, let edit = Self.textEdit(for: Int(event.keyCode), modifiers) {
            return NSApp.sendAction(edit, to: nil, from: self)
        }
        switch (Int(event.keyCode), modifiers) {
        case (kVK_ANSI_C, .command): choose(.copy)
        case (kVK_ANSI_S, .command): choose(.save)
        case (kVK_ANSI_P, .command): choose(.pin)
        case (kVK_ANSI_Z, .command): canvas?.undo()
        case (kVK_ANSI_Z, [.command, .shift]): canvas?.redo()
        default: return super.performKeyEquivalent(with: event)
        }
        return true
    }

    /// The standard text-editing action for a shortcut while typing, since the app has no Edit menu to supply them.
    private static func textEdit(for keyCode: Int, _ modifiers: NSEvent.ModifierFlags) -> Selector? {
        switch (keyCode, modifiers) {
        case (kVK_ANSI_X, .command): #selector(NSText.cut(_:))
        case (kVK_ANSI_C, .command): #selector(NSText.copy(_:))
        case (kVK_ANSI_V, .command): #selector(NSText.paste(_:))
        case (kVK_ANSI_A, .command): #selector(NSText.selectAll(_:))
        case (kVK_ANSI_Z, .command): Selector(("undo:"))
        case (kVK_ANSI_Z, [.command, .shift]): Selector(("redo:"))
        default: nil
        }
    }
}
