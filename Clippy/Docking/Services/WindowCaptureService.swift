import AppKit

actor WindowCaptureService {

    func captureWindows(for pid: pid_t) async -> [CapturedWindow] {
        // Remove .optionOnScreenOnly to include minimized windows
        let options: CGWindowListOption = [.excludeDesktopElements]
        guard let windowList = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]] else {
            return []
        }

        var capturedWindows: [CapturedWindow] = []

        for windowInfo in windowList {
            guard let windowPID = windowInfo[kCGWindowOwnerPID as String] as? pid_t, windowPID == pid else {
                continue
            }

            guard let app = NSRunningApplication(processIdentifier: windowPID) else {
                continue
            }

            guard let layer = windowInfo[kCGWindowLayer as String] as? Int, layer == 0 else {
                continue
            }

            guard let windowID = windowInfo[kCGWindowNumber as String] as? CGWindowID,
                  let boundsDict = windowInfo[kCGWindowBounds as String] as? [String: Any],
                  let frame = CGRect(dictionaryRepresentation: boundsDict as CFDictionary) else {
                continue
            }

            guard frame.width > 50 && frame.height > 50 else {
                continue
            }

            let title = windowInfo[kCGWindowName as String] as? String
            let ownerName = app.localizedName ?? "Unknown"
            if let image = CGWindowListCreateImage(.null, .optionIncludingWindow, windowID, [.boundsIgnoreFraming, .bestResolution]) {
                capturedWindows.append(CapturedWindow(image: image, windowID: windowID, frame: frame, title: title, ownerName: ownerName, pid: windowPID, ownerIcon: app.icon))
            }
        }

        return capturedWindows
    }
}
