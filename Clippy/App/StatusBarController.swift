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
    private var eventMonitor: Any?

    init(clipboardMonitor: ClipboardMonitor) {
        self.clipboardMonitor = clipboardMonitor
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        popover = NSPopover()
        super.init()
        popover.behavior = .semitransient
        popover.contentSize = NSSize(width: 360, height: 420)


        let hostingController = NSHostingController(rootView:
            ContentView()
                .environment(\.managedObjectContext, PersistenceController.shared.container.viewContext)
                .environmentObject(clipboardMonitor)
                .environmentObject(SettingsManager.shared)
        )
        popover.contentViewController = hostingController

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
