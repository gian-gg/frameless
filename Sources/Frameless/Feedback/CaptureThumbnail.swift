import AppKit

/// Floating preview of the latest capture in the screen's bottom-right corner: click to open, drag to share.
@MainActor
final class CaptureThumbnail {
    private var panel: NSPanel?
    private var dismissTask: Task<Void, Never>?

    /// Loads a preview of the saved file and slides it in on the given screen.
    func show(_ url: URL, on screen: NSScreen?) {
        guard let screen = screen ?? NSScreen.main else { return }
        let box = Config.Feedback.thumbnailSize
        let maxPixelSize = Int(max(box.width, box.height) * screen.backingScaleFactor)
        Task {
            guard let image = await ThumbnailImage.load(from: url, maxPixelSize: maxPixelSize) else { return }
            present(image, for: url, on: screen)
        }
    }

    func hide() {
        dismissTask?.cancel()
        panel?.orderOut(nil)
        panel = nil
    }

    /// Aspect-fits a size into a box without enlarging it.
    nonisolated static func fittedSize(_ size: CGSize, within box: CGSize) -> CGSize {
        guard size.width > 0, size.height > 0 else { return .zero }
        let factor = min(box.width / size.width, box.height / size.height, 1)
        return CGSize(width: (size.width * factor).rounded(), height: (size.height * factor).rounded())
    }

    private func present(_ image: CGImage, for url: URL, on screen: NSScreen) {
        hide()
        let scale = screen.backingScaleFactor
        let pointSize = CGSize(width: CGFloat(image.width) / scale, height: CGFloat(image.height) / scale)
        let size = Self.fittedSize(pointSize, within: Config.Feedback.thumbnailSize)
        let margin = Config.Feedback.thumbnailMargin
        let rim = Config.Feedback.thumbnailRim
        let outer = CGSize(width: size.width + rim * 2, height: size.height + rim * 2)
        let frame = CGRect(
            x: screen.visibleFrame.maxX - outer.width - margin, y: screen.visibleFrame.minY + margin,
            width: outer.width, height: outer.height)

        let panel = NSPanel(
            contentRect: frame, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        panel.level = .floating
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        panel.sharingType = .none
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]

        let view = ThumbnailView(image: image, fileURL: url)
        view.onOpen = { [weak self] in
            NSWorkspace.shared.open(url)
            self?.hide()
        }
        view.onDismiss = { [weak self] in self?.hide() }
        view.onHoverChange = { [weak self] isHovering in
            if isHovering { self?.dismissTask?.cancel() } else { self?.scheduleDismiss() }
        }
        let glass = GlassPanel(frame: CGRect(origin: .zero, size: outer))
        glass.isCapsule = false
        view.frame = CGRect(x: rim, y: rim, width: size.width, height: size.height)
        glass.content.addSubview(view)
        panel.contentView = glass

        panel.alphaValue = 0
        panel.orderFrontRegardless()
        NSAnimationContext.runAnimationGroup { context in
            context.duration = Config.Feedback.thumbnailFadeDuration
            panel.animator().alphaValue = 1
        }
        self.panel = panel
        scheduleDismiss()
    }

    private func scheduleDismiss() {
        dismissTask?.cancel()
        dismissTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(Config.Feedback.thumbnailDuration))
            guard !Task.isCancelled else { return }
            self?.hide()
        }
    }
}

/// The preview itself: rounded image, glass play badge for recordings, glass close button on hover.
private final class ThumbnailView: NSView, NSDraggingSource {
    private static let dragThreshold: CGFloat = 4

    var onOpen: (@MainActor () -> Void)?
    var onDismiss: (@MainActor () -> Void)?
    var onHoverChange: (@MainActor (Bool) -> Void)?

    private let image: CGImage
    private let fileURL: URL
    private let closeControl = GlassPanel(
        frame: CGRect(x: 0, y: 0, width: Config.Feedback.closeSize, height: Config.Feedback.closeSize))
    private var mouseDownPoint: CGPoint?

