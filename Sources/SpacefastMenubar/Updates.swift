import AppKit
import Sparkle

/// In-app updates via Sparkle. The feed (`SUFeedURL`) and the EdDSA public key
/// (`SUPublicEDKey`) are in the Info.plist build.sh writes; releases are made
/// with release.sh. Sparkle checks once a day on its own.
@MainActor
final class Updates {
    static let shared = Updates()

    /// None while rendering the website's screenshots, which must never update.
    private let controller = Demo.isRendering ? nil : SPUStandardUpdaterController(
        startingUpdater: true, updaterDelegate: nil, userDriverDelegate: nil)

    func checkForUpdates() {
        NSApp.activate()
        controller?.checkForUpdates(nil)
    }

    /// "Version 0.2.0", for the settings menu.
    var versionLabel: String {
        "Version \(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?")"
    }
}
