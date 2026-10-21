import AppKit
import Carbon.HIToolbox
import Foundation
import Testing

@testable import Frameless

struct ShortcutTests {
    private func shortcut(_ keyCode: Int, _ modifiers: Shortcut.Modifiers) -> Shortcut {
        Shortcut(keyCode: UInt32(keyCode), modifiers: modifiers)
    }

    @Test("accepts shortcuts with command, control or option")
    func acceptsModifiedKeys() {
        #expect(shortcut(kVK_ANSI_2, [.shift, .command]).problem == nil)
        #expect(shortcut(kVK_ANSI_R, [.control, .option]).problem == nil)
        #expect(shortcut(kVK_F5, [.option]).problem == nil)
    }

    @Test("rejects bare keys and shift alone")
    func needsModifier() {
        #expect(shortcut(kVK_ANSI_A, []).problem == .needsModifier)
        #expect(shortcut(kVK_ANSI_A, [.shift]).problem == .needsModifier)
    }

    @Test("rejects the macOS screenshot shortcuts", arguments: [kVK_ANSI_3, kVK_ANSI_4, kVK_ANSI_5])
    func rejectsSystemScreenshots(keyCode: Int) {
        #expect(shortcut(keyCode, [.shift, .command]).problem == .reservedBySystem)
        #expect(shortcut(keyCode, [.control, .shift, .command]).problem == nil)
    }

    @Test("orders modifier symbols like macOS and names special keys")
    func displaysSpecialKeys() {
        #expect(shortcut(kVK_Return, [.command, .shift, .option, .control]).displayString == "⌃⌥⇧⌘↩")
        #expect(shortcut(kVK_Space, [.option]).displayString == "⌥Space")
        #expect(shortcut(kVK_F12, [.command]).displayString == "⌘F12")
    }

    @Test("converts key event flags and Carbon flags")
    func convertsModifiers() {
        let modifiers = Shortcut.Modifiers(NSEvent.ModifierFlags([.command, .shift, .capsLock]))
        #expect(modifiers == [.command, .shift])
        #expect(modifiers.carbonFlags == UInt32(cmdKey | shiftKey))
    }

    @Test("survives saving and loading")
    func roundTrips() throws {
        let original = shortcut(kVK_ANSI_2, [.shift, .command])
        let decoded = try JSONDecoder().decode(Shortcut.self, from: JSONEncoder().encode(original))
        #expect(decoded == original)
    }
}
