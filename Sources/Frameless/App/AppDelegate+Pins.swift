import AppKit

/// Pinned screenshots: copying and saving from a pin, and closing them all from the menu.
extension AppDelegate {
    func setUpPins() {
        pins.onCopy = { [weak self] shot in
            Screenshotter.copy(shot)
            self?.playSound(.screenshot)
        }
        pins.onSave = { [weak self] shot in
            do {
                try self?.saveScreenshot(shot)
            } catch {
                self?.showError("Couldn't save the screenshot", error)
            }
        }
        pins.onChange = { [weak self] in self?.refreshMenu() }
    }

    @objc func closeAllPins() {
        pins.closeAll()
    }
}
