import AppKit

/// Screenshots pinned on screen as floating windows, until each is closed.
@MainActor
final class PinBoard {
    private var panels: [PinPanel] = []

    /// Floats the capture centred over `frame`, in global AppKit points, at its on-screen size.
    func pin(_ shot: CapturedImage, over frame: CGRect) {
        let size = CGSize(
            width: CGFloat(shot.image.width) / shot.scale, height: CGFloat(shot.image.height) / shot.scale)
        let origin = CGPoint(x: frame.midX - size.width / 2, y: frame.midY - size.height / 2)
        let panel = PinPanel(image: shot.image, frame: CGRect(origin: origin, size: size))
        panel.onClose = { [weak self, weak panel] in
            guard let panel else { return }
            self?.close(panel)
        }
        panels.append(panel)
        panel.orderFrontRegardless()
    }

    private func close(_ panel: PinPanel) {
        panel.orderOut(nil)
        panels.removeAll { $0 === panel }
    }

    /// Where a selection sits on screen, in global AppKit points.
    static func frame(of selection: CaptureSelection) -> CGRect {
        switch selection.target {
        case .display:
            return selection.screenFrame
        case .area(let area):
            return area.offsetBy(dx: selection.screenFrame.minX, dy: selection.screenFrame.minY)
        case .window(let id):
            let window = WindowList.snapshot().windows.first { $0.id == id }?.frame
            let onScreen = window?.intersection(selection.screenFrame) ?? .null
            return onScreen.isNull ? selection.screenFrame : onScreen
        }
    }
}
