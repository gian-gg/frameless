import AppKit

/// Update checks: a daily quiet check, a manual one from the menu, and opening a newer release's page.
extension AppDelegate {
    func setUpUpdates() {
        updates.onChange = { [weak self] in self?.refreshMenu() }
        updates.schedule(preferences.checksForUpdates)
    }

    /// The newer release when one is out, otherwise a manual check.
    func updateItem() -> NSMenuItem {
        let item =
            if let release = updates.available {
                NSMenuItem(title: "Update to \(release.version)…", action: #selector(openRelease), keyEquivalent: "")
            } else {
                NSMenuItem(title: "Check for Updates…", action: #selector(checkForUpdates), keyEquivalent: "")
            }
        item.target = self
        return item
    }

    @objc func checkForUpdates() {
        Task {
            do {
                if try await updates.check() != nil { return openRelease() }
                let alert = NSAlert()
                alert.messageText = "Frameless is up to date"
                alert.informativeText = "Version \(UpdateChecker.currentVersion) is the latest."
                NSApp.activate()
                alert.runModal()
            } catch {
                showError("Couldn't check for updates", error)
            }
        }
    }

    @objc func openRelease() {
        guard let page = updates.available?.page else { return }
        NSWorkspace.shared.open(page)
    }

    @objc func toggleUpdateChecks(_ sender: NSMenuItem) {
        preferences.checksForUpdates.toggle()
        updates.schedule(preferences.checksForUpdates)
    }
}
