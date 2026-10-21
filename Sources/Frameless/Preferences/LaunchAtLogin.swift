import ServiceManagement

/// Registers Frameless as a login item via SMAppService.
@MainActor
enum LaunchAtLogin {
    static var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    /// Flips the login item; opens Login Items settings when macOS needs the user to approve it.
    static func toggle() throws {
        let service = SMAppService.mainApp
        if service.status == .enabled {
            try service.unregister()
        } else {
            try service.register()
        }
        if service.status == .requiresApproval {
            SMAppService.openSystemSettingsLoginItems()
        }
    }
}
