import AppKit

@_silgen_name("_AXUIElementGetWindow")
private func _AXUIElementGetWindow(_ element: AXUIElement, _ windowID: inout CGWindowID) -> AXError

final class WindowActionService {
    static let shared = WindowActionService()

    private init() {}

    private func findWindowElement(with windowID: CGWindowID, pid: pid_t) -> AXUIElement? {
        let appElement = AXUIElementCreateApplication(pid)
        var windows: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(appElement, kAXWindowsAttribute as CFString, &windows)

        guard result == .success, let windowList = windows as? [AXUIElement] else {
            return nil
        }

        for windowElement in windowList {
            var id: CGWindowID = 0
            if _AXUIElementGetWindow(windowElement, &id) == .success {
                if id == windowID {
                    return windowElement
                }
            }
        }
        return nil
    }

    func raiseWindow(with windowID: CGWindowID, pid: pid_t) {
        guard let windowElement = findWindowElement(with: windowID, pid: pid) else {
            NSRunningApplication(processIdentifier: pid)?.activate(options: .activateIgnoringOtherApps)
            return
        }

        let result = AXUIElementPerformAction(windowElement, kAXRaiseAction as CFString)
        if result != .success {
        }
        NSRunningApplication(processIdentifier: pid)?.activate(options: .activateIgnoringOtherApps)
    }

    func minimizeWindow(with windowID: CGWindowID, pid: pid_t) {
        guard let windowElement = findWindowElement(with: windowID, pid: pid) else { return }

        var isMinimizable: DarwinBoolean = false
        if AXUIElementIsAttributeSettable(windowElement, kAXMinimizedAttribute as CFString, &isMinimizable) == .success && isMinimizable.boolValue {
            let result = AXUIElementSetAttributeValue(windowElement, kAXMinimizedAttribute as CFString, kCFBooleanTrue)
            if result != .success {
            }
        }
    }

    func closeWindow(with windowID: CGWindowID, pid: pid_t) {
        guard let windowElement = findWindowElement(with: windowID, pid: pid) else { return }

        var closeButton: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(windowElement, kAXCloseButtonAttribute as CFString, &closeButton)

        if result == .success, let closeButton = closeButton, CFGetTypeID(closeButton) == AXUIElementGetTypeID() {
            AXUIElementPerformAction(closeButton as! AXUIElement, kAXPressAction as CFString)
        } else {
        }
    }

