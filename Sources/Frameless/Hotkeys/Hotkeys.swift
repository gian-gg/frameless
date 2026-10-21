import Carbon.HIToolbox

/// Registers global shortcuts with Carbon and reports which action was pressed.
@MainActor
final class Hotkeys {
    /// What a global shortcut does.
    enum Action: UInt32, CaseIterable, Sendable {
        case screenshot = 1
        case record = 2
    }

    var onPress: (@MainActor (Action) -> Void)?

    /// "FRML", tagging our hotkeys among any others in the process.
    private static let signature: OSType = 0x4652_4D4C
    private var registered: [Action: EventHotKeyRef] = [:]
    private var handler: EventHandlerRef?

    init() {
        installHandler()
    }

    /// Registers or replaces an action's shortcut, or removes it when nil; false when macOS refuses it.
    @discardableResult
    func set(_ shortcut: Shortcut?, for action: Action) -> Bool {
        if let existing = registered.removeValue(forKey: action) { UnregisterEventHotKey(existing) }
        guard let shortcut else { return true }
        var reference: EventHotKeyRef?
        let status = RegisterEventHotKey(
            shortcut.keyCode, shortcut.modifiers.carbonFlags,
            EventHotKeyID(signature: Self.signature, id: action.rawValue),
            GetEventDispatcherTarget(), 0, &reference)
        guard status == noErr, let reference else { return false }
        registered[action] = reference
        return true
    }

    private func installHandler() {
        var pressed = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        let context = Unmanaged.passUnretained(self).toOpaque()
        InstallEventHandler(
            GetEventDispatcherTarget(),
            { _, event, context in
                guard let event, let context else { return OSStatus(eventNotHandledErr) }
                var hotKeyID = EventHotKeyID()
                let status = GetEventParameter(
                    event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID), nil,
                    MemoryLayout<EventHotKeyID>.size, nil, &hotKeyID)
                guard status == noErr, hotKeyID.signature == Hotkeys.signature,
                    let action = Action(rawValue: hotKeyID.id)
                else { return OSStatus(eventNotHandledErr) }
                MainActor.assumeIsolated {
                    Unmanaged<Hotkeys>.fromOpaque(context).takeUnretainedValue().onPress?(action)
                }
                return noErr
            }, 1, &pressed, context, &handler)
    }
}