    init(image: CGImage, fileURL: URL) {
        self.image = image
        self.fileURL = fileURL
        super.init(frame: .zero)
        wantsLayer = true
        layer?.contents = image
        layer?.contentsGravity = .resizeAspectFill
        layer?.cornerRadius = Config.Style.cornerRadius - Config.Feedback.thumbnailRim
        layer?.masksToBounds = true
        if fileURL.pathExtension == Config.Output.recordingExtension { addPlayBadge() }
        addCloseButton()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { nil }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    /// Glass circle with a play icon, marking a recording; clicks pass through to open it.
    private func addPlayBadge() {
        let side = Config.Feedback.badgeSize
        let badge = GlassPanel(frame: CGRect(x: 0, y: 0, width: side, height: side))
        let play = NSImageView(image: LucideIcon.play.image(size: side * 0.4, color: .labelColor, filled: true))
        play.imageScaling = .scaleNone
        play.frame = badge.bounds
        play.autoresizingMask = [.width, .height]
        badge.content.addSubview(play)
        pin(badge, size: side) {
            [
                $0.centerXAnchor.constraint(equalTo: centerXAnchor),
                $0.centerYAnchor.constraint(equalTo: centerYAnchor),
            ]
        }
    }

    /// Glass circle with ×, matching the bars' close button; shown on hover.
    private func addCloseButton() {
        let side = Config.Feedback.closeSize
        let button = BarButton(icon: .close, title: nil, toolTip: "Dismiss")
        button.target = self
        button.action = #selector(close)
        button.frame = closeControl.bounds
        button.autoresizingMask = [.width, .height]
        closeControl.content.addSubview(button)
        closeControl.isHidden = true
        let inset = Config.Feedback.thumbnailRim
        pin(closeControl, size: side) {
            [
                $0.topAnchor.constraint(equalTo: topAnchor, constant: inset),
                $0.leadingAnchor.constraint(equalTo: leadingAnchor, constant: inset),
            ]
        }
    }

    /// Adds a square subview of `size` with the given position constraints.
    private func pin(_ view: NSView, size: CGFloat, position: (NSView) -> [NSLayoutConstraint]) {
        view.translatesAutoresizingMaskIntoConstraints = false
        addSubview(view)
        NSLayoutConstraint.activate(
            [view.widthAnchor.constraint(equalToConstant: size), view.heightAnchor.constraint(equalToConstant: size)]
                + position(view))
    }

    @objc private func close() {
        onDismiss?()
    }

    // MARK: - Hover

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        trackingAreas.forEach(removeTrackingArea)
        addTrackingArea(
            NSTrackingArea(
                rect: .zero, options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect], owner: self))
    }

    override func mouseEntered(with event: NSEvent) {
        closeControl.isHidden = false
        onHoverChange?(true)
    }

    override func mouseExited(with event: NSEvent) {
        closeControl.isHidden = true
        onHoverChange?(false)
    }

    // MARK: - Click and drag

    override func mouseDown(with event: NSEvent) {
        mouseDownPoint = event.locationInWindow
    }

    override func mouseDragged(with event: NSEvent) {
        guard let start = mouseDownPoint else { return }
        let point = event.locationInWindow
        guard hypot(point.x - start.x, point.y - start.y) > Self.dragThreshold else { return }
        mouseDownPoint = nil
        let item = NSDraggingItem(pasteboardWriter: fileURL as NSURL)
        item.setDraggingFrame(bounds, contents: NSImage(cgImage: image, size: bounds.size))
        beginDraggingSession(with: [item], event: event, source: self)
    }

    override func mouseUp(with event: NSEvent) {
        guard mouseDownPoint != nil else { return }
        mouseDownPoint = nil
        onOpen?()
    }

    func draggingSession(
        _ session: NSDraggingSession, sourceOperationMaskFor context: NSDraggingContext
    ) -> NSDragOperation {
        .copy
    }

    func draggingSession(_ session: NSDraggingSession, endedAt screenPoint: NSPoint, operation: NSDragOperation) {
        if !operation.isEmpty { onDismiss?() }
    }
}
