import AppKit

/// Preferences ▸ Save To: choosing and showing where captures are saved.
extension AppDelegate {
    private static let sectionTitles: [CapturePurpose: String] = [.screenshot: "Screenshots", .recording: "Recordings"]

    func makeSaveLocationsMenu() -> NSMenu {
        let menu = NSMenu()
        for purpose in CapturePurpose.allCases {
            if purpose != CapturePurpose.allCases.first { menu.addItem(.separator()) }
            menu.addItem(.sectionHeader(title: Self.sectionTitles[purpose] ?? ""))
            let folder = shownFolder(for: purpose)
            let folderItem = saveLocationItem(Self.displayPath(folder), action: #selector(showSaveFolder(_:)), purpose)
            folderItem.image = NSWorkspace.shared.icon(for: .folder)
            folderItem.image?.size = NSSize(width: 16, height: 16)
            folderItem.toolTip = "Show in Finder"
            menu.addItem(folderItem)
            menu.addItem(saveLocationItem("Choose Folder…", action: #selector(chooseSaveFolder(_:)), purpose))
        }
        return menu
    }

    /// The chosen folder, or `<default>/Frameless`, without creating anything.
    private func shownFolder(for purpose: CapturePurpose) -> URL {
        preferences.saveFolder(for: purpose)
            ?? purpose.defaultSaveBase.appending(path: Config.Output.folderName, directoryHint: .isDirectory)
    }

    private func saveLocationItem(_ title: String, action: Selector, _ purpose: CapturePurpose) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: "")
        item.target = self
        item.representedObject = purpose
        return item
    }

    @objc private func showSaveFolder(_ sender: NSMenuItem) {
        guard let purpose = sender.representedObject as? CapturePurpose else { return }
        do {
            NSWorkspace.shared.open(try saveFolder(for: purpose))
        } catch {
            showError("Couldn't open the folder", error)
        }
    }

    @objc private func chooseSaveFolder(_ sender: NSMenuItem) {
        guard let purpose = sender.representedObject as? CapturePurpose else { return }
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = "Use Folder"
        panel.message = "Choose where to save \(Self.sectionTitles[purpose]?.lowercased() ?? "captures")"
        panel.directoryURL = shownFolder(for: purpose)
        NSApp.activate()
        guard panel.runModal() == .OK, let folder = panel.url else { return }
        preferences.setSaveFolder(folder, for: purpose)
        refreshMenu()
    }

    /// Rebuilds the menu so it reflects the current settings and pins.
    func refreshMenu() {
        menu = makeMenu()
        if case .idle = state { showIdle() }
    }

    /// The folder to save a capture in; alerts first when the chosen folder is gone.
    func saveFolder(for purpose: CapturePurpose) throws -> URL {
        let folder = try SaveFolder.resolve(
            chosen: preferences.saveFolder(for: purpose), defaultBase: purpose.defaultSaveBase)
        if folder.isFallback {
            showSaveFolderFallback(for: purpose, savingTo: folder.url)
        }
        return folder.url
    }

    private func showSaveFolderFallback(for purpose: CapturePurpose, savingTo folder: URL) {
        let chosen = preferences.saveFolder(for: purpose)?.lastPathComponent ?? "chosen"
        let alert = NSAlert()
        alert.messageText = "The \(chosen) folder isn't available"
        alert.informativeText =
            "Saving this \(purpose.noun) to \(Self.displayPath(folder)) instead. "
            + "Choose another folder in Preferences ▸ Save To."
        NSApp.activate()
        alert.runModal()
    }

    /// A folder path with the home folder shortened to ~.
    static func displayPath(_ folder: URL) -> String {
        (folder.path(percentEncoded: false) as NSString).abbreviatingWithTildeInPath
    }
}
