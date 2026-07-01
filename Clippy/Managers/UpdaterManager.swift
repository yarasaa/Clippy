import Foundation
import AppKit
import Combine
import UserNotifications
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
// Gentle reminders (this file's SPUStandardUserDriverDelegate conformance):
//   Clippy is a menu-bar agent (LSUIElement). When Sparkle finds an update
//   during a *background* check, throwing up a modal update sheet over
//   whatever the user is doing is jarring — and Sparkle now warns about
//   exactly this. Instead we:
//     1. Post a (provisional, non-intrusive) user notification.
//     2. Badge the menu-bar icon with a dot so there's a persistent cue
//        even if notifications are muted.
//   The loud modal sheet is reserved for *user-initiated* checks (Settings
//   → Check for Updates) and for when the user taps our notification.

extension Notification.Name {
    /// Posted when a background update becomes available — StatusBarController
    /// draws a badge dot on the menu-bar icon in response.
    static let clippyUpdateAvailable = Notification.Name("com.yarasa.Clippy.updateAvailable")
    /// Posted once the user has engaged with the update (or the session
    /// ended) — clears the menu-bar badge.
    static let clippyUpdateCleared = Notification.Name("com.yarasa.Clippy.updateCleared")
}

@MainActor
final class UpdaterManager: NSObject, ObservableObject {

    static let shared = UpdaterManager()

    /// IUO because `self` must be passed as the user-driver delegate, which
    /// requires the object to exist before the controller is created.
    private var controller: SPUStandardUpdaterController!

    private let updateNotificationID = "com.yarasa.Clippy.updateAvailableNotification"

    @Published private(set) var canCheckForUpdates = false
    @Published private(set) var lastCheckDate: Date?

    override init() {
        super.init()

        // startingUpdater: true — Sparkle begins scheduled checks as soon as
        // this object is created. We keep it alive for the app's lifetime.
        // userDriverDelegate: self — wires up the gentle-reminder behavior.
        self.controller = SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: nil,
            userDriverDelegate: self
        )

        // We handle taps on our own update notification.
        UNUserNotificationCenter.current().delegate = self

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

    // MARK: - Gentle reminder helpers

    private func postUpdateNotification(for update: SUAppcastItem) {
        let center = UNUserNotificationCenter.current()
        // Provisional authorization delivers quietly to Notification Center
        // with no upfront permission prompt — the textbook "gentle" path.
        center.requestAuthorization(options: [.alert, .sound, .provisional]) { granted, _ in
            guard granted else { return }
            let content = UNMutableNotificationContent()
            content.title = "Clippy update available"
            content.body = "Version \(update.displayVersionString) is ready to install."
            content.sound = nil
            let request = UNNotificationRequest(
                identifier: self.updateNotificationID,
                content: content,
                trigger: nil
            )
            center.add(request)
        }
        // Persistent visual cue on the menu-bar icon.
        NotificationCenter.default.post(name: .clippyUpdateAvailable, object: nil)
    }

    private func clearUpdateNotification() {
        UNUserNotificationCenter.current()
            .removeDeliveredNotifications(withIdentifiers: [updateNotificationID])
        NotificationCenter.default.post(name: .clippyUpdateCleared, object: nil)
    }
}

// MARK: - SPUStandardUserDriverDelegate (gentle reminders)

extension UpdaterManager: SPUStandardUserDriverDelegate {

    /// Tells Sparkle we want to manage scheduled (background) update
    /// reminders ourselves instead of letting it pop a modal sheet.
    nonisolated var supportsGentleScheduledUpdateReminders: Bool { true }

    /// For user-initiated checks `immediateFocus` is true → let Sparkle's
    /// standard driver show the update right away. For background checks
    /// it's false → we'll handle the gentle reminder in `willHandleShowingUpdate`.
    nonisolated func standardUserDriverShouldHandleShowingScheduledUpdate(
        _ update: SUAppcastItem,
        andInImmediateFocus immediateFocus: Bool
    ) -> Bool {
        return immediateFocus
    }

    /// Fires right before an update would be shown. When the check was a
    /// background one (`!state.userInitiated`) and the standard driver
    /// isn't taking over, we post our own gentle notification + badge.
    nonisolated func standardUserDriverWillHandleShowingUpdate(
        _ handleShowingUpdate: Bool,
        forUpdate update: SUAppcastItem,
        state: SPUUserUpdateState
    ) {
        guard !state.userInitiated else { return }
        Task { @MainActor in
            self.postUpdateNotification(for: update)
        }
    }

    /// The user engaged with the update (opened the sheet, etc.) — clear
    /// our gentle cues so they don't linger.
    nonisolated func standardUserDriverDidReceiveUserAttention(forUpdate update: SUAppcastItem) {
        Task { @MainActor in
            self.clearUpdateNotification()
        }
    }

    /// Update session finished (installed, dismissed, or skipped) — tidy up.
    nonisolated func standardUserDriverWillFinishUpdateSession() {
        Task { @MainActor in
            self.clearUpdateNotification()
        }
    }
}

// MARK: - UNUserNotificationCenterDelegate

extension UpdaterManager: UNUserNotificationCenterDelegate {

    /// Tapping the gentle notification brings the real update flow into
    /// focus — same as if the user had picked "Check for Updates".
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        if response.notification.request.identifier == updateNotificationID {
            Task { @MainActor in
                NSApp.activate(ignoringOtherApps: true)
                self.controller.checkForUpdates(NSApp)
            }
        }
        completionHandler()
    }

    /// Show the banner even while Clippy is the active app.
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .list])
    }
}
