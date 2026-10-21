/// How a preference menu item reads and changes its setting.
@MainActor
final class PreferenceBinding {
    let isOn: @MainActor (Preferences) -> Bool
    let apply: @MainActor (Preferences) -> Void

    init(isOn: @escaping @MainActor (Preferences) -> Bool, apply: @escaping @MainActor (Preferences) -> Void) {
        self.isOn = isOn
        self.apply = apply
    }
}
