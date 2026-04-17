import Foundation
import AppKit
import Combine
import Sparkle

// MARK: - UpdaterManager
//
// Thin wrapper around Sparkle's standard controller so SwiftUI views can:
//   • bind to `canCheckForUpdates` to enable/disable the menu item
//   • trigger a manual check via `checkForUpdates()`
//   • read `currentVersion` / `lastUpdateCheckDate` for the UI
//
// Sparkle itself is configured through Info.plist keys:
//   - SUFeedURL               → GitHub-hosted appcast.xml
//   - SUPublicEDKey           → EdDSA public key (private key signs each release)
//   - SUEnableAutomaticChecks → periodic background checks enabled
//   - SUScheduledCheckInterval = 86400 (every 24h)
//
// With those in place, Sparkle auto-fetches the feed, verifies the EdDSA
// signature of the downloaded DMG, and prompts the user with a native
// update sheet. We never have to write update logic ourselves.

@MainActor
final class UpdaterManager: NSObject, ObservableObject {

    static let shared = UpdaterManager()

    private let controller: SPUStandardUpdaterController

    @Published private(set) var canCheckForUpdates = false
    @Published private(set) var lastCheckDate: Date?

    override init() {
        // startingUpdater: true — Sparkle begins scheduled checks as soon as
        // this object is created. We keep it alive for the app's lifetime.
        self.controller = SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: nil,
            userDriverDelegate: nil
        )
        super.init()

        // Mirror Sparkle state into published properties so SwiftUI views update.
        controller.updater
            .publisher(for: \.canCheckForUpdates)
            .receive(on: DispatchQueue.main)
            .assign(to: &$canCheckForUpdates)

        // Seed once; Sparkle doesn't publish lastUpdateCheckDate changes,
        // so we poll whenever the user triggers a check.
        self.lastCheckDate = controller.updater.lastUpdateCheckDate
    }

    /// Manually triggered from the Settings UI. Shows Sparkle's native
    /// "Checking…" → "Up to date / Update available" sheet.
    ///
    /// The double-click bug this guards against: if the user hits the
    /// button while a background scheduled check is still in flight,
    /// Sparkle silently no-ops the first user-driven `checkForUpdates`
    /// call and only the second click actually surfaces the sheet.
    /// We explicitly use `checkForUpdates(_:)` with an AnyObject sender
    /// (the NSApp) which Sparkle treats as unambiguously user-initiated,
    /// and we fall through to `checkForUpdateInformation` if for any
    /// reason the updater isn't ready yet — so the user sees *something*
    /// on the first click.
    func checkForUpdates() {
        let updater = controller.updater

        if updater.canCheckForUpdates {
            controller.checkForUpdates(NSApp)
        } else {
            // Updater is mid-cycle or not yet ready — ask it to reload
            // feed state and try again on the next run loop tick. This
            // turns "two clicks needed" into a one-click experience.
            updater.checkForUpdateInformation()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { [weak self] in
                guard let self = self else { return }
                if self.controller.updater.canCheckForUpdates {
                    self.controller.checkForUpdates(NSApp)
                }
            }
        }

        // Refresh the cached check date on next run loop cycle.
        DispatchQueue.main.async {
            self.lastCheckDate = self.controller.updater.lastUpdateCheckDate
        }
    }

    var currentVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—"
    }

    var build: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "—"
    }

    var feedURL: String? {
        (Bundle.main.infoDictionary?["SUFeedURL"] as? String)
    }
}
