//
//  SettingsManager.swift
//  Clippy
//
//  Created by Mehmet Akbaba on 17.09.2025.
//

import Foundation
import Combine

class SettingsManager: ObservableObject {
    static let shared = SettingsManager()

    @Published var showCodeTab: Bool {
        didSet { UserDefaults.standard.set(showCodeTab, forKey: "showCodeTab") }
    }
    @Published var showImagesTab: Bool {
        didSet { UserDefaults.standard.set(showImagesTab, forKey: "showImagesTab") }
    }
    @Published var showSnippetsTab: Bool {
        didSet { UserDefaults.standard.set(showSnippetsTab, forKey: "showSnippetsTab") }
    }
    @Published var showFavoritesTab: Bool {
        didSet { UserDefaults.standard.set(showFavoritesTab, forKey: "showFavoritesTab") }
    }
    @Published var historyLimit: Int {
        didSet { UserDefaults.standard.set(historyLimit, forKey: "historyLimit") }
    }
    @Published var favoritesLimit: Int {
        didSet { UserDefaults.standard.set(favoritesLimit, forKey: "favoritesLimit") }
    }
    @Published var imagesLimit: Int {
        didSet { UserDefaults.standard.set(imagesLimit, forKey: "imagesLimit") }
    }
    @Published var popoverWidth: Int {
        didSet { UserDefaults.standard.set(popoverWidth, forKey: "popoverWidth") }
    }
    @Published var popoverHeight: Int {
        didSet { UserDefaults.standard.set(popoverHeight, forKey: "popoverHeight") }
    }
    @Published var appTheme: String {
        didSet { UserDefaults.standard.set(appTheme, forKey: "appTheme") }
    }
    @Published var hotkeyKey: String {
        didSet { UserDefaults.standard.set(hotkeyKey, forKey: "hotkeyKey") }
    }
    @Published var hotkeyModifiers: UInt {
        didSet { UserDefaults.standard.set(hotkeyModifiers, forKey: "hotkeyModifiers") }
    }
    @Published var pasteAllHotkeyKey: String {
        didSet { UserDefaults.standard.set(pasteAllHotkeyKey, forKey: "pasteAllHotkeyKey") }
    }
    @Published var pasteAllHotkeyModifiers: UInt {
        didSet { UserDefaults.standard.set(pasteAllHotkeyModifiers, forKey: "pasteAllHotkeyModifiers") }
    }
    @Published var appLanguage: String {
        didSet {
            UserDefaults.standard.set(appLanguage, forKey: "appLanguage")
            print("⚙️ SettingsManager: Dil ayarı kaydedildi -> \(appLanguage)")
        }
    }
    @Published var sequentialCopyHotkeyKey: String {
        didSet { UserDefaults.standard.set(sequentialCopyHotkeyKey, forKey: "sequentialCopyHotkeyKey") }
    }
    @Published var sequentialCopyHotkeyModifiers: UInt {
        didSet { UserDefaults.standard.set(sequentialCopyHotkeyModifiers, forKey: "sequentialCopyHotkeyModifiers") }
    }
    @Published var sequentialPasteHotkeyKey: String {
        didSet { UserDefaults.standard.set(sequentialPasteHotkeyKey, forKey: "sequentialPasteHotkeyKey") }
    }
    @Published var sequentialPasteHotkeyModifiers: UInt {
        didSet { UserDefaults.standard.set(sequentialPasteHotkeyModifiers, forKey: "sequentialPasteHotkeyModifiers") }
    }
    @Published var clearQueueHotkeyKey: String {
        didSet { UserDefaults.standard.set(clearQueueHotkeyKey, forKey: "clearQueueHotkeyKey") }
    }
    @Published var clearQueueHotkeyModifiers: UInt {
        didSet { UserDefaults.standard.set(clearQueueHotkeyModifiers, forKey: "clearQueueHotkeyModifiers") }
    }
    @Published var isKeywordExpansionEnabled: Bool {
        didSet { UserDefaults.standard.set(isKeywordExpansionEnabled, forKey: "isKeywordExpansionEnabled") }
    }
    @Published var snippetTimeoutDuration: Double {
        didSet { UserDefaults.standard.set(snippetTimeoutDuration, forKey: "snippetTimeoutDuration") }
    }
    @Published var screenshotHotkeyKey: String {
        didSet { UserDefaults.standard.set(screenshotHotkeyKey, forKey: "screenshotHotkeyKey") }
    }
    @Published var screenshotHotkeyModifiers: UInt {
        didSet { UserDefaults.standard.set(screenshotHotkeyModifiers, forKey: "screenshotHotkeyModifiers") }
    }
    @Published var scrollingScreenshotHotkeyKey: String {
        didSet { UserDefaults.standard.set(scrollingScreenshotHotkeyKey, forKey: "scrollingScreenshotHotkeyKey") }
    }
    @Published var scrollingScreenshotHotkeyModifiers: UInt {
        didSet { UserDefaults.standard.set(scrollingScreenshotHotkeyModifiers, forKey: "scrollingScreenshotHotkeyModifiers") }
    }

