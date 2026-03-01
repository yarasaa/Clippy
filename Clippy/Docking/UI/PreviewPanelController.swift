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

    private var currentAppIdentifier: String?

    var onWindowCloseAction: ((CGWindowID) -> Void)?
    var onWindowMinimizeAction: ((CGWindowID) -> Void)?
    var onWindowSelectAction: ((CGWindowID) -> Void)?
    var onMoveToMonitorAction: ((CGWindowID, NSScreen) -> Void)?

    private var currentItems: [PreviewItem] = []

    @Published private(set) var selectedIndex: Int = 0

    init() {
    }

    func show(appName: String, appIcon: NSImage?, items: [PreviewItem], at position: NSPoint, dockIconFrame: CGRect = .zero, forceUpdate: Bool = false) {
        currentItems = items
        selectedIndex = 0

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

        panel.contentViewController = NSHostingController(rootView: contentView)

        positionPanel(panel, above: position, dockIconFrame: dockIconFrame)

        let finalFrame = panel.frame

        if !panel.isVisible {
            let initialFrame = finalFrame.insetBy(dx: finalFrame.width * 0.05, dy: finalFrame.height * 0.05)
            panel.setFrame(initialFrame, display: false)
            panel.alphaValue = 0
            panel.orderFront(nil)
        }

        let animationStyle = SettingsManager.shared.dockPreviewAnimationStyle
        let (duration, timingFunction) = getAnimationParameters(for: animationStyle)

        NSAnimationContext.runAnimationGroup { context in
            context.duration = duration
            context.timingFunction = timingFunction
            panel.animator().alphaValue = 1.0
            panel.animator().setFrame(finalFrame, display: true)
        } completionHandler: {
            if SettingsManager.shared.enableDockPreviewKeyboardShortcuts {
                panel.makeKey()
            }
        }
    }

    func hide() {
        guard let panel = panel, panel.isVisible, panel.alphaValue > 0 else { return }

        currentAppIdentifier = nil

        // Stop all live preview streams when panel is hidden
        Task { @MainActor in
            await LivePreviewService.shared.stopAllStreams()
        }

        let currentFrame = panel.frame
        let finalFrame = currentFrame.insetBy(dx: currentFrame.width * 0.05, dy: currentFrame.height * 0.05)

        let animationStyle = SettingsManager.shared.dockPreviewAnimationStyle
        let (baseDuration, _) = getAnimationParameters(for: animationStyle)
        let hideDuration = animationStyle == "none" ? 0.0 : baseDuration * 0.8

        NSAnimationContext.runAnimationGroup({ context in
            context.duration = hideDuration
            context.timingFunction = CAMediaTimingFunction(name: .easeIn)
            panel.animator().alphaValue = 0.0
            panel.animator().setFrame(finalFrame, display: true)
        }, completionHandler: {
            panel.orderOut(nil)
            panel.setFrame(currentFrame, display: false)
        })
    }

    private func setupThemeListener() {
    }

    private func getAnimationParameters(for style: String) -> (duration: TimeInterval, timingFunction: CAMediaTimingFunction) {
        switch style {
        case "spring":
            return (0.35, CAMediaTimingFunction(controlPoints: 0.5, 1.1 + Float(1.0 / 3.0), 1.0, 1.0))
        case "easeInOut":
            return (0.25, CAMediaTimingFunction(name: .easeInEaseOut))
        case "linear":
            return (0.2, CAMediaTimingFunction(name: .linear))
        case "none":
            return (0.0, CAMediaTimingFunction(name: .linear))
        default:
            return (0.25, CAMediaTimingFunction(name: .easeOut))
        }
    }

    private func positionPanel(_ panel: NSPanel, above point: NSPoint, dockIconFrame: CGRect = .zero) {
        let panelSize = panel.contentView?.fittingSize ?? .zero

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

        panel.setFrameOrigin(NSPoint(x: x, y: y))
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
