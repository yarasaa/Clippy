import AppKit
import ApplicationServices
import AVFoundation
import Combine

// MARK: - Permission Manager
// Centralised detection + quick-open handlers for every system permission
// Clippy might need. Written as small enum so UI can iterate over them.

extension Notification.Name {
    /// Fired when a permission the user was sent to grant becomes granted.
    /// userInfo: ["permission": ClippyPermission.rawValue]
    static let clippyPermissionGranted = Notification.Name("com.yarasa.Clippy.permissionGranted")
}

enum ClippyPermission: String, CaseIterable, Identifiable {
    case accessibility
    case screenRecording
    case automation

    var id: String { rawValue }

    var title: String {
        switch self {
        case .accessibility:    return "Accessibility"
        case .screenRecording:  return "Screen Recording"
        case .automation:       return "Automation"
        }
    }

    var rationale: String {
        switch self {
        case .accessibility:
            return "Required for global hotkeys, keyword expansion, Dock Preview, and paste-into-active-app."
        case .screenRecording:
            return "Required for live window previews in Dock Preview. Not needed if you only use static thumbnails."
        case .automation:
            return "Required so Clippy can paste into other apps via Apple Events."
        }
    }

    var icon: String {
        switch self {
        case .accessibility:    return "accessibility"
        case .screenRecording:  return "rectangle.on.rectangle"
        case .automation:       return "gearshape.2"
        }
    }

    var settingsURLString: String {
        switch self {
        case .accessibility:
            return "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
        case .screenRecording:
            return "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture"
        case .automation:
            return "x-apple.systempreferences:com.apple.preference.security?Privacy_Automation"
        }
    }

    /// Required = app does not work without it. Optional = degraded experience.
    var isRequired: Bool {
        switch self {
        case .accessibility: return true
        case .screenRecording: return false
        case .automation: return false
        }
    }
}

enum PermissionStatus {
    case granted
    case denied
    case notDetermined

    var label: String {
        switch self {
        case .granted:       return "Granted"
        case .denied:        return "Denied"
        case .notDetermined: return "Not asked"
        }
    }
}

@MainActor
final class PermissionManager: ObservableObject {

    static let shared = PermissionManager()

    @Published private(set) var statuses: [ClippyPermission: PermissionStatus] = [:]

    private init() {
        refreshAll()
    }

    func refreshAll() {
        for permission in ClippyPermission.allCases {
            statuses[permission] = check(permission)
        }
    }

    /// True once we've fired the one-and-only system prompt for this
    /// permission. macOS shows that dialog a single time per app: after the
    /// user dismisses or denies it, calling the API again does nothing at
    /// all. Remembering that we already asked is what lets us switch to
    /// "open System Settings" instead of silently doing nothing.
    private func hasPrompted(_ permission: ClippyPermission) -> Bool {
        UserDefaults.standard.bool(forKey: "permissionPrompted.\(permission.rawValue)")
    }

    private func markPrompted(_ permission: ClippyPermission) {
        UserDefaults.standard.set(true, forKey: "permissionPrompted.\(permission.rawValue)")
    }

    func isGranted(_ permission: ClippyPermission) -> Bool {
        switch permission {
        case .accessibility:
            return AXIsProcessTrusted()
        case .screenRecording:
            if #available(macOS 10.15, *) { return CGPreflightScreenCaptureAccess() }
            return true
        case .automation:
            // No universal API to query Automation; it's per target app.
            return false
        }
    }

    func check(_ permission: ClippyPermission) -> PermissionStatus {
        if isGranted(permission) { return .granted }
        // Previously `.denied` was never returned, so a refused permission
        // kept showing as "Not asked" with a Request button that could no
        // longer do anything.
        return hasPrompted(permission) ? .denied : .notDetermined
    }

