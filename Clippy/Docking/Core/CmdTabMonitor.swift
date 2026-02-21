import AppKit
import Combine

final class CmdTabMonitor {
    static let shared = CmdTabMonitor()

    private let systemWideElement = AXUIElementCreateSystemWide()
    private var pollingTimer: Timer?
    private var lastPolledPID: pid_t?
    private var isRunning = false

    private let (stream, continuation) = AsyncStream<DockItem?>.makeStream()
    var appStream: AsyncStream<DockItem?> { stream }

    private init() {}

    deinit {
        stop()
    }

    func start() {
        guard !isRunning else { return }

        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(processFocusChange(notification:)),
            name: NSWorkspace.didActivateApplicationNotification,
            object: nil
        )
        isRunning = true
        print("✅ CmdTabMonitor: Started listening for Cmd+Tab focus changes.")
    }

    func stop() {
        guard isRunning else { return }
        stopPolling()
        NSWorkspace.shared.notificationCenter.removeObserver(self)
        isRunning = false
        print("🛑 CmdTabMonitor: Stopped.")
    }

    @objc private func processFocusChange(notification: NSNotification) {
        guard let activatedApp = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication else { return }

        if activatedApp.bundleIdentifier == "com.apple.dock" {
            startPolling()
        } else {
            stopPolling()
        }
    }

    private func startPolling() {
        guard pollingTimer == nil else { return }
        print("▶️ CmdTabMonitor: Switcher detected, starting polling.")
        pollingTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            self?.pollSelection()
        }
    }

    private func stopPolling() {
        guard pollingTimer != nil else { return }
        print("⏹️ CmdTabMonitor: Switcher closed, stopping polling.")
        pollingTimer?.invalidate()
        pollingTimer = nil
        if lastPolledPID != nil {
            lastPolledPID = nil
            continuation.yield(nil)
        }
    }

    private func pollSelection() {
        var focusedElement: CFTypeRef?
        guard AXUIElementCopyAttributeValue(systemWideElement, kAXFocusedUIElementAttribute as CFString, &focusedElement) == .success,
              let element = focusedElement as! AXUIElement? else { return }

        var pid: pid_t = 0
        guard AXUIElementGetPid(element, &pid) == .success, pid != 0 else {
            return
        }

        guard let app = NSRunningApplication(processIdentifier: pid) else {
            return
        }

        if pid == lastPolledPID { return }

        lastPolledPID = pid

        print("🎯 CmdTabMonitor: Polled selection: \(app.localizedName ?? "Unknown") (PID: \(pid))")

        // Get application frame from screen position
        let screens = NSScreen.screens
        var frame = CGRect.zero
        if let mainScreen = screens.first {
            frame = mainScreen.frame
        }

        let dockItem = DockItem(pid: pid, bundleIdentifier: app.bundleIdentifier, frame: frame)
        continuation.yield(dockItem)
    }

    // Get all windows for a specific PID
    func getWindowsForApp(pid: pid_t) -> [CGWindowID] {
        let options: CGWindowListOption = [.optionOnScreenOnly, .excludeDesktopElements]
        guard let windowList = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]] else {
            return []
        }

        var windowIDs: [CGWindowID] = []
        for windowInfo in windowList {
            guard let windowPID = windowInfo[kCGWindowOwnerPID as String] as? pid_t,
                  windowPID == pid,
                  let windowID = windowInfo[kCGWindowNumber as String] as? CGWindowID,
                  let alpha = windowInfo[kCGWindowAlpha as String] as? CGFloat, alpha > 0,
                  let layer = windowInfo[kCGWindowLayer as String] as? Int, layer == 0 else {
                continue
            }
            windowIDs.append(windowID)
        }

        return windowIDs
    }
}
