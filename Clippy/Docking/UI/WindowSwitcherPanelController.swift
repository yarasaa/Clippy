import AppKit
import SwiftUI
import Combine

private enum AppTheme: String {
    case system, light, dark
}

class KeyInterceptingPanel: NSPanel {
    override var canBecomeKey: Bool {
        return true
    }

    override var acceptsFirstResponder: Bool {
        return true
    }

    var onKeyDown: ((NSEvent) -> Void)?
    var onSwipe: ((NSEvent) -> Void)?
    var onOtherMouseDown: ((NSEvent) -> Void)?

    private var localEventMonitor: Any?
    private var scrollAccumulator: CGFloat = 0
    private var lastScrollTime: Date = Date()

    override init(contentRect: NSRect, styleMask style: NSWindow.StyleMask, backing backingStoreType: NSWindow.BackingStoreType, defer flag: Bool) {
        super.init(contentRect: contentRect, styleMask: style, backing: backingStoreType, defer: flag)

        self.acceptsMouseMovedEvents = true
        self.ignoresMouseEvents = false

        setupEventMonitor()
    }

    deinit {
        if let monitor = localEventMonitor {
            NSEvent.removeMonitor(monitor)
        }
    }

    private func setupEventMonitor() {
        localEventMonitor = NSEvent.addLocalMonitorForEvents(matching: [.scrollWheel, .swipe, .otherMouseDown]) { [weak self] event in
            guard let self = self else { return event }

            guard event.window === self else { return event }

            switch event.type {
            case .scrollWheel:
                self.handleScrollWheel(event)
            case .swipe:
                print("🎯 [EventMonitor] Native swipe detected!")
                self.onSwipe?(event)
            case .otherMouseDown:
                print("🖱️ [EventMonitor] OtherMouseDown detected, button: \(event.buttonNumber)")
                self.onOtherMouseDown?(event)
            default:
                break
            }

            return event
        }
    }

    private func handleScrollWheel(_ event: NSEvent) {
        let now = Date()
        let timeDiff = now.timeIntervalSince(lastScrollTime)

        if timeDiff > 0.5 {
            scrollAccumulator = 0
        }

        lastScrollTime = now
        scrollAccumulator += event.deltaY

        print("🎯 [EventMonitor] ScrollWheel - deltaY: \(event.deltaY), accumulated: \(scrollAccumulator), phase: \(event.phase.rawValue)")

        if abs(scrollAccumulator) > 20 {
            print("  Triggering swipe action!")
            onSwipe?(event)
            scrollAccumulator = 0
        }
    }

    override func keyDown(with event: NSEvent) {
        onKeyDown?(event)
    }

    override func swipe(with event: NSEvent) {
        print("🎯 [KeyInterceptingPanel] Swipe event received - deltaX: \(event.deltaX), deltaY: \(event.deltaY)")
        onSwipe?(event)
        super.swipe(with: event)
    }

    override func otherMouseDown(with event: NSEvent) {
        print("🖱️ [KeyInterceptingPanel] OtherMouseDown event received, button: \(event.buttonNumber)")
        onOtherMouseDown?(event)
        super.otherMouseDown(with: event)
    }

    override func scrollWheel(with event: NSEvent) {
        print("🎯 [KeyInterceptingPanel] ScrollWheel override - deltaY: \(event.deltaY), phase: \(event.phase.rawValue)")
        handleScrollWheel(event)
        super.scrollWheel(with: event)
    }
}

class WindowSwitcherPanelController: ObservableObject {
    var panel: KeyInterceptingPanel?
    var onWindowSelect: ((CGWindowID) -> Void)?
    var onCycleSelection: (() -> Void)?
    private var ignoreNextTab: Bool = false
    private var hostingController: NSHostingController<WindowSwitcherPanelView>?
    private var flagsChangedEventMonitor: Any?

    @Published var selectedItemID: CGWindowID?