    /// Ask for a permission the right way for whatever state we're in.
    ///
    /// First time: fire the real system prompt. Every time after that the
    /// OS will never show it again, so the only honest thing left is to
    /// take the user to the exact System Settings pane.
    func request(_ permission: ClippyPermission) {
        guard !isGranted(permission) else { return }

        // Make the platform call EVERY time, not only the first.
        //
        // `AXIsProcessTrustedWithOptions(prompt:)` does more than show a
        // dialog: it registers the app in the Accessibility list, so all the
        // user has to do is flip its switch. Gating it behind `hasPrompted`
        // sent anyone who had been asked before to a System Settings pane
        // where Clippy wasn't listed at all, leaving them to add it by hand
        // with the + button.
        //
        // The flag lives in UserDefaults, which is keyed by bundle id, while
        // TCC tracks the actual binary. A rebuilt or reinstalled copy
        // therefore inherits "already prompted" while being unknown to the
        // system — and could never register itself again. Both calls below
        // are idempotent, so making them unconditionally costs nothing.
        switch permission {
        case .accessibility:
            let options: [String: Bool] = [
                kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true
            ]
            _ = AXIsProcessTrustedWithOptions(options as CFDictionary)
        case .screenRecording:
            if #available(macOS 10.15, *) {
                _ = CGRequestScreenCaptureAccess()
            }
        case .automation:
            // No request API exists for this one, so System Settings is the
            // only route — and it's the only case where we open it ourselves.
            openSystemSettings(for: permission)
        }

        // Deliberately NOT opening System Settings for the other two.
        //
        // macOS's own dialog already carries an "Open System Settings"
        // button, so doing it here too meant the dialog and the Settings
        // window arrived on top of each other — two prompts for one action.
        // Where the system stays silent, the Permissions pane still offers an
        // explicit way through.

        markPrompted(permission)
        startWatching(permission)
    }

    // MARK: - Live re-check

    private var watchers: [ClippyPermission: Timer] = [:]

    /// Polls until the permission is granted (or we give up), so a feature
    /// lights up the moment the user flips the switch in System Settings —
    /// without needing to relaunch Clippy. Accessibility in particular has
    /// no notification we can subscribe to.
    func startWatching(_ permission: ClippyPermission, timeout: TimeInterval = 120) {
        watchers[permission]?.invalidate()
        let deadline = Date().addingTimeInterval(timeout)

        let timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] timer in
            Task { @MainActor in
                guard let self else { timer.invalidate(); return }
                if self.isGranted(permission) || Date() >= deadline {
                    timer.invalidate()
                    self.watchers[permission] = nil
                    self.refreshAll()
                    if self.isGranted(permission) {
                        NotificationCenter.default.post(
                            name: .clippyPermissionGranted, object: nil,
                            userInfo: ["permission": permission.rawValue]
                        )
                    }
                }
            }
        }
        watchers[permission] = timer
    }

    func openSystemSettings(for permission: ClippyPermission) {
        if let url = URL(string: permission.settingsURLString) {
            NSWorkspace.shared.open(url)
        }
    }

    /// Runs `tccutil reset All <bundle-id>` — the same trick developers use in Terminal.
    /// Most commonly needed after reinstalling a differently-signed build when macOS
    /// keeps an orphaned permission entry around.
    func resetAllPermissions() {
        guard let bundleID = Bundle.main.bundleIdentifier else { return }

        // tccutil wipes the system's record, so our "already prompted"
        // flags must go too — otherwise we'd keep sending the user to
        // System Settings when macOS is once again willing to show the
        // real prompt.
        for permission in ClippyPermission.allCases {
            UserDefaults.standard.removeObject(forKey: "permissionPrompted.\(permission.rawValue)")
        }

        let process = Process()
        process.launchPath = "/usr/bin/tccutil"
        process.arguments = ["reset", "All", bundleID]
        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            // If launch fails (rare), guide the user to do it manually.
            let alert = NSAlert()
            alert.messageText = "Couldn't reset permissions automatically"
            alert.informativeText = "Run this in Terminal:\n\ntccutil reset All \(bundleID)"
            alert.addButton(withTitle: "OK")
            alert.runModal()
        }
        refreshAll()
    }
}
