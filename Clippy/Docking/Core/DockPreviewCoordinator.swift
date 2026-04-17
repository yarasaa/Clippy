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

    // Event-driven mouse move monitor — fires on every cursor movement.
    // We use it instead of timer polling so hide is truly instant and we
    // don't burn CPU while the cursor is stationary.
    private var mouseMoveMonitor: Any?
    private var currentSafeZone: CGRect = .zero

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
                    // Mouse exited — clear intent so any sleeping hover task bails out on wake.
                    self.lastHoveredItem = nil
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
                    self.lastHoveredItem = nil
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
        Task { @MainActor in self.stopMouseMoveMonitor() }
        dockMonitor.stop()
        cmdTabMonitor.stop()
        panelController.hide()
    }

    // MARK: - Dynamic Downsample Size

    /// Calculates optimal downsample size based on preview size setting
    /// Smaller previews need less processing, saving GPU/CPU resources
    /// Converts NSEvent.mouseLocation (bottom-left origin, Cocoa) to the top-left-origin
    /// coordinate space that AX uses for AXUIElement positions. This lets us compare the
    /// live mouse location against the dock icon's AX frame without axis-flipping bugs.
    private static func mouseInAXCoords() -> CGPoint {
        let ns = NSEvent.mouseLocation
        // AX/CG coordinates are anchored to the top-left of the PRIMARY screen.
        // NSScreen.screens[0] is the primary; its frame.maxY equals the height
        // of the primary screen in Cocoa coords.
        guard let primary = NSScreen.screens.first else { return ns }
        return CGPoint(x: ns.x, y: primary.frame.maxY - ns.y)
    }

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

        // Dwell behavior with ACTIVE mouse tracking.
        // Dock's AX doesn't always emit a deselect when the mouse leaves the dock
        // area entirely (no new icon is hovered), so we poll the mouse position
        // and bail out if it leaves the icon's hit region. Both coordinate systems
        // are converted to match (NSEvent is bottom-left, AX is top-left-primary).
        let delay = SettingsManager.shared.dockPreviewHoverDelay
        let hitRegion = dockItem.frame.insetBy(dx: -8, dy: -8)

        if delay > 0 {
            let stepMs = 40
            let steps = max(1, Int(delay * 1000) / stepMs)
            for _ in 0..<steps {
                try? await Task.sleep(for: .milliseconds(stepMs))
                guard !Task.isCancelled else { return }
                guard self.lastHoveredItem?.pid == dockItem.pid else { return }

                // Bail early if mouse left the icon during the dwell.
                let mouse = Self.mouseInAXCoords()
                if !hitRegion.contains(mouse) {
                    return
                }
            }
        }

        guard !Task.isCancelled else { return }
        guard self.lastHoveredItem?.pid == dockItem.pid else { return }

        // Final confirmation right before committing to show.
        let finalMouse = Self.mouseInAXCoords()
        guard hitRegion.contains(finalMouse) else { return }

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

    /// Event-driven exit watcher. Registers a global mouse-move monitor that
    /// fires on every cursor movement and hides the panel the moment the mouse
    /// leaves the safe zone (panel ∪ dock icon + small bridge margin).
    /// No polling, no CPU cost while the cursor is stationary.
    private func startMouseExitMonitor(dockIconFrame: CGRect) {
        mouseExitTask?.cancel()
        stopMouseMoveMonitor()

        // Convert dockIconFrame from AX (top-left origin) to Cocoa (bottom-left origin)
        // so we can union it with the panel frame (which is already Cocoa) and compare
        // directly against NSEvent.mouseLocation (also Cocoa).
        let panelFrame = self.panelController.frame
        let dockInCocoa: CGRect = {
            guard let primary = NSScreen.screens.first else { return dockIconFrame }
            return CGRect(
                x: dockIconFrame.origin.x,
                y: primary.frame.maxY - dockIconFrame.origin.y - dockIconFrame.height,
                width: dockIconFrame.width,
                height: dockIconFrame.height
            )
        }()
        let safeZone = panelFrame.union(dockInCocoa).insetBy(dx: -6, dy: -6)
        self.currentSafeZone = safeZone

        // Short grace period so the first "show" mouse event doesn't trigger
        // an immediate hide if the cursor briefly leaves during the panel's
        // open animation.
        mouseExitTask = Task {
            try? await Task.sleep(for: .milliseconds(80))
            guard !Task.isCancelled else { return }
            await MainActor.run { self.installMouseMoveMonitor() }
        }
    }

    @MainActor
    private func installMouseMoveMonitor() {
        guard mouseMoveMonitor == nil else { return }
        mouseMoveMonitor = NSEvent.addGlobalMonitorForEvents(matching: .mouseMoved) { [weak self] _ in
            guard let self = self else { return }
            // NSEvent.mouseLocation already matches NSScreen's Cocoa bottom-left
            // space. Our safe zone (derived from panel.frame which is also Cocoa)
            // can be compared directly — no coord conversions to get wrong.
            let mouse = NSEvent.mouseLocation
            if !self.currentSafeZone.contains(mouse) {
                self.panelController.hide()
                self.stopMouseMoveMonitor()
            }
        }
    }

    @MainActor
    private func stopMouseMoveMonitor() {
        if let monitor = mouseMoveMonitor {
            NSEvent.removeMonitor(monitor)
            mouseMoveMonitor = nil
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
