import AppKit
import Carbon.HIToolbox

/// The dimmed screen with the live selection, its size tag and the bar; resizes, moves, and handles the keys.
final class SelectionEditorView: NSView {
    private static let grabTolerance: CGFloat = 8

    var onFinish: (@MainActor (SelectionEditor.Choice?) -> Void)?

    private let selection: CaptureSelection
    private let purpose: CapturePurpose
    private let scale: CGFloat
    /// The selection in this screen's local points; fixed for a window, editable otherwise.
    private var rect: CGRect
    private var toolbar: GlassBar?
    private let sizeTag = GlassTag()
    private var drag: Drag?
    private var tool: AnnotationTool?
    /// The capture taken when a tool is first picked, shown in place of the live screen from then on.
    private var canvas: AnnotationCanvas?
    private var isFreezing = false

    /// A resize or move in progress: what was grabbed, and where the pointer and selection started.
    private struct Drag {
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
            tools: purpose == .screenshot ? Self.tools : [], items: barItems(),
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
    private var finalSelection: CaptureSelection {
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
                    inset: Config.Style.barBottomOffset))
        }
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
        if let canvas, canvas.tool != nil, canvas.frame.contains(convert(event.locationInWindow, from: nil)) {
            NSCursor.crosshair.set()
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
        case kVK_Escape: onFinish?(nil)
        case kVK_Return, kVK_ANSI_KeypadEnter: choose(purpose == .screenshot ? .copy : .record)
        default:
            guard let tool = tool(for: event) else { return super.keyDown(with: event) }
            pick(self.tool == tool ? nil : tool)
        }
    }

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        let modifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        guard purpose == .screenshot else { return super.performKeyEquivalent(with: event) }
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
}

// MARK: - Annotation tools

extension SelectionEditorView {
    /// The annotation tools, each tooltip naming its key.
    private static var tools: [GlassBar.Tool] {
        AnnotationTool.allCases.map {
            GlassBar.Tool(icon: $0.icon, toolTip: "\($0.name) (\(String($0.key).uppercased()))")
        }
    }

    private func showCanvas(for shot: CapturedImage) {
        let canvas = AnnotationCanvas(shot: shot, frame: rect)
        canvas.tool = tool
        addSubview(canvas, positioned: .below, relativeTo: toolbar)
        self.canvas = canvas
    }

    /// The tool a bare key press picks, for screenshots only.
    private func tool(for event: NSEvent) -> AnnotationTool? {
        let modifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask).subtracting(.capsLock)
        guard purpose == .screenshot, modifiers.isEmpty else { return nil }
        return AnnotationTool.forKey(event.charactersIgnoringModifiers ?? "")
    }

    /// Selects a tool, or none; the first tool picked freezes the selection.
    private func pick(_ tool: AnnotationTool?) {
        self.tool = tool
        toolbar?.selectTool(tool.flatMap { AnnotationTool.allCases.firstIndex(of: $0) })
        canvas?.tool = tool
        if tool != nil { freeze() }
    }

    /// Captures the selection once and lays the canvas over it in place of the live screen.
    private func freeze() {
        guard canvas == nil, !isFreezing else { return }
        isFreezing = true
        let selection = finalSelection
        Task { [weak self] in
            do {
                let shot = try await Screenshotter.captureImage(selection)
                self?.showCanvas(for: shot)
            } catch {
                NSSound.beep()
                self?.pick(nil)
            }
            self?.isFreezing = false
            self?.needsDisplay = true
        }
    }
}
