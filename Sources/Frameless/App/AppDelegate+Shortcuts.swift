import AppKit

/// Preferences ▸ Shortcuts: listing, recording and registering the global shortcuts.
extension AppDelegate {
    private static let shortcutNames: [Hotkeys.Action: String] = [
        .screenshot: "Take Screenshot", .record: "Record Screen",
    ]

    func makeShortcutsMenu() -> NSMenu {
        let menu = NSMenu()
        for action in Hotkeys.Action.allCases {
            let item = NSMenuItem(
                title: "\(Self.shortcutNames[action] ?? "")…", action: #selector(editShortcut(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = action
            if let shortcut = preferences.shortcut(for: action), let key = shortcut.menuKeyEquivalent {
                item.keyEquivalent = key
                item.keyEquivalentModifierMask = shortcut.menuModifierFlags
            }
            menu.addItem(item)
        }
        return menu
    }

    /// Registers every saved shortcut; returns the actions whose shortcut macOS refused.
    @discardableResult
    func registerShortcuts() -> [Hotkeys.Action] {
        Hotkeys.Action.allCases.filter { !hotkeys.set(preferences.shortcut(for: $0), for: $0) }
    }

    /// At launch: says which saved shortcuts another app has taken, and where to change them.
    func reportUnavailableShortcuts(_ actions: [Hotkeys.Action]) {
        guard !actions.isEmpty else { return }
        let list = actions.map {
            "\(preferences.shortcut(for: $0)?.displayString ?? "") (\(Self.shortcutNames[$0] ?? ""))"
        }
        let alert = NSAlert()
        alert.messageText = "Some Frameless shortcuts are in use by another app"
        alert.informativeText =
            "\(list.joined(separator: ", ")) won't work. Pick different ones in Preferences ▸ Shortcuts."
        NSApp.activate()
        alert.runModal()
    }

    /// Why a shortcut can't be used for an action: the basic rules, the other action, then other apps.
    private func reasonToReject(_ shortcut: Shortcut, for action: Hotkeys.Action) -> String? {
        if let problem = shortcut.problemDescription { return problem }
        if let other = Hotkeys.Action.allCases.first(where: {
            $0 != action && preferences.shortcut(for: $0) == shortcut
        }) {
            return "\(shortcut.displayString) is already \(Self.shortcutNames[other] ?? "taken")"
        }
        let isFree = hotkeys.set(shortcut, for: action)
        hotkeys.set(nil, for: action)
        return isFree ? nil : "\(shortcut.displayString) is used by another app"
    }

    /// Records a new shortcut with the global ones paused, so pressing one assigns it instead of triggering it.
    @objc private func editShortcut(_ sender: NSMenuItem) {
        guard case .idle = state, let action = sender.representedObject as? Hotkeys.Action else { return }
        state = .busy
        for action in Hotkeys.Action.allCases { hotkeys.set(nil, for: action) }
        Task {
            let outcome = await shortcutRecorder.record(for: Self.shortcutNames[action] ?? "") { [weak self] shortcut in
                self?.reasonToReject(shortcut, for: action)
            }
            switch outcome {
            case .set(let shortcut): preferences.setShortcut(shortcut, for: action)
            case .clear: preferences.setShortcut(nil, for: action)
            case .cancel: break
            }
            registerShortcuts()
            menu = makeMenu()
            showIdle()
        }
    }
}
