//
//  AppDelegate.swift
//  Clippy
//
//  Created by Mehmet Akbaba on 17.09.2025.
//

import AppKit
import SwiftUI
import HotKey
import Combine

class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    var statusBarController: StatusBarController?
    var settingsWindow: NSWindow?
    var clipboardMonitor: ClipboardMonitor?
    var keywordManager: KeywordExpansionManager?
    var editorWindow: NSWindow?
    var pasteAllHotKey: HotKey?
    var hotKey: HotKey?
    var sequentialCopyHotKey: HotKey?
    var sequentialPasteHotKey: HotKey?
    var clearQueueHotKey: HotKey?
    private var cancellables = Set<AnyCancellable>()

    func applicationDidFinishLaunching(_ notification: Notification) {
        clipboardMonitor = ClipboardMonitor()
        keywordManager = KeywordExpansionManager()
        
        if SettingsManager.shared.isKeywordExpansionEnabled {
            keywordManager?.startMonitoring()
        }
        clipboardMonitor?.startMonitoring()

        statusBarController = StatusBarController(clipboardMonitor: clipboardMonitor!)

        PasteManager.shared.statusBarController = statusBarController
        PasteManager.shared.clipboardMonitor = clipboardMonitor
        
        checkAccessibilityPermissions()
        
        createMenu()
        
        setupHotkey()
        
        NSWorkspace.shared.notificationCenter.addObserver(self, selector: #selector(systemDidWake), name: NSWorkspace.didWakeNotification, object: nil)

    }
    
    func setupHotkey() {
        let settings = SettingsManager.shared

        settings.objectWillChange
            .receive(on: DispatchQueue.main)
            .debounce(for: .milliseconds(100), scheduler: RunLoop.main)
            .sink { [weak self] _ in
                self?.updateAllHotkeys()
                
                if settings.isKeywordExpansionEnabled {
                    self?.keywordManager?.startMonitoring()
                } else {
                    self?.keywordManager?.stopMonitoring()
                }
            }
            .store(in: &cancellables)

        // Başlangıçta tüm kısayolları ayarla.
        updateAllHotkeys()
    }

    private func updateAllHotkeys() {
        updateHotkey()
        updatePasteAllHotkey()
        updateSequentialCopyHotkey()
        updateSequentialPasteHotkey()
        updateClearQueueHotkey()
    }

    /// Sistem uyku modundan çıktığında çağrılır.
    @objc private func systemDidWake(notification: NSNotification) {
        print("💤 Sistem uyandı. Monitörler ve kısayollar yeniden başlatılıyor...")

        // Pano izleyicisini yeniden başlat.
        clipboardMonitor?.stopMonitoring()
        clipboardMonitor?.startMonitoring()

        // Anahtar kelime yöneticisini yeniden başlat (eğer ayarlarda açıksa).
        keywordManager?.stopMonitoring()
        if SettingsManager.shared.isKeywordExpansionEnabled {
            keywordManager?.startMonitoring()
        }

        // Tüm klavye kısayollarını yeniden kaydet.
        updateAllHotkeys()
    }
    func applicationWillTerminate(_ notification: Notification) {
        // Arka planda çalışan kaydetme zamanlayıcısını durdur.
        clipboardMonitor?.stopMonitoring()
        keywordManager?.stopMonitoring() // Dinlemeyi durdur
        // Bekleyen değişiklikleri SENKRON olarak kaydet.
        clipboardMonitor?.saveContext()
    }
    
    func updateHotkey() {
        let settings = SettingsManager.shared
        guard !settings.hotkeyKey.isEmpty, let key = Key(string: settings.hotkeyKey.lowercased()) else {
            print("Geçersiz kısayol tuşu: \(settings.hotkeyKey)")
            return
        }
        let modifiers = NSEvent.ModifierFlags(rawValue: settings.hotkeyModifiers)

        hotKey = nil
        
        hotKey = HotKey(key: key, modifiers: modifiers)
        hotKey?.keyDownHandler = { [weak self] in
            self?.statusBarController?.togglePopover(nil)
        }
        
        print("✅ Kısayol güncellendi: \(modifiers) + \(key)")
    }
    
    func updatePasteAllHotkey() {
        let settings = SettingsManager.shared
        guard !settings.pasteAllHotkeyKey.isEmpty, let key = Key(string: settings.pasteAllHotkeyKey.lowercased()) else {
            print("Geçersiz 'Tümünü Yapıştır' kısayol tuşu: \(settings.pasteAllHotkeyKey)")
            return
        }
        let modifiers = NSEvent.ModifierFlags(rawValue: settings.pasteAllHotkeyModifiers)

        pasteAllHotKey = nil
        
        pasteAllHotKey = HotKey(key: key, modifiers: modifiers)
        pasteAllHotKey?.keyDownHandler = { [weak self] in
            guard let self = self, let monitor = self.clipboardMonitor, !monitor.selectedItemIDs.isEmpty else { return }
            monitor.copySelectionToClipboard()
            PasteManager.shared.performPaste {
                monitor.clearSelection()
            }
        }
        
        print("✅ 'Tümünü Yapıştır' kısayolu güncellendi: \(modifiers) + \(key)")
    }
    
    func updateSequentialCopyHotkey() {
        let settings = SettingsManager.shared
        guard !settings.sequentialCopyHotkeyKey.isEmpty, let key = Key(string: settings.sequentialCopyHotkeyKey.lowercased()) else {
            return
        }
        let modifiers = NSEvent.ModifierFlags(rawValue: settings.sequentialCopyHotkeyModifiers)
        
        sequentialCopyHotKey = nil
        sequentialCopyHotKey = HotKey(key: key, modifiers: modifiers)
        sequentialCopyHotKey?.keyDownHandler = { [weak self] in
            self?.clipboardMonitor?.prepareForSequentialCopy()
            let source = CGEventSource(stateID: .hidSystemState)
            let cKeyDown = CGEvent(keyboardEventSource: source, virtualKey: 0x08, keyDown: true)
            cKeyDown?.flags = .maskCommand
            let cKeyUp = CGEvent(keyboardEventSource: source, virtualKey: 0x08, keyDown: false)
            cKeyUp?.flags = .maskCommand
            cKeyDown?.post(tap: .cgAnnotatedSessionEventTap)
            cKeyUp?.post(tap: .cgAnnotatedSessionEventTap)
        }
        
        print("✅ 'Sıraya Ekle' kısayolu güncellendi: \(modifiers) + \(key)")
    }
    
    func updateSequentialPasteHotkey() {
        let settings = SettingsManager.shared
        guard !settings.sequentialPasteHotkeyKey.isEmpty, let key = Key(string: settings.sequentialPasteHotkeyKey.lowercased()) else {
            return
        }
        let modifiers = NSEvent.ModifierFlags(rawValue: settings.sequentialPasteHotkeyModifiers)
        
        sequentialPasteHotKey = nil
        sequentialPasteHotKey = HotKey(key: key, modifiers: modifiers)
        sequentialPasteHotKey?.keyDownHandler = { [weak self] in
            guard let self = self, let monitor = self.clipboardMonitor else { return }
            
            monitor.pasteNextInSequence() {
            }
        }
        
        print("✅ 'Sıradakini Yapıştır' kısayolu güncellendi: \(modifiers) + \(key)")
    }
    
    func updateClearQueueHotkey() {
        let settings = SettingsManager.shared
        guard !settings.clearQueueHotkeyKey.isEmpty, let key = Key(string: settings.clearQueueHotkeyKey.lowercased()) else {
            return
        }
        let modifiers = NSEvent.ModifierFlags(rawValue: settings.clearQueueHotkeyModifiers)
        
        clearQueueHotKey = nil
        clearQueueHotKey = HotKey(key: key, modifiers: modifiers)
        clearQueueHotKey?.keyDownHandler = { [weak self] in
            self?.clipboardMonitor?.clearSequentialPasteQueue()
        }
        print("✅ 'Sıralı Kuyruğu Temizle' kısayolu güncellendi: \(modifiers) + \(key)")
    }
}

