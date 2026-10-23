import AppKit
import Carbon.HIToolbox

/// The finished scrolling screenshot in a glass card centred on its screen, scrollable when tall, with a bar to copy,
/// save or pin it, or close it.
@MainActor
final class ScrollResult {
    /// What to do with the image.
    enum Action {
        case copy
        case save
        case pin
    }

    private var panel: ScrollResultPanel?
    private var continuation: CheckedContinuation<Action?, Never>?

    /// Shows the image until an action is picked, giving it, or until it's closed, giving nil.
    func present(_ shot: CapturedImage, on screen: CGRect) async -> Action? {
        guard continuation == nil else { return nil }
        let bar = GlassBar(
            items: [
                .init(
                    icon: .copy, title: nil, shortcut: nil, toolTip: "Copy to the clipboard (⌘C)",
                    perform: { [weak self] in self?.finish(.copy) }),
                .init(
                    icon: .download, title: nil, shortcut: nil, toolTip: "Save (⌘S)",
                    perform: { [weak self] in self?.finish(.save) }),
                .init(
                    icon: .pin, title: nil, shortcut: nil, toolTip: "Pin on screen (⌘P)",
                    perform: { [weak self] in self?.finish(.pin) }),
            ], closeToolTip: "Close (Esc)", close: { [weak self] in self?.finish(nil) })
        let panel = ScrollResultPanel(shot: shot, bar: bar, on: screen)
        panel.onAction = { [weak self] action in self?.finish(action) }
        panel.orderFrontRegardless()
        panel.makeKey()
        self.panel = panel
        return await withCheckedContinuation { self.continuation = $0 }
    }

    private func finish(_ action: Action?) {
        panel?.orderOut(nil)
        panel = nil
        continuation?.resume(returning: action)
        continuation = nil
    }
}

/// The card and its bar in one window: takes the keys without taking focus from other apps.
private final class ScrollResultPanel: NSPanel {
    var onAction: (@MainActor (ScrollResult.Action?) -> Void)?

    init(shot: CapturedImage, bar: GlassBar, on screen: CGRect) {
        let rim = Config.Feedback.thumbnailRim
        let pointSize = CGSize(
            width: CGFloat(shot.image.width) / shot.scale, height: CGFloat(shot.image.height) / shot.scale)
        let imageWidth = min(pointSize.width, Config.Scroll.resultWidth)
        let imageHeight = (pointSize.height * imageWidth / pointSize.width).rounded()
        let gap = Config.Bar.selectionGap
        let tallest = screen.height * Config.Scroll.resultHeightShare - bar.frame.height - gap
        let card = CGSize(
            width: max(imageWidth, bar.frame.width) + rim * 2, height: min(imageHeight, tallest) + rim * 2)
        let size = CGSize(width: card.width, height: card.height + gap + bar.frame.height)
        let origin = CGPoint(x: (screen.midX - size.width / 2).rounded(), y: (screen.midY - size.height / 2).rounded())
        super.init(
            contentRect: CGRect(origin: origin, size: size), styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered, defer: false)
        level = .statusBar
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        hidesOnDeactivate = false
        isReleasedWhenClosed = false
        sharingType = .none
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]

        let content = NSView(frame: CGRect(origin: .zero, size: size))
        let glass = GlassPanel(frame: CGRect(x: 0, y: bar.frame.height + gap, width: card.width, height: card.height))
        glass.isCapsule = false
        let scroll = Self.scrollView(
            showing: shot.image, size: CGSize(width: imageWidth, height: imageHeight),
            frame: glass.bounds.insetBy(dx: rim, dy: rim))
        glass.content.addSubview(scroll)
        content.addSubview(glass)
        bar.setFrameOrigin(CGPoint(x: ((size.width - bar.frame.width) / 2).rounded(), y: 0))
        content.addSubview(bar)
        contentView = content
    }

    override var canBecomeKey: Bool { true }

    /// A scroll view over the image drawn at `size`, starting at its top.
    private static func scrollView(showing image: CGImage, size: CGSize, frame: CGRect) -> NSScrollView {
        let scroll = NSScrollView(frame: frame)
        scroll.drawsBackground = false
        scroll.hasVerticalScroller = size.height > frame.height
        scroll.autohidesScrollers = true
        scroll.scrollerStyle = .overlay
        let document = FlippedView(frame: CGRect(origin: .zero, size: CGSize(width: frame.width, height: size.height)))
        document.wantsLayer = true
        document.layer?.contents = image
        document.layer?.contentsGravity = .resizeAspect
        document.layer?.cornerRadius = Config.Style.cornerRadius
        document.layer?.masksToBounds = true
        scroll.documentView = document
        scroll.contentView.scroll(to: .zero)
        return scroll
    }

    override func keyDown(with event: NSEvent) {
        let modifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask).subtracting(.capsLock)
        switch (Int(event.keyCode), modifiers) {
        case (kVK_Return, []), (kVK_ANSI_KeypadEnter, []), (kVK_ANSI_C, .command): onAction?(.copy)
        case (kVK_ANSI_S, .command): onAction?(.save)
        case (kVK_ANSI_P, .command): onAction?(.pin)
        case (kVK_Escape, []): onAction?(nil)
        default: super.keyDown(with: event)
        }
    }

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        guard event.modifierFlags.contains(.command) else { return super.performKeyEquivalent(with: event) }
        keyDown(with: event)
        return true
    }
}

/// A view laid out from the top, so a tall image starts at its top edge.
private final class FlippedView: NSView {
    override var isFlipped: Bool { true }
}
