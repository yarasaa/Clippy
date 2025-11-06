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
    var aboutWindow: NSWindow?
    var detailWindow: NSWindow?
    var diffWindow: NSWindow?
    var clipboardMonitor: ClipboardMonitor?
    var parameterWindow: NSWindow?
    var keywordManager: KeywordExpansionManager?
    var screenshotEditorWindow: NSWindow?
    var editorWindow: NSWindow?
    var pasteAllHotKey: HotKey?
    var hotKey: HotKey?
    var sequentialCopyHotKey: HotKey?
    var sequentialPasteHotKey: HotKey?
    var clearQueueHotKey: HotKey?
    var screenshotHotKey: HotKey?
    
    private var cancellables = Set<AnyCancellable>()

    func applicationDidFinishLaunching(_ notification: Notification) {
        clipboardMonitor = ClipboardMonitor()
        keywordManager = KeywordExpansionManager()
        keywordManager?.appDelegate = self
        keywordManager?.startMonitoring()
        clipboardMonitor?.startMonitoring()

        statusBarController = StatusBarController(clipboardMonitor: clipboardMonitor!)
        clipboardMonitor?.appDelegate = self

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
            .sink { [weak self] in
                self?.updateAllHotkeys()
                self?.toggleKeywordExpansion() // Ayar değiştiğinde durumu kontrol et.
                self?.recreateUIForLanguageChange()
            }
            .store(in: &cancellables)

        // Başlangıçta tüm kısayolları ayarla.
        updateAllHotkeys()
    }

    @objc private func recreateUIForLanguageChange() {
        createMenu()
    }
    
    private func updateAllHotkeys() {
        updateHotkey()
        updatePasteAllHotkey()
        updateSequentialCopyHotkey()
        updateSequentialPasteHotkey()
        updateClearQueueHotkey()
        updateScreenshotHotkey()
    }

    /// Sistem uyku modundan çıktığında çağrılır.
    @objc private func systemDidWake(notification: NSNotification) {
        print("💤 Sistem uyandı. Monitörler ve kısayollar yeniden başlatılıyor...")

        // Pano izleyicisini yeniden başlat.
        clipboardMonitor?.stopMonitoring()
        clipboardMonitor?.startMonitoring()

        // Anahtar kelime yöneticisini yeniden başlat (eğer ayarlarda açıksa).
        toggleKeywordExpansion()
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

    func updateScreenshotHotkey() {
        let settings = SettingsManager.shared
        guard !settings.screenshotHotkeyKey.isEmpty, let key = Key(string: settings.screenshotHotkeyKey.lowercased()) else {
            print("Geçersiz 'Ekran Görüntüsü Al' kısayol tuşu: \(settings.screenshotHotkeyKey)")
            screenshotHotKey = nil
            return
        }
        let modifiers = NSEvent.ModifierFlags(rawValue: settings.screenshotHotkeyModifiers)

        screenshotHotKey = nil
        screenshotHotKey = HotKey(key: key, modifiers: modifiers)
        screenshotHotKey?.keyDownHandler = { [weak self] in
            self?.takeScreenshot()
        }
        print("✅ 'Ekran Görüntüsü Al' kısayolu güncellendi: \(modifiers) + \(key)")
    }
    
    private func createMenu() {
        let menu = NSMenu()
        
        // Hakkında menü öğesi
        let aboutItem = NSMenuItem(title: L("About Clippy", settings: SettingsManager.shared), action: #selector(openAbout), keyEquivalent: "")
        aboutItem.target = self
        menu.addItem(aboutItem)

        menu.addItem(NSMenuItem.separator())

        // Screenshot menü öğeleri
        let captureAreaItem = NSMenuItem(title: L("Capture Area", settings: SettingsManager.shared), action: #selector(captureArea), keyEquivalent: "")
        captureAreaItem.target = self
        menu.addItem(captureAreaItem)

        let captureScreenItem = NSMenuItem(title: L("Capture Screen", settings: SettingsManager.shared), action: #selector(captureFullScreen), keyEquivalent: "")
        captureScreenItem.target = self
        menu.addItem(captureScreenItem)

        let captureWindowItem = NSMenuItem(title: L("Capture Window", settings: SettingsManager.shared), action: #selector(captureWindow), keyEquivalent: "")
        captureWindowItem.target = self
        menu.addItem(captureWindowItem)

        let captureDelayedItem = NSMenuItem(title: L("Delayed Screenshot (3s)", settings: SettingsManager.shared), action: #selector(captureDelayed), keyEquivalent: "")
        captureDelayedItem.target = self
        menu.addItem(captureDelayedItem)

        menu.addItem(NSMenuItem.separator())

        // Ayarlar menü öğesi
        let settingsItem = NSMenuItem(title: L("Settings", settings: SettingsManager.shared), action: #selector(openSettings), keyEquivalent: ",")
        settingsItem.target = self
        menu.addItem(settingsItem)

        menu.addItem(NSMenuItem.separator())

        // Anahtar Kelime Genişletme'yi Duraklat/Başlat menü öğesi
        let toggleKeywordExpansionItem = NSMenuItem(title: L("Toggle Keyword Expansion", settings: SettingsManager.shared), action: #selector(toggleKeywordExpansion), keyEquivalent: "")
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
        // Eğer pencere zaten varsa, öne getir ve uygulamayı aktive et.
        if let window = settingsWindow {
            if window.isMiniaturized { window.deminiaturize(nil) }
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        // Yoksa yeni bir pencere oluştur.
        let settingsView = SettingsView()
            .environmentObject(SettingsManager.shared)
        let window = NSWindow(contentViewController: NSHostingController(rootView: settingsView))
        window.title = L("Clippy Settings", settings: SettingsManager.shared)
        window.styleMask = [.titled, .closable, .resizable]
        window.delegate = self
        window.setContentSize(NSSize(width: 500, height: 380))
        window.center()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        self.settingsWindow = window
    }
    
    @objc func openAbout() {
        // Eğer pencere zaten varsa, öne getir ve uygulamayı aktive et.
        if let window = aboutWindow {
            if window.isMiniaturized { window.deminiaturize(nil) }
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        // Yoksa yeni bir pencere oluştur.
        let aboutView = AboutView()
            .environmentObject(SettingsManager.shared)
        let window = NSWindow(contentViewController: NSHostingController(rootView: aboutView))
        window.title = L("About Clippy", settings: SettingsManager.shared)
        window.styleMask = [.titled, .closable]
        window.delegate = self
        window.setContentSize(NSSize(width: 320, height: 280))
        window.center()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        self.aboutWindow = window
    }
    
    @objc func clearSequentialQueue() {
        clipboardMonitor?.clearSequentialPasteQueue()
    }

    @objc func toggleKeywordExpansion() {
        // Ayarlardaki değere göre monitörü başlat veya durdur.
        let settings = SettingsManager.shared
        settings.isKeywordExpansionEnabled ? keywordManager?.startMonitoring() : keywordManager?.stopMonitoring()
    }
    
    func showDetailWindow(for item: ClipboardItemEntity) {
        // Mevcut bir detay penceresi varsa kapat.
        detailWindow?.close()
        detailWindow = nil

        let detailView = ClipboardDetailView(item: item, monitor: clipboardMonitor!)
            .environmentObject(SettingsManager.shared)

        let hostingController = NSHostingController(rootView: detailView)
        let window = NSWindow(contentViewController: hostingController)
        
        // Ana popover penceresini al
        guard let mainPopoverWindow = statusBarController?.popover.contentViewController?.view.window else {
            print("❌ Ana popover penceresi bulunamadı.")
            return
        }

        // Detay penceresini ana pencerenin bir alt penceresi yap.
        mainPopoverWindow.addChildWindow(window, ordered: .above)

        window.title = L("Detail", settings: SettingsManager.shared)
        window.styleMask = [.titled, .closable, .miniaturizable, .resizable]
        window.delegate = self
        window.center()
        
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true) // Pencerenin öne gelmesini garantiler.
        
        self.detailWindow = window
    }

    func showDiffWindow(oldText: String, newText: String) {
        // Mevcut bir diff penceresi varsa kapat.
        diffWindow?.close()
        diffWindow = nil

        let diffView = DiffView(oldText: oldText, newText: newText)
            .environmentObject(SettingsManager.shared)
            .environmentObject(clipboardMonitor!)

        let hostingController = NSHostingController(rootView: diffView)
        let window = NSWindow(contentViewController: hostingController)
        
        // Ana popover penceresini al
        guard let mainPopoverWindow = statusBarController?.popover.contentViewController?.view.window else {
            print("❌ Ana popover penceresi bulunamadı.")
            return
        }

        // Diff penceresini ana pencerenin bir alt penceresi yap.
        mainPopoverWindow.addChildWindow(window, ordered: .above)

        window.title = L("Compare Differences", settings: SettingsManager.shared)
        window.styleMask = [.titled, .closable, .miniaturizable, .resizable]
        window.delegate = self
        window.center()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        self.diffWindow = window
    }

    func checkAccessibilityPermissions() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
        let _ = AXIsProcessTrustedWithOptions(options as CFDictionary)
    }
    
    func showParameterInputDialog(parameters: [String], completion: @escaping ([String: String]?) -> Void) {
        parameterWindow?.close()

        let parameterView = ParameterInputView(
            parameters: parameters,
            onConfirm: { values in
                self.parameterWindow?.close()
                completion(values)
            },
            onCancel: {
                self.parameterWindow?.close()
                completion(nil)
            }
        )
        .environmentObject(SettingsManager.shared)

        let window = NSWindow(contentViewController: NSHostingController(rootView: parameterView))
        window.title = L("Enter Snippet Values", settings: SettingsManager.shared)
        window.styleMask = [.titled, .closable]
        window.delegate = self
        window.center()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        self.parameterWindow = window
    }
    
    func showScreenshotEditor(with image: NSImage) {
        if let existingWindow = screenshotEditorWindow, existingWindow.isVisible {
            existingWindow.makeKeyAndOrderFront(nil)
            return
        }

        let editorView = ScreenshotEditorView(image: image, clipboardMonitor: self.clipboardMonitor!)
            .environmentObject(SettingsManager.shared)

        let hostingController = NSHostingController(rootView: editorView)
        let window = NSWindow(contentViewController: hostingController)
        
        // Modern, çerçevesiz bir pencere stili uygula
        window.styleMask = [NSWindow.StyleMask.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView]
        window.isOpaque = true
        window.backgroundColor = NSColor.windowBackgroundColor
        window.hasShadow = true
        window.titlebarAppearsTransparent = true
        window.titleVisibility = NSWindow.TitleVisibility.hidden
        window.title = "Screenshot Editor"
        
        // Görüntü için makul bir başlangıç boyutu hesapla.
        let padding: CGFloat = 80 // Kenar boşlukları
        let toolbarHeight: CGFloat = 60 // Toolbar yüksekliği

        // Ekran boyutunu al
        var desiredSize = NSSize(width: image.size.width + padding, height: image.size.height + padding + toolbarHeight)

        // Pencerenin ekran boyutunu aşmamasını sağla ve aspect ratio'yu koru
        if let screenFrame = NSScreen.main?.visibleFrame {
            let maxW = screenFrame.width * 0.9
            let maxH = screenFrame.height * 0.9

            // Eğer görüntü ekrandan büyükse, aspect ratio'yu koruyarak küçült
            if desiredSize.width > maxW || desiredSize.height > maxH {
                let imageAspectRatio = image.size.width / image.size.height

                // Genişlik sınırlaması
                if desiredSize.width > maxW {
                    desiredSize.width = maxW
                    desiredSize.height = (maxW - padding) / imageAspectRatio + padding + toolbarHeight
                }

                // Yükseklik hala çok büyükse
                if desiredSize.height > maxH {
                    desiredSize.height = maxH
                    desiredSize.width = (maxH - padding - toolbarHeight) * imageAspectRatio + padding
                }
            }
        }
        window.setContentSize(desiredSize)
        
        window.center()
        window.makeKeyAndOrderFront(self)
        window.delegate = self
        self.screenshotEditorWindow = window
    }
    
    @objc func takeScreenshot() {
        ScreenshotManager.shared.captureArea(mode: .interactive) { [weak self] image in
            self?.showScreenshotEditor(with: image)
        }
    }

    @objc func captureArea() {
        ScreenshotManager.shared.captureArea(mode: .interactive) { [weak self] image in
            self?.showScreenshotEditor(with: image)
        }
    }

    @objc func captureFullScreen() {
        ScreenshotManager.shared.captureArea(mode: .fullScreen) { [weak self] image in
            self?.showScreenshotEditor(with: image)
        }
    }

    @objc func captureWindow() {
        ScreenshotManager.shared.captureArea(mode: .window) { [weak self] image in
            self?.showScreenshotEditor(with: image)
        }
    }

    @objc func captureDelayed() {
        // 3 saniye bekle, sonra tüm ekranı yakala
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) { [weak self] in
            ScreenshotManager.shared.captureArea(mode: .fullScreen) { image in
                self?.showScreenshotEditor(with: image)
            }
        }
    }
}

extension AppDelegate: NSWindowDelegate, NSMenuItemValidation {
    func windowWillClose(_ notification: Notification) {
        if (notification.object as? NSWindow) == settingsWindow {
            settingsWindow = nil
        }
        if (notification.object as? NSWindow) == aboutWindow {
            aboutWindow = nil
        }
        if (notification.object as? NSWindow) == parameterWindow {
            parameterWindow = nil
        }
        if (notification.object as? NSWindow) == screenshotEditorWindow {
            screenshotEditorWindow = nil
        }
        if (notification.object as? NSWindow) == detailWindow {
            detailWindow = nil
            // Child pencere kapandığında, ana pencere ile olan ilişkisini kes.
            if let parentWindow = statusBarController?.popover.contentViewController?.view.window,
               let childWindow = notification.object as? NSWindow {
                parentWindow.removeChildWindow(childWindow)
            }
        }
        if (notification.object as? NSWindow) == diffWindow {
            diffWindow = nil
            // Child pencere kapandığında, ana pencere ile olan ilişkisini kes.
            if let parentWindow = statusBarController?.popover.contentViewController?.view.window,
               let childWindow = notification.object as? NSWindow {
                parentWindow.removeChildWindow(childWindow)
            }
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
