
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
            (NSApp.delegate as? AppDelegate)?.checkAccessibilityPermissions()
            return
        }
        
        DispatchQueue.main.async {
            self.simulateKeyPress(keyCode: 0x33, count: times)
            completion?()
        }
    }

    func performPaste(completion: (() -> Void)? = nil) {
        paste(using: { /* Panoyu değiştirme, sadece yapıştır */ }, targetApp: nil, completion: completion)
    }

    // Ortak yapıştırma mantığı
    private func paste(using pasteBlock: @escaping () -> Void, targetApp: NSRunningApplication?, completion: (() -> Void)? = nil) {
        guard AXIsProcessTrusted() else {
            print("Erişilebilirlik izni yok. Yapıştırma işlemi engellendi.")
            (NSApp.delegate as? AppDelegate)?.checkAccessibilityPermissions()
            return
        }

        // Eğer özel bir hedef uygulama belirtilmediyse, o anki aktif uygulamayı kullan.
        let appToActivate = targetApp ?? NSWorkspace.shared.frontmostApplication

        statusBarController?.closePopover(sender: nil)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            pasteBlock()
            
            let generalPasteboard = NSPasteboard.general
            generalPasteboard.addTypes([PasteManager.pasteFromClippyType], owner: nil)
            
            // Yapıştırmadan hemen önce, asıl uygulamayı tekrar öne getir.
            appToActivate?.activate(options: .activateIgnoringOtherApps)
            
            let vKeyCode: CGKeyCode = 9
            let source = CGEventSource(stateID: .hidSystemState)
            
            // 1. Command tuşuna bas
            let cmdDown = CGEvent(keyboardEventSource: source, virtualKey: 0x37, keyDown: true) // 0x37 = kVK_Command
            cmdDown?.flags = .maskCommand
            
            // 2. V tuşuna bas
            let vDown = CGEvent(keyboardEventSource: source, virtualKey: vKeyCode, keyDown: true)
            vDown?.flags = .maskCommand

            // 3. V tuşunu bırak
            let vUp = CGEvent(keyboardEventSource: source, virtualKey: vKeyCode, keyDown: false)
            vUp?.flags = .maskCommand
            
            // 4. Command tuşunu bırak
            let cmdUp = CGEvent(keyboardEventSource: source, virtualKey: 0x37, keyDown: false)
            cmdUp?.flags = .maskCommand
            
            // Tüm olayları sırayla gönder
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