import AppKit
import ApplicationServices
import AVFoundation
import Combine

// MARK: - Permission Manager
// Centralised detection + quick-open handlers for every system permission
// Clippy might need. Written as small enum so UI can iterate over them.

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

    func check(_ permission: ClippyPermission) -> PermissionStatus {
        switch permission {
        case .accessibility:
            // AXIsProcessTrusted is synchronous; no prompt with this form.
            return AXIsProcessTrusted() ? .granted : .notDetermined

        case .screenRecording:
            if #available(macOS 10.15, *) {
                // CGPreflightScreenCaptureAccess returns whether access is granted
                // without triggering a prompt.
                return CGPreflightScreenCaptureAccess() ? .granted : .notDetermined
            }
            return .granted

        case .automation:
            // Automation per target app — no universal check. Treat as "not determined"
            // unless the user has clearly granted it to the target bundle. We surface a
            // helper button to open the pane regardless.
            return .notDetermined
        }
    }

    func request(_ permission: ClippyPermission) {
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
            openSystemSettings(for: .automation)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            self.refreshAll()
        }
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
