import AVFoundation
import AppKit
import ScreenCaptureKit

/// Owns the menu bar item, its menu and the recording lifecycle.
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private enum State {
        case idle
        case busy
        case recording(since: Date)
    }

    private enum Permission {
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

    private let preferences = Preferences()
    private let recorder = Recorder()
    private let selector = AreaSelector()
    private let outline = AreaOutline()
    private var state = State.idle
    private var statusItem: NSStatusItem?
    private var menu: NSMenu?
    private let recordingMenu = NSMenu()
    private let elapsedItem = NSMenuItem(title: "", action: nil, keyEquivalent: "")
    private var timer: Timer?

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        menu = makeMenu()
        buildRecordingMenu()
        recorder.onUnexpectedStop = { [weak self] error in
            self?.showIdle()
            self?.showError("Recording stopped", error)
        }
        showIdle()
    }

    /// Menu shown while recording: elapsed time, stop and discard.
    private func buildRecordingMenu() {
        recordingMenu.delegate = self
        recordingMenu.addItem(elapsedItem)
        recordingMenu.addItem(.separator())
        recordingMenu.addItem(withTitle: "Stop and Save", action: #selector(stopRecording), keyEquivalent: "\r")
            .target = self
        recordingMenu.addItem(withTitle: "Discard Recording", action: #selector(discardRecording), keyEquivalent: "")
            .target = self
    }

    func makeMenu() -> NSMenu {
        let menu = NSMenu()
        menu.addItem(withTitle: "Record Screen", action: #selector(startRecording), keyEquivalent: "").target = self
        menu.addItem(.separator())
        menu.addItem(withTitle: "Preferences", action: nil, keyEquivalent: "").submenu = makePreferencesMenu()
        menu.addItem(.separator())
        menu.addItem(withTitle: "Quit Frameless", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        return menu
    }

    private func makePreferencesMenu() -> NSMenu {
        let menu = NSMenu()
        menu.addItem(toggleItem("System Audio", \.capturesSystemAudio))
        menu.addItem(toggleItem("Microphone", \.capturesMicrophone, action: #selector(toggleMicrophone(_:))))
        menu.addItem(toggleItem("Show Cursor", \.showsCursor))
        menu.addItem(.separator())
        menu.addItem(withTitle: "Quality", action: nil, keyEquivalent: "").submenu = makeQualityMenu()
        menu.addItem(withTitle: "Frame Rate", action: nil, keyEquivalent: "").submenu = choiceMenu(
            FrameRate.allCases, title: \.title, action: #selector(selectFrameRate(_:)))
        menu.addItem(.separator())
        menu.addItem(withTitle: "Launch at Login", action: #selector(toggleLaunchAtLogin), keyEquivalent: "")
            .target = self
        return menu
    }

    private func makeQualityMenu() -> NSMenu {
        let menu = NSMenu()
        menu.addItem(.sectionHeader(title: "Codec"))
        choiceItems(VideoCodec.allCases, title: \.title, action: #selector(selectCodec(_:))).forEach(menu.addItem)
        menu.addItem(.separator())
        menu.addItem(.sectionHeader(title: "Resolution"))
        choiceItems(Resolution.allCases, title: \.title, action: #selector(selectResolution(_:))).forEach(menu.addItem)
        return menu
    }

    private func choiceMenu<Choice>(_ choices: [Choice], title: (Choice) -> String, action: Selector) -> NSMenu {
        let menu = NSMenu()
        choiceItems(choices, title: title, action: action).forEach(menu.addItem)
        return menu
    }

    private func choiceItems<Choice>(
        _ choices: [Choice], title: (Choice) -> String, action: Selector
    ) -> [NSMenuItem] {
        choices.map { choice in
            let item = NSMenuItem(title: title(choice), action: action, keyEquivalent: "")
            item.target = self
            item.representedObject = choice
            return item
        }
    }

    @objc private func selectResolution(_ sender: NSMenuItem) {
        guard let resolution = sender.representedObject as? Resolution else { return }
        preferences.resolution = resolution
    }

    @objc private func selectCodec(_ sender: NSMenuItem) {
        guard let codec = sender.representedObject as? VideoCodec else { return }
        preferences.videoCodec = codec
    }

    @objc private func selectFrameRate(_ sender: NSMenuItem) {
        guard let frameRate = sender.representedObject as? FrameRate else { return }
        preferences.frameRate = frameRate
    }

    @objc private func toggleLaunchAtLogin() {
        do {
            try LaunchAtLogin.toggle()
        } catch {
            showError("Couldn't change Launch at Login", error)
        }
    }

    private func toggleItem(
        _ title: String, _ keyPath: ReferenceWritableKeyPath<Preferences, Bool>,
        action: Selector = #selector(toggle(_:))
    ) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: "")
        item.target = self
        item.representedObject = keyPath
        return item
    }

    @objc private func toggle(_ sender: NSMenuItem) {
        guard let keyPath = sender.representedObject as? ReferenceWritableKeyPath<Preferences, Bool> else { return }
        preferences[keyPath: keyPath].toggle()
    }

    @objc private func toggleMicrophone(_ sender: NSMenuItem) {
        guard !preferences.capturesMicrophone else {
            preferences.capturesMicrophone = false
            return
        }
        Task {
            guard await AVCaptureDevice.requestAccess(for: .audio) else { return showPermissionAlert(.microphone) }
            preferences.capturesMicrophone = true
        }
    }

    @objc private func startRecording() {
        guard case .idle = state else { return }
        guard CGPreflightScreenCaptureAccess() || CGRequestScreenCaptureAccess() else {
            showPermissionAlert(.screenRecording)
            return
        }
        if preferences.capturesMicrophone, AVCaptureDevice.authorizationStatus(for: .audio) != .authorized {
            preferences.capturesMicrophone = false
            showPermissionAlert(.microphone)
            return
        }
        state = .busy
        Task {
            guard let selection = await selector.select() else { return showIdle() }
            do {
                let url = try RecordingFile.directory().appending(path: RecordingFile.name(for: .now))
                try await recorder.start(selection, options: preferences.recordingOptions, to: url)
                outline.show(selection)
                showRecording(since: .now)
            } catch let error as SCStreamError where error.code == .userDeclined {
                showIdle()
                showPermissionAlert(.screenRecording)
            } catch {
                showIdle()
                showError("Couldn't start recording", error)
            }
        }
    }

    @objc private func stopRecording() {
        finishRecording(saving: true)
    }

    @objc private func discardRecording() {
        finishRecording(saving: false)
    }

    /// Stops the recording, then copies the file to the clipboard or deletes it.
    private func finishRecording(saving: Bool) {
        guard case .recording = state else { return }
        state = .busy
        outline.hide()
        Task {
            do {
                let url = try await recorder.stop()
                if saving {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.writeObjects([url as NSURL])
                } else {
                    try FileManager.default.removeItem(at: url)
                }
                showIdle()
            } catch {
                showIdle()
                showError(saving ? "Couldn't save recording" : "Couldn't discard recording", error)
            }
        }
    }

    private func showIdle() {
        state = .idle
        timer?.invalidate()
        timer = nil
        outline.hide()
        guard let statusItem else { return }
        statusItem.button?.image = NSImage(
            systemSymbolName: Config.StatusItem.symbolName, accessibilityDescription: "Frameless")
        statusItem.menu = menu
    }

    private func showRecording(since start: Date) {
        state = .recording(since: start)
        guard let statusItem else { return }
        let red = NSImage.SymbolConfiguration(paletteColors: [.systemRed])
        statusItem.button?.image = NSImage(
            systemSymbolName: Config.StatusItem.recordingSymbolName, accessibilityDescription: "Recording"
        )?.withSymbolConfiguration(red)
        statusItem.menu = recordingMenu
    }

    private func updateElapsed() {
        guard case .recording(let start) = state else { return }
        let font = NSFont.monospacedDigitSystemFont(ofSize: NSFont.systemFontSize, weight: .regular)
        elapsedItem.attributedTitle = NSAttributedString(
            string: "Recording · " + RecordingFile.elapsed(Date.now.timeIntervalSince(start)),
            attributes: [.font: font, .foregroundColor: NSColor.secondaryLabelColor])
    }

    private func showError(_ message: String, _ error: Error) {
        let alert = NSAlert()
        alert.messageText = message
        alert.informativeText = error.localizedDescription
        NSApp.activate()
        alert.runModal()
    }

    private func showPermissionAlert(_ permission: Permission) {
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
}

extension AppDelegate: NSMenuDelegate {
    /// Ticks the elapsed time only while the recording menu is open.
    func menuWillOpen(_ menu: NSMenu) {
        guard menu === recordingMenu else { return }
        updateElapsed()
        let timer = Timer(timeInterval: Config.StatusItem.timerInterval, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.updateElapsed() }
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    func menuDidClose(_ menu: NSMenu) {
        guard menu === recordingMenu else { return }
        timer?.invalidate()
        timer = nil
    }
}

extension AppDelegate: NSMenuItemValidation {
    func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        if let keyPath = menuItem.representedObject as? ReferenceWritableKeyPath<Preferences, Bool> {
            menuItem.state = preferences[keyPath: keyPath] ? .on : .off
            return true
        }
        if let codec = menuItem.representedObject as? VideoCodec {
            menuItem.state = preferences.videoCodec == codec ? .on : .off
            return true
        }
        if let frameRate = menuItem.representedObject as? FrameRate {
            menuItem.state = preferences.frameRate == frameRate ? .on : .off
            return true
        }
        if let resolution = menuItem.representedObject as? Resolution {
            menuItem.state = preferences.resolution == resolution ? .on : .off
            return true
        }
        if menuItem.action == #selector(toggleLaunchAtLogin) {
            menuItem.state = LaunchAtLogin.isEnabled ? .on : .off
            return true
        }
        guard menuItem.action == #selector(startRecording) else { return true }
        if case .idle = state { return true }
        return false
    }
}
