import AppKit
import Carbon.HIToolbox

/// A global keyboard shortcut: a virtual key code plus modifiers.
struct Shortcut: Codable, Equatable, Sendable {
    struct Modifiers: OptionSet, Codable, Sendable {
        let rawValue: UInt32

        static let control = Modifiers(rawValue: 1 << 0)
        static let option = Modifiers(rawValue: 1 << 1)
        static let shift = Modifiers(rawValue: 1 << 2)
        static let command = Modifiers(rawValue: 1 << 3)

        init(rawValue: UInt32) {
            self.rawValue = rawValue
        }

        /// The modifiers held in a key event.
        init(_ flags: NSEvent.ModifierFlags) {
            var modifiers: Modifiers = []
            if flags.contains(.control) { modifiers.insert(.control) }
            if flags.contains(.option) { modifiers.insert(.option) }
            if flags.contains(.shift) { modifiers.insert(.shift) }
            if flags.contains(.command) { modifiers.insert(.command) }
            self = modifiers
        }

        /// The same modifiers as Carbon flags, for `RegisterEventHotKey`.
        var carbonFlags: UInt32 {
            var flags = 0
            if contains(.control) { flags |= controlKey }
            if contains(.option) { flags |= optionKey }
            if contains(.shift) { flags |= shiftKey }
            if contains(.command) { flags |= cmdKey }
            return UInt32(flags)
        }

        /// Symbols in macOS's order: ⌃⌥⇧⌘.
        var symbols: String {
            [(Modifiers.control, "⌃"), (.option, "⌥"), (.shift, "⇧"), (.command, "⌘")]
                .filter { contains($0.0) }
                .map(\.1)
                .joined()
        }
    }

    /// Why a shortcut can't be used globally.
    enum Problem: Equatable {
        /// Needs ⌘, ⌃ or ⌥, so it doesn't swallow ordinary typing.
        case needsModifier
        /// macOS keeps ⇧⌘3, ⇧⌘4 and ⇧⌘5 for its own screenshots.
        case reservedBySystem
    }

    let keyCode: UInt32
    let modifiers: Modifiers

    private static let systemScreenshotKeys: Set<Int> = [kVK_ANSI_3, kVK_ANSI_4, kVK_ANSI_5]

    /// Why this can't be used as a global shortcut, or nil if it can.
    var problem: Problem? {
        if modifiers.isDisjoint(with: [.command, .option, .control]) { return .needsModifier }
        if modifiers == [.shift, .command], Self.systemScreenshotKeys.contains(Int(keyCode)) {
            return .reservedBySystem
        }
        return nil
    }

    /// Modifiers then key, e.g. "⇧⌘2", with the key named by the current keyboard layout.
    var displayString: String {
        modifiers.symbols + Self.keyName(for: keyCode)
    }

    /// The key as an `NSMenuItem` key equivalent, so a menu shows the shortcut; nil when it has no character.
    var menuKeyEquivalent: String? {
        if let special = Self.menuSpecialKeys[Int(keyCode)] { return special }
        return Self.layoutCharacter(for: keyCode)?.lowercased()
    }

    /// The modifiers as an `NSMenuItem` modifier mask.
    var menuModifierFlags: NSEvent.ModifierFlags {
        var flags: NSEvent.ModifierFlags = []
        if modifiers.contains(.control) { flags.insert(.control) }
        if modifiers.contains(.option) { flags.insert(.option) }
        if modifiers.contains(.shift) { flags.insert(.shift) }
        if modifiers.contains(.command) { flags.insert(.command) }
        return flags
    }

    private static let menuSpecialKeys: [Int: String] = {
        var keys: [Int: String] = [
            kVK_Return: "\r", kVK_Tab: "\t", kVK_Space: " ", kVK_Delete: "\u{8}", kVK_Escape: "\u{1b}",
        ]
        let functionKeys: [(Int, Int)] = [
            (kVK_LeftArrow, NSLeftArrowFunctionKey), (kVK_RightArrow, NSRightArrowFunctionKey),
            (kVK_UpArrow, NSUpArrowFunctionKey), (kVK_DownArrow, NSDownArrowFunctionKey),
            (kVK_F1, NSF1FunctionKey), (kVK_F2, NSF2FunctionKey), (kVK_F3, NSF3FunctionKey), (kVK_F4, NSF4FunctionKey),
            (kVK_F5, NSF5FunctionKey), (kVK_F6, NSF6FunctionKey), (kVK_F7, NSF7FunctionKey), (kVK_F8, NSF8FunctionKey),
            (kVK_F9, NSF9FunctionKey), (kVK_F10, NSF10FunctionKey), (kVK_F11, NSF11FunctionKey),
            (kVK_F12, NSF12FunctionKey),
        ]
        for (keyCode, unicode) in functionKeys {
            if let scalar = UnicodeScalar(unicode) { keys[keyCode] = String(Character(scalar)) }
        }
        return keys
    }()

    private static let namedKeys: [Int: String] = [
        kVK_Return: "↩", kVK_Tab: "⇥", kVK_Space: "Space", kVK_Delete: "⌫", kVK_ForwardDelete: "⌦",
        kVK_Escape: "⎋", kVK_LeftArrow: "←", kVK_RightArrow: "→", kVK_UpArrow: "↑", kVK_DownArrow: "↓",
        kVK_Home: "↖", kVK_End: "↘", kVK_PageUp: "⇞", kVK_PageDown: "⇟",
        kVK_F1: "F1", kVK_F2: "F2", kVK_F3: "F3", kVK_F4: "F4", kVK_F5: "F5", kVK_F6: "F6",
        kVK_F7: "F7", kVK_F8: "F8", kVK_F9: "F9", kVK_F10: "F10", kVK_F11: "F11", kVK_F12: "F12",
    ]

    /// A key's name: a symbol for special keys, otherwise what the current layout types for it, uppercased.
    static func keyName(for keyCode: UInt32) -> String {
        if let name = namedKeys[Int(keyCode)] { return name }
        return layoutCharacter(for: keyCode)?.uppercased() ?? "#\(keyCode)"
    }

    private static func layoutCharacter(for keyCode: UInt32) -> String? {
        guard let source = TISCopyCurrentKeyboardLayoutInputSource()?.takeRetainedValue(),
            let pointer = TISGetInputSourceProperty(source, kTISPropertyUnicodeKeyLayoutData)
        else { return nil }
        let data = Unmanaged<CFData>.fromOpaque(pointer).takeUnretainedValue() as Data
        return data.withUnsafeBytes { buffer -> String? in
            guard let layout = buffer.bindMemory(to: UCKeyboardLayout.self).baseAddress else { return nil }
            var deadKeys: UInt32 = 0
            var length = 0
            var characters = [UniChar](repeating: 0, count: 4)
            let status = UCKeyTranslate(
                layout, UInt16(keyCode), UInt16(kUCKeyActionDisplay), 0, UInt32(LMGetKbdType()),
                OptionBits(kUCKeyTranslateNoDeadKeysBit), &deadKeys, characters.count, &length, &characters)
            guard status == noErr, length > 0 else { return nil }
            return String(utf16CodeUnits: characters, count: length)
        }
    }
}
