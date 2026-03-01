//
//  QuickPreviewPanelController.swift
//  Clippy
//

import AppKit
import SwiftUI
import CoreData

class QuickPreviewPanelController {
    static let shared = QuickPreviewPanelController()

    // Bug 1 fix: KeyInterceptingPanel (canBecomeKey = true, onKeyDown callback)
    private var panel: KeyInterceptingPanel?
    private var items: [ClipboardItemEntity] = []

    // Bug 3 fix: Hedef uygulamayı panel açılmadan önce kaydet
    private var previousApp: NSRunningApplication?

    // Bug 2 fix: Drag-drop auto-close için global monitor
    private var dragMonitor: Any?

    var isVisible: Bool {
        panel?.isVisible ?? false
    }

    private init() {}

    func toggle() {
        if isVisible {
            hide()
        } else {
            show()
        }
    }

    func show() {
        let settings = SettingsManager.shared
        guard settings.enableQuickPreview else { return }

        // Bug 3 fix: Hedef uygulamayı kaydet (panel açılmadan önce)
        previousApp = NSWorkspace.shared.frontmostApplication

        // Fetch latest items from CoreData
        let request = NSFetchRequest<ClipboardItemEntity>(entityName: "ClipboardItemEntity")
        request.sortDescriptors = [
            NSSortDescriptor(keyPath: \ClipboardItemEntity.isPinned, ascending: false),
            NSSortDescriptor(keyPath: \ClipboardItemEntity.date, ascending: false)
        ]
        request.predicate = NSPredicate(format: "(keyword == nil OR keyword == '') AND isFavorite == NO")
        request.fetchLimit = settings.quickPreviewItemCount

        let context = PersistenceController.shared.container.viewContext
        do {
            items = try context.fetch(request)
        } catch {
            return
        }

        guard !items.isEmpty else {
            return
        }

        if panel == nil {
            // Bug 1 fix: KeyInterceptingPanel kullan (NSPanel yerine)
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
            newPanel.hidesOnDeactivate = false

            // Disable global background dragging - header uses custom drag view
            newPanel.isMovableByWindowBackground = false

            // nonactivatingPanel'de ilk tıklamada Button'ların çalışması için
            newPanel.acceptsMouseMovedEvents = true

            // Bug 1 fix: Keyboard handler - KeyInterceptingPanel callback
            newPanel.onKeyDown = { [weak self] event in
                self?.handleKeyEvent(event)
            }

            self.panel = newPanel
        }

        guard let panel = panel else { return }

        let view = QuickPreviewPanelView(
            items: items,
            onPaste: { [weak self] item in
                self?.pasteAndClose(item: item)
            },
            onDismiss: { [weak self] in
                self?.hide()
            },
            onDragStarted: { [weak self] in
                self?.handleDragStarted()
            }
        )
        .environmentObject(settings)

        let hostingController = NSHostingController(rootView: view)
        hostingController.view.wantsLayer = true
        hostingController.view.layer?.backgroundColor = .clear

        // Wrap in a FirstClickView so clicks work immediately on nonactivatingPanel
        let wrapper = FirstClickView()
        wrapper.translatesAutoresizingMaskIntoConstraints = false
        let hostingView = hostingController.view
        hostingView.translatesAutoresizingMaskIntoConstraints = false
        wrapper.addSubview(hostingView)
        NSLayoutConstraint.activate([
            hostingView.topAnchor.constraint(equalTo: wrapper.topAnchor),
            hostingView.bottomAnchor.constraint(equalTo: wrapper.bottomAnchor),
            hostingView.leadingAnchor.constraint(equalTo: wrapper.leadingAnchor),
            hostingView.trailingAnchor.constraint(equalTo: wrapper.trailingAnchor)
        ])

        let wrapperController = NSViewController()
        wrapperController.view = wrapper
        panel.contentViewController = wrapperController

        positionPanel(panel)

        panel.alphaValue = 0
        panel.orderFront(nil)
        // Make key immediately so clicks and keyboard work from the start
        panel.makeKey()

        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.2
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            panel.animator().alphaValue = 1.0
        }, completionHandler: {
        })

    }

    // Bug 3 fix: completionHandler ile zamanlama düzeltme
    func hide(completion: (() -> Void)? = nil) {
        guard let panel = panel, panel.isVisible else {
            completion?()
            return
        }

        removeDragMonitor()

        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.15
            context.timingFunction = CAMediaTimingFunction(name: .easeIn)
            panel.animator().alphaValue = 0.0
        }, completionHandler: {
            panel.orderOut(nil)
            completion?()
        })

    }

    // MARK: - Paste & Close

    private func pasteAndClose(item: ClipboardItemEntity) {
        let clipboardItem = item.toClipboardItem()
        let targetApp = previousApp

        // Set pasteboard content BEFORE hiding, so it's ready when we paste
        let pb = NSPasteboard.general
        pb.clearContents()
        switch clipboardItem.contentType {
        case .text(let text):
            pb.setString(text, forType: .string)
        case .image(let path):
            if let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first {
                let imageURL = appSupport.appendingPathComponent("Clippy/Images").appendingPathComponent(path)
                if let image = NSImage(contentsOf: imageURL) {
                    pb.writeObjects([image])
                }
            }
        }
        pb.addTypes([PasteManager.pasteFromClippyType], owner: nil)

        // Hide panel, then activate target app and simulate Cmd+V
        hide {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                targetApp?.activate(options: .activateIgnoringOtherApps)

                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    guard AXIsProcessTrusted() else { return }
                    let source = CGEventSource(stateID: .hidSystemState)
                    let vKeyCode: CGKeyCode = 9
                    let cmdDown = CGEvent(keyboardEventSource: source, virtualKey: 0x37, keyDown: true)
                    cmdDown?.flags = .maskCommand
                    let vDown = CGEvent(keyboardEventSource: source, virtualKey: vKeyCode, keyDown: true)
                    vDown?.flags = .maskCommand
                    let vUp = CGEvent(keyboardEventSource: source, virtualKey: vKeyCode, keyDown: false)
                    vUp?.flags = .maskCommand
                    let cmdUp = CGEvent(keyboardEventSource: source, virtualKey: 0x37, keyDown: false)
                    cmdUp?.flags = .maskCommand
                    cmdDown?.post(tap: .cgAnnotatedSessionEventTap)
                    vDown?.post(tap: .cgAnnotatedSessionEventTap)
                    vUp?.post(tap: .cgAnnotatedSessionEventTap)
                    cmdUp?.post(tap: .cgAnnotatedSessionEventTap)
                }
            }
        }
    }

    // MARK: - Drag Handling (Bug 2 fix)

    private func handleDragStarted() {
        removeDragMonitor()

        // Use both global and local monitors to catch mouse-up after drag
        let globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseUp]) { [weak self] _ in
            self?.handleDragEnded()
        }
        let localMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseUp]) { [weak self] event in
            self?.handleDragEnded()
            return event
        }
        dragMonitor = (globalMonitor, localMonitor)
    }

    private func handleDragEnded() {
        guard isVisible else { return }
        removeDragMonitor()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            self?.hide()
        }
    }

    private func removeDragMonitor() {
        guard let monitors = dragMonitor else { return }
        if let tuple = monitors as? (Any?, Any?) {
            if let global = tuple.0 { NSEvent.removeMonitor(global) }
            if let local = tuple.1 { NSEvent.removeMonitor(local) }
        } else {
            NSEvent.removeMonitor(monitors)
        }
        dragMonitor = nil
    }

    // MARK: - Positioning

    private func positionPanel(_ panel: NSPanel) {
        let panelSize = panel.contentView?.fittingSize ?? NSSize(width: 340, height: 300)

        guard let screen = NSScreen.main else { return }
        let screenFrame = screen.visibleFrame

        // Center on screen
        let x = screenFrame.midX - (panelSize.width / 2)
        let y = screenFrame.midY - (panelSize.height / 2)

        panel.setFrame(NSRect(x: x, y: y, width: panelSize.width, height: panelSize.height), display: true)
    }

    // MARK: - Keyboard Handling

    private func handleKeyEvent(_ event: NSEvent) {
        // ESC to dismiss
        if event.keyCode == 53 {
            hide()
            return
        }

        // Number keys 1-9 to paste corresponding item
        if let characters = event.charactersIgnoringModifiers,
           let digit = characters.first?.wholeNumberValue,
           digit >= 1, digit <= 9 {
            let index = digit - 1
            if index < items.count {
                pasteAndClose(item: items[index])
            }
        }
    }
}

// MARK: - FirstClickView (accepts first mouse for nonactivatingPanel)

class FirstClickView: NSView {
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        return true
    }
}
