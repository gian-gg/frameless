import CoreGraphics
import Foundation
import Testing

@testable import Frameless

struct WindowListTests {
    private let ownPID: pid_t = 999

    private func description(
        id: UInt32, pid: pid_t = 1, layer: Int = 0, alpha: Double = 1,
        frame: CGRect = CGRect(x: 100, y: 50, width: 400, height: 300)
    ) -> [String: Any] {
        [
            kCGWindowNumber as String: NSNumber(value: id),
            kCGWindowOwnerPID as String: NSNumber(value: pid),
            kCGWindowLayer as String: NSNumber(value: layer),
            kCGWindowAlpha as String: NSNumber(value: alpha),
            kCGWindowBounds as String: frame.dictionaryRepresentation as NSDictionary,
            kCGWindowOwnerName as String: "Safari",
            kCGWindowName as String: "Docs",
        ]
    }

    @Test("parses a window and flips its frame to AppKit coordinates")
    func parsesWindow() {
        let list = WindowList(descriptions: [description(id: 7)], primaryScreenHeight: 1000, ownPID: ownPID)
        #expect(
            list.windows == [
                WindowInfo(
                    id: 7, appName: "Safari", title: "Docs", frame: CGRect(x: 100, y: 650, width: 400, height: 300))
            ])
    }

    @Test("skips own, system-layer, transparent and tiny windows")
    func skipsUnpickableWindows() {
        let descriptions = [
            description(id: 1, pid: ownPID),
            description(id: 2, layer: 25),
            description(id: 3, alpha: 0),
            description(id: 4, frame: CGRect(x: 0, y: 0, width: 20, height: 300)),
            description(id: 5),
        ]
        let list = WindowList(descriptions: descriptions, primaryScreenHeight: 1000, ownPID: ownPID)
        #expect(list.windows.map(\.id) == [5])
    }

    @Test("label joins app and title and shortens long names")
    func displayName() {
        let frame = CGRect(x: 0, y: 0, width: 100, height: 100)
        #expect(WindowInfo(id: 1, appName: "Finder", title: "", frame: frame).displayName == "Finder")
        #expect(WindowInfo(id: 1, appName: "Safari", title: "Docs", frame: frame).displayName == "Safari — Docs")
        let long = WindowInfo(id: 1, appName: "Safari", title: String(repeating: "x", count: 100), frame: frame)
        #expect(long.displayName.count == Config.Overlay.windowLabelLength)
        #expect(long.displayName.hasSuffix("…"))
    }

    @Test("picks the frontmost window under the point")
    func picksFrontmost() {
        let front = WindowInfo(id: 1, appName: "A", title: "", frame: CGRect(x: 0, y: 0, width: 100, height: 100))
        let back = WindowInfo(id: 2, appName: "B", title: "", frame: CGRect(x: 0, y: 0, width: 500, height: 500))
        let list = WindowList(windows: [front, back])
        #expect(list.window(at: CGPoint(x: 50, y: 50))?.id == 1)
        #expect(list.window(at: CGPoint(x: 300, y: 300))?.id == 2)
        #expect(list.window(at: CGPoint(x: 900, y: 900)) == nil)
    }
}
