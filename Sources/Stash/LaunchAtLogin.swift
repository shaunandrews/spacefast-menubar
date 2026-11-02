import Foundation
import ServiceManagement

/// Opens Stash at login. On by default: a menu bar app that's gone after a
/// restart looks like it quit or broke. Settings › Open at Login turns it off.
@MainActor
enum LaunchAtLogin {
    static var isEnabled: Bool { SMAppService.mainApp.status == .enabled }

    static func set(_ enabled: Bool) {
        do {
            if enabled { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
        } catch {
            NSLog("Stash: couldn't change Open at Login: \(error)")
        }
    }

    /// Once, on the first launch; after that it's the user's choice.
    static func enableOnFirstLaunch() {
        let key = "launchAtLoginDefaulted"
        guard !UserDefaults.standard.bool(forKey: key) else { return }
        UserDefaults.standard.set(true, forKey: key)
        set(true)
    }
}
