import AppKit
import Combine

private let kAXWindowIDAttribute = "AXWindowID" as CFString

@MainActor
final class DockPreviewCoordinator {

    // MARK: - Singleton
    static let shared: DockPreviewCoordinator? = DockPreviewCoordinator()

    private let dockMonitor: DockMonitor
    private let cmdTabMonitor: CmdTabMonitor
    private let windowCaptureService: WindowCaptureService
    private let imageProcessingService: ImageProcessingService
    private let panelController: PreviewPanelController

    private var mainTask: Task<Void, Never>?
    private var mouseExitTask: Task<Void, Never>?
    private var cmdTabTask: Task<Void, Never>?
    private var isRunning = false
    private var lastHoveredItem: DockItem?
    private var lastCapturedWindows: [CapturedWindow] = []
    private var currentHoverTask: Task<Void, Never>?

    private init?() {
        guard let imageProcessingService = ImageProcessingService() else {
            return nil
        }

        self.dockMonitor = DockMonitor.shared
        self.cmdTabMonitor = CmdTabMonitor.shared
        self.windowCaptureService = WindowCaptureService()
        self.imageProcessingService = imageProcessingService
        self.panelController = PreviewPanelController()


        self.panelController.onWindowSelectAction = { [weak self] windowID in
            guard let self = self, let pid = self.lastHoveredItem?.pid else { return }
            WindowActionService.shared.raiseWindow(with: windowID, pid: pid)
            self.panelController.hide()
        }
        self.panelController.onWindowMinimizeAction = { [weak self] windowID in
            guard let self = self, let pid = self.lastHoveredItem?.pid else { return }

            self.removeWindowFromPreview(windowID: windowID)

            // Invalidate cache so next hover captures fresh windows
            WindowCacheManager.shared.invalidateCache(for: pid)

            WindowActionService.shared.minimizeWindow(with: windowID, pid: pid)
        }
        self.panelController.onWindowCloseAction = { [weak self] windowID in
            guard let self = self, let pid = self.lastHoveredItem?.pid else { return }

            self.removeWindowFromPreview(windowID: windowID)

            // Invalidate cache so next hover captures fresh windows
            WindowCacheManager.shared.invalidateCache(for: pid)

            WindowActionService.shared.closeWindow(with: windowID, pid: pid)
        }
        self.panelController.onMoveToMonitorAction = { [weak self] windowID, screen in
            guard let self = self, let pid = self.lastHoveredItem?.pid else { return }
            WindowActionService.shared.moveWindow(with: windowID, pid: pid, to: screen)
        }
    }

    deinit {
        mainTask?.cancel()
        mouseExitTask?.cancel()
        cmdTabTask?.cancel()
        currentHoverTask?.cancel()
    }

    func start() {
        guard !isRunning else { return }
        isRunning = true
        dockMonitor.start()
        cmdTabMonitor.start()

        mainTask = Task {
            for await dockItem in dockMonitor.dockItemStream {
                self.currentHoverTask?.cancel()
                self.mouseExitTask?.cancel()

                if let dockItem = dockItem {
                    self.lastHoveredItem = dockItem

                    self.currentHoverTask = Task {
                        await self.handleHover(on: dockItem)
                    }
                } else {
                    self.currentHoverTask = nil
                    panelController.hide()
                }
            }
        }

        cmdTabTask = Task {
            for await dockItem in cmdTabMonitor.appStream {
                self.currentHoverTask?.cancel()
                self.mouseExitTask?.cancel()

                if let dockItem = dockItem {
                    self.lastHoveredItem = dockItem

                    self.currentHoverTask = Task {
                        await self.handleHover(on: dockItem)
                    }
                } else {
                    self.currentHoverTask = nil
                    panelController.hide()
                }
            }
        }
    }

    func stop() {
        guard isRunning else { return }
        isRunning = false
        mainTask?.cancel()
        mouseExitTask?.cancel()
        cmdTabTask?.cancel()
        currentHoverTask?.cancel()
        dockMonitor.stop()
        cmdTabMonitor.stop()
        panelController.hide()
    }

    // MARK: - Dynamic Downsample Size

