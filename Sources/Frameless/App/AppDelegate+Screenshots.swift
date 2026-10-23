import AppKit
import ScreenCaptureKit

/// Taking screenshots: picking, editing, then copying, saving or pinning the result.
extension AppDelegate {
    /// Saves a capture to the screenshots folder with the shutter sound and the thumbnail.
    func saveScreenshot(_ shot: CapturedImage) throws {
        let url = try Screenshotter.save(shot, in: saveFolder(for: .screenshot))
        playSound(.screenshot)
        thumbnail.show(url, on: NSScreen.screens.first { $0.displayID == shot.displayID })
    }

    /// Picks a display, area or window with the overlay, then captures it.
    @objc func takeScreenshot() {
        guard case .idle = state, hasScreenRecordingAccess() else { return }
        state = .busy
        let windowList = WindowList.snapshot()
        let frozen = FrozenScreens(
            displays: NSScreen.screens.compactMap(\.displayID), windows: windowList.windows.map(\.id))
        Task {
            defer {
                frozen.discard()
                showIdle()
            }
            guard let selection = await selector.select(for: .screenshot, windowList: windowList, frozen: frozen)
            else { return }
            defer { selector.dismiss() }
            let shot = await frozen.image(for: selection)
            frozen.discard()
            guard
                let choice = await editor.present(
                    selection, for: .screenshot, frozen: shot, onShown: { [selector] in selector.dismiss() })
            else {
                return
            }
            if choice.action == .scroll { return await scrollCapture(choice.selection) }
            do {
                let shot = try await Screenshotter.image(for: choice)
                switch choice.action {
                case .copy:
                    Screenshotter.copy(shot)
                    playSound(.screenshot)
                case .save:
                    try saveScreenshot(shot)
                case .pin:
                    pins.pin(shot, over: PinBoard.frame(of: choice.selection))
                    playSound(.screenshot)
                case .record, .scroll:
                    break
                }
            } catch let error as SCStreamError where error.code == .userDeclined {
                selector.dismiss()
                showPermissionAlert(.screenRecording)
            } catch {
                selector.dismiss()
                showError("Couldn't take screenshot", error)
            }
        }
    }

    /// Stitches a scrolling screenshot of the area and copies it.
    private func scrollCapture(_ selection: CaptureSelection) async {
        guard let tall = await scroller.run(over: selection) else { return }
        Screenshotter.copy(tall)
        playSound(.screenshot)
    }

    func hasScreenRecordingAccess() -> Bool {
        guard CGPreflightScreenCaptureAccess() || CGRequestScreenCaptureAccess() else {
            showPermissionAlert(.screenRecording)
            return false
        }
        return true
    }
}
