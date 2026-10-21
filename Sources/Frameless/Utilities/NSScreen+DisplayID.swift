import AppKit

extension NSScreen {
    /// The Core Graphics display ID behind this screen.
    var displayID: CGDirectDisplayID? {
        deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID
    }
}
