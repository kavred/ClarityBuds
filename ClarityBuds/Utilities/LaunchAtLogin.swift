import ServiceManagement

/// Manages the "Launch at Login" functionality using SMAppService (macOS 13+).
enum LaunchAtLoginManager {

    /// Whether the app is currently registered to launch at login.
    static var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    /// Enable or disable launch at login.
    /// - Parameter enabled: Whether to enable launch at login.
    /// - Returns: True if the operation succeeded.
    @discardableResult
    static func setEnabled(_ enabled: Bool) -> Bool {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
            return true
        } catch {
            print("LaunchAtLogin error: \(error.localizedDescription)")
            return false
        }
    }
}
