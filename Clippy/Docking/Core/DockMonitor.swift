import AppKit
import Combine

/// Watches the Dock's accessibility tree and reports which dock icon the
/// cursor is currently over (or nil when none is).
///
/// Three things this has to survive, none of which the previous version
/// handled — each one showed up as "the preview just doesn't open":
///
///   1. **Accessibility not ready yet.** At launch (or before the user
///      grants permission) the Dock's AX tree can't be read. Attaching
///      failed silently and was never retried, so the preview stayed dead
///      for the whole session.
///   2. **The Dock restarts.** `killall Dock`, a display change, or macOS
///      itself recycles it. The observer is bound to an AXUIElement that
///      is now dead; it simply stops firing forever.
///   3. **The stream identity changing.** The stream used to be recreated
///      on every `start()`, but `DockPreviewCoordinator` binds to it once
///      with `for await`. A restart therefore left the coordinator
///      listening to an orphaned stream that would never yield again —
///      and `dockItemStream`'s `stream!` could crash outright after stop().
///      The stream is now created once and lives for the app's lifetime.
final class DockMonitor {

    static let shared = DockMonitor()

    // MARK: - Stream (stable identity for the whole app lifetime)

    private let (stream, continuation) = AsyncStream<DockItem?>.makeStream()
    var dockItemStream: AsyncStream<DockItem?> { stream }

    // MARK: - State

    private var axObserver: AXObserver?
    private var mainListElement: AXUIElement?
    private var isRunning = false
    /// True once the AX observer is successfully hooked up.
    private var isAttached = false
    private var retryWorkItem: DispatchWorkItem?
    private var retryDelay: TimeInterval = 0.5

    private init() { }

    deinit {
        NSWorkspace.shared.notificationCenter.removeObserver(self)
    }

    // MARK: - Lifecycle

    func start() {
        guard !isRunning else { return }
        isRunning = true

        // Re-attach when the Dock comes back after a restart.
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(dockDidLaunch(_:)),
            name: NSWorkspace.didLaunchApplicationNotification,
            object: nil
        )

