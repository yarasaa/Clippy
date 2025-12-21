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
    var snippetPreviewWindow: NSWindow?
    var pasteAllHotKey: HotKey?
    var hotKey: HotKey?
    var sequentialCopyHotKey: HotKey?
    var sequentialPasteHotKey: HotKey?
    var clearQueueHotKey: HotKey?
    var screenshotHotKey: HotKey?

    private var dockPreviewCoordinator: DockPreviewCoordinator?
    private var dockPreviewCancellable: AnyCancellable?
    private var windowSwitcherCoordinator: WindowSwitcherCoordinator?
    private var eventTap: CFMachPort?

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

        createMenu()

        setupHotkey()

        NSWorkspace.shared.notificationCenter.addObserver(self, selector: #selector(systemDidWake), name: NSWorkspace.didWakeNotification, object: nil)

        setupAdvancedWindowFeatures()
        
        // GEÇICI TEST: Dock Preview'u otomatik etkinleştir
        SettingsManager.shared.enableDockPreview = true

    }

    func setupHotkey() {
        let settings = SettingsManager.shared

        settings.objectWillChange
            .receive(on: DispatchQueue.main)
            .debounce(for: .milliseconds(100), scheduler: RunLoop.main)
            .sink { [weak self] in
                self?.updateAllHotkeys()
                self?.toggleKeywordExpansion()
                self?.recreateUIForLanguageChange()
            }
            .store(in: &cancellables)

        updateAllHotkeys()
    }

    @objc private func recreateUIForLanguageChange() {
        createMenu()
    }

    private func setupAdvancedWindowFeatures() {
        // Her iki koordinatörü de uygulama başında bir kez oluşturarak yönetimi basitleştir.
        // Bu, onların durumlarını daha tutarlı bir şekilde yönetmemizi sağlar.
        windowSwitcherCoordinator = WindowSwitcherCoordinator()

        // Ayar değişikliklerini dinle ve koordinatörü yönet.
        dockPreviewCancellable = SettingsManager.shared.$enableDockPreview
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isEnabled in
                guard let self = self else { return }
                if isEnabled {
                    print("✅ [AppDelegate] 'enableDockPreview' is ON. Using shared DockPreviewCoordinator.")
                    // Singleton tasarım desenine geçildiği için, her zaman paylaşılan örneği kullanıyoruz.
                    self.dockPreviewCoordinator = DockPreviewCoordinator.shared
                    self.startDockPreviewWithPermissionCheck()
                    self.setupSwitcherEventTap()
                } else {
                    print("🛑 [AppDelegate] 'enableDockPreview' is OFF. Stopping shared DockPreviewCoordinator.")
                    self.dockPreviewCoordinator?.stop()
                    // Belleği serbest bırakmak ve durumu sıfırlamak için referansı kaldır.
                    self.dockPreviewCoordinator = nil
                    self.stopSwitcherEventTap()
                }
            }
    }

    private func stopSwitcherEventTap() {
        if let tap = eventTap {
            CFMachPortInvalidate(tap)
            eventTap = nil
            print("🚫 'Uygulama Değiştirici' için Event Tap durduruldu.")
        }
        windowSwitcherCoordinator?.confirmSelectionAndHide() // Switcher'ı gizle
    }

    private func setupSwitcherEventTap() {
        // Option tuşunun (keyCode: 58) ve Tab tuşunun (keyCode: 48) olaylarını dinle.
        let eventMask: CGEventMask = (1 << CGEventType.keyDown.rawValue) | (1 << CGEventType.keyUp.rawValue) | (1 << CGEventType.flagsChanged.rawValue)

        // DOCKDOOR ÇÖZÜMÜ: Event Tap oluşturmak için Erişilebilirlik izni gereklidir.
        // İzin yoksa, kullanıcıyı bilgilendir ve işlemi durdur.
        guard AXIsProcessTrusted() else {
            print("🚫 'Uygulama Değiştirici' için Erişilebilirlik izni yok. Event Tap başlatılamadı.")
            // Kullanıcıya izin istemek için, daha önce yazdığımız yardımcı fonksiyonu çağır.
            requestAccessibilityPermissions()
            return
        }

        guard eventTap == nil else { return }

        eventTap = CGEvent.tapCreate(
            tap: .cghidEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: eventMask,
            callback: { _, type, event, refcon -> Unmanaged<CGEvent>? in
                guard let refcon = refcon else { return Unmanaged.passUnretained(event) }
                let appDelegate = Unmanaged<AppDelegate>.fromOpaque(refcon).takeUnretainedValue()

                let keyCode = event.getIntegerValueField(.keyboardEventKeycode)

                // Sadece Option (Alt) ve Tab tuşlarıyla ilgileniyoruz.
                // KeyCode 58: Option, KeyCode 48: Tab
                if keyCode == 58 || keyCode == 48 {
                    switch type {
                    case .flagsChanged:
                        // Option tuşu bırakıldığında seçimi onayla.
                        if !event.flags.contains(.maskAlternate) {
                            DispatchQueue.main.async {
                                appDelegate.windowSwitcherCoordinator?.confirmSelectionAndHide()
                            }
                        }
                    case .keyDown:
                        // Option basılıyken Tab tuşuna basıldı mı diye kontrol et.
                        if keyCode == 48 && event.flags.contains(.maskAlternate) {
                            DispatchQueue.main.async {
                                appDelegate.windowSwitcherCoordinator?.handleTab()
                            }
                            return nil // Tab tuşunun normal işlevini engelle.
                        }
                    default:
                        break
                    }
                }
                
                return Unmanaged.passUnretained(event)
            },
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        )

        guard eventTap != nil else {
            print("🚫 'Uygulama Değiştirici' için Event Tap oluşturulamadı (CGEvent.tapCreate nil döndü).")
            return
        }

        let runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, eventTap, 0)
        CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
        print("✅ 'Uygulama Değiştirici' için Event Tap başlatıldı.")
    }

    @MainActor
    private func startDockPreviewWithPermissionCheck() {
        // Erişilebilirlik iznini kontrol et - macOS'un kendi dialogunu göster
        let options: [String: Bool] = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
        guard AXIsProcessTrustedWithOptions(options as CFDictionary) else {
            // İzin verilmedi - macOS zaten dialog gösterdi, ayarı kapat
            SettingsManager.shared.enableDockPreview = false
            print("⚠️ [AppDelegate] Accessibility permission needed - user will see system dialog")
            return
        }

        // İzin tamam, Dock Preview'u başlat
        // Screen Recording izni sadece Live Preview kullanıldığında gerekli
        print("✅ [AppDelegate] Accessibility OK. Starting dock preview...")
        dockPreviewCoordinator?.start()
    }

    @MainActor
    func requestAccessibilityPermissions() {
        // Bu, kullanıcıya daha önce sorulmadıysa sistem istemini gösterir.
        // Eğer daha önce reddedildiyse, hiçbir şey yapmaz, bu yüzden kendi uyarımızı göstermemiz gerekir.
        let options: [String: Bool] = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
        if !AXIsProcessTrustedWithOptions(options as CFDictionary) {
            let alert = NSAlert()
            alert.messageText = "Erişilebilirlik İzni Gerekli"
            alert.informativeText = "Clippy'nin bu özelliği kullanabilmesi için Erişilebilirlik iznine ihtiyacı var. Lütfen Sistem Ayarları'nda izni verin."
            alert.addButton(withTitle: "Sistem Ayarları'nı Aç")
            alert.addButton(withTitle: "İptal")
            if alert.runModal() == .alertFirstButtonReturn {
                NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
            }
        }
    }

    @MainActor
    func requestScreenCapturePermission() {
        let alert = NSAlert()
        alert.messageText = "Ekran Kaydı İzni Gerekli"
        alert.informativeText = "Canlı pencere önizlemeleri özelliğinin çalışması için Clippy'nin Ekran Kaydı iznine ihtiyacı var. Lütfen Sistem Ayarları'nda izni verin."
        alert.addButton(withTitle: "Sistem Ayarları'nı Aç")
        alert.addButton(withTitle: "İptal")
        if alert.runModal() == .alertFirstButtonReturn {
            // Kullanıcıyı doğrudan Ekran Kaydı ayarlarına yönlendir.
            NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture")!)
        }
        // İzin verilmediği için özelliği devre dışı bırak.
        SettingsManager.shared.enableDockPreview = false
    }

    private func updateAllHotkeys() {
        updateHotkey()
        updatePasteAllHotkey()
        updateSequentialCopyHotkey()
        updateSequentialPasteHotkey()
        updateClearQueueHotkey()
        updateScreenshotHotkey()
        // updateSwitcherHotkey() artık kullanılmıyor.
    }

    @objc private func systemDidWake(notification: NSNotification) {
        print("💤 Sistem uyandı. Monitörler ve kısayollar yeniden başlatılıyor...")

        clipboardMonitor?.stopMonitoring()
        clipboardMonitor?.startMonitoring()

        keywordManager?.stopMonitoring()
        toggleKeywordExpansion()

        updateAllHotkeys()

    }
    func applicationWillTerminate(_ notification: Notification) {
        clipboardMonitor?.stopMonitoring()
        keywordManager?.stopMonitoring()
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

        let aboutItem = NSMenuItem(title: L("About Clippy", settings: SettingsManager.shared), action: #selector(openAbout), keyEquivalent: "")
        aboutItem.target = self
        menu.addItem(aboutItem)

        menu.addItem(NSMenuItem.separator())

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

        let settingsItem = NSMenuItem(title: L("Settings", settings: SettingsManager.shared), action: #selector(openSettings), keyEquivalent: ",")
        settingsItem.target = self
        menu.addItem(settingsItem)

        menu.addItem(NSMenuItem.separator())

        let toggleKeywordExpansionItem = NSMenuItem(title: L("Toggle Keyword Expansion", settings: SettingsManager.shared), action: #selector(toggleKeywordExpansion), keyEquivalent: "")
        toggleKeywordExpansionItem.target = self
        menu.addItem(toggleKeywordExpansionItem)

        let clearQueueItem = NSMenuItem(title: L("Clear Sequential Queue", settings: SettingsManager.shared), action: #selector(clearSequentialQueue), keyEquivalent: "")
        clearQueueItem.target = self
        menu.addItem(clearQueueItem)

        menu.addItem(NSMenuItem.separator())

        let dockPreviewToggleItem = NSMenuItem(title: "Dock Preview & Switcher", action: #selector(toggleDockPreview), keyEquivalent: "")
        dockPreviewToggleItem.target = self
        menu.addItem(dockPreviewToggleItem)

        menu.addItem(NSMenuItem.separator())

        menu.addItem(withTitle: L("Quit Clippy", settings: SettingsManager.shared), action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")

        statusBarController?.rightClickMenu = menu
        menu.delegate = self
    }

    @objc func openSettings() {
        if let window = settingsWindow {
            // Önce uygulamayı aktif et
            NSApp.activate(ignoringOtherApps: true)

            // Minimize edilmiş ise geri aç
            if window.isMiniaturized {
                window.deminiaturize(nil)
            }

            // Pencere seviyesini geçici olarak yükselt
            let originalLevel = window.level
            window.level = .floating

            // Pencereyi en öne getir - tüm metodlar birlikte
            window.orderFrontRegardless()
            window.makeKeyAndOrderFront(nil)

            // Kısa bir gecikme sonrası normal seviyeye dön
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                window.level = originalLevel
            }

            return
        }

        let settingsView = SettingsView()
            .environmentObject(SettingsManager.shared)
        let window = NSWindow(contentViewController: NSHostingController(rootView: settingsView))
        window.title = L("Clippy Settings", settings: SettingsManager.shared)
        window.styleMask = [.titled, .closable, .resizable]
        window.delegate = self
        window.setContentSize(NSSize(width: 500, height: 380))
        window.center()

        // İlk açılışta da uygulamayı aktif et ve window'u öne getir
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)

        self.settingsWindow = window
    }

    @objc func openAbout() {
        if let window = aboutWindow {
            // Önce uygulamayı aktif et
            NSApp.activate(ignoringOtherApps: true)

            // Minimize edilmiş ise geri aç
            if window.isMiniaturized {
                window.deminiaturize(nil)
            }

            // Pencere seviyesini geçici olarak yükselt
            let originalLevel = window.level
            window.level = .floating

            // Pencereyi en öne getir - tüm metodlar birlikte
            window.orderFrontRegardless()
            window.makeKeyAndOrderFront(nil)

            // Kısa bir gecikme sonrası normal seviyeye dön
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                window.level = originalLevel
            }

            return
        }

        let aboutView = AboutView()
            .environmentObject(SettingsManager.shared)
        let window = NSWindow(contentViewController: NSHostingController(rootView: aboutView))
        window.title = L("About Clippy", settings: SettingsManager.shared)
        window.styleMask = [.titled, .closable]
        window.delegate = self
        window.setContentSize(NSSize(width: 320, height: 280))
        window.center()

        // İlk açılışta da uygulamayı aktif et ve window'u öne getir
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)

        self.aboutWindow = window
    }

    @objc func toggleDockPreview() {
        SettingsManager.shared.enableDockPreview.toggle()
    }

    @objc func clearSequentialQueue() {
        clipboardMonitor?.clearSequentialPasteQueue()
    }

    @objc func toggleKeywordExpansion() {
        let settings = SettingsManager.shared
        settings.isKeywordExpansionEnabled ? keywordManager?.startMonitoring() : keywordManager?.stopMonitoring()
    }

    func showDetailWindow(for item: ClipboardItemEntity) {
        detailWindow?.close()
        detailWindow = nil

        let detailView = ClipboardDetailView(item: item, monitor: clipboardMonitor!)
            .environmentObject(SettingsManager.shared)

        let hostingController = NSHostingController(rootView: detailView)
        let window = NSWindow(contentViewController: hostingController)

        guard let mainPopoverWindow = statusBarController?.popover.contentViewController?.view.window else {
            print("❌ Ana popover penceresi bulunamadı.")
            return
        }

        mainPopoverWindow.addChildWindow(window, ordered: .above)

        window.title = L("Detail", settings: SettingsManager.shared)
        window.styleMask = [.titled, .closable, .miniaturizable, .resizable]
        window.delegate = self
        window.center()

        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        self.detailWindow = window
    }

    func showDiffWindow(oldText: String, newText: String) {
        diffWindow?.close()
        diffWindow = nil

        let diffView = DiffView(oldText: oldText, newText: newText)
            .environmentObject(SettingsManager.shared)
            .environmentObject(clipboardMonitor!)

        let hostingController = NSHostingController(rootView: diffView)
        let window = NSWindow(contentViewController: hostingController)

        guard let mainPopoverWindow = statusBarController?.popover.contentViewController?.view.window else {
            print("❌ Ana popover penceresi bulunamadı.")
            return
        }

        mainPopoverWindow.addChildWindow(window, ordered: .above)

        window.title = L("Compare Differences", settings: SettingsManager.shared)
        window.styleMask = [.titled, .closable, .miniaturizable, .resizable]
        window.delegate = self
        window.center()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        self.diffWindow = window
    }

    func showParameterInputDialog(parameters: [String], snippetTemplate: String? = nil, completion: @escaping ([String: String]?) -> Void) {
        parameterWindow?.close()

        let parameterView = ParameterInputView(
            parameters: parameters,
            snippetTemplate: snippetTemplate,
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

    func showSnippetPreview(keyword: String, content: String, completion: @escaping (Bool) -> Void) {
        snippetPreviewWindow?.close()

        let previewView = SnippetPreviewView(
            keyword: keyword,
            previewContent: content,
            onConfirm: {
                self.snippetPreviewWindow?.close()
                completion(true)
            },
            onCancel: {
                self.snippetPreviewWindow?.close()
                completion(false)
            }
        )
        .environmentObject(SettingsManager.shared)

        let window = NSWindow(contentViewController: NSHostingController(rootView: previewView))
        window.title = "Snippet Önizleme"
        window.styleMask = [.titled, .closable]
        window.delegate = self
        window.center()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        self.snippetPreviewWindow = window
    }

    func showScreenshotEditor(with image: NSImage) {
        // Close existing window if any to prevent memory accumulation
        if let existingWindow = screenshotEditorWindow {
            existingWindow.close()
            screenshotEditorWindow = nil
        }

        let editorView = ScreenshotEditorView(image: image, clipboardMonitor: self.clipboardMonitor!)
            .environmentObject(SettingsManager.shared)

        let hostingController = NSHostingController(rootView: editorView)
        let window = NSWindow(contentViewController: hostingController)

        window.styleMask = [NSWindow.StyleMask.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView]
        window.isOpaque = true
        window.backgroundColor = NSColor.windowBackgroundColor
        window.hasShadow = true
        window.titlebarAppearsTransparent = true
        window.titleVisibility = NSWindow.TitleVisibility.hidden
        window.title = "Screenshot Editor"

        let padding: CGFloat = 80
        let toolbarHeight: CGFloat = 60

        var desiredSize = NSSize(width: image.size.width + padding, height: image.size.height + padding + toolbarHeight)

        if let screenFrame = NSScreen.main?.visibleFrame {
            let maxW = screenFrame.width * 0.9
            let maxH = screenFrame.height * 0.9

            if desiredSize.width > maxW || desiredSize.height > maxH {
                let imageAspectRatio = image.size.width / image.size.height

                if desiredSize.width > maxW {
                    desiredSize.width = maxW
                    desiredSize.height = (maxW - padding) / imageAspectRatio + padding + toolbarHeight
                }

                if desiredSize.height > maxH {
                    desiredSize.height = maxH
                    desiredSize.width = (maxH - padding - toolbarHeight) * imageAspectRatio + padding
                }
            }
        }
        window.setContentSize(desiredSize)

        window.center()

        window.level = .floating

        NSApp.activate(ignoringOtherApps: true)

        window.makeKeyAndOrderFront(self)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            window.level = .normal
        }

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
        if (notification.object as? NSWindow) == snippetPreviewWindow {
            snippetPreviewWindow = nil
        }
        if (notification.object as? NSWindow) == screenshotEditorWindow {
            autoreleasepool {
                screenshotEditorWindow?.contentViewController = nil
                screenshotEditorWindow = nil
                print("🧹 Screenshot editor window closed - memory cleanup triggered")
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                autoreleasepool {
                    print("🧹 Delayed memory cleanup pass completed")
                }
            }
        }
        if (notification.object as? NSWindow) == detailWindow {
            detailWindow = nil
            if let parentWindow = statusBarController?.popover.contentViewController?.view.window,
               let childWindow = notification.object as? NSWindow {
                parentWindow.removeChildWindow(childWindow)
            }
        }
        if (notification.object as? NSWindow) == diffWindow {
            diffWindow = nil
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
        if menuItem.action == #selector(toggleDockPreview) {
            let isEnabled = SettingsManager.shared.enableDockPreview
            menuItem.state = isEnabled ? .on : .off
            menuItem.title = isEnabled ? L("Disable Dock Preview & Switcher", settings: SettingsManager.shared) : L("Enable Dock Preview & Switcher", settings: SettingsManager.shared)
        }
        return true
    }
}