    private init() {
        // Varsayılan değerleri belirle ve UserDefaults'tan oku
        self.showCodeTab = UserDefaults.standard.object(forKey: "showCodeTab") as? Bool ?? true
        self.showImagesTab = UserDefaults.standard.object(forKey: "showImagesTab") as? Bool ?? true
        self.showSnippetsTab = UserDefaults.standard.object(forKey: "showSnippetsTab") as? Bool ?? true
        self.showFavoritesTab = UserDefaults.standard.object(forKey: "showFavoritesTab") as? Bool ?? true
        // Varsayılan geçmiş limiti 20'dir.
        self.historyLimit = UserDefaults.standard.object(forKey: "historyLimit") as? Int ?? 20
        // Varsayılan favori limiti 50'dir.
        self.favoritesLimit = UserDefaults.standard.object(forKey: "favoritesLimit") as? Int ?? 50
        // Varsayılan resim limiti 5'tir.
        self.imagesLimit = UserDefaults.standard.object(forKey: "imagesLimit") as? Int ?? 5
        // Varsayılan popover boyutu
        self.popoverWidth = UserDefaults.standard.object(forKey: "popoverWidth") as? Int ?? 380
        self.popoverHeight = UserDefaults.standard.object(forKey: "popoverHeight") as? Int ?? 450
        // Varsayılan tema: Sistem
        self.appTheme = UserDefaults.standard.string(forKey: "appTheme") ?? "system"
        // Varsayılan kısayol: Cmd+Shift+V
        self.hotkeyKey = UserDefaults.standard.string(forKey: "hotkeyKey") ?? "v"
        // NSEvent.ModifierFlags'ın rawValue'larını kullanıyoruz. Cmd+Shift = 131072 + 256 = 131328
        self.hotkeyModifiers = UserDefaults.standard.object(forKey: "hotkeyModifiers") as? UInt ?? 131328
        // Varsayılan "Tümünü Yapıştır" kısayolu: Cmd+Shift+P
        self.pasteAllHotkeyKey = UserDefaults.standard.string(forKey: "pasteAllHotkeyKey") ?? "p"
        self.pasteAllHotkeyModifiers = UserDefaults.standard.object(forKey: "pasteAllHotkeyModifiers") as? UInt ?? 131328
        // Varsayılan dil: Sistem dili
        self.appLanguage = UserDefaults.standard.string(forKey: "appLanguage") ?? "system"
        // Varsayılan "Sıraya Ekle" kısayolu: Cmd+Shift+C
        self.sequentialCopyHotkeyKey = UserDefaults.standard.string(forKey: "sequentialCopyHotkeyKey") ?? "c"
        self.sequentialCopyHotkeyModifiers = UserDefaults.standard.object(forKey: "sequentialCopyHotkeyModifiers") as? UInt ?? 1179648 // Cmd+Shift
        // Varsayılan "Sıradakini Yapıştır" kısayolu: Cmd+Shift+B
        self.sequentialPasteHotkeyKey = UserDefaults.standard.string(forKey: "sequentialPasteHotkeyKey") ?? "b"
        self.sequentialPasteHotkeyModifiers = UserDefaults.standard.object(forKey: "sequentialPasteHotkeyModifiers") as? UInt ?? 1179648 // Cmd+Shift
        // Varsayılan "Sıralı Kuyruğu Temizle" kısayolu: Cmd+Shift+X
        self.clearQueueHotkeyKey = UserDefaults.standard.string(forKey: "clearQueueHotkeyKey") ?? "k" // Varsayılanı 'k' olarak değiştirildi
        self.clearQueueHotkeyModifiers = UserDefaults.standard.object(forKey: "clearQueueHotkeyModifiers") as? UInt ?? 1179648 // Cmd+Shift
        // Anahtar Kelime Genişletme varsayılan olarak etkin.
        self.isKeywordExpansionEnabled = UserDefaults.standard.object(forKey: "isKeywordExpansionEnabled") as? Bool ?? true
        // Snippet zaman aşımı varsayılan olarak 3 saniye.
        self.snippetTimeoutDuration = UserDefaults.standard.object(forKey: "snippetTimeoutDuration") as? Double ?? 3.0
        // Varsayılan "Ekran Görüntüsü Al" kısayolu: Cmd+Shift+1
        self.screenshotHotkeyKey = UserDefaults.standard.string(forKey: "screenshotHotkeyKey") ?? "1"
        self.screenshotHotkeyModifiers = UserDefaults.standard.object(forKey: "screenshotHotkeyModifiers") as? UInt ?? 1179648 // Cmd+Shift
        // Varsayılan "Kaydırmalı Ekran Görüntüsü Al" kısayolu: Cmd+Shift+2
        self.scrollingScreenshotHotkeyKey = UserDefaults.standard.string(forKey: "scrollingScreenshotHotkeyKey") ?? "2"
        self.scrollingScreenshotHotkeyModifiers = UserDefaults.standard.object(forKey: "scrollingScreenshotHotkeyModifiers") as? UInt ?? 1179648 // Cmd+Shift
    }
}