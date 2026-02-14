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
    @Published var snippetVariables: [SnippetVariable] = [] {
        didSet { saveSnippetVariables() }
    }
    @Published var snippetCategories: [SnippetCategory] = [] {
        didSet { saveSnippetCategories() }
    }
    @Published var isCategorySystemEnabled: Bool {
        didSet { UserDefaults.standard.set(isCategorySystemEnabled, forKey: "isCategorySystemEnabled") }
    }
    @Published var enableDockPreview: Bool {
        didSet { UserDefaults.standard.set(enableDockPreview, forKey: "enableDockPreview") }
    }
    @Published var switcherHotkeyKey: String {
        didSet { UserDefaults.standard.set(switcherHotkeyKey, forKey: "switcherHotkeyKey") }
    }
    @Published var switcherHotkeyModifiers: UInt {
        didSet { UserDefaults.standard.set(switcherHotkeyModifiers, forKey: "switcherHotkeyModifiers") }
    }

    // MARK: - Dock Preview Settings

    @Published var dockPreviewAnimationStyle: String {
        didSet { UserDefaults.standard.set(dockPreviewAnimationStyle, forKey: "dockPreviewAnimationStyle") }
    }
    @Published var dockPreviewSize: String {
        didSet { UserDefaults.standard.set(dockPreviewSize, forKey: "dockPreviewSize") }
    }
    @Published var showWindowTitles: Bool {
        didSet { UserDefaults.standard.set(showWindowTitles, forKey: "showWindowTitles") }
    }
    @Published var enableDockPreviewKeyboardShortcuts: Bool {
        didSet { UserDefaults.standard.set(enableDockPreviewKeyboardShortcuts, forKey: "enableDockPreviewKeyboardShortcuts") }
    }
    @Published var enableWindowCaching: Bool {
        didSet { UserDefaults.standard.set(enableWindowCaching, forKey: "enableWindowCaching") }
    }
    @Published var enableDockPreviewGestures: Bool {
        didSet { UserDefaults.standard.set(enableDockPreviewGestures, forKey: "enableDockPreviewGestures") }
    }
    @Published var dockSwipeUpAction: String {
        didSet { UserDefaults.standard.set(dockSwipeUpAction, forKey: "dockSwipeUpAction") }
    }
    @Published var dockSwipeDownAction: String {
        didSet { UserDefaults.standard.set(dockSwipeDownAction, forKey: "dockSwipeDownAction") }
    }
    @Published var middleClickAction: String {
        didSet { UserDefaults.standard.set(middleClickAction, forKey: "middleClickAction") }
    }
    @Published var dockPreviewHoverDelay: Double {
        didSet { UserDefaults.standard.set(dockPreviewHoverDelay, forKey: "dockPreviewHoverDelay") }
    }

    // MARK: - Memory Management Settings

    @Published var maxCacheSizeMB: Int {
        didSet { UserDefaults.standard.set(maxCacheSizeMB, forKey: "maxCacheSizeMB") }
    }
    @Published var enableMemoryPressureHandling: Bool {
        didSet { UserDefaults.standard.set(enableMemoryPressureHandling, forKey: "enableMemoryPressureHandling") }
    }

    // MARK: - Auto-Refresh Settings

    @Published var enableAutoRefresh: Bool {
        didSet { UserDefaults.standard.set(enableAutoRefresh, forKey: "enableAutoRefresh") }
    }

    // MARK: - Feature Toggles

    @Published var enableAutoCodeDetection: Bool {
        didSet { UserDefaults.standard.set(enableAutoCodeDetection, forKey: "enableAutoCodeDetection") }
    }
    @Published var enableContentDetection: Bool {
        didSet { UserDefaults.standard.set(enableContentDetection, forKey: "enableContentDetection") }
    }
    @Published var enableSequentialPaste: Bool {
        didSet { UserDefaults.standard.set(enableSequentialPaste, forKey: "enableSequentialPaste") }
    }
    @Published var enableScreenshot: Bool {
        didSet { UserDefaults.standard.set(enableScreenshot, forKey: "enableScreenshot") }
    }
    @Published var enableOCR: Bool {
        didSet { UserDefaults.standard.set(enableOCR, forKey: "enableOCR") }
    }
    @Published var enableDuplicateDetection: Bool {
        didSet { UserDefaults.standard.set(enableDuplicateDetection, forKey: "enableDuplicateDetection") }
    }
    @Published var enableSourceAppTracking: Bool {
        didSet { UserDefaults.standard.set(enableSourceAppTracking, forKey: "enableSourceAppTracking") }
    }
    @Published var maxTextStorageLength: Int {
        didSet { UserDefaults.standard.set(maxTextStorageLength, forKey: "maxTextStorageLength") }
    }

    // MARK: - Quick Preview Overlay

    @Published var enableQuickPreview: Bool {
        didSet { UserDefaults.standard.set(enableQuickPreview, forKey: "enableQuickPreview") }
    }
    @Published var quickPreviewHotkeyKey: String {
        didSet { UserDefaults.standard.set(quickPreviewHotkeyKey, forKey: "quickPreviewHotkeyKey") }
    }
    @Published var quickPreviewHotkeyModifiers: UInt {
        didSet { UserDefaults.standard.set(quickPreviewHotkeyModifiers, forKey: "quickPreviewHotkeyModifiers") }
    }
    @Published var quickPreviewItemCount: Int {
        didSet { UserDefaults.standard.set(quickPreviewItemCount, forKey: "quickPreviewItemCount") }
    }
    @Published var quickPreviewAutoClose: Bool {
        didSet { UserDefaults.standard.set(quickPreviewAutoClose, forKey: "quickPreviewAutoClose") }
    }

    // MARK: - AI Settings

    @Published var enableAI: Bool {
        didSet { UserDefaults.standard.set(enableAI, forKey: "enableAI") }
    }
    @Published var aiProvider: String {
        didSet { UserDefaults.standard.set(aiProvider, forKey: "aiProvider") }
    }
    @Published var aiAPIKey: String {
        didSet { UserDefaults.standard.set(aiAPIKey, forKey: "aiAPIKey") }
    }
    @Published var aiModel: String {
        didSet { UserDefaults.standard.set(aiModel, forKey: "aiModel") }
    }
    @Published var ollamaURL: String {
        didSet { UserDefaults.standard.set(ollamaURL, forKey: "ollamaURL") }
    }
    @Published var ollamaModel: String {
        didSet { UserDefaults.standard.set(ollamaModel, forKey: "ollamaModel") }
    }

    private init() {
        self.showCodeTab = UserDefaults.standard.object(forKey: "showCodeTab") as? Bool ?? true
        self.showImagesTab = UserDefaults.standard.object(forKey: "showImagesTab") as? Bool ?? true
        self.showSnippetsTab = UserDefaults.standard.object(forKey: "showSnippetsTab") as? Bool ?? true
        self.showFavoritesTab = UserDefaults.standard.object(forKey: "showFavoritesTab") as? Bool ?? true
        self.historyLimit = UserDefaults.standard.object(forKey: "historyLimit") as? Int ?? 20
        self.favoritesLimit = UserDefaults.standard.object(forKey: "favoritesLimit") as? Int ?? 50
        self.imagesLimit = UserDefaults.standard.object(forKey: "imagesLimit") as? Int ?? 5
        self.popoverWidth = UserDefaults.standard.object(forKey: "popoverWidth") as? Int ?? 380
        self.popoverHeight = UserDefaults.standard.object(forKey: "popoverHeight") as? Int ?? 450
        self.appTheme = UserDefaults.standard.string(forKey: "appTheme") ?? "system"
        self.hotkeyKey = UserDefaults.standard.string(forKey: "hotkeyKey") ?? "v"
        self.hotkeyModifiers = UserDefaults.standard.object(forKey: "hotkeyModifiers") as? UInt ?? 131328
        self.pasteAllHotkeyKey = UserDefaults.standard.string(forKey: "pasteAllHotkeyKey") ?? "p"
        self.pasteAllHotkeyModifiers = UserDefaults.standard.object(forKey: "pasteAllHotkeyModifiers") as? UInt ?? 131328
        self.appLanguage = UserDefaults.standard.string(forKey: "appLanguage") ?? "system"
        self.sequentialCopyHotkeyKey = UserDefaults.standard.string(forKey: "sequentialCopyHotkeyKey") ?? "c"
        self.sequentialCopyHotkeyModifiers = UserDefaults.standard.object(forKey: "sequentialCopyHotkeyModifiers") as? UInt ?? 1179648
        self.sequentialPasteHotkeyKey = UserDefaults.standard.string(forKey: "sequentialPasteHotkeyKey") ?? "b"
        self.sequentialPasteHotkeyModifiers = UserDefaults.standard.object(forKey: "sequentialPasteHotkeyModifiers") as? UInt ?? 1179648
        self.clearQueueHotkeyKey = UserDefaults.standard.string(forKey: "clearQueueHotkeyKey") ?? "k"
        self.clearQueueHotkeyModifiers = UserDefaults.standard.object(forKey: "clearQueueHotkeyModifiers") as? UInt ?? 1179648
        self.isKeywordExpansionEnabled = UserDefaults.standard.object(forKey: "isKeywordExpansionEnabled") as? Bool ?? true
        self.snippetTimeoutDuration = UserDefaults.standard.object(forKey: "snippetTimeoutDuration") as? Double ?? 3.0
        self.screenshotHotkeyKey = UserDefaults.standard.string(forKey: "screenshotHotkeyKey") ?? "1"
        self.screenshotHotkeyModifiers = UserDefaults.standard.object(forKey: "screenshotHotkeyModifiers") as? UInt ?? 1179648
        self.isCategorySystemEnabled = UserDefaults.standard.object(forKey: "isCategorySystemEnabled") as? Bool ?? true
        self.enableDockPreview = UserDefaults.standard.object(forKey: "enableDockPreview") as? Bool ?? false
        self.switcherHotkeyKey = UserDefaults.standard.string(forKey: "switcherHotkeyKey") ?? "tab" // Varsayılan: Tab
        self.switcherHotkeyModifiers = UserDefaults.standard.object(forKey: "switcherHotkeyModifiers") as? UInt ?? 524288 // Varsayılan: Option (⌥)

        // Dock Preview Settings
        self.dockPreviewAnimationStyle = UserDefaults.standard.string(forKey: "dockPreviewAnimationStyle") ?? "spring"
        self.dockPreviewSize = UserDefaults.standard.string(forKey: "dockPreviewSize") ?? "medium"
        self.showWindowTitles = UserDefaults.standard.object(forKey: "showWindowTitles") as? Bool ?? true
        self.enableDockPreviewKeyboardShortcuts = UserDefaults.standard.object(forKey: "enableDockPreviewKeyboardShortcuts") as? Bool ?? true
        self.enableWindowCaching = UserDefaults.standard.object(forKey: "enableWindowCaching") as? Bool ?? true
        self.enableDockPreviewGestures = UserDefaults.standard.object(forKey: "enableDockPreviewGestures") as? Bool ?? true
        self.dockSwipeUpAction = UserDefaults.standard.string(forKey: "dockSwipeUpAction") ?? "close"
        self.dockSwipeDownAction = UserDefaults.standard.string(forKey: "dockSwipeDownAction") ?? "minimize"
        self.middleClickAction = UserDefaults.standard.string(forKey: "middleClickAction") ?? "close"
        self.dockPreviewHoverDelay = UserDefaults.standard.object(forKey: "dockPreviewHoverDelay") as? Double ?? 0.3

        // Memory Management Settings
        self.maxCacheSizeMB = UserDefaults.standard.object(forKey: "maxCacheSizeMB") as? Int ?? 100
        self.enableMemoryPressureHandling = UserDefaults.standard.object(forKey: "enableMemoryPressureHandling") as? Bool ?? true

        // Live Preview Settings (ScreenCaptureKit)
        self.enableAutoRefresh = UserDefaults.standard.object(forKey: "enableAutoRefresh") as? Bool ?? false

        // Feature Toggles
        self.enableAutoCodeDetection = UserDefaults.standard.object(forKey: "enableAutoCodeDetection") as? Bool ?? true
        self.enableContentDetection = UserDefaults.standard.object(forKey: "enableContentDetection") as? Bool ?? true
        self.enableSequentialPaste = UserDefaults.standard.object(forKey: "enableSequentialPaste") as? Bool ?? true
        self.enableScreenshot = UserDefaults.standard.object(forKey: "enableScreenshot") as? Bool ?? true
        self.enableOCR = UserDefaults.standard.object(forKey: "enableOCR") as? Bool ?? true
        self.enableDuplicateDetection = UserDefaults.standard.object(forKey: "enableDuplicateDetection") as? Bool ?? true
        self.enableSourceAppTracking = UserDefaults.standard.object(forKey: "enableSourceAppTracking") as? Bool ?? true
        self.maxTextStorageLength = UserDefaults.standard.object(forKey: "maxTextStorageLength") as? Int ?? 500000

        // Quick Preview Overlay
        self.enableQuickPreview = UserDefaults.standard.object(forKey: "enableQuickPreview") as? Bool ?? false
        self.quickPreviewHotkeyKey = UserDefaults.standard.string(forKey: "quickPreviewHotkeyKey") ?? "v"
        self.quickPreviewHotkeyModifiers = UserDefaults.standard.object(forKey: "quickPreviewHotkeyModifiers") as? UInt ?? 1572864 // Cmd+Option
        self.quickPreviewItemCount = UserDefaults.standard.object(forKey: "quickPreviewItemCount") as? Int ?? 10
        self.quickPreviewAutoClose = UserDefaults.standard.object(forKey: "quickPreviewAutoClose") as? Bool ?? true

        // AI Settings
        self.enableAI = UserDefaults.standard.object(forKey: "enableAI") as? Bool ?? false
        self.aiProvider = UserDefaults.standard.string(forKey: "aiProvider") ?? "ollama"
        self.aiAPIKey = UserDefaults.standard.string(forKey: "aiAPIKey") ?? ""
        self.aiModel = UserDefaults.standard.string(forKey: "aiModel") ?? ""
        self.ollamaURL = UserDefaults.standard.string(forKey: "ollamaURL") ?? "http://localhost:11434"
        self.ollamaModel = UserDefaults.standard.string(forKey: "ollamaModel") ?? "llama3.2"

        loadSnippetVariables()
        loadSnippetCategories()
    }

    // MARK: - Snippet Variables Management

    private func loadSnippetVariables() {
        if let data = UserDefaults.standard.data(forKey: "snippetVariables"),
           let variables = try? JSONDecoder().decode([SnippetVariable].self, from: data) {
            self.snippetVariables = variables
        } else {
            // Default variables for new users
            self.snippetVariables = [
                SnippetVariable(name: "MY_NAME", value: ""),
                SnippetVariable(name: "MY_EMAIL", value: ""),
                SnippetVariable(name: "MY_PHONE", value: ""),
                SnippetVariable(name: "MY_COMPANY", value: "")
            ]
        }
    }

    private func saveSnippetVariables() {
        if let data = try? JSONEncoder().encode(snippetVariables) {
            UserDefaults.standard.set(data, forKey: "snippetVariables")
        }
    }

    func addSnippetVariable(name: String, value: String) {
        let newVariable = SnippetVariable(name: name, value: value)
        snippetVariables.append(newVariable)
    }

    func updateSnippetVariable(id: UUID, name: String, value: String) {
        if let index = snippetVariables.firstIndex(where: { $0.id == id }) {
            snippetVariables[index] = SnippetVariable(id: id, name: name, value: value)
        }
    }

    func deleteSnippetVariable(id: UUID) {
        snippetVariables.removeAll { $0.id == id }
    }

    // MARK: - Snippet Categories Management

    private func loadSnippetCategories() {
        if let data = UserDefaults.standard.data(forKey: "snippetCategories"),
           let categories = try? JSONDecoder().decode([SnippetCategory].self, from: data) {
            self.snippetCategories = categories
        } else {
            // Default categories for new users
            self.snippetCategories = [
                SnippetCategory(name: "Email", icon: "📧", isDefault: true),
                SnippetCategory(name: "Work", icon: "💼", isDefault: true),
                SnippetCategory(name: "Personal", icon: "📝", isDefault: true),
                SnippetCategory(name: "Code", icon: "💻", isDefault: true),
                SnippetCategory(name: "Templates", icon: "📋", isDefault: true)
            ]
        }
    }

    private func saveSnippetCategories() {
        if let data = try? JSONEncoder().encode(snippetCategories) {
            UserDefaults.standard.set(data, forKey: "snippetCategories")
        }
    }

    func addSnippetCategory(name: String, icon: String) {
        let newCategory = SnippetCategory(name: name, icon: icon, isDefault: false)
        snippetCategories.append(newCategory)
    }

    func updateSnippetCategory(id: UUID, name: String, icon: String) {
        if let index = snippetCategories.firstIndex(where: { $0.id == id }) {
            let isDefault = snippetCategories[index].isDefault
            snippetCategories[index] = SnippetCategory(id: id, name: name, icon: icon, isDefault: isDefault)
        }
    }

    func deleteSnippetCategory(id: UUID) {
        snippetCategories.removeAll { $0.id == id }
    }
}

// MARK: - SnippetCategory Model

struct SnippetCategory: Codable, Identifiable, Equatable {
    let id: UUID
    let name: String
    let icon: String
    let isDefault: Bool

    init(id: UUID = UUID(), name: String, icon: String, isDefault: Bool) {
        self.id = id
        self.name = name
        self.icon = icon
        self.isDefault = isDefault
    }
}
