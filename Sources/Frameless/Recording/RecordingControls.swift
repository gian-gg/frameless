import AppKit

/// Stop and Discard under an area or window being recorded, anchored like the editor's bar; displays show nothing.
@MainActor
final class RecordingControls {
    private var panel: BarPanel?

    func show(
        for selection: CaptureSelection, onStop: @escaping @MainActor () -> Void,
        onDiscard: @escaping @MainActor () -> Void
    ) {
        hide()
        guard let region = Self.region(of: selection, windows: .snapshot()) else { return }
        let bar = GlassBar(
            items: [
                .init(icon: .circleStop, title: "Stop", shortcut: nil, toolTip: "Stop and save", perform: onStop)
            ], closeToolTip: "Discard recording", close: onDiscard)
        let origin = ScreenGeometry.barOrigin(
            for: bar.frame.size, under: region, in: selection.screenFrame, gap: Config.Bar.selectionGap,
            inset: Config.Style.barBottomOffset, centred: selection.area == nil)
        let panel = BarPanel(frame: CGRect(origin: origin, size: bar.frame.size))
        panel.contentView = bar
        panel.orderFrontRegardless()
        self.panel = panel
    }

    func hide() {
        panel?.orderOut(nil)
        panel = nil
    }

    /// The recorded rect in global AppKit points: the area, or the window's frame; nil for a whole display.
    static func region(of selection: CaptureSelection, windows: WindowList) -> CGRect? {
        switch selection.target {
        case .display:
            nil
        case .area(let area):
            area.offsetBy(dx: selection.screenFrame.minX, dy: selection.screenFrame.minY)
        case .window(let id):
            windows.windows.first { $0.id == id }?.frame
        }
    }
}