    /// Move a window to a target screen, proportionally scaled so the
    /// window occupies roughly the same fraction of screen real-estate
    /// as it did on the source display.
    ///
    /// Why proportional scale (not just clamp): going 4K → 1080p with a
    /// clamp leaves a 2000×1400 window at ~1060×700 — technically fits,
    /// but looks like it "shrank" because it's now a tiny fraction of
    /// a smaller screen. With proportional scale it becomes 1000×700
    /// (0.5× of both dims), which on the 1080p target covers the same
    /// ~52% × 65% of the screen it did on 4K. Feels like the window
    /// "moved" instead of "got stuck and shrunk".
    ///
    /// Why this used to be "half-working": the Accessibility API uses a
    /// top-left-origin coordinate space anchored to the PRIMARY screen,
    /// while `NSScreen.visibleFrame` is bottom-left-origin Cocoa coords.
    /// The old code fed Cocoa coords straight to AX, so on any multi-
    /// display layout where the secondary monitor wasn't flush with the
    /// primary the window landed off-screen or on the wrong display.
    /// We now convert explicitly and raise the window post-move.
    func moveWindow(with windowID: CGWindowID, pid: pid_t, to screen: NSScreen) {
        guard let windowElement = findWindowElement(with: windowID, pid: pid) else {
            return
        }

        // Read current window size so we can scale + recenter on the new screen.
        var sizeRef: CFTypeRef?
        var windowSize = CGSize(width: 800, height: 600)  // fallback
        if AXUIElementCopyAttributeValue(windowElement, kAXSizeAttribute as CFString, &sizeRef) == .success,
           let sv = sizeRef as! AXValue?,
           CFGetTypeID(sv) == AXValueGetTypeID() {
            AXValueGetValue(sv, .cgSize, &windowSize)
        }

        let target = screen.visibleFrame  // Cocoa (origin bottom-left of primary)

        // --- Proportional scale ---------------------------------------------
        // Find where the window currently lives so we can compare the two
        // displays' visible area. If we can't locate it (weird free-floating
        // window, missing window entry in CG list, etc.), fall back to the
        // primary screen's size — that still gives a reasonable ratio.
        let sourceVisible: CGRect = {
            if let src = currentScreenForWindow(windowID: windowID) {
                return src.visibleFrame
            }
            return NSScreen.screens.first?.visibleFrame ?? target
        }()

        // Scale by the smaller ratio so the window's aspect is preserved
        // and it's guaranteed to fit the new screen. Going to a LARGER
        // display (ratio > 1) also scales up — same fraction-of-screen feel.
        let ratioX = target.width  / sourceVisible.width
        let ratioY = target.height / sourceVisible.height
        let scale = min(ratioX, ratioY)

        // Skip the scaling math (and AX size set) when ratio is basically 1.
        // Two displays of the same size → pure move, no resize flicker.
        if abs(scale - 1.0) > 0.02 {
            windowSize.width  *= scale
            windowSize.height *= scale
        }

        // Safety clamp: never let the window exceed the target's visible
        // area (accounts for odd cases where the window was already larger
        // than its source screen, e.g. snapped-to-edges-but-overflowing).
        windowSize.width  = min(windowSize.width,  max(320, target.width  - 20))
        windowSize.height = min(windowSize.height, max(240, target.height - 20))
        // --------------------------------------------------------------------

        // Cocoa-coord centered position on the target screen.
        let cocoaX = target.origin.x + (target.width  - windowSize.width)  / 2
        let cocoaY = target.origin.y + (target.height - windowSize.height) / 2

        // Convert Cocoa (bottom-left, primary-anchored) → AX (top-left, primary-anchored).
        // axY = primary.maxY - (cocoaY + height)
        guard let primary = NSScreen.screens.first else { return }
        let axX = cocoaX
        let axY = primary.frame.maxY - (cocoaY + windowSize.height)
        var axPosition = CGPoint(x: axX, y: axY)

        // Size first, then position — prevents a flicker where the window
        // briefly appears oversized on the new screen.
        var clampedSize = windowSize
        if let sizeValue = AXValueCreate(.cgSize, &clampedSize) {
            AXUIElementSetAttributeValue(windowElement, kAXSizeAttribute as CFString, sizeValue)
        }
        if let positionValue = AXValueCreate(.cgPoint, &axPosition) {
            AXUIElementSetAttributeValue(windowElement, kAXPositionAttribute as CFString, positionValue)
        }

        // Bring the app (and this specific window) to the foreground.
        NSRunningApplication(processIdentifier: pid)?.activate(options: .activateIgnoringOtherApps)
        AXUIElementPerformAction(windowElement, kAXRaiseAction as CFString)
    }

    /// One-click "send this window to the next screen". If the user has
    /// exactly 2 displays this behaves as a toggle. With 3+, it cycles
    /// through the screen arrangement in index order.
    func moveWindowToNextScreen(with windowID: CGWindowID, pid: pid_t) {
        let screens = NSScreen.screens
        guard screens.count > 1 else { return }

        let currentScreen = currentScreenForWindow(windowID: windowID) ?? screens.first!
        guard let idx = screens.firstIndex(of: currentScreen) else {
            moveWindow(with: windowID, pid: pid, to: screens[0])
            return
        }
        let next = screens[(idx + 1) % screens.count]
        moveWindow(with: windowID, pid: pid, to: next)
    }

    /// Find which NSScreen contains the given window's center.
    /// Uses CG bounds (top-left anchored to primary) and converts to Cocoa.
    private func currentScreenForWindow(windowID: CGWindowID) -> NSScreen? {
        guard let info = CGWindowListCopyWindowInfo([.optionIncludingWindow], windowID) as? [[String: Any]],
              let first = info.first,
              let boundsDict = first[kCGWindowBounds as String] as? [String: Any],
              let bounds = CGRect(dictionaryRepresentation: boundsDict as CFDictionary) else {
            return nil
        }
        guard let primary = NSScreen.screens.first else { return nil }
        let cgCenter = CGPoint(x: bounds.midX, y: bounds.midY)
        let cocoaCenter = CGPoint(x: cgCenter.x, y: primary.frame.maxY - cgCenter.y)
        return NSScreen.screens.first(where: { $0.frame.contains(cocoaCenter) })
    }
}
