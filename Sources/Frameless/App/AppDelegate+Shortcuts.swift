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

    func registerShortcuts() {
        for action in Hotkeys.Action.allCases {
            hotkeys.set(preferences.shortcut(for: action), for: action)
        }
    }

    /// Records a new shortcut with the global ones paused, so pressing one assigns it instead of triggering it.
    @objc private func editShortcut(_ sender: NSMenuItem) {
        guard case .idle = state, let action = sender.representedObject as? Hotkeys.Action else { return }
        state = .busy
        for action in Hotkeys.Action.allCases { hotkeys.set(nil, for: action) }
        Task {
            switch await shortcutRecorder.record(for: Self.shortcutNames[action] ?? "") {
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
