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
                self.onSwipe?(event)
            case .otherMouseDown:
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


        if abs(scrollAccumulator) > 20 {
            onSwipe?(event)
            scrollAccumulator = 0
        }
    }

    override func keyDown(with event: NSEvent) {
        onKeyDown?(event)
    }

    override func swipe(with event: NSEvent) {
        onSwipe?(event)
        super.swipe(with: event)
    }

    override func otherMouseDown(with event: NSEvent) {
        onOtherMouseDown?(event)
        super.otherMouseDown(with: event)
    }

    override func scrollWheel(with event: NSEvent) {
        handleScrollWheel(event)
        super.scrollWheel(with: event)
    }
}

class WindowSwitcherPanelController: ObservableObject {
    var panel: KeyInterceptingPanel?
    var onWindowSelect: ((CGWindowID) -> Void)?
    var onCycleSelection: (() -> Void)?
    /// Fires when the user releases the Option modifier — the gesture
    /// equivalent of "commit my selection" on a macOS Cmd+Tab switcher.
    /// Coordinator hooks this up to raise the selected window and close
    /// the panel.
    var onConfirmSelection: (() -> Void)?
    /// Shift+Tab — cycle backward through items.
    var onCyclePrevious: (() -> Void)?
    private var ignoreNextTab: Bool = false
    private var hostingController: NSHostingController<WindowSwitcherPanelView>?

    // Both global AND local monitors. NSEvent's global monitor doesn't
    // fire while OUR app is frontmost, which is exactly what happens
    // when the switcher panel becomes key — so option-release events
    // delivered to our process get silently dropped. The local monitor
    // catches those. Together they cover every focus state.
    private var flagsChangedGlobalMonitor: Any?
    private var flagsChangedLocalMonitor: Any?

    // Safety poll: if for any reason a flagsChanged event is dropped
    // (system load, focus weirdness, etc.) we still close the panel
    // within ~150ms by checking the modifier state directly.
    private var optionCheckTimer: Timer?

    @Published var selectedItemID: CGWindowID?

    func show(items: [SwitcherItem]) {
        self.ignoreNextTab = true
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

                switch event.keyCode {
                case 48:  // Tab — cycle forward (shift+tab → cycle backward)
                    if self.ignoreNextTab {
                        self.ignoreNextTab = false
                        return
                    }
                    if event.modifierFlags.contains(.shift) {
                        self.onCyclePrevious?()
                    } else {
                        self.onCycleSelection?()
                    }
                case 123, 126:  // Left arrow, Up arrow — previous
                    self.onCyclePrevious?()
                case 124, 125:  // Right arrow, Down arrow — next
                    self.onCycleSelection?()
                case 36, 76:  // Return / Enter — confirm selection
                    self.onConfirmSelection?()
                case 53:  // Escape — dismiss without raising
                    self.hide()
                default:
                    break
                }
            }

        }

        guard let panel = panel, let screen = NSScreen.main else {
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
            // Start: slight shrink + nudge down — Windows Alt+Tab rise-in feel
            var initialFrame = finalFrame
            initialFrame.size.width *= 0.93
            initialFrame.size.height *= 0.93
            initialFrame.origin.x += (finalFrame.width - initialFrame.width) / 2
            initialFrame.origin.y += (finalFrame.height - initialFrame.height) / 2 - 10
            panel.setFrame(initialFrame, display: false)
            panel.alphaValue = 0
            panel.makeKeyAndOrderFront(nil)
        }

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.28
            // Subtle overshoot — feels natural, not bouncy
            context.timingFunction = CAMediaTimingFunction(controlPoints: 0.34, 1.45, 0.64, 1.0)
            context.allowsImplicitAnimation = true
            panel.animator().alphaValue = 1.0
            panel.animator().setFrame(finalFrame, display: true)
        }

        startOptionKeyMonitor()
    }

    func hide(completion: (() -> Void)? = nil) {
        self.ignoreNextTab = false
        stopOptionKeyMonitor()
        guard let panel = panel, panel.isVisible, panel.alphaValue > 0 else {
            completion?()
            return
        }

        let currentFrame = panel.frame
        var finalFrame = currentFrame
        finalFrame.size.width *= 0.96
        finalFrame.size.height *= 0.96
        finalFrame.origin.x += (currentFrame.width - finalFrame.width) / 2
        finalFrame.origin.y += (currentFrame.height - finalFrame.height) / 2 - 6

        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.16
            context.timingFunction = CAMediaTimingFunction(controlPoints: 0.4, 0.0, 1.0, 1.0)
            context.allowsImplicitAnimation = true
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

    // MARK: - Option Key Monitoring (Event-Driven + Safety Poll)

    /// "Release Option to commit" is the gesture this switcher mimics
    /// (like Cmd+Tab on stock macOS). Two layers of detection ensure
    /// it actually fires every time:
    ///   1) Global + local NSEvent monitors for `.flagsChanged` — the
    ///      fast path, ~0ms latency. Local catches events delivered to
    ///      our own app (switcher panel is key), global catches the
    ///      ones delivered elsewhere. Either alone misses cases.
    ///   2) A 150ms safety poll that reads
    ///      `NSEvent.modifierFlags.contains(.option)` directly — used
    ///      whenever a flagsChanged event is dropped (system load,
    ///      focus weirdness, fast key release timing on race).
    /// When option is detected as released we call `confirmSelection`
    /// — raise the highlighted window — rather than just dismissing.
    private func startOptionKeyMonitor() {
        stopOptionKeyMonitor()  // defensive: never double-install

        let onRelease: (NSEvent.ModifierFlags) -> Void = { [weak self] flags in
            guard let self = self else { return }
            if !flags.contains(.option) {
                self.handleOptionReleased()
            }
        }

        flagsChangedGlobalMonitor = NSEvent.addGlobalMonitorForEvents(matching: .flagsChanged) { event in
            DispatchQueue.main.async { onRelease(event.modifierFlags) }
        }
        flagsChangedLocalMonitor = NSEvent.addLocalMonitorForEvents(matching: .flagsChanged) { event in
            DispatchQueue.main.async { onRelease(event.modifierFlags) }
            return event
        }

        // Belt-and-braces poll. 150ms is fast enough to feel
        // instant, slow enough to be CPU-invisible.
        optionCheckTimer = Timer.scheduledTimer(withTimeInterval: 0.15, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            if !NSEvent.modifierFlags.contains(.option) {
                self.handleOptionReleased()
            }
        }
    }

    private func stopOptionKeyMonitor() {
        if let monitor = flagsChangedGlobalMonitor {
            NSEvent.removeMonitor(monitor)
            flagsChangedGlobalMonitor = nil
        }
        if let monitor = flagsChangedLocalMonitor {
            NSEvent.removeMonitor(monitor)
            flagsChangedLocalMonitor = nil
        }
        optionCheckTimer?.invalidate()
        optionCheckTimer = nil
    }

    private func handleOptionReleased() {
        // Stop monitors immediately so we don't fire multiple times
        // when global + local + poll race each other on the same event.
        stopOptionKeyMonitor()
        if let onConfirmSelection = onConfirmSelection {
            onConfirmSelection()
        } else {
            // No handler wired — fall back to plain dismissal.
            hide()
        }
    }
}
