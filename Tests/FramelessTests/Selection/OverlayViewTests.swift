import AppKit
import Testing

@testable import Frameless

@MainActor
struct OverlayViewTests {
    private let window = WindowInfo(
        id: 42, appName: "Safari", title: "Docs", frame: CGRect(x: 0, y: 0, width: 800, height: 600))

    @Test("a drag picks the area even over a highlighted window")
    func dragPicksArea() {
        let area = CGRect(x: 10, y: 10, width: 100, height: 80)
        #expect(OverlayView.target(area: area, window: window) == .area(area))
    }

    @Test("a click picks the window under the cursor")
    func clickPicksWindow() {
        #expect(OverlayView.target(area: nil, window: window) == .window(42))
    }

    @Test("a click on the empty desktop picks the display")
    func clickOnDesktopPicksDisplay() {
        #expect(OverlayView.target(area: nil, window: nil) == .display)
    }
}
