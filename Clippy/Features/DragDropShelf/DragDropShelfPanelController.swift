//
//  DragDropShelfPanelController.swift
//  Clippy
//

import AppKit
import SwiftUI
import Quartz

/// NSPanel subclass that can become key window for keyboard events
class KeyablePanel: NSPanel {
    override var canBecomeKey: Bool { true }
}

class DragDropShelfPanelController {
    static let shared = DragDropShelfPanelController()

    private var panel: KeyablePanel?
    private let viewModel = DragDropShelfViewModel()
    private var keyMonitor: Any?
    private var closeObserver: NSObjectProtocol?
    private let quickLookDelegate = ShelfQuickLookDelegate()
    private var lastExternalApp: NSRunningApplication?
    private var appObserver: NSObjectProtocol?

    var isVisible: Bool {
        panel?.isVisible ?? false
    }

    private init() {
        startAppObserver()
        viewModel.onPasteToApp = { [weak self] item in
            self?.pasteItemToExternalApp(item)
        }
    }

    func toggle() {
        if isVisible {
            hide()
        } else {
            show()
        }
    }

    func show() {
        guard SettingsManager.shared.enableDragDropShelf else { return }

        if panel == nil {
            let newPanel = KeyablePanel(
                contentRect: NSRect(x: 0, y: 0, width: 300, height: 420),
                styleMask: [.titled, .closable, .resizable, .nonactivatingPanel, .utilityWindow],
                backing: .buffered,
                defer: false
            )
            newPanel.title = "Shelf"
            newPanel.isFloatingPanel = true
            newPanel.level = .floating
            newPanel.isOpaque = false
            newPanel.backgroundColor = .clear
            newPanel.hasShadow = true
            newPanel.hidesOnDeactivate = false
            newPanel.isReleasedWhenClosed = false
            newPanel.minSize = NSSize(width: 260, height: 280)

            let shelfView = DragDropShelfView(viewModel: viewModel)
                .environmentObject(SettingsManager.shared)
            newPanel.contentView = NSHostingView(rootView: shelfView)

            // Position at right side of screen
            if let screen = NSScreen.main {
                let screenFrame = screen.visibleFrame
                let x = screenFrame.maxX - 310
                let y = screenFrame.midY - 210
                newPanel.setFrameOrigin(NSPoint(x: x, y: y))
            }

            // Observe panel close (red button) to clean up key monitor
            closeObserver = NotificationCenter.default.addObserver(
                forName: NSWindow.willCloseNotification,
                object: newPanel,
                queue: .main
            ) { [weak self] _ in
                self?.removeKeyMonitor()
            }

            panel = newPanel
        }

        panel?.orderFront(nil)
        installKeyMonitor()
    }

    func hide() {
        panel?.orderOut(nil)
        removeKeyMonitor()
    }

    func addFromClipboard() {
        viewModel.addFromPasteboard()
    }

    // MARK: - App Tracking (for double-click paste)

    private func startAppObserver() {
        appObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
                  app.bundleIdentifier != Bundle.main.bundleIdentifier else { return }
            self?.lastExternalApp = app
        }
    }

    private func pasteItemToExternalApp(_ item: ShelfItem) {
        // Copy item to clipboard
        viewModel.copyItemToClipboard(item)

        // Activate the last external app
        guard let app = lastExternalApp else { return }
        app.activate(options: [])

        // Simulate ⌘V after a short delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            let source = CGEventSource(stateID: .combinedSessionState)

            let vDown = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: true)
            vDown?.flags = .maskCommand
            vDown?.post(tap: .cghidEventTap)

            let vUp = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: false)
            vUp?.flags = .maskCommand
            vUp?.post(tap: .cghidEventTap)
        }
    }

    // MARK: - Keyboard Shortcuts

    private func installKeyMonitor() {
        guard keyMonitor == nil else { return }
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self, self.panel?.isKeyWindow == true else { return event }
            return self.handleKeyEvent(event) ? nil : event
        }
    }

    private func removeKeyMonitor() {
        if let monitor = keyMonitor {
            NSEvent.removeMonitor(monitor)
            keyMonitor = nil
        }
    }

    private func handleKeyEvent(_ event: NSEvent) -> Bool {
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)

        // ⌘A — Select All / Deselect All
        if flags == .command && event.charactersIgnoringModifiers == "a" {
            if viewModel.allSelected {
                viewModel.deselectAll()
            } else {
                viewModel.selectAll()
            }
            return true
        }

        // ⌘C — Copy Selected
        if flags == .command && event.charactersIgnoringModifiers == "c" {
            if !viewModel.selectedIDs.isEmpty {
                viewModel.copySelectedToClipboard()
            }
            return true
        }

        // ⌘Z — Undo
        if flags == .command && event.charactersIgnoringModifiers == "z" {
            if viewModel.canUndo {
                withAnimation(.easeInOut(duration: 0.2)) {
                    viewModel.undo()
                }
            }
            return true
        }

        // Delete / Backspace — Remove Selected
        if flags.isEmpty && (event.keyCode == 51 || event.keyCode == 117) {
            if !viewModel.selectedIDs.isEmpty {
                withAnimation(.easeInOut(duration: 0.2)) {
                    viewModel.removeSelected()
                }
            }
            return true
        }

        // Space — Quick Look
        if flags.isEmpty && event.keyCode == 49 {
            showQuickLook()
            return true
        }

        // Arrow Up
        if flags.isEmpty && event.keyCode == 126 {
            viewModel.moveFocusUp()
            return true
        }

        // Arrow Down
        if flags.isEmpty && event.keyCode == 125 {
            viewModel.moveFocusDown()
            return true
        }

        // Return / Enter — Toggle selection on focused item
        if flags.isEmpty && (event.keyCode == 36 || event.keyCode == 76) {
            viewModel.toggleFocusedSelection()
            return true
        }

        // Escape — Deselect all & clear focus
        if flags.isEmpty && event.keyCode == 53 {
            viewModel.deselectAll()
            viewModel.focusedID = nil
            return true
        }

        return false
    }

    // MARK: - Quick Look

    private func showQuickLook() {
        let urls = viewModel.quickLookURLs()
        guard !urls.isEmpty else { return }

        quickLookDelegate.urls = urls

        let qlPanel = QLPreviewPanel.shared()!
        qlPanel.dataSource = quickLookDelegate
        qlPanel.delegate = quickLookDelegate
        qlPanel.reloadData()
        qlPanel.makeKeyAndOrderFront(nil)
    }
}

// MARK: - Quick Look Delegate

class ShelfQuickLookDelegate: NSObject, QLPreviewPanelDataSource, QLPreviewPanelDelegate {
    var urls: [URL] = []

    func numberOfPreviewItems(in panel: QLPreviewPanel!) -> Int {
        urls.count
    }

    func previewPanel(_ panel: QLPreviewPanel!, previewItemAt index: Int) -> (any QLPreviewItem)! {
        urls[index] as NSURL
    }
}
