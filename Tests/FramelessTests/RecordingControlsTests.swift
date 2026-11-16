import AppKit
import Testing

@testable import Frameless

@MainActor
struct RecordingControlsTests {
    private let screen = CGRect(x: 1440, y: 0, width: 1920, height: 1080)
    private let windows = WindowList(windows: [
        WindowInfo(id: 7, appName: "Safari", title: "", frame: CGRect(x: 1600, y: 200, width: 800, height: 600))
    ])

    private func selection(_ target: CaptureSelection.Target) -> CaptureSelection {
        CaptureSelection(displayID: 1, screenFrame: screen, target: target)
    }

    @Test("a whole-display recording shows no controls")
    func displayHasNoRegion() {
        #expect(RecordingControls.region(of: selection(.display), windows: windows) == nil)
    }

    @Test("an area recording places the controls by the area on its screen")
    func areaRegionIsGlobal() {
        let region = RecordingControls.region(
            of: selection(.area(CGRect(x: 100, y: 50, width: 400, height: 300))), windows: windows)
        #expect(region == CGRect(x: 1540, y: 50, width: 400, height: 300))
    }

    @Test("a window recording places the controls by the window")
    func windowRegionIsItsFrame() {
        #expect(
            RecordingControls.region(of: selection(.window(7)), windows: windows)
                == CGRect(x: 1600, y: 200, width: 800, height: 600))
    }

    @Test("a window that has closed shows no controls")
    func missingWindowHasNoRegion() {
        #expect(RecordingControls.region(of: selection(.window(99)), windows: windows) == nil)
    }
}
