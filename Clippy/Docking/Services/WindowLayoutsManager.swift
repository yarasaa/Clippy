import Foundation
import AppKit
import Combine

@MainActor
final class WindowLayoutsManager: ObservableObject {
    static let shared = WindowLayoutsManager()

    @Published var savedLayouts: [WindowLayout] = []

    private let layoutsKey = "windowLayouts"

    private init() {
        loadLayouts()
        print("📐 [WindowLayoutsManager] INIT: WindowLayoutsManager initialized with \(savedLayouts.count) layouts")
    }

    // MARK: - Public Methods

    func saveCurrentLayout(name: String) {
        let layout = captureCurrentLayout(name: name)
        savedLayouts.append(layout)
        persistLayouts()
        print("📐 [WindowLayoutsManager] Saved layout '\(name)' with \(layout.windows.count) windows")
    }

    func applyLayout(_ layout: WindowLayout) {
        print("📐 [WindowLayoutsManager] Applying layout '\(layout.name)' with \(layout.windows.count) windows")

        for windowState in layout.windows {
            // Find the window by bundle identifier
            guard let app = NSWorkspace.shared.runningApplications.first(where: { $0.bundleIdentifier == windowState.bundleIdentifier }),
                  let windowID = findWindowID(for: app.processIdentifier, title: windowState.title) else {
                print("⚠️ [WindowLayoutsManager] Could not find window for \(windowState.bundleIdentifier ?? "unknown") - \(windowState.title)")
                continue
            }

            // Move and resize window
            moveWindow(windowID: windowID, to: windowState.frame)
        }
    }

    func deleteLayout(id: UUID) {
        savedLayouts.removeAll { $0.id == id }
        persistLayouts()
        print("📐 [WindowLayoutsManager] Deleted layout \(id)")
    }

    // MARK: - Private Methods

    private func captureCurrentLayout(name: String) -> WindowLayout {
        let options: CGWindowListOption = [.optionOnScreenOnly, .excludeDesktopElements]
        guard let windowList = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]] else {
            return WindowLayout(name: name, windows: [])
        }

        var windowStates: [WindowState] = []

        for windowInfo in windowList {
            guard let windowPID = windowInfo[kCGWindowOwnerPID as String] as? pid_t,
                  let app = NSRunningApplication(processIdentifier: windowPID),
                  app.activationPolicy == .regular,
                  let title = windowInfo[kCGWindowName as String] as? String, !title.isEmpty,
                  let alpha = windowInfo[kCGWindowAlpha as String] as? CGFloat, alpha > 0,
                  let layer = windowInfo[kCGWindowLayer as String] as? Int, layer == 0,
                  let _ = windowInfo[kCGWindowNumber as String] as? CGWindowID,
                  let boundsDict = windowInfo[kCGWindowBounds as String] as? [String: Any],
                  let frame = CGRect(dictionaryRepresentation: boundsDict as CFDictionary) else {
                continue
            }

            let windowState = WindowState(
                bundleIdentifier: app.bundleIdentifier,
                title: title,
                frame: frame
            )
            windowStates.append(windowState)
        }

        return WindowLayout(name: name, windows: windowStates)
    }

    private func findWindowID(for pid: pid_t, title: String) -> CGWindowID? {
        let options: CGWindowListOption = [.optionOnScreenOnly, .excludeDesktopElements]
        guard let windowList = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]] else {
            return nil
        }

        for windowInfo in windowList {
            guard let windowPID = windowInfo[kCGWindowOwnerPID as String] as? pid_t,
                  windowPID == pid,
                  let windowTitle = windowInfo[kCGWindowName as String] as? String,
                  windowTitle == title,
                  let windowID = windowInfo[kCGWindowNumber as String] as? CGWindowID else {
                continue
            }
            return windowID
        }

        return nil
    }

    private func moveWindow(windowID: CGWindowID, to frame: CGRect) {
        // Get window info
        guard let windowInfo = CGWindowListCopyWindowInfo([.optionIncludingWindow], windowID) as? [[String: Any]],
              let info = windowInfo.first,
              let pid = info[kCGWindowOwnerPID as String] as? pid_t else {
            return
        }

        // Use Accessibility API to move window
        guard NSRunningApplication(processIdentifier: pid) != nil else { return }

        let appElement = AXUIElementCreateApplication(pid)
        var windowsRef: CFTypeRef?

        guard AXUIElementCopyAttributeValue(appElement, kAXWindowsAttribute as CFString, &windowsRef) == .success,
              let windows = windowsRef as? [AXUIElement] else {
            return
        }

        // Try to match window by position or title
        for window in windows {
            // Set position
            var position = CGPoint(x: frame.origin.x, y: frame.origin.y)
            let positionValue = AXValue.from(value: &position, type: .cgPoint)
            AXUIElementSetAttributeValue(window, kAXPositionAttribute as CFString, positionValue)

            // Set size
            var size = CGSize(width: frame.width, height: frame.height)
            let sizeValue = AXValue.from(value: &size, type: .cgSize)
            AXUIElementSetAttributeValue(window, kAXSizeAttribute as CFString, sizeValue)

            print("📐 [WindowLayoutsManager] Moved window to \(frame)")
            break
        }
    }

    // MARK: - Persistence

    private func loadLayouts() {
        guard let data = UserDefaults.standard.data(forKey: layoutsKey),
              let decoded = try? JSONDecoder().decode([WindowLayout].self, from: data) else {
            return
        }
        savedLayouts = decoded
    }

    private func persistLayouts() {
        guard let encoded = try? JSONEncoder().encode(savedLayouts) else {
            return
        }
        UserDefaults.standard.set(encoded, forKey: layoutsKey)
    }
}

// MARK: - Models

struct WindowLayout: Codable, Identifiable {
    let id: UUID
    let name: String
    let windows: [WindowState]
    let dateCreated: Date

    init(id: UUID = UUID(), name: String, windows: [WindowState], dateCreated: Date = Date()) {
        self.id = id
        self.name = name
        self.windows = windows
        self.dateCreated = dateCreated
    }
}

struct WindowState: Codable {
    let bundleIdentifier: String?
    let title: String
    let frame: CGRect

    init(bundleIdentifier: String?, title: String, frame: CGRect) {
        self.bundleIdentifier = bundleIdentifier
        self.title = title
        self.frame = frame
    }
}

// Note: CGRect is already Codable in modern macOS/iOS

// MARK: - AXValue Extension

extension AXValue {
    static func from<T>(value: inout T, type: AXValueType) -> AXValue {
        return AXValueCreate(type, &value)!
    }
}
