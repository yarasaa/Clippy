import AppKit

extension AXUIElement {
    func getWindowID() -> CGWindowID? {
        var value: CFTypeRef?

        if AXUIElementCopyAttributeValue(self, "AXWindowID" as CFString, &value) == .success {
            if let number = value as? NSNumber {
                return number.uint32Value
            }
        }

        typealias _AXUIElementGetWindowType = @convention(c) (AXUIElement, UnsafeMutablePointer<CGWindowID>) -> AXError

        if let handle = dlopen("/System/Library/Frameworks/ApplicationServices.framework/ApplicationServices", RTLD_LAZY) {
            defer { dlclose(handle) }
            if let sym = dlsym(handle, "_AXUIElementGetWindow") {
                let _AXUIElementGetWindow = unsafeBitCast(sym, to: _AXUIElementGetWindowType.self)
                var id: CGWindowID = 0
                if _AXUIElementGetWindow(self, &id) == .success {
                    return id
                }
            }
        }
        return nil
    }
}