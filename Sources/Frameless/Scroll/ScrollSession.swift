import AppKit
import Carbon.HIToolbox

/// Scroll mode: the area stays outlined over the live screen, letting scrolls through to the app beneath, while each
/// frame is stitched into one tall image, previewed beside it; a small bar finishes or cancels.
@MainActor
final class ScrollSession {
    private let outline = AreaOutline()
    private let preview = ScrollPreview()
    private var panel: ScrollBarPanel?
    private var capture: ScrollCapture?
    private var continuation: CheckedContinuation<Bool, Never>?

    /// Runs until Done or Return, giving the stitched image, or Cancel or Esc, giving nil.
    func run(over selection: CaptureSelection) async -> CapturedImage? {
        guard continuation == nil, let area = selection.area else { return nil }
        let stitching = ScrollStitching()
        let globalArea = area.offsetBy(dx: selection.screenFrame.minX, dy: selection.screenFrame.minY)
        outline.show(selection)
        preview.show(beside: globalArea, on: selection.screenFrame)
        let capture = ScrollCapture { [weak self] frame in
            guard let update = stitching.add(frame) else { return }
            Task { @MainActor in self?.show(update) }
        }
        self.capture = capture
        let scale: CGFloat
        do {
            scale = try await capture.start(selection)
        } catch {
            end()
            return nil
        }
        let isDone = await withCheckedContinuation { continuation in
            self.continuation = continuation
            showBar(under: globalArea, on: selection.screenFrame)
        }
        await capture.stop()
        end()
        guard isDone, let image = stitching.image() else { return nil }
        return CapturedImage(image: image, scale: scale, displayID: selection.displayID)
    }

    private func show(_ update: ScrollStitching.Update) {
        switch update {
        case .image(let image): preview.update(image)
        case .lost: preview.showHint("Scroll back a little")
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
        continuation?.resume(returning: isDone)
        continuation = nil
    }

    private func end() {
        capture = nil
        outline.hide()
        preview.hide()
        panel?.orderOut(nil)
        panel = nil
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
        sharingType = .none
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
