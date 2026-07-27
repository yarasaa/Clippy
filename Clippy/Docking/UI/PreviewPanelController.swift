import AppKit
import SwiftUI
import Combine

private enum AppTheme: String {
    case system, light, dark
}

class PreviewPanelController {

    var panel: KeyInterceptingPanel?

    var frame: CGRect {
        panel?.frame ?? .zero
    }

    /// Authoritative "is the preview on screen" flag for the dismiss
    /// watchdog. Uses real AppKit visibility, not a frame heuristic.
    var isVisible: Bool {
        panel?.isVisible ?? false
    }

    /// Guards against a dismiss being requested repeatedly while the
    /// hide animation is already in flight (which would restart it).
    private var isHiding = false

    /// Bumped on every `show()`. The hide animation's completion handler
    /// captures the value at the time it started and only tears the panel
    /// down if it still matches — otherwise a fade-out that was already
    /// running when the user hovered a new dock icon would `orderOut` the
    /// panel we just presented, which looked like "the preview won't open".
    private var showGeneration = 0

    private var currentAppIdentifier: String?

    var onWindowCloseAction: ((CGWindowID) -> Void)?
    var onWindowMinimizeAction: ((CGWindowID) -> Void)?
    var onWindowSelectAction: ((CGWindowID) -> Void)?
    var onMoveToMonitorAction: ((CGWindowID, NSScreen) -> Void)?

    private var currentItems: [PreviewItem] = []

    @Published private(set) var selectedIndex: Int = 0

    init() {
    }

    /// Guards against `show` being entered again while it's still running.
    /// Window ordering and hosting-controller sizing both drive layout,
    /// and a re-entrant call there is what turned a layout cycle into a
    /// stack overflow rather than a dropped frame.
    private var isShowing = false

    func show(appName: String, appIcon: NSImage?, items: [PreviewItem], at position: NSPoint, dockIconFrame: CGRect = .zero, forceUpdate: Bool = false) {
        guard !isShowing else { return }
        isShowing = true
        defer { isShowing = false }

        currentItems = items
        selectedIndex = 0
        // A new show cancels any in-flight hide (e.g. the user moved
        // from one dock icon straight to the panel), and invalidates that
        // hide's pending completion handler.
        isHiding = false
        showGeneration &+= 1

        if panel?.isVisible == true, currentAppIdentifier == appName, !forceUpdate {
            return
        }

        if panel == nil {
            let newPanel = KeyInterceptingPanel(
                contentRect: .zero,
                styleMask: [.borderless, .nonactivatingPanel],
                backing: .buffered,
                defer: false
            )
            newPanel.isFloatingPanel = true
            newPanel.level = .popUpMenu
            newPanel.backgroundColor = .clear
            newPanel.isOpaque = false
            newPanel.hasShadow = true

            setupKeyboardHandling(for: newPanel)

            setupGestureHandling(for: newPanel)

            self.panel = newPanel
        }

        currentAppIdentifier = appName

        guard let panel = panel else { return }

        let contentView = PreviewPanelView(
            appIcon: appIcon,
            appName: appName,
            items: items,
            onWindowClose: { [weak self] windowID in
                self?.onWindowCloseAction?(windowID)
            },
            onWindowMinimize: { [weak self] windowID in
                self?.onWindowMinimizeAction?(windowID)
            },
            onWindowSelect: { [weak self] windowID in
                self?.onWindowSelectAction?(windowID)
            },
            onMoveToMonitor: { [weak self] windowID, screen in
                self?.onMoveToMonitorAction?(windowID, screen)
            }
        )

        // Build a fresh hosting controller and tell it to track the
        // SwiftUI view's intrinsic size. Without this, when the same panel
        // is reused across hover events the contentView's fittingSize can
        // report a STALE value from the previous show — which is why
        // hovering a single-window app right after a multi-window one was
        // leaving a panel sized for the previous content.
        let host = NSHostingController(rootView: contentView)
        if #available(macOS 13.0, *) {
            // `.intrinsicContentSize` re-publishes the SwiftUI ideal size
            // on every layout pass; `.preferredContentSize` propagates it
            // up to the panel so window-level sizing can pick it up.
            host.sizingOptions = [.intrinsicContentSize, .preferredContentSize]
        }
        panel.contentViewController = host