    /// Calculates optimal downsample size based on preview size setting
    /// Smaller previews need less processing, saving GPU/CPU resources
    private func getOptimalDownsampleSize() -> CGFloat {
        let sizeStyle = SettingsManager.shared.dockPreviewSize
        switch sizeStyle {
        case "small":
            return 400.0   // 200px preview → 400px downsample (2x for Retina)
        case "large":
            return 800.0   // 400px preview → 800px downsample
        case "xlarge":
            return 1000.0  // 500px preview → 1000px downsample
        case "xxlarge":
            return 1200.0  // 600px preview → 1200px downsample
        default:
            return 600.0   // 300px preview → 600px downsample (medium)
        }
    }

    private func handleHover(on dockItem: DockItem) async {

        // Apply hover delay
        let delay = SettingsManager.shared.dockPreviewHoverDelay
        if delay > 0 {
            try? await Task.sleep(for: .milliseconds(Int(delay * 1000)))
        }

        guard !Task.isCancelled else {
            return
        }

        guard let app = NSRunningApplication(processIdentifier: dockItem.pid) else {
            panelController.hide()
            return
        }

        let capturedWindows: [CapturedWindow]
        if let cachedWindows = WindowCacheManager.shared.getCachedWindows(for: dockItem.pid) {
            capturedWindows = cachedWindows
        } else {
            capturedWindows = await windowCaptureService.captureWindows(for: dockItem.pid)

            if !capturedWindows.isEmpty {
                WindowCacheManager.shared.cacheWindows(capturedWindows, for: dockItem.pid)
            }
        }

        guard !Task.isCancelled else {
            return
        }

        self.lastCapturedWindows = capturedWindows
        guard !capturedWindows.isEmpty else {
            panelController.hide()
            return
        }

        let downsampleDimension = self.getOptimalDownsampleSize()

        let previewItems: [PreviewItem] = await withTaskGroup(of: PreviewItem?.self, returning: [PreviewItem].self) { group in
            for window in capturedWindows {
                group.addTask {
                    guard !Task.isCancelled else { return nil }

                    guard let downsampledCGImage = await self.imageProcessingService.downsample(image: window.image, maxDimension: downsampleDimension) else {
                        return nil
                    }
                    let nsImage = NSImage(cgImage: downsampledCGImage, size: .zero)
                    return PreviewItem(id: window.windowID, image: nsImage, title: window.title)
                }
            }

            var results: [PreviewItem] = []
            for await item in group {
                if let item = item {
                    results.append(item)
                }
            }
            return results.sorted { $0.id < $1.id }
        }

        guard !Task.isCancelled else {
            return
        }


        if !previewItems.isEmpty {
            let positionPoint = dockItem.frame == .zero ? NSEvent.mouseLocation : CGPoint(x: dockItem.frame.midX, y: dockItem.frame.midY)

            panelController.show(
                appName: app.localizedName ?? "Bilinmeyen Uygulama",
                appIcon: app.icon,
                items: previewItems,
                at: positionPoint,
                dockIconFrame: dockItem.frame
            )

            startMouseExitMonitor(dockIconFrame: dockItem.frame)

            // Live preview is now handled by LivePreviewService in PreviewPanelView
            // No manual refresh needed - ScreenCaptureKit streams updates automatically
        } else {
            panelController.hide()
        }
    }

    private func removeWindowFromPreview(windowID: CGWindowID) {
        guard let lastHoveredItem = lastHoveredItem else { return }
        guard let app = NSRunningApplication(processIdentifier: lastHoveredItem.pid) else { return }


        lastCapturedWindows.removeAll { $0.windowID == windowID }

        if lastCapturedWindows.isEmpty {
            panelController.hide()
            return
        }

        Task { @MainActor in
            let downsampleDimension = self.getOptimalDownsampleSize()

            let previewItems: [PreviewItem] = await withTaskGroup(of: PreviewItem?.self, returning: [PreviewItem].self) { group in
                for window in self.lastCapturedWindows {
                    group.addTask {
                        guard let downsampledCGImage = await self.imageProcessingService.downsample(image: window.image, maxDimension: downsampleDimension) else {
                            return nil
                        }
                        let nsImage = NSImage(cgImage: downsampledCGImage, size: .zero)
                        return PreviewItem(id: window.windowID, image: nsImage, title: window.title)
                    }
                }

                var results: [PreviewItem] = []
                for await item in group {
                    if let item = item {
                        results.append(item)
                    }
                }
                return results.sorted { $0.id < $1.id }
            }

            if !previewItems.isEmpty {
                let positionPoint = lastHoveredItem.frame == .zero ? NSEvent.mouseLocation : CGPoint(x: lastHoveredItem.frame.midX, y: lastHoveredItem.frame.midY)

                self.panelController.show(
                    appName: app.localizedName ?? "Bilinmeyen Uygulama",
                    appIcon: app.icon,
                    items: previewItems,
                    at: positionPoint,
                    dockIconFrame: lastHoveredItem.frame,
                    forceUpdate: true  // Force update when removing windows
                )
            } else {
                self.panelController.hide()
            }
        }
    }

