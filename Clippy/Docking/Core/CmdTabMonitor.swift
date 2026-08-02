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
    }

    func stop() {
        guard isRunning else { return }
        stopPolling()
        NSWorkspace.shared.notificationCenter.removeObserver(self)
        isRunning = false
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
        pollingTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            self?.pollSelection()
        }
    }

    private func stopPolling() {
        guard pollingTimer != nil else { return }
        pollingTimer?.invalidate()
        pollingTimer = nil
        if lastPolledPID != nil {
            lastPolledPID = nil
            continuation.yield(nil)
        }
    }

    private func pollSelection() {
        // The Command key must actually be held.
        //
        // Polling starts whenever `com.apple.dock` becomes the active
        // application, and that is far broader than "the user is ⌘-Tabbing":
        // Mission Control, Launchpad, switching Spaces and plain clicks on
        // the Dock all activate the same process. Every focus change during
        // those was being treated as an app-switch intent, and since the
        // DockItem below carries the whole screen as its frame, none of the
        // cursor checks downstream could reject it — a preview appeared for
        // an app nobody was pointing at, then vanished as soon as focus
        // settled and `stopPolling()` yielded nil.
        //
        // A real ⌘-Tab holds Command for the whole interaction; none of the
        // others do. That single bit separates them.
        //
        // Releasing Command also *ends* the interaction, so emit the dismiss
        // from here rather than relying on `stopPolling()` — that only fires
        // when some other application activates, which may be much later or
        // never. Downstream this is the only signal that can take the panel
        // down on the ⌘-Tab path: the DockItem below carries the whole screen
        // as its frame, so the cursor-based safe zone can never fall outside
        // it and the dismiss watchdog will not act on its own.
        guard NSEvent.modifierFlags.contains(.command) else {
            if lastPolledPID != nil {
                lastPolledPID = nil
                continuation.yield(nil)
            }
            return
        }

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
