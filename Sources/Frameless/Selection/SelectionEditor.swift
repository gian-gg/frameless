import AppKit
import Carbon.HIToolbox

/// After picking, keeps the selection on screen to resize or move until it's confirmed: Copy or Save for a
/// screenshot, Record for a recording. Nothing is captured until then.
@MainActor
final class SelectionEditor {
    enum Action {
        case copy
        case save
        case record
    }

    /// The chosen action and the selection as it was when it was chosen.
    struct Choice {
        let action: Action
        let selection: CaptureSelection
    }

    private var window: ScreenCoverWindow?
    private var continuation: CheckedContinuation<Choice?, Never>?

    /// Shows the selection on its screen, calls `onShown` once it's up; returns the choice, or nil when closed.
    func present(
        _ selection: CaptureSelection, for purpose: CapturePurpose, onShown: @MainActor () -> Void = {}
    ) async -> Choice? {
        guard continuation == nil,
            let screen = NSScreen.screens.first(where: { $0.displayID == selection.displayID })
        else { return nil }
        return await withCheckedContinuation { continuation in
            self.continuation = continuation
            show(selection, for: purpose, on: screen)
            onShown()
        }
    }

    private func show(_ selection: CaptureSelection, for purpose: CapturePurpose, on screen: NSScreen) {
        let window = ScreenCoverWindow(screen: screen)
        let view = SelectionEditorView(selection: selection, purpose: purpose, scale: screen.backingScaleFactor)
        view.onFinish = { [weak self] choice in self?.finish(choice) }
        window.contentView = view
        window.makeFirstResponder(view)
        window.orderFrontRegardless()
        window.makeKey()
        self.window = window
    }

    private func finish(_ choice: Choice?) {
        window?.orderOut(nil)
        window = nil
        continuation?.resume(returning: choice)
        continuation = nil
    }
}

/// The dimmed screen with the live selection, its size tag and the bar; resizes, moves, and handles the keys.
private final class SelectionEditorView: NSView {
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
            items: barItems(), closeToolTip: "Close (Esc)", close: { [weak self] in self?.onFinish?(nil) })
        addSubview(toolbar)
        self.toolbar = toolbar
        addSubview(sizeTag)
        updateTag()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { nil }

    override var acceptsFirstResponder: Bool { true }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    private var isResizable: Bool {
        if case .window = selection.target { return false }
        return true
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
        if !isResizable { return selection }
        let isWholeScreen = rect == CGRect(origin: .zero, size: selection.screenFrame.size)
        return CaptureSelection(
            displayID: selection.displayID, screenFrame: selection.screenFrame,
            target: isWholeScreen ? .display : .area(rect))
    }

    /// Copy and Save for a screenshot; Record for a recording.
    private func barItems() -> [GlassBar.Item] {
        switch purpose {
        case .screenshot:
            [
                .init(
                    symbol: "doc.on.doc", title: "Copy", shortcut: .text("⌘C"), toolTip: "Copy to the clipboard",
                    perform: { [weak self] in self?.choose(.copy) }),
                .init(
                    symbol: "square.and.arrow.down", title: "Save", shortcut: .text("⌘S"), toolTip: "Save to Pictures",
                    perform: { [weak self] in self?.choose(.save) }),
            ]
        case .recording:
            [
                .init(
                    symbol: Config.StatusItem.recordingSymbolName, title: "Record", shortcut: .text("↩"),
                    toolTip: "Start recording", perform: { [weak self] in self?.choose(.record) })
            ]
        }
    }

    private func choose(_ action: SelectionEditor.Action) {
        onFinish?(SelectionEditor.Choice(action: action, selection: finalSelection))
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
        Self.cursor(for: handle(at: event)).set()
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
        default: super.keyDown(with: event)
        }
    }

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        guard purpose == .screenshot, event.modifierFlags.intersection(.deviceIndependentFlagsMask) == .command else {
            return super.performKeyEquivalent(with: event)
        }
        switch Int(event.keyCode) {
        case kVK_ANSI_C: choose(.copy)
        case kVK_ANSI_S: choose(.save)
        default: return super.performKeyEquivalent(with: event)
        }
        return true
    }
}