    private func startMouseExitMonitor(dockIconFrame: CGRect) {
        mouseExitTask?.cancel()

        mouseExitTask = Task {
            let startTime = Date()
            // Reduced initial delay from 300ms to 100ms for faster response
            try? await Task.sleep(for: .milliseconds(100))

            while !Task.isCancelled {
                let mouseLocation = NSEvent.mouseLocation
                let panelFrame = self.panelController.frame

                if let screen = NSScreen.main {
                    let globalMouseLocation = NSPoint(x: mouseLocation.x, y: screen.frame.height - mouseLocation.y)

                    let y = screen.frame.height - panelFrame.origin.y - panelFrame.size.height
                    let globalPanelFrame = CGRect(origin: CGPoint(x: panelFrame.origin.x, y: y), size: panelFrame.size)

                    // Reduced safe zone margin from 10px to 5px for tighter bounds
                    let safeZone = globalPanelFrame.union(dockIconFrame).insetBy(dx: -5, dy: -5)

                    if !safeZone.contains(globalMouseLocation) {
                        self.panelController.hide()
                        break
                    }
                }

                // Aggressive adaptive polling for maximum CPU savings:
                // - First 1 sec: 50ms (very responsive for initial exit)
                // - 1-3 sec: 100ms (balanced)
                // - After 3 sec: 200ms (minimal CPU, user is likely interacting with panel)
                let elapsed = Date().timeIntervalSince(startTime)
                let pollInterval: Int
                if elapsed < 1.0 {
                    pollInterval = 50   // Very responsive initially
                } else if elapsed < 3.0 {
                    pollInterval = 100  // Balanced
                } else {
                    pollInterval = 200  // Minimal CPU after 3 seconds
                }
                try? await Task.sleep(for: .milliseconds(pollInterval))
            }
        }
    }

    private func refreshPreview(for dockItem: DockItem) async {
        // Note: With live preview, this manual refresh is rarely needed
        // as ScreenCaptureKit streams updates automatically
        await performRefresh(for: dockItem)
    }

    private func performRefresh(for dockItem: DockItem) async {
        guard let app = NSRunningApplication(processIdentifier: dockItem.pid) else {
            return
        }

        WindowCacheManager.shared.invalidateCache(for: dockItem.pid)

        let capturedWindows = await windowCaptureService.captureWindows(for: dockItem.pid)

        guard !capturedWindows.isEmpty else {
            return
        }

        // Cache the new windows
        WindowCacheManager.shared.cacheWindows(capturedWindows, for: dockItem.pid)

        // Process images with dynamic downsample
        let downsampleDimension = self.getOptimalDownsampleSize()

        let previewItems: [PreviewItem] = await withTaskGroup(of: PreviewItem?.self, returning: [PreviewItem].self) { group in
            for window in capturedWindows {
                group.addTask {
                    guard let downsampledCGImage = await self.imageProcessingService.downsample(image: window.image, maxDimension: downsampleDimension) else {
                        return nil
                    }
                    let nsImage = NSImage(cgImage: downsampledCGImage, size: .zero)
                    return PreviewItem(id: window.windowID, image: nsImage, title: window.title)
                }
            }

            var results: [PreviewItem] = []
            for await item in group {
                if let item = item {
                    results.append(item)
                }
            }
            return results.sorted { $0.id < $1.id }
        }

        guard !previewItems.isEmpty else {
            return
        }

        // Update the panel
        let positionPoint = dockItem.frame == .zero ? NSEvent.mouseLocation : CGPoint(x: dockItem.frame.midX, y: dockItem.frame.midY)

        panelController.show(
            appName: app.localizedName ?? "Bilinmeyen Uygulama",
            appIcon: app.icon,
            items: previewItems,
            at: positionPoint,
            dockIconFrame: dockItem.frame
        )
    }
}
