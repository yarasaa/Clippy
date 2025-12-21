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
            print("Pencere öne getirilirken hata oluştu: \(result.rawValue)")
        }
        NSRunningApplication(processIdentifier: pid)?.activate(options: .activateIgnoringOtherApps)
    }

    func minimizeWindow(with windowID: CGWindowID, pid: pid_t) {
        guard let windowElement = findWindowElement(with: windowID, pid: pid) else { return }

        var isMinimizable: DarwinBoolean = false
        if AXUIElementIsAttributeSettable(windowElement, kAXMinimizedAttribute as CFString, &isMinimizable) == .success && isMinimizable.boolValue {
            let result = AXUIElementSetAttributeValue(windowElement, kAXMinimizedAttribute as CFString, kCFBooleanTrue)
            if result != .success {
                print("Pencere küçültülürken hata oluştu: \(result.rawValue)")
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
            print("Pencere için kapatma düğmesi bulunamadı.")
        }
    }

    func moveWindow(with windowID: CGWindowID, pid: pid_t, to screen: NSScreen) {
        guard let windowElement = findWindowElement(with: windowID, pid: pid) else {
            print("🚫 Window element bulunamadı: \(windowID)")
            return
        }

        var sizeValue: CFTypeRef?
        guard AXUIElementCopyAttributeValue(windowElement, kAXSizeAttribute as CFString, &sizeValue) == .success,
              let sizeVal = sizeValue as! AXValue?,
              CFGetTypeID(sizeVal) == AXValueGetTypeID() else {
            print("🚫 Window boyutu alınamadı")
            return
        }

        var windowSize = CGSize.zero
        AXValueGetValue(sizeVal, .cgSize, &windowSize)

        let targetFrame = screen.visibleFrame

        let newX = targetFrame.origin.x + (targetFrame.width - windowSize.width) / 2
        let newY = targetFrame.origin.y + (targetFrame.height - windowSize.height) / 2
        var newPosition = CGPoint(x: newX, y: newY)

        guard let newPositionValue = AXValueCreate(.cgPoint, &newPosition) else {
            print("🚫 AXValue oluşturulamadı")
            return
        }

        let result = AXUIElementSetAttributeValue(windowElement, kAXPositionAttribute as CFString, newPositionValue)
        if result == .success {
            print("✅ Window \(windowID) başarıyla \(screen.localizedName) ekranına taşındı")
        } else {
            print("🚫 Window taşıma hatası: \(result.rawValue)")
        }
    }
}
