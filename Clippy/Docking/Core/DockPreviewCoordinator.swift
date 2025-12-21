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
            print("HATA: ImageProcessingService başlatılamadı. Metal kullanılamıyor olabilir.")
            return nil
        }

        self.dockMonitor = DockMonitor.shared
        self.cmdTabMonitor = CmdTabMonitor.shared
        self.windowCaptureService = WindowCaptureService()
        self.imageProcessingService = imageProcessingService
        self.panelController = PreviewPanelController()

        print("✅ [Coordinator] INIT: DockPreviewCoordinator created.")

        self.panelController.onWindowSelectAction = { [weak self] windowID in
            guard let self = self, let pid = self.lastHoveredItem?.pid else { return }
            print("🎯 [Coordinator] Window selected: \(windowID) for PID: \(pid)")
            WindowActionService.shared.raiseWindow(with: windowID, pid: pid)
            self.panelController.hide()
        }
        self.panelController.onWindowMinimizeAction = { [weak self] windowID in
            guard let self = self, let pid = self.lastHoveredItem?.pid else { return }
            print("📦 [Coordinator] Window minimized: \(windowID) for PID: \(pid)")

            self.removeWindowFromPreview(windowID: windowID)

            // Invalidate cache so next hover captures fresh windows
            WindowCacheManager.shared.invalidateCache(for: pid)

            WindowActionService.shared.minimizeWindow(with: windowID, pid: pid)
        }
        self.panelController.onWindowCloseAction = { [weak self] windowID in
            guard let self = self, let pid = self.lastHoveredItem?.pid else { return }
            print("❌ [Coordinator] Window closed: \(windowID) for PID: \(pid)")

            self.removeWindowFromPreview(windowID: windowID)

            // Invalidate cache so next hover captures fresh windows
            WindowCacheManager.shared.invalidateCache(for: pid)

            WindowActionService.shared.closeWindow(with: windowID, pid: pid)
        }
        self.panelController.onMoveToMonitorAction = { [weak self] windowID, screen in
            guard let self = self, let pid = self.lastHoveredItem?.pid else { return }
            print("🖥️ [Coordinator] Moving window \(windowID) to screen: \(screen.localizedName)")
            WindowActionService.shared.moveWindow(with: windowID, pid: pid, to: screen)
        }
    }

    deinit {
        mainTask?.cancel()
        mouseExitTask?.cancel()
        cmdTabTask?.cancel()
        currentHoverTask?.cancel()
        print("🗑️ [Coordinator] DEINIT: DockPreviewCoordinator destroyed.")
    }

    func start() {
        guard !isRunning else { return }
        isRunning = true
        print("🚀 [Coordinator] START: Starting services.")
        dockMonitor.start()
        cmdTabMonitor.start()

        mainTask = Task {
            print("  [Coordinator] Task started for 'dockMonitor.dockItemStream'.")
            for await dockItem in dockMonitor.dockItemStream {
                self.currentHoverTask?.cancel()
                self.mouseExitTask?.cancel()

                if let dockItem = dockItem {
                    print("➡️ [Coordinator] Received hover from DockMonitor stream for PID \(dockItem.pid).")
                    self.lastHoveredItem = dockItem

                    self.currentHoverTask = Task {
                        await self.handleHover(on: dockItem)
                    }
                } else {
                    print("⬅️ [Coordinator] Received 'nil' from DockMonitor stream (hover ended).")
                    self.currentHoverTask = nil
                    panelController.hide()
                }
            }
            print("  [Coordinator] Task for 'dockMonitor.dockItemStream' finished.")
        }

        cmdTabTask = Task {
            print("  [Coordinator] Task started for 'cmdTabMonitor.appStream'.")
            for await dockItem in cmdTabMonitor.appStream {
                self.currentHoverTask?.cancel()
                self.mouseExitTask?.cancel()

                if let dockItem = dockItem {
                    print("➡️ [Coordinator] Received hover from CmdTabMonitor stream for PID \(dockItem.pid).")
                    self.lastHoveredItem = dockItem

                    self.currentHoverTask = Task {
                        await self.handleHover(on: dockItem)
                    }
                } else {
                    print("⬅️ [Coordinator] Received 'nil' from CmdTabMonitor stream (switcher closed).")
                    self.currentHoverTask = nil
                    panelController.hide()
                }
            }
            print("  [Coordinator] Task for 'cmdTabMonitor.appStream' finished.")
        }
    }

    func stop() {
        guard isRunning else { return }
        isRunning = false
        print("🛑 [Coordinator] STOP: Stopping services and cancelling tasks.")
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
        print("🎯 [Coordinator] === handleHover CALLED for PID \(dockItem.pid) ===")

        // Apply hover delay
        let delay = SettingsManager.shared.dockPreviewHoverDelay
        if delay > 0 {
            try? await Task.sleep(for: .milliseconds(Int(delay * 1000)))
        }

        guard !Task.isCancelled else {
            print("  [Coordinator] Task cancelled before processing PID \(dockItem.pid).")
            return
        }

        guard let app = NSRunningApplication(processIdentifier: dockItem.pid) else {
            panelController.hide()
            return
        }

        let capturedWindows: [CapturedWindow]
        if let cachedWindows = WindowCacheManager.shared.getCachedWindows(for: dockItem.pid) {
            print("    📦 [Coordinator] Using cached windows (\(cachedWindows.count) items)")
            capturedWindows = cachedWindows
        } else {
            print("    🔄 [Coordinator] Cache miss, capturing fresh windows...")
            capturedWindows = await windowCaptureService.captureWindows(for: dockItem.pid)

            if !capturedWindows.isEmpty {
                WindowCacheManager.shared.cacheWindows(capturedWindows, for: dockItem.pid)
            }
        }

        guard !Task.isCancelled else {
            print("  [Coordinator] Task cancelled after capturing windows for PID \(dockItem.pid).")
            return
        }

        print("    [Coordinator] Captured \(capturedWindows.count) windows.")
        self.lastCapturedWindows = capturedWindows
        guard !capturedWindows.isEmpty else {
            panelController.hide()
            return
        }

        let downsampleDimension = self.getOptimalDownsampleSize()
        print("    [Coordinator] Using dynamic downsample: \(downsampleDimension)px for preview size '\(SettingsManager.shared.dockPreviewSize)'")

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
            print("  [Coordinator] Task cancelled after processing images for PID \(dockItem.pid).")
            return
        }

        print("    [Coordinator] Processed \(previewItems.count) images.")

        if !previewItems.isEmpty {
            let positionPoint = dockItem.frame == .zero ? NSEvent.mouseLocation : CGPoint(x: dockItem.frame.midX, y: dockItem.frame.midY)

            print("✨ [Coordinator] Showing panel with \(previewItems.count) items.")
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
            print("🤷 [Coordinator] Hiding panel because no items were processed.")
            panelController.hide()
        }
    }

    private func removeWindowFromPreview(windowID: CGWindowID) {
        guard let lastHoveredItem = lastHoveredItem else { return }
        guard let app = NSRunningApplication(processIdentifier: lastHoveredItem.pid) else { return }

        print("🗑️ [Coordinator] Removing window \(windowID) from preview...")

        lastCapturedWindows.removeAll { $0.windowID == windowID }

        if lastCapturedWindows.isEmpty {
            print("    No windows remaining, hiding preview")
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

                print("    [Coordinator] Updating panel with \(previewItems.count) remaining items")
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
                        print("💨 [Coordinator] Mouse exited safe zone. Hiding panel.")
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
        print("🔄 [Coordinator] === refreshPreview CALLED for PID \(dockItem.pid) ===")
        // Note: With live preview, this manual refresh is rarely needed
        // as ScreenCaptureKit streams updates automatically
        await performRefresh(for: dockItem)
    }

    private func performRefresh(for dockItem: DockItem) async {
        guard let app = NSRunningApplication(processIdentifier: dockItem.pid) else {
            print("  [Coordinator] App no longer running")
            return
        }

        print("  [Coordinator] Invalidating cache and capturing fresh windows...")
        WindowCacheManager.shared.invalidateCache(for: dockItem.pid)

        let capturedWindows = await windowCaptureService.captureWindows(for: dockItem.pid)

        guard !capturedWindows.isEmpty else {
            print("  [Coordinator] No windows captured during refresh")
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
            print("  [Coordinator] No items after processing")
            return
        }

        // Update the panel
        let positionPoint = dockItem.frame == .zero ? NSEvent.mouseLocation : CGPoint(x: dockItem.frame.midX, y: dockItem.frame.midY)

        print("✅ [Coordinator] Refresh complete - updating panel with \(previewItems.count) items")
        panelController.show(
            appName: app.localizedName ?? "Bilinmeyen Uygulama",
            appIcon: app.icon,
            items: previewItems,
            at: positionPoint,
            dockIconFrame: dockItem.frame
        )
    }
}
