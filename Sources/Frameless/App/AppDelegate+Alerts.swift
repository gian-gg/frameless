import AppKit

/// A system permission Frameless asks for, with where to grant it.
enum Permission {
    case screenRecording
    case microphone

    var name: String {
        switch self {
        case .screenRecording: "Screen Recording"
        case .microphone: "Microphone"
        }
    }

    var settingsPane: String {
        switch self {
        case .screenRecording: "Screen & System Audio Recording"
        case .microphone: "Microphone"
        }
    }

    var settingsURL: URL? {
        switch self {
        case .screenRecording: Config.Links.screenRecordingSettings
        case .microphone: Config.Links.microphoneSettings
        }
    }
}

extension AppDelegate {
    func showError(_ message: String, _ error: Error) {
        let alert = NSAlert()
        alert.messageText = message
        alert.informativeText = error.localizedDescription
        NSApp.activate()
        alert.runModal()
    }

    func showPermissionAlert(_ permission: Permission) {
        let alert = NSAlert()
        alert.messageText = "Frameless needs \(permission.name) permission"
        alert.informativeText =
            "Turn on Frameless in System Settings › Privacy & Security › \(permission.settingsPane), then try again."
        alert.addButton(withTitle: "Open System Settings")
        alert.addButton(withTitle: "Cancel")
        NSApp.activate()
        if alert.runModal() == .alertFirstButtonReturn, let url = permission.settingsURL {
            NSWorkspace.shared.open(url)
        }
    }

    /// Reports a recording that stopped unexpectedly and offers to show what was saved.
    func showRecordingStopped(_ reason: Error, savedAt url: URL) {
        let alert = NSAlert()
        alert.messageText = "Recording stopped unexpectedly"
        alert.informativeText =
            reason.localizedDescription + "\n\nWhat was recorded until then was saved and copied to the clipboard."
        alert.addButton(withTitle: "OK")
        alert.addButton(withTitle: "Show in Finder")
        NSApp.activate()
        if alert.runModal() == .alertSecondButtonReturn {
            NSWorkspace.shared.activateFileViewerSelecting([url])
        }
    }

    /// Asks before throwing away the recording in progress.
    func confirmDiscardRecording() -> Bool {
        let alert = NSAlert()
        alert.messageText = "Discard this recording?"
        alert.informativeText = "The recording will stop and won't be saved."
        alert.alertStyle = .warning
        let discard = alert.addButton(withTitle: "Discard")
        discard.hasDestructiveAction = true
        alert.addButton(withTitle: "Keep Recording")
        NSApp.activate()
        return alert.runModal() == .alertFirstButtonReturn
    }
}
