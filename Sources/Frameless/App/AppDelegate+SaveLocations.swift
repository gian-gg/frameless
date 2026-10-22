import AppKit

extension AppDelegate {
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