        attachOrRetry()
    }

    func stop() {
        guard isRunning else { return }
        isRunning = false

        cancelRetry()
        NSWorkspace.shared.notificationCenter.removeObserver(self)
        detach()
        // The continuation is deliberately NOT finished: the stream must
        // outlive stop/start cycles so an already-awaiting coordinator
        // keeps receiving events after the feature is toggled back on.
    }

    @objc private func dockDidLaunch(_ note: Notification) {
        guard let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
              app.bundleIdentifier == "com.apple.dock",
              isRunning else { return }

        // The old element is dead; rebuild against the new Dock process.
        detach()
        retryDelay = 0.5
        attachOrRetry()
    }

    // MARK: - Attach

    /// Attempts to hook the AX observer, scheduling a backoff retry when
    /// the Dock isn't readable yet (typically missing accessibility
    /// permission, or the Dock still starting up).
    private func attachOrRetry() {
        guard isRunning, !isAttached else { return }

        if attach() {
            retryDelay = 0.5
            return
        }

        // Back off, but keep trying: the usual cause is a permission the
        // user is about to grant, and we want to come alive the moment
        // they do — without them having to restart Clippy.
        cancelRetry()
        let work = DispatchWorkItem { [weak self] in self?.attachOrRetry() }
        retryWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + retryDelay, execute: work)
        retryDelay = min(retryDelay * 2, 30)
    }

    private func attach() -> Bool {
        guard let dockApp = NSRunningApplication
            .runningApplications(withBundleIdentifier: "com.apple.dock").first else {
            return false
        }

        let dockPID = dockApp.processIdentifier
        let dockElement = AXUIElementCreateApplication(dockPID)

        guard let mainList = findMainDockList(in: dockElement) else { return false }

        var observer: AXObserver?
        guard AXObserverCreate(dockPID, observerCallback, &observer) == .success,
              let observer else {
            return false
        }

        let error = AXObserverAddNotification(
            observer,
            mainList,
            kAXSelectedChildrenChangedNotification as CFString,
            Unmanaged.passUnretained(self).toOpaque()
        )
        guard error == .success else { return false }

        CFRunLoopAddSource(CFRunLoopGetCurrent(), AXObserverGetRunLoopSource(observer), .defaultMode)

        self.axObserver = observer
        self.mainListElement = mainList
        self.isAttached = true
        return true
    }

    private func detach() {
        if let observer = axObserver {
            if let listElement = mainListElement {
                AXObserverRemoveNotification(
                    observer, listElement,
                    kAXSelectedChildrenChangedNotification as CFString
                )
            }
            CFRunLoopRemoveSource(CFRunLoopGetCurrent(), AXObserverGetRunLoopSource(observer), .defaultMode)
        }
        axObserver = nil
        mainListElement = nil
        isAttached = false
    }

    private func cancelRetry() {
        retryWorkItem?.cancel()
        retryWorkItem = nil
    }

    // MARK: - Selection

    fileprivate func processSelectionChange() {
        guard let mainListElement = mainListElement else { return }

        var selectedChildren: CFTypeRef?
        guard AXUIElementCopyAttributeValue(mainListElement, kAXSelectedChildrenAttribute as CFString, &selectedChildren) == .success,
              let selectedElements = selectedChildren as? [AXUIElement],
              let selectedIcon = selectedElements.first else {
            continuation.yield(nil)
            return
        }

        var positionValue: CFTypeRef?
        var sizeValue: CFTypeRef?
        guard AXUIElementCopyAttributeValue(selectedIcon, kAXPositionAttribute as CFString, &positionValue) == .success,
              AXUIElementCopyAttributeValue(selectedIcon, kAXSizeAttribute as CFString, &sizeValue) == .success else {
            continuation.yield(nil)
            return
        }
        var iconPosition = CGPoint.zero
        var iconSize = CGSize.zero
        guard let posVal = positionValue as! AXValue?, AXValueGetValue(posVal, .cgPoint, &iconPosition),
              let sizeVal = sizeValue as! AXValue?, AXValueGetValue(sizeVal, .cgSize, &iconSize) else {
            continuation.yield(nil)
            return
        }
        let iconFrame = CGRect(origin: iconPosition, size: iconSize)

        var appURLRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(selectedIcon, kAXURLAttribute as CFString, &appURLRef) == .success,
              let appURL = appURLRef as? URL,
              let bundle = Bundle(url: appURL),
              let bundleIdentifier = bundle.bundleIdentifier,
              !bundleIdentifier.isEmpty,
              bundleIdentifier != "com.apple.dock" else {
            continuation.yield(nil)
            return
        }

        guard let runningApp = NSRunningApplication
            .runningApplications(withBundleIdentifier: bundleIdentifier).first else {
            continuation.yield(nil)
            return
        }

        let dockItem = DockItem(
            pid: runningApp.processIdentifier,
            bundleIdentifier: runningApp.bundleIdentifier,
            frame: iconFrame
        )
        continuation.yield(dockItem)
    }

    private func findMainDockList(in dockElement: AXUIElement) -> AXUIElement? {
        var children: AnyObject?
        guard AXUIElementCopyAttributeValue(dockElement, kAXChildrenAttribute as CFString, &children) == .success,
              let axChildren = children as? [AXUIElement] else {
            return nil
        }

        return axChildren.first { element in
            var role: AnyObject?
            if AXUIElementCopyAttributeValue(element, kAXRoleAttribute as CFString, &role) == .success {
                return (role as? String) == (kAXListRole as String)
            }
            return false
        }
    }
}

private func observerCallback(_ observer: AXObserver, _ element: AXUIElement, _ notification: CFString, _ refcon: UnsafeMutableRawPointer?) {
    guard let refcon = refcon else { return }
    let dockMonitor = Unmanaged<DockMonitor>.fromOpaque(refcon).takeUnretainedValue()
    dockMonitor.processSelectionChange()
}