extension AppDelegate {
    func checkAccessibilityPermissions() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
        let _ = AXIsProcessTrustedWithOptions(options as CFDictionary)
    }
    
    func createMenu() {
        let menu = NSMenu()
        
        // Ayarlar menü öğesi
        let settingsItem = NSMenuItem(title: L("Settings...", settings: SettingsManager.shared), action: #selector(openSettings), keyEquivalent: ",")
        settingsItem.target = self
        menu.addItem(settingsItem)

        menu.addItem(NSMenuItem.separator())

        // Anahtar Kelime Genişletme'yi Duraklat/Başlat menü öğesi
        let toggleKeywordExpansionItem = NSMenuItem(title: "Toggle Keyword Expansion", action: #selector(toggleKeywordExpansion), keyEquivalent: "")
        toggleKeywordExpansionItem.target = self
        menu.addItem(toggleKeywordExpansionItem)
        
        // Sıralı Yapıştırma Kuyruğunu Temizle menü öğesi
        let clearQueueItem = NSMenuItem(title: L("Clear Sequential Queue", settings: SettingsManager.shared), action: #selector(clearSequentialQueue), keyEquivalent: "")
        clearQueueItem.target = self
        menu.addItem(clearQueueItem)

        
        menu.addItem(NSMenuItem.separator())
        
        menu.addItem(withTitle: L("Quit Clippy", settings: SettingsManager.shared), action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        
        statusBarController?.rightClickMenu = menu
        menu.delegate = self
    }
    
    @objc func openSettings() {
        if settingsWindow == nil {
            let settingsView = SettingsView()
                .environmentObject(SettingsManager.shared)
            settingsWindow = NSWindow(contentViewController: NSHostingController(rootView: settingsView))
            settingsWindow?.title = L("Clippy Settings", settings: SettingsManager.shared)
            settingsWindow?.styleMask = [.titled, .closable, .resizable]
            settingsWindow?.setContentSize(NSSize(width: 500, height: 380))
        }
        settingsWindow?.center()
        settingsWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    
    @objc func clearSequentialQueue() {
        clipboardMonitor?.clearSequentialPasteQueue()
    }

    @objc func toggleKeywordExpansion() {
        keywordManager?.toggleMonitoring()
    }

    func showImageEditor(with image: NSImage) {
        if let existingWindow = editorWindow, existingWindow.isVisible {
            existingWindow.makeKeyAndOrderFront(nil)
            return
        }

        let editorView = ImageEditorView(image: image) { editedImage in
            let pasteboard = NSPasteboard.general
            pasteboard.clearContents()
            pasteboard.writeObjects([editedImage])
            self.editorWindow?.close()
        }
        .environmentObject(SettingsManager.shared)

        let hostingController = NSHostingController(rootView: editorView)
        let window = NSWindow(contentViewController: hostingController)
        window.styleMask = [.titled, .closable, .miniaturizable, .resizable]
        window.title = "Edit Image"
        window.center()
        window.makeKeyAndOrderFront(nil)

        window.delegate = self
        self.editorWindow = window
    }
}

extension AppDelegate: NSWindowDelegate, NSMenuItemValidation {
    func windowWillClose(_ notification: Notification) {
        if (notification.object as? NSWindow) == editorWindow {
            editorWindow = nil
        }
    }

    func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        if menuItem.action == #selector(toggleKeywordExpansion) {
            guard SettingsManager.shared.isKeywordExpansionEnabled else { return false }
            
            menuItem.title = (keywordManager?.isEnabled ?? false) ? L("Pause Keyword Expansion", settings: SettingsManager.shared) : L("Resume Keyword Expansion", settings: SettingsManager.shared)
        }
        return true
    }
}
