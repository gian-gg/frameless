import AppKit
import Carbon.HIToolbox

/// Scroll mode: the area stays outlined over the live screen, letting scrolls through to the app beneath, with a
/// small bar to finish or cancel.
@MainActor
final class ScrollSession {
    private let outline = AreaOutline()
    private var panel: ScrollBarPanel?
    private var continuation: CheckedContinuation<Bool, Never>?

    /// Runs until Done or Return (true) or Cancel or Esc (false).
    func run(over selection: CaptureSelection) async -> Bool {
        guard continuation == nil, let area = selection.area else { return false }
        return await withCheckedContinuation { continuation in
            self.continuation = continuation
            outline.show(selection)
            showBar(
                under: area.offsetBy(dx: selection.screenFrame.minX, dy: selection.screenFrame.minY),
                on: selection.screenFrame)
        }
    }

    private func showBar(under area: CGRect, on screen: CGRect) {
        let bar = GlassBar(
            items: [
                .init(
                    icon: .check, title: "Done", shortcut: nil, toolTip: "Finish (↩)",
                    perform: { [weak self] in self?.finish(true) })
            ], closeToolTip: "Cancel (Esc)", close: { [weak self] in self?.finish(false) })
        let origin = ScreenGeometry.barOrigin(
            for: bar.frame.size, under: area, in: screen, gap: Config.Bar.selectionGap,
            inset: Config.Style.barBottomOffset, centred: true)
        let panel = ScrollBarPanel(frame: CGRect(origin: origin, size: bar.frame.size))
        panel.contentView = bar
        panel.onKey = { [weak self] isDone in self?.finish(isDone) }
        panel.orderFrontRegardless()
        panel.makeKey()
        self.panel = panel
    }

    private func finish(_ isDone: Bool) {
        outline.hide()
        panel?.orderOut(nil)
        panel = nil
        continuation?.resume(returning: isDone)
        continuation = nil
    }
}

/// The floating bar's window: takes Return and Esc without taking focus from the app being scrolled.
private final class ScrollBarPanel: NSPanel {
    var onKey: (@MainActor (Bool) -> Void)?

    init(frame: CGRect) {
        super.init(contentRect: frame, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        level = .statusBar
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        hidesOnDeactivate = false
        isReleasedWhenClosed = false
        animationBehavior = .none
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
    }

    override var canBecomeKey: Bool { true }

    override func keyDown(with event: NSEvent) {
        switch Int(event.keyCode) {
        case kVK_Return, kVK_ANSI_KeypadEnter: onKey?(true)
        case kVK_Escape: onKey?(false)
        default: super.keyDown(with: event)
        }
    }
}
