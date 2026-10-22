import CoreGraphics
import Testing

@testable import Frameless

@MainActor
struct PinBoardTests {
    private let screenFrame = CGRect(x: 1440, y: 0, width: 1920, height: 1080)

    @Test("a display pin covers the whole screen")
    func displayFrame() {
        let selection = CaptureSelection(displayID: 2, screenFrame: screenFrame, target: .display)
        #expect(PinBoard.frame(of: selection) == screenFrame)
    }

    @Test("an area pin sits where the area was on its screen")
    func areaFrame() {
        let area = CGRect(x: 100, y: 200, width: 300, height: 150)
        let selection = CaptureSelection(displayID: 2, screenFrame: screenFrame, target: .area(area))
        #expect(PinBoard.frame(of: selection) == CGRect(x: 1540, y: 200, width: 300, height: 150))
    }

    @Test("a window pin falls back to its screen once the window is gone")
    func missingWindowFrame() {
        let selection = CaptureSelection(displayID: 2, screenFrame: screenFrame, target: .window(0))
        #expect(PinBoard.frame(of: selection) == screenFrame)
    }
}
