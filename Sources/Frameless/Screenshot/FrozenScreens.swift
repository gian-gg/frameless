import ScreenCaptureKit

/// Every display and listed window, captured the moment a screenshot starts and held until it's done.
@MainActor
final class FrozenScreens {
    private var displays: [CGDirectDisplayID: Task<CapturedImage?, Never>] = [:]
    private var windows: [CGWindowID: Task<CapturedImage?, Never>] = [:]

    /// Starts capturing the displays and windows straight away, all at once.
    init(displays displayIDs: [CGDirectDisplayID], windows windowIDs: [CGWindowID]) {
        let content = Task {
            (try? await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)).map(Snapshot.init)
        }
        for id in displayIDs {
            displays[id] = Task {
                guard let snapshot = await content.value else { return nil }
                return try? await Screenshotter.captureDisplay(id, in: snapshot.content)
            }
        }
        for id in windowIDs {
            windows[id] = Task {
                guard let snapshot = await content.value else { return nil }
                return try? await Screenshotter.captureWindow(id, in: snapshot.content)
            }
        }
    }

    /// The frozen display, once its capture lands.
    func display(_ id: CGDirectDisplayID) async -> CapturedImage? {
        await displays[id]?.value
    }

    /// The frozen image a selection is cut from: its window's own capture, or its display's.
    func image(for selection: CaptureSelection) async -> CapturedImage? {
        if case .window(let id) = selection.target { return await windows[id]?.value }
        return await display(selection.displayID)
    }

    /// Drops every capture.
    func discard() {
        for task in displays.values { task.cancel() }
        for task in windows.values { task.cancel() }
        displays = [:]
        windows = [:]
    }
}

/// What's on screen at one moment, read-only once fetched, shared by all the captures.
private struct Snapshot: @unchecked Sendable {
    let content: SCShareableContent
}
