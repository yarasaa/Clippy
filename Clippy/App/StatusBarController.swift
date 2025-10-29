//
//  StatusBarController.swift
//  Clippy
//
//  Created by Mehmet Akbaba on 17.09.2025.
//

import AppKit
import SwiftUI
import Combine

extension Notification.Name {
    static let closeClippyPopover = Notification.Name("com.yarasa.Clippy.closePopover")
}

class StatusBarController: NSObject, NSPopoverDelegate {
    private var statusItem: NSStatusItem
    var popover: NSPopover
    private var clipboardMonitor: ClipboardMonitor
    var rightClickMenu: NSMenu?
    private var cancellables = Set<AnyCancellable>()
    private var eventMonitor: Any?
    private var isRecording = false

    init(clipboardMonitor: ClipboardMonitor) {
        self.clipboardMonitor = clipboardMonitor
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        popover = NSPopover()
        super.init()        


        let hostingController = NSHostingController(rootView:
            ContentView()
                .environment(\.managedObjectContext, PersistenceController.shared.container.viewContext)
                .environmentObject(clipboardMonitor)
                .environmentObject(SettingsManager.shared)
        )
        popover.contentViewController = hostingController
        popover.behavior = .semitransient
        
        let settings = SettingsManager.shared
        popover.contentSize = NSSize(width: settings.popoverWidth, height: settings.popoverHeight)

        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "doc.on.clipboard", accessibilityDescription: "Clippy")
            button.action = #selector(togglePopover(_:))
            button.target = self
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }
        popover.delegate = self
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleClosePopoverNotification),
            name: .closeClippyPopover,
            object: nil)
        
        eventMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
            guard let self = self, self.popover.isShown else { return }
            
            if let popoverWindow = self.popover.contentViewController?.view.window {
                let popoverFrame = popoverWindow.frame
                if !popoverFrame.contains(event.locationInWindow) {
                    self.popover.performClose(nil)
                }
            }
        }
        
        // ClipboardMonitor'daki değişiklikleri dinle ve ikonu güncelle.
        setupBindings()
    }
    
    private func setupBindings() {
        clipboardMonitor.$isPastingFromQueue
            .combineLatest(clipboardMonitor.$sequentialPasteIndex, clipboardMonitor.$sequentialPasteQueueIDs)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _, _, _ in
                self?.updateStatusItem()
            }
            .store(in: &cancellables)
        
        SettingsManager.shared.objectWillChange.receive(on: DispatchQueue.main).sink { [weak self] _ in
            self?.updatePopoverSize()
                self?.updateStatusItem()
            }
            .store(in: &cancellables)
    }
    
    private func updateStatusItem() {
        guard let button = statusItem.button else { return }

        // Öncelik sırası: Kayıt > Yapıştırma > Normal
        if isRecording {
            button.image = NSImage(systemSymbolName: "record.circle.fill", accessibilityDescription: "Recording")
            button.title = ""
            // Kırmızı renk uygula
            if let image = button.image {
                image.isTemplate = false
                let tinted = NSImage(size: image.size, flipped: false) { rect in
                    NSColor.systemRed.setFill()
                    rect.fill()
                    image.draw(in: rect)
                    return true
                }
                button.image = tinted
            }
        } else {
            let isPasting = clipboardMonitor.isPastingFromQueue
            button.image = NSImage(systemSymbolName: isPasting ? "list.clipboard.fill" : "doc.on.clipboard", accessibilityDescription: "Clippy")
            button.title = isPasting ? " \(clipboardMonitor.sequentialPasteIndex)/\(clipboardMonitor.sequentialPasteQueueIDs.count)" : ""
        }
    }

    /// Kayıt durumunu günceller ve ikonu değiştirir
    func updateRecordingState(isRecording: Bool) {
        self.isRecording = isRecording
        updateStatusItem()
    }

    private func updatePopoverSize() {
        let settings = SettingsManager.shared
        popover.contentSize = NSSize(width: settings.popoverWidth, height: settings.popoverHeight)
    }
    
    @objc func togglePopover(_ sender: AnyObject?) {
        guard let button = statusItem.button else { return }
        
        if let event = NSApp.currentEvent, event.type == .rightMouseUp {
            if let menu = rightClickMenu {
                menu.popUp(positioning: nil, at: NSEvent.mouseLocation, in: nil)
            }
            return
        }

        if popover.isShown {
            popover.performClose(sender)
        } else {
            clipboardMonitor.navigationPath = NavigationPath()
            self.popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        }
    }

    func closePopover(sender: Any?) {
        popover.performClose(sender)
    }

    @objc private func handleClosePopoverNotification() {
        self.closePopover(sender: nil)
    }

    func popoverDidClose(_ notification: Notification) {
        clipboardMonitor.navigationPath = NavigationPath()
    }

    func closePopoverAfterDrag() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.closePopover(sender: nil)
        }
    }
}
