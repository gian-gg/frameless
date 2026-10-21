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

    private let recorder = Recorder()
    private let selector = AreaSelector()
    private let outline = AreaOutline()
    private var state = State.idle
    private var statusItem: NSStatusItem?
    private var menu: NSMenu?
    private var timer: Timer?

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        menu = makeMenu()
        recorder.onUnexpectedStop = { [weak self] error in
            self?.showIdle()
            self?.showError("Recording stopped", error)
        }
        showIdle()
    }

    func makeMenu() -> NSMenu {
        let menu = NSMenu()
        menu.addItem(withTitle: "Record Screen", action: #selector(startRecording), keyEquivalent: "").target = self
        menu.addItem(.separator())
        menu.addItem(withTitle: "Quit Frameless", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        return menu
    }

    @objc private func startRecording() {
        guard case .idle = state else { return }
        guard CGPreflightScreenCaptureAccess() || CGRequestScreenCaptureAccess() else {
            showPermissionAlert()
            return
        }
        state = .busy
        Task {
            guard let selection = await selector.select() else { return showIdle() }
            do {
                let url = try RecordingFile.directory().appending(path: RecordingFile.name(for: .now))
                try await recorder.start(selection, to: url)
                outline.show(selection)
                showRecording(since: .now)
            } catch let error as SCStreamError where error.code == .userDeclined {
                showIdle()
                showPermissionAlert()
            } catch {
                showIdle()
                showError("Couldn't start recording", error)
            }
        }
    }

    @objc private func stopRecording() {
        guard case .recording = state else { return }
        state = .busy
        timer?.invalidate()
        timer = nil
        outline.hide()
        Task {
            do {
                let url = try await recorder.stop()
                NSPasteboard.general.clearContents()
                NSPasteboard.general.writeObjects([url as NSURL])
                showIdle()
            } catch {
                showIdle()
                showError("Couldn't save recording", error)
            }
        }
    }

    private func showIdle() {
        state = .idle
        timer?.invalidate()
        timer = nil
        outline.hide()
        guard let statusItem, let button = statusItem.button else { return }
        button.attributedTitle = NSAttributedString()
        button.image = NSImage(systemSymbolName: Config.StatusItem.symbolName, accessibilityDescription: "Frameless")
        button.target = nil
        button.action = nil
        statusItem.menu = menu
    }

    private func showRecording(since start: Date) {
        state = .recording(since: start)
        guard let statusItem, let button = statusItem.button else { return }
        statusItem.menu = nil
        button.image = nil
        button.target = self
        button.action = #selector(stopRecording)
        updateElapsed()
        let interval = Config.StatusItem.timerInterval
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.updateElapsed() }
        }
    }

    private func updateElapsed() {
        guard case .recording(let start) = state, let button = statusItem?.button else { return }
        let font = NSFont.monospacedDigitSystemFont(ofSize: NSFont.systemFontSize, weight: .regular)
        let title = NSMutableAttributedString(
            string: "● ", attributes: [.foregroundColor: NSColor.systemRed, .font: font])
        title.append(
            NSAttributedString(
                string: RecordingFile.elapsed(Date.now.timeIntervalSince(start)),
                attributes: [.font: font]))
        button.attributedTitle = title
    }

    private func showError(_ message: String, _ error: Error) {
        let alert = NSAlert()
        alert.messageText = message
        alert.informativeText = error.localizedDescription
        NSApp.activate()
        alert.runModal()
    }

    private func showPermissionAlert() {
        let alert = NSAlert()
        alert.messageText = "Frameless needs Screen Recording permission"
        alert.informativeText =
            "Turn on Frameless in System Settings › Privacy & Security › Screen & System Audio "
            + "Recording, then try again."
        alert.addButton(withTitle: "Open System Settings")
        alert.addButton(withTitle: "Cancel")
        NSApp.activate()
        if alert.runModal() == .alertFirstButtonReturn, let url = Config.Links.screenRecordingSettings {
            NSWorkspace.shared.open(url)
        }
    }
}

extension AppDelegate: NSMenuItemValidation {
    func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        guard menuItem.action == #selector(startRecording) else { return true }
        if case .idle = state { return true }
        return false
    }
}
