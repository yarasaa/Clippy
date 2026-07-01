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

    /// Returns whichever value in `options` is closest to `value`.
    /// Used by the storage-limit init to coerce legacy UserDefaults
    /// values (e.g. an old `historyLimit = 20`) onto the picker's
    /// discrete tag list — otherwise SwiftUI logs "selection is
    /// invalid" and renders the picker blank.
    static func nearest(_ value: Int, in options: [Int]) -> Int {
        guard !options.isEmpty else { return value }
        return options.min(by: { abs($0 - value) < abs($1 - value) }) ?? value
    }

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
    // historyLimit / favoritesLimit / imagesLimit — REMOVED.
    // These powered the old per-type `applyLimits()` system in
    // ClipboardMonitor (also removed) which had a pin-loss bug —
    // see the comment in ClipboardMonitor.saveContext for details.
    // Replaced by a single `maxHistoryItems` setting consumed by
    // HistoryPruner with proper protected-category support.
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

    // Launch animation when the panel appears.
    //   "fade-stagger" — current behavior, soft up-fade with staggered delay
    //   "fan-out"      — cards swoop up from the dock, slight horizontal spread
    //   "scale-pop"    — quick scale from 0.6→1.0, no offset
    //   "none"         — no animation, instant appearance
    @Published var dockPreviewLaunchAnimation: String {
        didSet { UserDefaults.standard.set(dockPreviewLaunchAnimation, forKey: "dockPreviewLaunchAnimation") }
    }

    // Background material for the panel.
    //   "auto"        — Liquid Glass on macOS 26+, ultraThin on older
    //   "translucent" — always ultraThinMaterial (current default behavior)
    //   "solid"       — opaque tinted background (best on slow Macs)
    @Published var dockPreviewMaterial: String {
        didSet { UserDefaults.standard.set(dockPreviewMaterial, forKey: "dockPreviewMaterial") }
    }

    // When to show the numeric "1, 2, 3..." keyboard-shortcut badges on cards.
    // Independent of `enableDockPreviewKeyboardShortcuts` (which gates the
    // hotkeys themselves); this just controls visual presentation.
    //   "always"      — always visible (current behavior)
    //   "on-keypress" — hidden until any key is pressed, then fades in
    //   "never"       — never show badges (cleaner for mouse-only users)
    @Published var dockPreviewKeyboardHintMode: String {
        didSet { UserDefaults.standard.set(dockPreviewKeyboardHintMode, forKey: "dockPreviewKeyboardHintMode") }
    }

    // MARK: - Storage / History Pruning

    /// When true, history items beyond `maxHistoryItems` are
    /// automatically deleted (along with any image files they
    /// reference). Pinned, starred, snippet and encrypted items
    /// are never pruned.
    @Published var enableHistoryAutoPrune: Bool {
        didSet { UserDefaults.standard.set(enableHistoryAutoPrune, forKey: "enableHistoryAutoPrune") }
    }

    /// Max text history items kept on disk (and shown in popover).
    /// Anything older beyond this is hard-deleted. Protected items
    /// (pinned, starred, snippet, encrypted) don't count toward the
    /// cap and are never deleted by the pruner.
    @Published var historyTextLimit: Int {
        didSet { UserDefaults.standard.set(historyTextLimit, forKey: "historyTextLimit") }
    }

    /// Max IMAGE history items kept on disk — separate from text
    /// because each image is 100×–1000× larger on disk than a text
    /// item. When an image row is pruned, its file under
    /// `Application Support/Clippy/Images/` is removed too.
    @Published var historyImageLimit: Int {
        didSet { UserDefaults.standard.set(historyImageLimit, forKey: "historyImageLimit") }
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
    /// When true, every captured image is OCR'd in the background and
    /// the extracted text is stored so it shows up in clipboard search.
    /// Independent of `enableOCR` (which gates the manual OCR button
    /// in the detail view) — a user could keep manual OCR but turn
    /// off auto-OCR if they're worried about battery on Intel Macs.
    @Published var enableAutoOCR: Bool {
        didSet { UserDefaults.standard.set(enableAutoOCR, forKey: "enableAutoOCR") }
    }
    @Published var enableDuplicateDetection: Bool {
        didSet { UserDefaults.standard.set(enableDuplicateDetection, forKey: "enableDuplicateDetection") }
    }
    @Published var enableSourceAppTracking: Bool {
        didSet { UserDefaults.standard.set(enableSourceAppTracking, forKey: "enableSourceAppTracking") }
    }
    @Published var enableFileConverter: Bool {
        didSet { UserDefaults.standard.set(enableFileConverter, forKey: "enableFileConverter") }
    }
    @Published var enableDragDropShelf: Bool {
        didSet { UserDefaults.standard.set(enableDragDropShelf, forKey: "enableDragDropShelf") }
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
        // Removed: historyLimit / favoritesLimit / imagesLimit
        // (see note next to their @Published declarations)
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
        self.dockPreviewHoverDelay = UserDefaults.standard.object(forKey: "dockPreviewHoverDelay") as? Double ?? 0.5

        // Defaults match the previous hard-coded behavior so existing users
        // see no change after upgrade. New users can flip these in Settings.
        self.dockPreviewLaunchAnimation = UserDefaults.standard.string(forKey: "dockPreviewLaunchAnimation") ?? "fade-stagger"
        self.dockPreviewMaterial = UserDefaults.standard.string(forKey: "dockPreviewMaterial") ?? "auto"
        self.dockPreviewKeyboardHintMode = UserDefaults.standard.string(forKey: "dockPreviewKeyboardHintMode") ?? "always"

        // Storage / history pruning. Default ON so the store doesn't
        // grow unbounded over months of use — a real performance
        // problem reported by long-running installs.
        self.enableHistoryAutoPrune = UserDefaults.standard.object(forKey: "enableHistoryAutoPrune") as? Bool ?? true
        // Migrate from old per-type settings (`historyLimit` /
        // `imagesLimit`) if present, so upgrading users keep the
        // values they had chosen instead of getting reset to defaults.
        let oldHistoryLimit = UserDefaults.standard.object(forKey: "historyLimit") as? Int
        let oldImagesLimit = UserDefaults.standard.object(forKey: "imagesLimit") as? Int

        if let oldText = oldHistoryLimit,
           UserDefaults.standard.object(forKey: "historyTextLimit") == nil {
            UserDefaults.standard.set(oldText, forKey: "historyTextLimit")
        }
        if let oldImage = oldImagesLimit,
           UserDefaults.standard.object(forKey: "historyImageLimit") == nil {
            UserDefaults.standard.set(oldImage, forKey: "historyImageLimit")
        }

        // Snap to the nearest picker option. The old system allowed
        // arbitrary values in steps of 5 (e.g. 15, 20, 55) but the
        // new picker only has discrete tags (10, 25, 50, 75, 100).
        // Without snapping, an upgrading user with `historyLimit = 20`
        // sees a blank picker and the console logs
        // "selection 20 is invalid and does not have an associated tag".
        // Snap once on load — picker always renders a valid choice.
        let textOptions = [10, 25, 50, 75, 100]
        let imageOptions = [5, 10, 15, 20]

        let rawText = UserDefaults.standard.object(forKey: "historyTextLimit") as? Int ?? 100
        let rawImage = UserDefaults.standard.object(forKey: "historyImageLimit") as? Int ?? 20

        let snappedText = SettingsManager.nearest(rawText, in: textOptions)
        let snappedImage = SettingsManager.nearest(rawImage, in: imageOptions)

        // Write the snapped values back so subsequent loads are
        // already valid and we don't keep silently coercing every
        // launch (also stops the picker from oscillating if the
        // user closes Settings without making a choice).
        if snappedText != rawText {
            UserDefaults.standard.set(snappedText, forKey: "historyTextLimit")
        }
        if snappedImage != rawImage {
            UserDefaults.standard.set(snappedImage, forKey: "historyImageLimit")
        }

        self.historyTextLimit = snappedText
        self.historyImageLimit = snappedImage

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
        // Default ON — Apple Vision is on-device, fast, free. Making
        // every screenshot searchable is the single biggest "wow"
        // moment of the app. Intel-Mac users who notice battery drain
        // can turn it off in Settings → Features.
        self.enableAutoOCR = UserDefaults.standard.object(forKey: "enableAutoOCR") as? Bool ?? true
        self.enableDuplicateDetection = UserDefaults.standard.object(forKey: "enableDuplicateDetection") as? Bool ?? true
        self.enableSourceAppTracking = UserDefaults.standard.object(forKey: "enableSourceAppTracking") as? Bool ?? true
        self.enableFileConverter = UserDefaults.standard.object(forKey: "enableFileConverter") as? Bool ?? true
        self.enableDragDropShelf = UserDefaults.standard.object(forKey: "enableDragDropShelf") as? Bool ?? true
        self.maxTextStorageLength = UserDefaults.standard.object(forKey: "maxTextStorageLength") as? Int ?? 500000

        // Quick Preview Overlay
        // Default ON for new users — Quick Preview is one of Clippy's
        // most loved features and discoverability is poor when the
        // hotkey overlay starts disabled. Existing users keep whatever
        // they explicitly chose (UserDefaults.object returns nil only
        // for never-set keys, so this can't override a user's "off").
        self.enableQuickPreview = UserDefaults.standard.object(forKey: "enableQuickPreview") as? Bool ?? true
        self.quickPreviewHotkeyKey = UserDefaults.standard.string(forKey: "quickPreviewHotkeyKey") ?? "v"
        self.quickPreviewHotkeyModifiers = UserDefaults.standard.object(forKey: "quickPreviewHotkeyModifiers") as? UInt ?? 1572864 // Cmd+Option
        self.quickPreviewItemCount = UserDefaults.standard.object(forKey: "quickPreviewItemCount") as? Int ?? 10
        self.quickPreviewAutoClose = UserDefaults.standard.object(forKey: "quickPreviewAutoClose") as? Bool ?? true

        // AI Settings
        self.enableAI = UserDefaults.standard.object(forKey: "enableAI") as? Bool ?? false
        // Prefer Apple Foundation Models on macOS 26+ — zero config,
        // free, private. Falls back to Ollama (also free) on older
        // macOS where Apple Intelligence is unavailable.
        let storedProvider = UserDefaults.standard.string(forKey: "aiProvider")
        self.aiProvider = storedProvider ?? (AppleFoundationModelsClient.isReady ? "apple" : "ollama")
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