    func show(items: [SwitcherItem]) {
        self.ignoreNextTab = true
        print("🖥️ WindowSwitcherPanelController: show() called with \(items.count) items.")
        if panel == nil {
            panel = KeyInterceptingPanel(
                contentRect: .zero,
                styleMask: [.borderless, .nonactivatingPanel],
                backing: .buffered,
                defer: false
            )
            panel?.isFloatingPanel = true
            panel?.level = .popUpMenu
            panel?.backgroundColor = .clear
            panel?.isOpaque = false
            panel?.hasShadow = true
            panel?.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
            panel?.hidesOnDeactivate = false

            panel?.onKeyDown = { [weak self] event in
                guard let self = self else { return }
                if event.keyCode == 48 {
                    if self.ignoreNextTab {
                        self.ignoreNextTab = false
                        return
                    }
                    self.onCycleSelection?()
                }
            }

            print("✅ WindowSwitcherPanelController: New panel created.")
        }

        guard let panel = panel, let screen = NSScreen.main else {
            print("🚫 WindowSwitcherPanelController: Panel or main screen not available, aborting show.")
            return
        }

        let contentView = WindowSwitcherPanelView(panelController: self, items: items) { [weak self] windowID in
            self?.onWindowSelect?(windowID)
        }

        if let hostingController = self.hostingController {
            hostingController.rootView = contentView
        } else {
            let newHostingController = NSHostingController(rootView: contentView)
            self.hostingController = newHostingController
            panel.contentViewController = newHostingController
        }

        let itemWidth: CGFloat = 220
        let spacing: CGFloat = 20

        let maxWidth = screen.frame.width * 0.8
        let finalWidth = min(maxWidth, (itemWidth + spacing) * CGFloat(items.count) + spacing)

        let columns = max(1, floor(finalWidth / (itemWidth + spacing)))

        let rows = ceil(CGFloat(items.count) / columns)

        let estimatedItemHeight = (itemWidth * 0.625) + 40
        let totalHeight = (rows * estimatedItemHeight) + ((rows - 1) * spacing) + (spacing * 2)
        let finalHeight = min(totalHeight, screen.frame.height * 0.8)

        let panelSize = CGSize(width: finalWidth, height: finalHeight)
        let origin = CGPoint(
            x: (screen.frame.width - panelSize.width) / 2,
            y: (screen.frame.height - panelSize.height) / 2
        )
        let finalFrame = CGRect(origin: origin, size: panelSize)

        if !panel.isVisible {
            let initialFrame = finalFrame.insetBy(dx: finalFrame.width * 0.05, dy: finalFrame.height * 0.05)
            panel.setFrame(initialFrame, display: false)
            panel.alphaValue = 0
            panel.makeKeyAndOrderFront(nil)
        }

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.25
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            panel.animator().alphaValue = 1.0
            panel.animator().setFrame(finalFrame, display: true)
        }

        startOptionKeyMonitor()
        print("✅ WindowSwitcherPanelController: Panel shown or updated.")
    }

    func hide(completion: (() -> Void)? = nil) {
        self.ignoreNextTab = false
        stopOptionKeyMonitor()
        guard let panel = panel, panel.isVisible, panel.alphaValue > 0 else {
            completion?()
            return
        }
        print("🙈 WindowSwitcherPanelController: Hiding panel.")

        let currentFrame = panel.frame
        let finalFrame = currentFrame.insetBy(dx: currentFrame.width * 0.05, dy: currentFrame.height * 0.05)

        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.2
            context.timingFunction = CAMediaTimingFunction(name: .easeIn)
            panel.animator().alphaValue = 0
            panel.animator().setFrame(finalFrame, display: true)
        }, completionHandler: {
            panel.orderOut(nil)
            panel.setFrame(currentFrame, display: false)
            completion?()
        })
    }

    var isVisible: Bool {
        panel?.isVisible ?? false
    }

    deinit {
        stopOptionKeyMonitor()
    }

    // MARK: - Option Key Monitoring (Event-Driven)

    private func startOptionKeyMonitor() {
        guard flagsChangedEventMonitor == nil else { return }
        flagsChangedEventMonitor = NSEvent.addGlobalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
            DispatchQueue.main.async {
                if !event.modifierFlags.contains(.option) {
                    self?.hide()
                }
            }
        }
    }

    private func stopOptionKeyMonitor() {
        if let monitor = flagsChangedEventMonitor {
            NSEvent.removeMonitor(monitor)
            flagsChangedEventMonitor = nil
        }
    }
}
