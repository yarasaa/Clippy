import AppKit
import Combine

final class DockMonitor {

    static let shared = DockMonitor()

    // MARK: - State
    private var axObserver: AXObserver?
    private var mainListElement: AXUIElement?
    private var isRunning = false

    // MARK: - Stream
    private var stream: AsyncStream<DockItem?>?
    private var continuation: AsyncStream<DockItem?>.Continuation?

    var dockItemStream: AsyncStream<DockItem?> { stream! }

    private init() { }

    deinit {
        stop()
    }

    func start() {
        guard !isRunning else {
            print("🟡 [Monitor] START called but already running.")
            return
        }

        let (newStream, newContinuation) = AsyncStream<DockItem?>.makeStream()
        self.stream = newStream
        self.continuation = newContinuation

        guard let dockApp = NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.dock").first else {
            print("🚫 [Monitor] Dock application is not running.")
            continuation?.finish()
            continuation = nil
            return
        }
        let dockPID = dockApp.processIdentifier
        let dockElement = AXUIElementCreateApplication(dockPID)

        guard let mainList = findMainDockList(in: dockElement) else {
            print("🚫 [Monitor] Could not find main icon list (AXList) in Dock.")
            return
        }
        self.mainListElement = mainList

        guard AXObserverCreate(dockPID, observerCallback, &axObserver) == .success, let observer = axObserver else {
            print("🚫 [Monitor] Failed to create AXObserver.")
            return
        }

        let error = AXObserverAddNotification(observer, mainList, kAXSelectedChildrenChangedNotification as CFString, Unmanaged.passUnretained(self).toOpaque())
        if error != AXError.success {
            print("🚫 [Monitor] Failed to subscribe to notification. Error: \(error.rawValue)")
            return
        }

        CFRunLoopAddSource(CFRunLoopGetCurrent(), AXObserverGetRunLoopSource(observer), .defaultMode)

        isRunning = true
        print("✅ [Monitor] Started listening for Dock selection changes.")
    }

    func stop() {
        guard isRunning, let observer = axObserver, let listElement = mainListElement else {
            print("🟡 [Monitor] STOP called but not running or already stopped.")
            return
        }

        print("🛑 [Monitor] Stopping listener.")
        CFRunLoopRemoveSource(CFRunLoopGetCurrent(), AXObserverGetRunLoopSource(observer), .defaultMode)
        AXObserverRemoveNotification(observer, listElement, kAXSelectedChildrenChangedNotification as CFString)

        continuation?.finish()
        continuation = nil
        stream = nil

        axObserver = nil
        mainListElement = nil
        isRunning = false
    }

    fileprivate func processSelectionChange() {
        guard let mainListElement = mainListElement, let continuation = continuation else { return }

        var selectedChildren: CFTypeRef?
        guard AXUIElementCopyAttributeValue(mainListElement, kAXSelectedChildrenAttribute as CFString, &selectedChildren) == .success,
              let selectedElements = selectedChildren as? [AXUIElement],
              let selectedIcon = selectedElements.first else {
            print("  [Monitor] Selection changed to nil. Yielding nil to stream.")
            continuation.yield(nil)
            return
        }

        var positionValue: CFTypeRef?
        var sizeValue: CFTypeRef?
        guard AXUIElementCopyAttributeValue(selectedIcon, kAXPositionAttribute as CFString, &positionValue) == .success,
              AXUIElementCopyAttributeValue(selectedIcon, kAXSizeAttribute as CFString, &sizeValue) == .success else {
            print("  [Monitor] Could not get icon frame. Yielding nil to stream.")
            continuation.yield(nil)
            return
        }
        var iconPosition = CGPoint.zero
        var iconSize = CGSize.zero
        guard let posVal = positionValue as! AXValue?, AXValueGetValue(posVal, .cgPoint, &iconPosition),
              let sizeVal = sizeValue as! AXValue?, AXValueGetValue(sizeVal, .cgSize, &iconSize) else {
            print("  [Monitor] Could not convert icon frame values. Yielding nil to stream.")
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
            print("  [Monitor] Hovered item is not a running app (folder, trash, etc). Yielding nil to stream.")
            continuation.yield(nil)
            return
        }

        guard let runningApp = NSRunningApplication.runningApplications(withBundleIdentifier: bundleIdentifier).first else {
            print("  [Monitor] App with bundleID '\(bundleIdentifier)' is not running. Yielding nil to stream.")
            continuation.yield(nil)
            return
        }

        let pid = runningApp.processIdentifier
        let appName = runningApp.localizedName ?? "Bilinmeyen Uygulama"
        print("🎯 [Monitor] Hover detected on PID \(pid) (app: \(appName)). Yielding DockItem to stream.")
        let dockItem = DockItem(pid: pid, bundleIdentifier: runningApp.bundleIdentifier, frame: iconFrame)
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
