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

    private let preferences = Preferences()
    private let recorder = Recorder()
    private let selector = AreaSelector()
    private let outline = AreaOutline()
    private let thumbnail = CaptureThumbnail()
    private let editor = SelectionEditor()
    private var recordingScreen: NSScreen?
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
        recorder.onEndedEarly = { [weak self] end in self?.recordingEndedEarly(end) }
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
        menu.addItem(withTitle: "Take Screenshot", action: #selector(takeScreenshot), keyEquivalent: "").target = self
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
            FrameRate.allCases, title: \.title, \.frameRate)
        menu.addItem(.separator())
        menu.addItem(toggleItem("Play Sounds", \.playsSounds))
        menu.addItem(withTitle: "Launch at Login", action: #selector(toggleLaunchAtLogin), keyEquivalent: "")
            .target = self
        return menu
    }

    private func makeQualityMenu() -> NSMenu {
        let menu = NSMenu()
        menu.addItem(.sectionHeader(title: "Codec"))
        choiceItems(VideoCodec.allCases, title: \.title, \.videoCodec).forEach(menu.addItem)
        menu.addItem(.separator())
        menu.addItem(.sectionHeader(title: "Resolution"))
        choiceItems(Resolution.allCases, title: \.title, \.resolution).forEach(menu.addItem)
        return menu
    }

    private func choiceMenu<Choice: Equatable>(
        _ choices: [Choice], title: (Choice) -> String, _ keyPath: ReferenceWritableKeyPath<Preferences, Choice>
    ) -> NSMenu {
        let menu = NSMenu()
        choiceItems(choices, title: title, keyPath).forEach(menu.addItem)
        return menu
    }

    /// One checkable item per choice, each setting the preference to its value.
    private func choiceItems<Choice: Equatable>(
        _ choices: [Choice], title: (Choice) -> String, _ keyPath: ReferenceWritableKeyPath<Preferences, Choice>
    ) -> [NSMenuItem] {
        choices.map { choice in
            preferenceItem(
                title(choice),
                PreferenceBinding(
                    isOn: { $0[keyPath: keyPath] == choice },
                    apply: { $0[keyPath: keyPath] = choice }))
        }
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
        action: Selector = #selector(applyPreference(_:))
    ) -> NSMenuItem {
        preferenceItem(
            title,
            PreferenceBinding(isOn: { $0[keyPath: keyPath] }, apply: { $0[keyPath: keyPath].toggle() }),
            action: action)
    }

    private func preferenceItem(
        _ title: String, _ binding: PreferenceBinding, action: Selector = #selector(applyPreference(_:))
    ) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: "")
        item.target = self
        item.representedObject = binding
        return item
    }

    @objc private func applyPreference(_ sender: NSMenuItem) {
        (sender.representedObject as? PreferenceBinding)?.apply(preferences)
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

    private func playSound(_ sound: CaptureSound) {
        if preferences.playsSounds { sound.play() }
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

}

// MARK: - Recording

extension AppDelegate {
    @objc private func startRecording() {
        guard case .idle = state, hasScreenRecordingAccess() else { return }
        if preferences.capturesMicrophone, AVCaptureDevice.authorizationStatus(for: .audio) != .authorized {
            preferences.capturesMicrophone = false
            showPermissionAlert(.microphone)
            return
        }
        state = .busy
        Task {
            guard let picked = await selector.select(for: .recording) else { return showIdle() }
            defer { selector.dismiss() }
            guard
                let choice = await editor.present(
                    picked, for: .recording, onShown: { [selector] in selector.dismiss() })
            else { return showIdle() }
            let selection = choice.selection
            do {
                let url = try RecordingFile.directory().appending(path: RecordingFile.name(for: .now))
                try await recorder.start(selection, options: preferences.recordingOptions, to: url)
                recordingScreen = NSScreen.screens.first { $0.displayID == selection.displayID }
                outline.show(selection)
                showRecording(since: .now)
                playSound(.recordingStarted)
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
                    recordingSaved(url)
                } else {
                    try FileManager.default.removeItem(at: url)
                }
                showIdle()
            } catch Recorder.RecorderError.alreadyStopping {
                // recordingEndedEarly resets the menu and reports the result.
            } catch {
                showIdle()
                showError(saving ? "Couldn't save recording" : "Couldn't discard recording", error)
            }
        }
    }

    /// A recording macOS ended by itself is saved like Stop and Save; only a lost file is reported.
    private func recordingEndedEarly(_ end: Recorder.EarlyEnd) {
        showIdle()
        switch end {
        case .saved(let url):
            recordingSaved(url)
        case .failed(let error):
            showError("Recording ended and couldn't be saved", error)
        }
    }

    /// Puts a saved recording on the clipboard and plays the saved sound.
    private func recordingSaved(_ url: URL) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.writeObjects([url as NSURL])
        playSound(.recordingSaved)
        thumbnail.show(url, on: recordingScreen)
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
}

// MARK: - Screenshots

extension AppDelegate {
    /// Picks a display, area or window with the overlay, then captures it.
    @objc private func takeScreenshot() {
        guard case .idle = state, hasScreenRecordingAccess() else { return }
        state = .busy
        Task {
            defer { showIdle() }
            guard let selection = await selector.select(for: .screenshot) else { return }
            defer { selector.dismiss() }
            guard
                let choice = await editor.present(
                    selection, for: .screenshot, onShown: { [selector] in selector.dismiss() })
            else {
                return
            }
            do {
                let shot = try await Screenshotter.captureImage(choice.selection)
                switch choice.action {
                case .copy:
                    Screenshotter.copy(shot)
                    playSound(.screenshot)
                case .save:
                    let url = try Screenshotter.save(shot)
                    playSound(.screenshot)
                    thumbnail.show(url, on: NSScreen.screens.first { $0.displayID == shot.displayID })
                case .record:
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

    private func hasScreenRecordingAccess() -> Bool {
        guard CGPreflightScreenCaptureAccess() || CGRequestScreenCaptureAccess() else {
            showPermissionAlert(.screenRecording)
            return false
        }
        return true
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
        if let binding = menuItem.representedObject as? PreferenceBinding {
            menuItem.state = binding.isOn(preferences) ? .on : .off
            return true
        }
        if menuItem.action == #selector(toggleLaunchAtLogin) {
            menuItem.state = LaunchAtLogin.isEnabled ? .on : .off
            return true
        }
        guard menuItem.action == #selector(startRecording) || menuItem.action == #selector(takeScreenshot) else {
            return true
        }
        if case .idle = state { return true }
        return false
    }
}