        // `fittingSize` (read in positionPanel) already lays the view out
        // on demand, so forcing it here was redundant — and unsafe.
        //
        // Calling `layoutSubtreeIfNeeded` on a view that AppKit is already
        // laying out is explicitly illegal ("It's not legal to call
        // -layoutSubtreeIfNeeded on a view which is already being laid
        // out"), and when show() happened to be reached during a layout
        // pass it recursed until the stack ran out — crashing in
        // `orderFront` with EXC_BAD_ACCESS from `___chkstk_darwin`.
        positionPanel(panel, above: position, dockIconFrame: dockIconFrame)

        let finalFrame = panel.frame

        if !panel.isVisible {
            // Start: slightly smaller and nudged down (Windows 11-style rise-up reveal)
            var initialFrame = finalFrame
            initialFrame.size.width *= 0.94
            initialFrame.size.height *= 0.94
            initialFrame.origin.x += (finalFrame.width - initialFrame.width) / 2
            initialFrame.origin.y -= 12
            panel.setFrame(initialFrame, display: false)
            panel.alphaValue = 0
            panel.orderFront(nil)
        }

        let animationStyle = SettingsManager.shared.dockPreviewAnimationStyle
        let (duration, timingFunction) = getAnimationParameters(for: animationStyle)

        NSAnimationContext.runAnimationGroup { context in
            context.duration = duration
            context.timingFunction = timingFunction
            context.allowsImplicitAnimation = true
            panel.animator().alphaValue = 1.0
            panel.animator().setFrame(finalFrame, display: true)
        } completionHandler: {
            if SettingsManager.shared.enableDockPreviewKeyboardShortcuts {
                panel.makeKey()
            }
        }
    }

    func hide() {
        // NOTE: intentionally does NOT gate on `alphaValue > 0`. The old
        // guard silently dropped a dismiss requested *during* the reveal
        // animation (alpha still ~0), which then tore down the exit
        // watchers and left the panel stuck open forever. We only skip if
        // the panel is already hidden or a hide is already animating.
        guard let panel = panel, panel.isVisible, !isHiding else { return }
        isHiding = true
        let generation = showGeneration

        currentAppIdentifier = nil

        Task { @MainActor in
            await LivePreviewService.shared.stopAllStreams()
        }

        let currentFrame = panel.frame
        // Slight shrink + nudge down (reverse of reveal) for Windows-like dismiss
        var finalFrame = currentFrame
        finalFrame.size.width *= 0.96
        finalFrame.size.height *= 0.96
        finalFrame.origin.x += (currentFrame.width - finalFrame.width) / 2
        finalFrame.origin.y -= 6

        let animationStyle = SettingsManager.shared.dockPreviewAnimationStyle
        let hideDuration = animationStyle == "none" ? 0.0 : 0.16

        NSAnimationContext.runAnimationGroup({ context in
            context.duration = hideDuration
            context.timingFunction = CAMediaTimingFunction(name: .easeIn)
            context.allowsImplicitAnimation = true
            panel.animator().alphaValue = 0.0
            panel.animator().setFrame(finalFrame, display: true)
        }, completionHandler: { [weak self] in
            guard let self else { return }
            // A show() that landed mid-fade already claimed this panel —
            // leave it alone rather than ordering out a live preview.
            guard self.showGeneration == generation else { return }
            panel.orderOut(nil)
            panel.setFrame(currentFrame, display: false)
            self.isHiding = false
        })
    }

    private func setupThemeListener() {
    }

    private func getAnimationParameters(for style: String) -> (duration: TimeInterval, timingFunction: CAMediaTimingFunction) {
        switch style {
        case "spring":
            // Subtle overshoot + settle — feels like Windows 11 taskbar thumbnails
            return (0.32, CAMediaTimingFunction(controlPoints: 0.34, 1.56, 0.64, 1.0))
        case "easeInOut":
            return (0.22, CAMediaTimingFunction(controlPoints: 0.4, 0.0, 0.2, 1.0))
        case "linear":
            return (0.18, CAMediaTimingFunction(name: .linear))
        case "none":
            return (0.0, CAMediaTimingFunction(name: .linear))
        default:
            return (0.22, CAMediaTimingFunction(controlPoints: 0.2, 0.0, 0.0, 1.0))
        }
    }

    private func positionPanel(_ panel: NSPanel, above point: NSPoint, dockIconFrame: CGRect = .zero) {
        // Prefer the hosting controller's view for fittingSize. The panel's
        // top-level contentView is sometimes a wrapper that caches its
        // size from the previous controller; the hosting controller's
        // own `view` reflects the live SwiftUI intrinsic size and is what
        // we just asked to lay out in `show()`.
        let panelSize: CGSize = {
            if let hostView = panel.contentViewController?.view {
                // No explicit `layoutSubtreeIfNeeded()` here: `fittingSize`
                // already lays the view out on demand, and forcing it is
                // illegal if AppKit happens to be mid-layout already. Measured
                // both ways against the real view hierarchy — identical sizes.
                return hostView.fittingSize
            }
            return panel.contentView?.fittingSize ?? .zero
        }()

        guard let screen = findScreenContaining(point: point) else {
            return
        }

        let screenFrame = screen.visibleFrame

        // Center horizontally around the dock icon or mouse position
        var x = point.x - (panelSize.width / 2)

        // Position panel above the dock (10px from bottom of visible frame)
        // This correctly handles different screens by using the screen's own frame
        var y = screenFrame.minY + 10

        // Keep panel within screen bounds
        x = max(screenFrame.minX, min(x, screenFrame.maxX - panelSize.width))
        y = max(screenFrame.minY, min(y, screenFrame.maxY - panelSize.height))

        // IMPORTANT: set the full frame (not just origin). Otherwise the
        // panel keeps whatever size it had before — when the previous app
        // had 3 windows the panel is wide, then hovering an app with 1
        // window leaves a wide panel with empty space on the right
        // because the panel was never resized down to the new content's
        // fittingSize. Setting the rect both repositions and resizes.
        panel.setFrame(
            NSRect(origin: NSPoint(x: x, y: y), size: panelSize),
            display: false
        )
    }

    private func findScreenContaining(point: NSPoint) -> NSScreen? {
        for screen in NSScreen.screens {
            if screen.frame.contains(point) {
                return screen
            }
        }

        var closestScreen: NSScreen?
        var minDistance: CGFloat = .infinity

        for screen in NSScreen.screens {
            let screenCenter = CGPoint(
                x: screen.frame.midX,
                y: screen.frame.midY
            )
            let distance = hypot(point.x - screenCenter.x, point.y - screenCenter.y)

            if distance < minDistance {
                minDistance = distance
                closestScreen = screen
            }
        }

        return closestScreen ?? NSScreen.main
    }

    // MARK: - Keyboard Handling

    private func setupKeyboardHandling(for panel: KeyInterceptingPanel) {
        panel.onKeyDown = { [weak self] event in
            guard let self = self else { return }
            guard SettingsManager.shared.enableDockPreviewKeyboardShortcuts else { return }

            self.handleKeyDown(event)
        }
    }

    // MARK: - Gesture Handling

    private func setupGestureHandling(for panel: KeyInterceptingPanel) {
    }

    private func handleKeyDown(_ event: NSEvent) {
        let keyCode = event.keyCode
        let characters = event.charactersIgnoringModifiers ?? ""


        switch keyCode {
        case 53:
            hide()

        case 36:
            selectCurrentWindow()

        case 123:
            moveToPreviousWindow()

        case 124:
            moveToNextWindow()

        case 18...26:
            let number = keyCode - 18
            selectWindow(at: Int(number))

        default:
            break
        }
    }

    private func moveToNextWindow() {
        guard !currentItems.isEmpty else { return }
        selectedIndex = (selectedIndex + 1) % currentItems.count
    }

    private func moveToPreviousWindow() {
        guard !currentItems.isEmpty else { return }
        selectedIndex = selectedIndex > 0 ? selectedIndex - 1 : currentItems.count - 1
    }

    private func selectWindow(at index: Int) {
        guard index >= 0 && index < currentItems.count else { return }
        selectedIndex = index
        selectCurrentWindow()
    }

    private func selectCurrentWindow() {
        guard selectedIndex >= 0 && selectedIndex < currentItems.count else { return }
        let windowID = currentItems[selectedIndex].id
        onWindowSelectAction?(windowID)
    }

    func moveWindowToMonitor(windowID: CGWindowID, screen: NSScreen) {
        onMoveToMonitorAction?(windowID, screen)
    }

    func getAvailableScreens() -> [NSScreen] {
        return NSScreen.screens
    }
}
