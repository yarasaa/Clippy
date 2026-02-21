import AppKit
import Combine

@MainActor
final class WindowSwitcherCoordinator {

    // MARK: - Dependencies
    private let panelController = WindowSwitcherPanelController()
    private let imageProcessingService: ImageProcessingService

    private enum State {
        case hidden
        case preparing
        case visible
    }

    // MARK: - State
    private var state: State = .hidden
    private var items: [SwitcherItem] = []
    private var selectionIndex = 0

    // MARK: - Configuration
    private let downsampleDimension: CGFloat = 1000.0

    init?() {
        guard let imageProcessingService = ImageProcessingService() else {
            print("HATA: WindowSwitcherCoordinator için ImageProcessingService başlatılamadı.")
            return nil
        }
        self.imageProcessingService = imageProcessingService

        panelController.onWindowSelect = { [weak self] windowID in
            self?.panelController.selectedItemID = windowID
            self?.confirmSelectionAndHide()
        }
        panelController.onCycleSelection = { [weak self] in
            self?.cycleSelection()
        }
    }

    func handleTab() {
        switch state {
        case .hidden:
            state = .preparing
            print("➡️ State: .hidden -> .preparing")
            Task {
                let items = await prepareItems()
                guard !items.isEmpty else {
                    state = .hidden
                    return
                }
                self.items = items
                selectionIndex = 0
                panelController.selectedItemID = items.first?.id
                panelController.show(items: items)
                state = .visible
                print("✅ State: .preparing -> .visible")
            }
        case .visible:
            print("🔄 State: .visible. Cycling selection.")
            cycleSelection()
        case .preparing:
            print("⏳ State: .preparing. Ignoring tab press.")
            break
        }
    }

    func confirmSelectionAndHide() {
        print("🔼 Option key released or item clicked.")

        let itemToRaise = items.first { $0.id == panelController.selectedItemID }

        panelController.hide { [weak self] in
            if let item = itemToRaise {
                WindowActionService.shared.raiseWindow(with: item.windowID, pid: item.pid)
            }
            self?.state = .hidden
            self?.items = []
            print("⏹️ State reset to .hidden.")
        }
    }

    private func prepareItems() async -> [SwitcherItem] {
        print("➡️ WindowSwitcherCoordinator: Preparing...")
        let options: CGWindowListOption = [.optionOnScreenOnly, .excludeDesktopElements]
        guard let windowList = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]] else { return [] }

        var capturedWindows: [CapturedWindow] = []
        for windowInfo in windowList {
            guard let windowPID = windowInfo[kCGWindowOwnerPID as String] as? pid_t,
                  let app = NSRunningApplication(processIdentifier: windowPID),
                  app.activationPolicy == .regular,
                  let name = windowInfo[kCGWindowName as String] as? String, !name.isEmpty,
                  let alpha = windowInfo[kCGWindowAlpha as String] as? CGFloat, alpha > 0,
                  let layer = windowInfo[kCGWindowLayer as String] as? Int, layer == 0,
                  let windowID = windowInfo[kCGWindowNumber as String] as? CGWindowID,
                  let boundsDict = windowInfo[kCGWindowBounds as String] as? [String: Any],
                  let frame = CGRect(dictionaryRepresentation: boundsDict as CFDictionary),
                  frame.width > 100 && frame.height > 100,
                  let image = CGWindowListCreateImage(.null, .optionIncludingWindow, windowID, [.boundsIgnoreFraming, .bestResolution])
            else { continue }

            capturedWindows.append(CapturedWindow(image: image, windowID: windowID, frame: frame, title: name, ownerName: app.localizedName ?? "Unknown", pid: windowPID, ownerIcon: app.icon))
        }

        let switcherItems = await withTaskGroup(of: SwitcherItem?.self, returning: [SwitcherItem].self) { group in
            for window in capturedWindows {
                group.addTask {
                    guard let downsampledCGImage = await self.imageProcessingService.downsample(image: window.image, maxDimension: self.downsampleDimension) else { return nil }
                    let nsImage = NSImage(cgImage: downsampledCGImage, size: .zero)
                    return SwitcherItem(windowID: window.windowID, pid: window.pid, appIcon: window.ownerIcon, appName: window.ownerName, windowTitle: window.title, previewImage: nsImage)
                }
            }
            var results: [SwitcherItem] = []
            for await item in group { if let item = item { results.append(item) } }
            return results
        }

        print("✅ WindowSwitcherCoordinator: Prepared with \(switcherItems.count) items.")
        return switcherItems
    }

    private func cycleSelection() {
        guard !items.isEmpty else { return }
        var nextIndex = 0
        if let currentId = panelController.selectedItemID, let currentIndex = items.firstIndex(where: { $0.id == currentId }) {
            nextIndex = (currentIndex + 1) % items.count
        }
        panelController.selectedItemID = items[nextIndex].id
        print("🔹 Selection cycled to index \(nextIndex), window ID: \(items[nextIndex].id)")
    }
}
