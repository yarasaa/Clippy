
//
//  PasteManager.swift
//  Clippy
//
//  Created by Mehmet Akbaba on 17.09.2025.
//


import AppKit

class PasteManager {
    static let shared = PasteManager()

    static let pasteFromClippyType = NSPasteboard.PasteboardType("com.yarasa.Clippy.paste")

    weak var statusBarController: StatusBarController?
    weak var clipboardMonitor: ClipboardMonitor?

    private init() {}

    func pasteText(_ text: String, into targetApp: NSRunningApplication? = nil, completion: (() -> Void)? = nil) {
        paste(using: {
            let pb = NSPasteboard.general
            pb.clearContents()
            pb.setString(text, forType: .string)
        }, targetApp: targetApp, completion: completion)
    }

    func pasteImage(_ image: NSImage, into targetApp: NSRunningApplication? = nil, completion: (() -> Void)? = nil) {
        paste(using: {
            let pb = NSPasteboard.general
            pb.clearContents()
            pb.writeObjects([image])
        }, targetApp: targetApp, completion: completion)
    }

    func pasteItem(_ item: ClipboardItem, into targetApp: NSRunningApplication? = nil, completion: (() -> Void)? = nil) {
        paste(using: {
            let pb = NSPasteboard.general
            pb.clearContents()
            switch item.contentType {
            case .text(let text):
                pb.setString(text, forType: .string)
            case .image(let path):
                if let image = self.loadImage(from: path) {
                    pb.writeObjects([image])
                }
            }
        }, targetApp: targetApp, completion: completion)
    }

    func deleteBackward(times: Int, completion: (() -> Void)? = nil) {
        guard AXIsProcessTrusted() else {
            (NSApp.delegate as? AppDelegate)?.requestAccessibilityPermissions()
            return
        }

        DispatchQueue.main.async {
            self.simulateKeyPress(keyCode: 0x33, count: times)
            completion?()
        }
    }

    func performPaste(completion: (() -> Void)? = nil) {
        paste(using: { }, targetApp: nil, completion: completion)
    }

    private func paste(using pasteBlock: @escaping () -> Void, targetApp: NSRunningApplication?, completion: (() -> Void)? = nil) {
        guard AXIsProcessTrusted() else {
            (NSApp.delegate as? AppDelegate)?.requestAccessibilityPermissions()
            return
        }

        let appToActivate = targetApp ?? NSWorkspace.shared.frontmostApplication

        statusBarController?.closePopover(sender: nil)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            pasteBlock()

            let generalPasteboard = NSPasteboard.general
            generalPasteboard.addTypes([PasteManager.pasteFromClippyType], owner: nil)

            appToActivate?.activate(options: .activateIgnoringOtherApps)

            let vKeyCode: CGKeyCode = 9
            let source = CGEventSource(stateID: .hidSystemState)

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

            completion?()
        }
    }

    private func simulateKeyPress(keyCode: CGKeyCode, count: Int) {
        let source = CGEventSource(stateID: .hidSystemState)
        for _ in 0..<count {
            let downEvent = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: true)
            let upEvent = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: false)
            downEvent?.post(tap: .cgAnnotatedSessionEventTap)
            upEvent?.post(tap: .cgAnnotatedSessionEventTap)
        }
    }

    private func loadImage(from path: String) -> NSImage? {
        guard let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            return nil
        }
        let imageURL = appSupport
            .appendingPathComponent("Clippy/Images")
            .appendingPathComponent(path)

        return NSImage(contentsOf: imageURL)
    }
}
