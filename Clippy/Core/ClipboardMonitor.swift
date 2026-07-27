//
//  ClipboardMonitor.swift
//  Clippy
//
//  Created by Mehmet Akbaba on 17.09.2025.
//


import AppKit
import Combine
import SwiftUI
import CoreData
import Vision
import NaturalLanguage

extension Notification.Name {
    static let keywordsDidChange = Notification.Name("com.yarasa.Clippy.keywordsDidChange")

    /// Right-click → "Show only items from this app" / "Show all".
    /// userInfo: ["bundleID": String, "appName": String] — or empty
    /// dict to clear the filter. ContentView listens and updates its
    /// fetch predicate.
    static let clippyFilterBySourceApp = Notification.Name("com.yarasa.Clippy.filterBySourceApp")
}

enum ImageOrientation {
    case vertical, horizontal
}

@MainActor
class ClipboardMonitor: ObservableObject {
    @Published var navigationPath = NavigationPath()
    @Published var selectedItemIDs: [UUID] = []
    weak var appDelegate: AppDelegate?
    @Published var sequentialPasteQueueIDs: [UUID] = []

    @Published var sequentialPasteIndex: Int = 1
    @Published var isPastingFromQueue: Bool = false
    private var shouldAddToSequentialQueue = false

    // NOTE: every `setObject` into these caches MUST pass `cost:`.
    // NSCache treats a missing cost as 0, which silently makes
    // `totalCostLimit` unenforceable — only `countLimit` would apply. That
    // was the case here, and it mattered: a JPEG that's 200 KB on disk
    // decodes to ~5.5 MB in memory (a full-screen Retina grab is ~59 MB),
    // so a 50-image count limit alone permits hundreds of MB to GBs.
    private let imageCache: NSCache<NSString, NSImage> = {
        let cache = NSCache<NSString, NSImage>()
        cache.countLimit = 50
        cache.totalCostLimit = 100 * 1024 * 1024 // 100MB
        return cache
    }()
    private let thumbnailCache: NSCache<NSString, NSImage> = {
        let cache = NSCache<NSString, NSImage>()
        cache.countLimit = 100
        cache.totalCostLimit = 20 * 1024 * 1024 // 20MB
        return cache
    }()
    private let appIconCache: NSCache<NSString, NSImage> = {
        let cache = NSCache<NSString, NSImage>()
        cache.countLimit = 100
        cache.totalCostLimit = 15 * 1024 * 1024 // 15MB — app icons are small but accumulate
        return cache
    }()

    private var changeCount: Int
    private var monitoringTask: Task<Void, Error>?
    private var saveTask: Task<Void, Never>?

    // Adaptive polling: tightens when activity is detected, relaxes when idle.
    // This gives sub-second responsiveness during active copy/paste
    // while dropping to a 2 s cadence during long idle stretches.
    private let activeInterval: TimeInterval = 0.5
    private let mediumInterval: TimeInterval = 1.0
    private let idleInterval: TimeInterval   = 2.0
    private let mediumIdleThreshold: TimeInterval = 10.0
    private let fullIdleThreshold: TimeInterval   = 45.0
    private var lastActivityAt: Date = Date()

    private let viewContext = PersistenceController.shared.container.viewContext

    init() {
        self.changeCount = NSPasteboard.general.changeCount
    }

    func startMonitoring(interval: TimeInterval = 0.5) {
        monitoringTask = Task {
            while !Task.isCancelled {
                let didChange = await checkClipboard()
                if didChange {
                    self.lastActivityAt = Date()
                }
                let idle = Date().timeIntervalSince(self.lastActivityAt)
                let nextInterval: TimeInterval
                if idle < self.mediumIdleThreshold {
                    nextInterval = self.activeInterval
                } else if idle < self.fullIdleThreshold {
                    nextInterval = self.mediumInterval
                } else {
                    nextInterval = self.idleInterval
                }
                try await Task.sleep(for: .seconds(nextInterval))
            }
        }
    }

    func stopMonitoring() {
        monitoringTask?.cancel()
        monitoringTask = nil
        saveTask?.cancel()
        saveTask = nil
    }

    func setMonitoringInterval(_ interval: TimeInterval) {
        stopMonitoring()
        startMonitoring(interval: interval)
    }

    @discardableResult
    private func checkClipboard() async -> Bool {
        let pb = NSPasteboard.general
        if pb.changeCount != changeCount {
            changeCount = pb.changeCount

            if pb.types?.contains(PasteManager.pasteFromClippyType) == true {
                return true
            }

            let frontmostApp = NSWorkspace.shared.frontmostApplication
            let sourceAppName = frontmostApp?.localizedName
            let sourceAppBundleIdentifier = frontmostApp?.bundleIdentifier

            let settings = SettingsManager.shared

            if let str = pb.string(forType: .string), !str.isEmpty {
                // Check duplicates if enabled
                if settings.enableDuplicateDetection && isDuplicateText(str) {
                    return true
                }

                // Truncate extremely long texts based on settings
                let maxStorageLength = settings.maxTextStorageLength
                let textToStore = (maxStorageLength != Int.max && str.count > maxStorageLength) ? String(str.prefix(maxStorageLength)) : str
                let isCode = settings.enableAutoCodeDetection ? self.isLikelyCode(textToStore) : false
                let appName = settings.enableSourceAppTracking ? sourceAppName : nil
                let appBundle = settings.enableSourceAppTracking ? sourceAppBundleIdentifier : nil
                let item = ClipboardItem(contentType: .text(textToStore), date: Date(), isCode: isCode, sourceAppName: appName, sourceAppBundleIdentifier: appBundle, enableContentDetection: settings.enableContentDetection)
                addNewItem(item)

                return true
            }

            if let image = pb.readObjects(forClasses: [NSImage.self], options: nil)?.first as? NSImage {
                guard SettingsManager.shared.showImagesTab else {
                    return true
                }
                await self.saveImageInBackground(image, sourceAppName: sourceAppName, sourceAppBundleIdentifier: sourceAppBundleIdentifier)
                return true
            }

            return true
        }
        return false
    }

    private func saveImageInBackground(_ image: NSImage, sourceAppName: String?, sourceAppBundleIdentifier: String?) async {
        guard let jpegData = image.storageJPEGData() else { return }

        let fileName = "\(UUID().uuidString).jpg"
        guard let imageDir = self.getImagesDirectory() else { return }
        let fileURL = imageDir.appendingPathComponent(fileName)

        do {
            try await Task(priority: .background) {
                try jpegData.write(to: fileURL)
            }.value

            let item = ClipboardItem(contentType: .image(imagePath: fileName), date: Date(), sourceAppName: sourceAppName, sourceAppBundleIdentifier: sourceAppBundleIdentifier)
            self.addNewItem(item)
        } catch {
        }
    }

    func addImageToHistory(image: NSImage) {
        guard let newImagePath = saveImage(image) else {
            return
        }
        let newItem = ClipboardItem(contentType: .image(imagePath: newImagePath), date: Date(), sourceAppName: "Clippy Editor", sourceAppBundleIdentifier: "com.yarasa.Clippy.Editor")
        addNewItem(newItem)
    }

    func saveEditedImage(_ image: NSImage, from originalItem: ClipboardItemEntity) {
        guard let jpegData = image.storageJPEGData(),
              let imageDir = getImagesDirectory() else {
            return
        }

        let fileName = "\(UUID().uuidString).jpg"
        let fileURL = imageDir.appendingPathComponent(fileName)

        do {
            try jpegData.write(to: fileURL)
            let newItem = ClipboardItem(contentType: .image(imagePath: fileName), date: Date(), sourceAppName: "Clippy Editor", sourceAppBundleIdentifier: "com.yarasa.Clippy.Editor")
            addNewItem(newItem)
        } catch {
        }
    }

    func recognizeText(for item: ClipboardItemEntity) async {
        guard item.contentType == "image",
              let imagePath = item.content,
              let image = loadImage(from: imagePath) else {
            return
        }

        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            return
        }
        let request = VNRecognizeTextRequest { (request, error) in
            guard let observations = request.results as? [VNRecognizedTextObservation], error == nil else {
                return
            }

            let recognizedStrings = observations.compactMap { observation in
                return observation.topCandidates(1).first?.string
            }

            guard !recognizedStrings.isEmpty else {
                return
            }

            let fullText = recognizedStrings.joined(separator: "\n")

            let ocrItem = ClipboardItem(contentType: .text(fullText), date: Date(), isCode: self.isLikelyCode(fullText), sourceAppName: "Clippy OCR", sourceAppBundleIdentifier: "com.yarasa.Clippy.OCR")
            self.addNewItem(ocrItem)
        }

        var languages: [String] = []
        let currentLanguageCode = SettingsManager.shared.appLanguage
        if currentLanguageCode == "tr" {
            languages.append("tr-TR")
        }
        languages.append("en-US")

        request.recognitionLevel = .accurate
        request.recognitionLanguages = languages

        try? VNImageRequestHandler(cgImage: cgImage, options: [:]).perform([request])
    }

    func addNewItem(_ item: ClipboardItem) {
        if self.shouldAddToSequentialQueue && self.isPastingFromQueue {
            self.sequentialPasteQueueIDs.removeAll()
            self.isPastingFromQueue = false
        }

        if self.shouldAddToSequentialQueue {
            self.sequentialPasteIndex = 0
            self.sequentialPasteQueueIDs.append(item.id)
            self.shouldAddToSequentialQueue = false
        }

        let newItemEntity = ClipboardItemEntity(context: viewContext)
        newItemEntity.id = item.id
        newItemEntity.date = item.date
        newItemEntity.isFavorite = item.isFavorite
        newItemEntity.isCode = item.isCode
        newItemEntity.isPinned = item.isPinned
        newItemEntity.isEncrypted = item.isEncrypted
        newItemEntity.sourceAppName = item.sourceAppName
        newItemEntity.sourceAppBundleIdentifier = item.sourceAppBundleIdentifier
        newItemEntity.detectedDate = item.detectedDate

        switch item.contentType {
        case .text(let text):
            newItemEntity.contentType = "text"
            newItemEntity.content = text
            // Long text → queue an AI title so the card list stays
            // scannable. Service self-gates on settings + local-only
            // providers and skips snippets/encrypted at write time.
            if text.count >= AutoTitleService.minTextLength {
                AutoTitleService.shared.requestTitle(for: item.id)
            }
            // Track repeated text *shapes* so we can suggest a reusable
            // template. Cheap, synchronous, self-gates on the setting.
            TemplateDetector.shared.observe(text, isCode: item.isCode)
        case .image(let imagePath):
            newItemEntity.contentType = "image"
            newItemEntity.content = imagePath
            // Kick off OCR in the background so the screenshot
            // becomes searchable by its visible text. Never blocks
            // the capture path; result is written back via a
            // background context once Vision finishes.
            runAutoOCRInBackground(itemID: item.id, imagePath: imagePath)
        }

        // Note: the per-type `applyLimits()` (kept below as dead code
        // for now) was replaced by `HistoryPruner` — it batches across
        // 25 inserts on a background context AND protects pinned,
        // starred, snippet, and encrypted items by predicate, which
        // the old per-type sweep didn't. notifyInsert() is fired by
        // saveContext() once the row is actually committed.
        scheduleSave()
    }

    /// The two selected text items to diff, oldest first — or nil unless
    /// exactly two *text* items are selected.
    ///
    /// Resolves the IDs against the store rather than whatever list is
    /// currently on screen. The previous implementation searched the
    /// filtered fetch results, so typing a search or switching tabs made
    /// an active selection silently un-comparable.
    func comparablePair() -> (ClipboardItemEntity, ClipboardItemEntity)? {
        guard selectedItemIDs.count == 2 else { return nil }

        let request = NSFetchRequest<ClipboardItemEntity>(entityName: "ClipboardItemEntity")
        request.predicate = NSPredicate(format: "id IN %@ AND contentType == 'text'", selectedItemIDs)
        request.fetchLimit = 2
        guard let found = try? viewContext.fetch(request), found.count == 2 else { return nil }

        let sorted = found.sorted { ($0.date ?? .distantPast) < ($1.date ?? .distantPast) }
        return (sorted[0], sorted[1])
    }

    /// Short column label for the compare window, e.g. "Chrome · 2m ago".
    /// Without this both sides just said "Old"/"New", which doesn't help
    /// when you're comparing two things you copied minutes apart.
    static func diffLabel(for item: ClipboardItemEntity) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        let when = formatter.localizedString(for: item.date ?? Date(), relativeTo: Date())
        if let app = item.sourceAppName, !app.isEmpty {
            return "\(app) · \(when)"
        }
        return when
    }

    /// Persist a reusable template as a snippet. `keyword` should already
    /// include the `;` trigger (e.g. ";invoice"). Returns the new item's
    /// id, or nil if a snippet with that keyword already exists.
    @discardableResult
    func createTemplateSnippet(keyword: String, content: String, category: String? = nil) -> UUID? {
        let trimmedKeyword = keyword.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedKeyword.isEmpty, !content.isEmpty else { return nil }

        // Don't clobber an existing snippet with the same trigger.
        let existing = NSFetchRequest<ClipboardItemEntity>(entityName: "ClipboardItemEntity")
        existing.predicate = NSPredicate(format: "keyword ==[c] %@", trimmedKeyword)
        existing.fetchLimit = 1
        if let hit = try? viewContext.fetch(existing), !hit.isEmpty { return nil }

        let entity = ClipboardItemEntity(context: viewContext)
        let id = UUID()
        entity.id = id
        entity.date = Date()
        entity.contentType = "text"
        entity.content = content
        entity.keyword = trimmedKeyword
        entity.category = category
        entity.sourceAppName = "Clippy Templates"
        entity.sourceAppBundleIdentifier = "com.yarasa.Clippy.Templates"

        saveContext()
        return id
    }

    /// Runs Apple Vision OCR on a freshly-captured image in the
    /// background and writes the result into the item's
    /// `extractedText` field.
    ///
    /// Design notes:
    ///   - Detached `.utility` task: never blocks the main thread or
    ///     the capture hot path. OCR can take 100–500ms depending on
    ///     image size; the user sees the new item appear instantly
    ///     and the searchable text shows up shortly after.
    ///   - Uses a background CoreData context. `viewContext` has
    ///     `automaticallyMergesChangesFromParent = true`, so the
    ///     update propagates to the UI without us touching it.
    ///   - Silent on failure. OCR is bonus value — if Vision can't
    ///     read the image (low contrast, no text), the item is still
    ///     saved fine, just without searchable text.
    ///   - Gated by `enableAutoOCR`. Users on Intel Macs or those who
    ///     prefer manual control can opt out; the manual OCR button
    ///     in the detail view still works either way.
    private func runAutoOCRInBackground(itemID: UUID, imagePath: String) {
        guard SettingsManager.shared.enableAutoOCR else { return }

        // Snapshot UI-actor state on the main thread before hopping off.
        let appLanguage = SettingsManager.shared.appLanguage
        let imagesDir = getImagesDirectory()

        Task.detached(priority: .utility) {
            guard let imagesDir = imagesDir else { return }
            let imageURL = imagesDir.appendingPathComponent(imagePath)
            guard FileManager.default.fileExists(atPath: imageURL.path) else { return }

            // Serialised, and with a ceiling on the decode size. Copying
            // several screenshots in a row used to start that many Vision
            // recognitions concurrently, each holding a full-resolution
            // decode — measured at 158% CPU and 108 MB → 297 MB resident.
            let extractedText = await OCRScheduler.shared.recognize(
                imageURL: imageURL,
                primaryHint: appLanguage
            )
            guard !extractedText.isEmpty else { return }

            // Promote to "code" when the OCR text looks like source
            // (curly braces, keywords, operators). Lets the Code tab
            // surface Stack Overflow screenshots alongside textually
            // copied snippets.
            let promoteToCode = await MainActor.run { self.isLikelyCode(extractedText) }

            // Detect dominant language for the flag badge. Skip on
            // code (keywords like `func`/`return` fool the model
            // into picking Spanish/Italian) and on very short text
            // (under ~20 chars NLLanguageRecognizer is unreliable).
            let detectedLanguage: String? = promoteToCode
                ? nil
                : Self.detectDominantLanguage(in: extractedText)

            await Self.persistExtractedText(extractedText,
                                            promoteToCode: promoteToCode,
                                            language: detectedLanguage,
                                            forItemID: itemID)
        }
    }

    /// Returns the short BCP-47-ish code NLLanguageRecognizer is
    /// most confident in ("tr", "en", "ja"). Returns nil only for
    /// very short input (< 10 chars; below that recognizer guesses
    /// are noise) or when confidence is genuinely poor.
    ///
    /// CJK / Arabic / Cyrillic scripts pass with any positive
    /// confidence because they're already script-unambiguous — the
    /// 0.5 bar is there for Latin-script disambiguation (Italian
    /// vs Spanish, etc.) and would unfairly drop short CJK samples.
    nonisolated private static func detectDominantLanguage(in text: String) -> String? {
        guard text.count >= 10 else { return nil }
        let recognizer = NLLanguageRecognizer()
        recognizer.processString(text)
        guard let language = recognizer.dominantLanguage else { return nil }

        let scriptDistinct: Set<String> = ["ja", "ko", "zh", "ar", "ru", "uk", "th"]
        if scriptDistinct.contains(language.rawValue) {
            return language.rawValue
        }
        let hypotheses = recognizer.languageHypotheses(withMaximum: 1)
        if let conf = hypotheses[language], conf < 0.5 { return nil }
        return language.rawValue
    }

    /// Retries a background fetch up to a few times so we don't lose
    /// OCR results when the main context's debounced save lags
    /// behind Vision's ~300ms finish. By the 2nd or 3rd attempt the
    /// row is on disk and the background context can find it.
    nonisolated private static func persistExtractedText(_ text: String,
                                                         promoteToCode: Bool = false,
                                                         language: String? = nil,
                                                         forItemID itemID: UUID) async {
        let backoffsMs: [UInt64] = [0, 100, 250, 500, 1000]

        for delayMs in backoffsMs {
            if delayMs > 0 {
                try? await Task.sleep(nanoseconds: delayMs * 1_000_000)
            }

            let bgContext = await PersistenceController.shared.newBackgroundContext()
            let saved: Bool = await withCheckedContinuation { continuation in
                bgContext.perform {
                    let fetch = NSFetchRequest<ClipboardItemEntity>(entityName: "ClipboardItemEntity")
                    fetch.predicate = NSPredicate(format: "id == %@", itemID as CVarArg)
                    fetch.fetchLimit = 1
                    guard let entity = (try? bgContext.fetch(fetch))?.first else {
                        continuation.resume(returning: false)
                        return
                    }
                    entity.extractedText = text
                    // Promotion only — never demote, since the user
                    // may have explicitly classified this item.
                    if promoteToCode { entity.isCode = true }
                    if let language { entity.detectedLanguage = language }
                    do {
                        try bgContext.save()
                        continuation.resume(returning: true)
                    } catch {
                        continuation.resume(returning: false)
                    }
                }
            }

            if saved {
                // OCR text is now persisted — if it's substantial,
                // queue an AI title so the screenshot card gets a
                // scannable name ("AWS IAM Policy Error" instead of
                // just dimensions). Service self-gates on settings.
                if text.count >= AutoTitleService.minOCRLength {
                    await MainActor.run {
                        AutoTitleService.shared.requestTitle(for: itemID)
                    }
                }
                return
            }
        }
    }

    private func isDuplicateText(_ text: String) -> Bool {
        // Original CoreData-based duplicate detection — most reliable.
        // The earlier fingerprint optimization caused some captures to be
        // incorrectly treated as duplicates and skipped.
        let fetchRequest: NSFetchRequest<ClipboardItemEntity> = ClipboardItemEntity.fetchRequest()
        fetchRequest.sortDescriptors = [NSSortDescriptor(keyPath: \ClipboardItemEntity.date, ascending: false)]
        fetchRequest.predicate = NSPredicate(format: "isFavorite == NO AND contentType == 'text'")
        fetchRequest.fetchLimit = 1

        do {
            guard let lastItem = try viewContext.fetch(fetchRequest).first,
                  let lastContent = lastItem.content else { return false }

            // Quick length check before expensive string comparison
            guard lastContent.count == text.count else { return false }

            // For very long texts, compare prefix + suffix + length instead of full comparison
            if text.count > 100_000 {
                return lastContent.prefix(1000) == text.prefix(1000) &&
                       lastContent.suffix(1000) == text.suffix(1000)
            }

            return lastContent == text
        } catch {
            return false
        }
    }

    private func findEntity(for itemID: UUID) -> ClipboardItemEntity? {
        let fetchRequest: NSFetchRequest<ClipboardItemEntity> = ClipboardItemEntity.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "id == %@", itemID as CVarArg)
        fetchRequest.fetchLimit = 1

        do {
            let result = try viewContext.fetch(fetchRequest)
            return result.first
        } catch {
        }
        return nil
    }

    func copyToClipboard(item: ClipboardItem) {
        let pb = NSPasteboard.general
        pb.clearContents()

        switch item.contentType {
        case .text(let string):
            pb.setString(string, forType: .string)
        case .image(let imagePath):
            if let imageDir = getImagesDirectory() {
                let imageURL = imageDir.appendingPathComponent(imagePath)
                if let image = NSImage(contentsOf: imageURL) {
                    pb.writeObjects([image])
                }
            }
        }

        pb.addTypes([PasteManager.pasteFromClippyType], owner: nil)
    }

    func prepareForSequentialCopy() {
        shouldAddToSequentialQueue = true
    }
    func pasteNextInSequence(completion: @escaping () -> Void) {
        guard !sequentialPasteQueueIDs.isEmpty else { return }

        isPastingFromQueue = true

        let itemID = sequentialPasteQueueIDs[sequentialPasteIndex]
        guard let itemToPaste = findEntity(for: itemID)?.toClipboardItem() else { return }

        PasteManager.shared.pasteItem(itemToPaste) { [weak self] in
            guard let self = self else { return }

            if self.sequentialPasteIndex + 1 >= self.sequentialPasteQueueIDs.count {
                self.clearSequentialPasteQueue()
            } else {
                self.sequentialPasteIndex += 1
            }
            completion()
        }
    }

    func clearSequentialPasteQueue() {
        sequentialPasteQueueIDs.removeAll()
        sequentialPasteIndex = 0
        isPastingFromQueue = false
    }

    func addSelectionToSequentialQueue() {
        guard !selectedItemIDs.isEmpty else { return }

        self.sequentialPasteQueueIDs = self.selectedItemIDs

        self.sequentialPasteIndex = 0
        self.isPastingFromQueue = false


        clearSelection()
    }

    func toggleSelection(for itemID: UUID) {
        if let index = selectedItemIDs.firstIndex(of: itemID) {
            selectedItemIDs.remove(at: index)
        } else { 
            selectedItemIDs.append(itemID)
        }
    }

    func clearSelection() {
        selectedItemIDs.removeAll()
    }

    func getCombinedTextForSelection() -> String {
        let selectedItems = selectedItemIDs.compactMap { id in findEntity(for: id) }.filter { $0.contentType == "text" }
        return selectedItems.compactMap { $0.content }.joined(separator: "\n")
    }

    func copySelectionToClipboard() {
        let pb = NSPasteboard.general
        pb.clearContents()

        let fetchRequest: NSFetchRequest<ClipboardItemEntity> = ClipboardItemEntity.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "id IN %@", selectedItemIDs)
        guard let selectedItems = try? viewContext.fetch(fetchRequest) else { return }
        var pasteboardObjects: [NSPasteboardWriting] = []

        let combinedText = selectedItems.filter { $0.contentType == "text" }.compactMap { $0.content }.joined(separator: "\n")
        if !combinedText.isEmpty {
            pasteboardObjects.append(combinedText as NSPasteboardWriting)
        }

        let images = selectedItems.filter { $0.contentType == "image" }.compactMap { item -> NSImage? in
            guard let path = item.content, let image = loadImage(from: path) else { return nil }
            return image
        }

        pasteboardObjects.append(contentsOf: images as [NSPasteboardWriting])

        if !pasteboardObjects.isEmpty {
            pb.writeObjects(pasteboardObjects)
            pb.addTypes([PasteManager.pasteFromClippyType], owner: nil)
        }
    }

    func createItemProviderForSelection() -> NSItemProvider {
        let combinedText = getCombinedTextForSelection()

        return NSItemProvider(object: combinedText as NSString)
    }

    func combineSelectedImagesAsNewItem(orientation: ImageOrientation) {
        let fetchRequest: NSFetchRequest<ClipboardItemEntity> = ClipboardItemEntity.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "id IN %@", selectedItemIDs)

        guard let selectedItems = try? viewContext.fetch(fetchRequest) else { return }

        let images = selectedItemIDs.compactMap { id -> (image: NSImage, sourceApp: String?)? in
            guard let item = selectedItems.first(where: { $0.id == id }),
                  item.contentType == "image",
                  let path = item.content,
                  let image = loadImage(from: path) else {
                return nil
            }
            return (image, item.sourceAppName)
        }

        guard images.count > 1 else { return }

        let imageList = images.map { $0.image }
        let combinedImage: NSImage?

        switch orientation {
        case .vertical:
            combinedImage = combineImagesVertically(imageList)
        case .horizontal:
            combinedImage = combineImagesHorizontally(imageList)
        }

        if let finalImage = combinedImage, let newImagePath = saveImage(finalImage) {
            let newItem = ClipboardItem(contentType: .image(imagePath: newImagePath), date: Date(), sourceAppName: L("Clippy Combiner", settings: SettingsManager.shared), sourceAppBundleIdentifier: "com.yarasa.Clippy.Combiner")
            addNewItem(newItem)
        }
    }

    func toggleFavorite(for itemID: UUID) {
        guard let entity = findEntity(for: itemID) else { return }
        entity.isFavorite.toggle()
        scheduleSave()
    }

    func togglePin(for itemID: UUID) {
        guard let entity = findEntity(for: itemID) else { return }
        entity.isPinned.toggle()
        scheduleSave()
    }

    func toggleEncryption(for itemID: UUID) {
        guard let entity = findEntity(for: itemID) else { return }
        entity.isEncrypted.toggle()
        scheduleSave()
    }

    func deleteSelectedItems() {
        let idsToDelete = selectedItemIDs

        let fetchRequest: NSFetchRequest<ClipboardItemEntity> = ClipboardItemEntity.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "id IN %@", idsToDelete)

        do {
            let itemsToDelete = try viewContext.fetch(fetchRequest)
            for item in itemsToDelete {
                delete(item: item, shouldSave: false)
            }
            clearSelection()
            scheduleSave()
        } catch {
        }
    }

    func delete(item: ClipboardItemEntity) {
        if item.contentType == "image" {
            if let path = item.content {
                imageCache.removeObject(forKey: path as NSString)
            }
            Task(priority: .background) {
                deleteImageFile(for: item)
            }
        }

        viewContext.delete(item)
        scheduleSave()
    }

    private func delete(item: ClipboardItemEntity, shouldSave: Bool) {
        if item.contentType == "image" {
            if let path = item.content { imageCache.removeObject(forKey: path as NSString) }
            Task(priority: .background) { deleteImageFile(for: item) }
        }
        viewContext.delete(item)
        if shouldSave {
            scheduleSave()
        }
    }

    func clear(tab: ContentView.Tab) {
        var predicates: [NSPredicate] = []

        switch tab {
        case .history:
            predicates.append(NSPredicate(format: "(keyword == nil OR keyword == '')"))
            predicates.append(NSPredicate(format: "isFavorite == NO"))
            // Keep pinned items — a "clear" shouldn't wipe things the
            // user explicitly pinned to the top (issue #9).
            predicates.append(NSPredicate(format: "isPinned == NO"))
            predicates.append(NSPredicate(format: "contentType == 'text'"))
            if SettingsManager.shared.showCodeTab {
                predicates.append(NSPredicate(format: "isCode == NO"))
            }
        case .code:
            predicates.append(NSPredicate(format: "(keyword == nil OR keyword == '')"))
            predicates.append(NSPredicate(format: "isFavorite == NO"))
            predicates.append(NSPredicate(format: "isPinned == NO"))
            predicates.append(NSPredicate(format: "isCode == YES"))
        case .images:
            predicates.append(NSPredicate(format: "(keyword == nil OR keyword == '')"))
            predicates.append(NSPredicate(format: "isFavorite == NO"))
            predicates.append(NSPredicate(format: "isPinned == NO"))
            predicates.append(NSPredicate(format: "contentType == 'image'"))
            let imagesFetchRequest: NSFetchRequest<ClipboardItemEntity> = ClipboardItemEntity.fetchRequest()
            imagesFetchRequest.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: predicates)
            if let imagesToRemove = try? viewContext.fetch(imagesFetchRequest) {
                imagesToRemove.forEach { deleteImageFile(for: $0) }
            }
        case .snippets:
            predicates.append(NSPredicate(format: "keyword != nil AND keyword != ''"))

        case .favorites:
            let favFetchRequest: NSFetchRequest<ClipboardItemEntity> = ClipboardItemEntity.fetchRequest()
            favFetchRequest.predicate = NSPredicate(format: "isFavorite == YES")
            if let favoritesToUpdate = try? viewContext.fetch(favFetchRequest) {
                favoritesToUpdate.forEach { $0.isFavorite = false }
            }
            scheduleSave()
            return
        }

        let fetchRequestToDelete: NSFetchRequest<ClipboardItemEntity> = ClipboardItemEntity.fetchRequest()
        fetchRequestToDelete.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: predicates)

        do {
            let itemsToDelete = try viewContext.fetch(fetchRequestToDelete)
            for item in itemsToDelete {
                viewContext.delete(item)
            }
        } catch {
        }
        scheduleSave()
    }
    func removeDuplicates() {
        let request: NSFetchRequest<NSFetchRequestResult> = ClipboardItemEntity.fetchRequest()
        request.predicate = NSPredicate(format: "contentType == 'text'")
        request.resultType = .dictionaryResultType

        let contentKey = "content"
        let countKey = "count"

        let countExpression = NSExpressionDescription()
        countExpression.name = countKey
        countExpression.expression = NSExpression(forFunction: "count:", arguments: [NSExpression(forKeyPath: "id")])
        countExpression.expressionResultType = .integer64AttributeType

        request.propertiesToFetch = [contentKey, countExpression]
        request.propertiesToGroupBy = [contentKey]
        request.havingPredicate = NSPredicate(format: "%K > 1", countKey)

        do {
            let duplicates = try viewContext.fetch(request) as? [[String: Any]] ?? []
            for duplicate in duplicates {
                if let content = duplicate[contentKey] as? String { 
                    let duplicateFetchRequest: NSFetchRequest<ClipboardItemEntity> = ClipboardItemEntity.fetchRequest()
                    duplicateFetchRequest.predicate = NSPredicate(format: "content == %@", content)
                    duplicateFetchRequest.sortDescriptors = [NSSortDescriptor(keyPath: \ClipboardItemEntity.date, ascending: false)]

                    let items = try viewContext.fetch(duplicateFetchRequest)
                    for itemToDelete in items.dropFirst() {
                        viewContext.delete(itemToDelete)
                    }
                }
            }
        } catch {
        }
        scheduleSave()
    }

    /// On-disk location of a stored clipboard image.
    func imageURL(forRelativePath path: String) -> URL? {
        ThumbnailStore.imageURL(for: path)
    }

    /// Pixel dimensions read from the file header — no decode. See
    /// ThumbnailStore for why this isn't `loadImage(...)?.size`.
    func imagePixelSize(from path: String) -> CGSize? {
        ThumbnailStore.pixelSize(for: path)
    }

    func loadImage(from path: String) -> NSImage? {
        if let cachedImage = imageCache.object(forKey: path as NSString) {
            return cachedImage
        }

        guard let imageURL = imageURL(forRelativePath: path) else {
            return nil
        }

        if let image = NSImage(contentsOf: imageURL) {
            imageCache.setObject(image, forKey: path as NSString, cost: image.approximateByteCost)
            return image
        }
        return nil
    }

    /// Card-sized thumbnail, decoded straight from disk at reduced
    /// resolution.
    ///
    /// The important part is that this never goes through `loadImage`.
    /// ImageIO decodes only the reduced bitmap, so a 5K screenshot costs
    /// ~1.6 MB here instead of ~59 MB — and the full-size decode never
    /// enters `imageCache` at all. The previous implementation loaded the
    /// full image first and scaled it down, which paid the entire memory
    /// cost to produce something small (and it was dead code — nothing
    /// called it, so cards were rendering full-size images directly).
    func loadThumbnail(from path: String, maxPixel: CGFloat = 640) -> NSImage? {
        ThumbnailStore.thumbnail(for: path, maxPixel: maxPixel)
    }

    func loadIcon(for bundleIdentifier: String, completion: @escaping (NSImage?) -> Void) {
        if let cachedIcon = appIconCache.object(forKey: bundleIdentifier as NSString) {
            completion(cachedIcon)
            return
        }

        Task(priority: .userInitiated) {
            var icon: NSImage?
            if let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleIdentifier) {
                icon = NSWorkspace.shared.icon(forFile: appURL.path)
            }

            if bundleIdentifier == "com.yarasa.Clippy.OCR" {
                icon = NSImage(systemSymbolName: "text.viewfinder", accessibilityDescription: "OCR")
            }

            if let finalIcon = icon {
                self.appIconCache.setObject(finalIcon, forKey: bundleIdentifier as NSString,
                                            cost: finalIcon.approximateByteCost)
                await MainActor.run { completion(finalIcon) }
            } else {
                let genericIcon = NSImage(systemSymbolName: "questionmark.app.dashed", accessibilityDescription: "Unknown App")!
                self.appIconCache.setObject(genericIcon, forKey: bundleIdentifier as NSString,
                                            cost: genericIcon.approximateByteCost)
                await MainActor.run { completion(genericIcon) }
            }
        }
    }

    func transformText(for item: ClipboardItem, transformation: (String) -> String?) {
        guard item.isText, let transformedText = transformation(item.content) else { return }

        let newItem = ClipboardItem(contentType: .text(transformedText),
                                    date: Date(),
                                    isCode: self.isLikelyCode(transformedText),
                                    sourceAppName: item.sourceAppName)
        addNewItem(newItem)
    }

    func updateText(for itemID: UUID, transformation: (String) -> String) {
        guard let entity = findEntity(for: itemID),
              let originalText = entity.content else { return }

        let transformedText = transformation(originalText)
        entity.content = transformedText
        entity.isCode = self.isLikelyCode(transformedText)
        scheduleSave()
    }

    func formatJSON(for itemID: UUID) {
        guard let entity = findEntity(for: itemID),
              let originalText = entity.content,
              let transformedText = prettyPrintJSON(originalText) else { return }

        entity.content = transformedText
        entity.isCode = true
        scheduleSave()
    }

    func generateUUID() {
        let uuidString = UUID().uuidString

        copyTextToClipboard(uuidString)

        let item = ClipboardItem(contentType: .text(uuidString), date: Date(), isCode: true)

        addNewItem(item)
    }

    func generateLoremIpsum() {
        let loremIpsumText = "Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat."

        copyTextToClipboard(loremIpsumText)

        let item = ClipboardItem(contentType: .text(loremIpsumText), date: Date())
        addNewItem(item)
    }

    func minifyJSON(for itemID: UUID) {
        guard let entity = findEntity(for: itemID),
              let originalText = entity.content,
              let transformedText = minifyJSON(originalText) else { return }

        entity.content = transformedText
        entity.isCode = true
        scheduleSave()
    }

    func removeDuplicateLines(for itemID: UUID) {
        updateText(for: itemID) { originalText in
            let lines = originalText.components(separatedBy: .newlines)
            let orderedSet = NSOrderedSet(array: lines)
            let uniqueLines = orderedSet.array as! [String]
            return uniqueLines.joined(separator: "\n")
        }
    }

    func joinLines(for itemID: UUID) {
        updateText(for: itemID) { originalText in
            return originalText.components(separatedBy: .newlines)
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty }
                .joined(separator: " ")
        }
    }

    func encodeAsJSONString(for itemID: UUID) {
        updateText(for: itemID) { originalText in
            do {
                let data = try JSONSerialization.data(withJSONObject: [originalText], options: [])
                let jsonArrayString = String(data: data, encoding: .utf8) ?? "[]"
                return String(jsonArrayString.dropFirst().dropLast())
            } catch {
                return originalText
            }
        }
    }

    func decodeFromJSONString(for itemID: UUID) {
        updateText(for: itemID) { originalText in
            guard let data = originalText.data(using: .utf8) else { return originalText }
            return (try? JSONSerialization.jsonObject(with: data, options: .allowFragments)) as? String ?? originalText
        }
    }

    func createCalendarEvent(for item: ClipboardItemEntity) {
        guard let startDate = item.detectedDate, let title = item.content else { return }

        let endDate = startDate.addingTimeInterval(3600)

        let icsString = """
        BEGIN:VCALENDAR
        VERSION:2.0
        PRODID:-
        BEGIN:VEVENT
        UID:\(UUID().uuidString)
        DTSTAMP:\(formattedDate(Date()))
        DTSTART:\(formattedDate(startDate))
        DTEND:\(formattedDate(endDate))
        SUMMARY:\(title.trimmingCharacters(in: .whitespacesAndNewlines))
        END:VEVENT
        END:VCALENDAR
        """

        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("\(UUID().uuidString).ics")
        try? icsString.write(to: tempURL, atomically: true, encoding: .utf8)

        NSWorkspace.shared.open(tempURL)
    }
    private func copyTextToClipboard(_ text: String) {
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(text, forType: .string)
        pb.addTypes([PasteManager.pasteFromClippyType], owner: nil)
    }

    func prettyPrintJSON(_ jsonString: String) -> String? {
        guard let data = jsonString.data(using: .utf8) else { return nil }
        do {
            let jsonObject = try JSONSerialization.jsonObject(with: data, options: .allowFragments)
            let prettyData = try JSONSerialization.data(withJSONObject: jsonObject, options: [.prettyPrinted, .sortedKeys])
            return String(data: prettyData, encoding: .utf8)
        } catch {
            return nil
        }
    }

    func minifyJSON(_ jsonString: String) -> String? {
        guard let data = jsonString.data(using: .utf8) else { return nil }
        do {
            let jsonObject = try JSONSerialization.jsonObject(with: data, options: .allowFragments)
            let minifiedData = try JSONSerialization.data(withJSONObject: jsonObject, options: [])
            return String(data: minifiedData, encoding: .utf8)
        } catch {
            return nil
        }
    }

    func hexToRGB(from hex: String) -> String? {
        let hex = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r, g, b: UInt64
        switch hex.count {
        case 3:
            (r, g, b) = ((int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17) 
        case 6:
            (r, g, b) = (int >> 16, int >> 8 & 0xFF, int & 0xFF)
        default:
            return nil
        }
        return "rgb(\(r), \(g), \(b))"
    }
    func rgbToHex(from rgb: String) -> String? {
        let pattern = #"rgba?\((\d+),\s*(\d+),\s*(\d+)(?:,\s*([\d.]+))?\)"#
        guard let match = rgb.range(of: pattern, options: .regularExpression) else { return nil }

        let components = rgb[match]
            .replacingOccurrences(of: "rgba", with: "")
            .replacingOccurrences(of: "rgb", with: "")
            .replacingOccurrences(of: "(", with: "")
            .replacingOccurrences(of: ")", with: "")
            .split(separator: ",")
            .map { Int($0.trimmingCharacters(in: .whitespaces)) ?? 0 }

        guard components.count >= 3 else { return nil }
        return String(format: "#%02X%02X%02X", components[0], components[1], components[2])
    }

    private func deleteImageFile(for item: ClipboardItemEntity) {
        guard item.contentType == "image", let imagePath = item.content,
              let imageDir = getImagesDirectory() else { return }
        let fileURL = imageDir.appendingPathComponent(imagePath)
        do {
            try FileManager.default.removeItem(at: fileURL)
        } catch { print("❌ Resim dosyası silme hatası: \(error)") }
    }

    private func combineImagesVertically(_ images: [NSImage]) -> NSImage? {
        guard !images.isEmpty else { return nil }

        let totalHeight = images.reduce(0) { $0 + $1.size.height }
        let maxWidth = images.reduce(0) { max($0, $1.size.width) }

        let compositeImage = NSImage(size: NSSize(width: maxWidth, height: totalHeight))
        compositeImage.lockFocus() 

        var currentY: CGFloat = 0
        for image in images.reversed() {
            let drawPoint = NSPoint(x: (maxWidth - image.size.width) / 2, y: currentY)
            image.draw(at: drawPoint, from: .zero, operation: .sourceOver, fraction: 1.0)
            currentY += image.size.height
        }

        compositeImage.unlockFocus()
        return compositeImage
    }

    private func combineImagesHorizontally(_ images: [NSImage]) -> NSImage? {
        guard !images.isEmpty else { return nil }

        let totalWidth = images.reduce(0) { $0 + $1.size.width }
        let maxHeight = images.reduce(0) { max($0, $1.size.height) }

        let compositeImage = NSImage(size: NSSize(width: totalWidth, height: maxHeight))
        compositeImage.lockFocus()

        var currentX: CGFloat = 0
        for image in images {
            let drawPoint = NSPoint(x: currentX, y: (maxHeight - image.size.height) / 2)
            image.draw(at: drawPoint, from: .zero, operation: .sourceOver, fraction: 1.0)
            currentX += image.size.width
        }

        compositeImage.unlockFocus()
        return compositeImage
    }

    private func saveImage(_ image: NSImage) -> String? {
        guard let jpegData = image.storageJPEGData(),
              let imageDir = getImagesDirectory() else {
            return nil
        }

        let fileName = "\(UUID().uuidString).jpg"
        let fileURL = imageDir.appendingPathComponent(fileName)

        do {
            try jpegData.write(to: fileURL)
            return fileName
        } catch {
            return nil
        }
    }

    /// Heuristic "is this source code?" classifier.
    ///
    /// Design priority is PRECISION over recall: it's much worse to
    /// flag a normal paragraph as code (and shove it into the Code
    /// tab) than to miss the occasional one-liner snippet. The big
    /// failure of the previous version was scoring bare keywords —
    /// `if`, `for`, `return`, `class`, `import`, `try` are all common
    /// English words, so a sentence like "If you want to import this
    /// for example, try again" scored as code. We fix that by only
    /// counting keywords in real *syntactic context* (e.g. `func name(`,
    /// `if (`, `let x =`) and by subtracting points for prose.
    func isLikelyCode(_ text: String) -> Bool {
        // 4K is plenty to classify code vs prose, and keeps the dozen
        // regex passes cheap. This runs synchronously on the main
        // actor for every copy, so a 10K window on a big paste was a
        // noticeable hitch.
        let maxAnalysisLength = 4_000
        let content = (text.count > maxAnalysisLength
                       ? String(text.prefix(maxAnalysisLength))
                       : text).trimmingCharacters(in: .whitespacesAndNewlines)

        guard content.count >= 12 else { return false }

        // URLs / emails aren't code.
        if let url = URL(string: content), let scheme = url.scheme,
           ["http", "https", "mailto"].contains(scheme) {
            return false
        }

        let lines = content.split(separator: "\n", omittingEmptySubsequences: true).map(String.init)
        guard !lines.isEmpty else { return false }

        func regex(_ pattern: String) -> Bool {
            content.range(of: pattern, options: .regularExpression) != nil
        }
        func regexCount(_ pattern: String) -> Int {
            guard content.count <= 5_000,
                  let re = try? NSRegularExpression(pattern: pattern) else { return 0 }
            return re.numberOfMatches(in: content, range: NSRange(content.startIndex..., in: content))
        }

        var score = 0.0

        // ---- High-precision structural signals ----

        // Function definition: `func name(`, `def name(`, `function name(`
        if regex("(?m)\\b(func|def|function|fn|sub)\\s+\\w+\\s*\\(") { score += 3 }

        // Type definition: `class Name`, `struct Name`, `enum Name`, …
        if regex("(?m)\\b(class|struct|enum|interface|trait|impl|protocol)\\s+[A-Za-z_]\\w*") { score += 3 }

        // Control flow WITH parentheses — `if (`, `for (`, `while (`.
        // The paren is what separates `if (x > 0)` from "if you want".
        if regex("(?m)\\b(if|for|while|switch|catch|foreach)\\s*\\(") { score += 2 }

        // Declaration + binding at line start: `let x =`, `const y:`, `var z =`
        if regex("(?m)^\\s*(let|var|const|val|final)\\s+\\w+\\s*[:=]") { score += 2 }

        // Import / include statements at line start.
        if regex("(?m)^\\s*(import|from|#include|require|using|package|export)\\b") { score += 2 }

        // Operators that essentially never appear in prose.
        if regex("(=>|->|::|===|!==|&&|\\|\\||\\+=|-=|\\*=)") { score += 2 }

        // HTML / XML markup — an opening tag plus a closing `</` or
        // self-close `/>` is unambiguous, so it's strong on its own.
        if regex("<[a-zA-Z][^>]*>") && (content.contains("</") || content.contains("/>")) { score += 5 }

        // Shebang — a script file, near-certain code.
        if content.hasPrefix("#!") { score += 3 }

        // Comment lines.
        if lines.contains(where: {
            let t = $0.trimmingCharacters(in: .whitespaces)
            return t.hasPrefix("//") || t.hasPrefix("/*") || t.hasPrefix(" *")
        }) { score += 1.5 }

        // Method / property call on an object: `.reduce(`, `.map(`,
        // `.toString(`. Prose essentially never writes `.word(`.
        if regex("\\.[A-Za-z_]\\w*\\(") { score += 1.5 }

        // SQL statements. Case-sensitive uppercase keyword pairs —
        // "select … from" in lowercase prose ("please select from the
        // menu") shouldn't trip it, but real copied SQL almost always
        // uppercases its keywords.
        if regex("\\bSELECT\\b.{1,200}\\bFROM\\b")
            || regex("\\b(INSERT\\s+INTO|DELETE\\s+FROM|CREATE\\s+TABLE|ALTER\\s+TABLE|UPDATE\\b.{1,100}\\bSET)\\b") {
            score += 3
        }

        // Lines ending in code punctuation (; { }) — strong block signal.
        let codeEnders = lines.filter {
            let t = $0.trimmingCharacters(in: .whitespaces)
            return t.hasSuffix(";") || t.hasSuffix("{") || t.hasSuffix("}")
        }
        let enderRatio = Double(codeEnders.count) / Double(lines.count)
        if enderRatio >= 0.3 { score += 3 }
        else if enderRatio >= 0.15 { score += 1.5 }

        // Balanced braces spanning multiple lines.
        if content.contains("{") && content.contains("}") && lines.count >= 2 { score += 1.5 }

        // Function-call pattern `name(args)` appearing repeatedly.
        let calls = regexCount("[A-Za-z_]\\w*\\([^)]*\\)")
        if calls >= 2 { score += 2 } else if calls == 1 { score += 1 }

        // ---- Prose disqualifier ----
        // If the text reads like sentences (most lines end with . ? !
        // and carry many words), it's natural language — pull the
        // score down hard so a stray keyword can't tip it over.
        let sentenceEnders = lines.filter {
            let t = $0.trimmingCharacters(in: .whitespaces)
            return t.hasSuffix(".") || t.hasSuffix("?") || t.hasSuffix("!")
        }
        let proseRatio = Double(sentenceEnders.count) / Double(lines.count)
        let wordCount = content.split { $0 == " " || $0 == "\n" }.count
        let avgWordsPerLine = Double(wordCount) / Double(lines.count)
        if proseRatio >= 0.5 && avgWordsPerLine > 6 { score -= 4 }

        return score >= 4.5
    }
     func getImagesDirectory() -> URL? {
        guard let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            return nil
        }
        let dir = appSupport.appendingPathComponent("Clippy/Images")
        if !FileManager.default.fileExists(atPath: dir.path) {
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir
    }
    private static let isoDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd'T'HHmmss'Z'"
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        return formatter
    }()

    private func formattedDate(_ date: Date) -> String {
        Self.isoDateFormatter.string(from: date)
    }

    func scheduleSave() {
        saveTask?.cancel()

        saveTask = Task {
            do {
                try await Task.sleep(for: .seconds(0.5))
                saveContext()
            } catch {}
        }
    }

    func saveContext() {
        guard viewContext.hasChanges else { return }

        do {
            try viewContext.save()
            NotificationCenter.default.post(name: .keywordsDidChange, object: nil)
            // Tell the pruner an insert/update happened. It batches
            // (every Nth insert) so this is cheap on the hot path —
            // disk cleanup runs on a background context, not here.
            HistoryPruner.shared.notifyInsert()
        } catch {
            // A failed save used to be discarded entirely — the user's edit
            // was gone with no trace. The merge policy set on viewContext
            // makes conflicts merge rather than throw, so reaching here now
            // means something genuinely unexpected (disk full, corrupt
            // store). Roll the context back so it isn't left holding
            // unsaved changes that will fail again on every later save.
            assertionFailure("CoreData save failed: \(error)")
            viewContext.rollback()
        }
    }
    // applyLimits() / applyLimit(for:isFavorite:limit:) — REMOVED.
    //
    // The previous implementation's NSPredicate only filtered by
    // `isFavorite` and `contentType` — it did NOT exclude `isPinned`.
    // Result: once the per-type limit was hit (text default = 100),
    // any non-favorite item was eligible for deletion INCLUDING
    // pinned ones. That's the source of the "pins keep disappearing
    // on their own" bug some users reported.
    //
    // Replaced by `HistoryPruner` whose predicate explicitly excludes
    // every protected category: pinned, favorite, snippet (has keyword),
    // and encrypted.
}

extension Collection {
    subscript (safe index: Index) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
}

extension NSImage {
    /// Rough decoded size in bytes, for NSCache cost accounting.
    ///
    /// Uses the representation's *pixel* dimensions, not `size` — `size` is
    /// in points, so on a Retina display it under-reports by 4x and would
    /// let the cache grow to four times its intended ceiling.
    var approximateByteCost: Int {
        if let rep = representations.first, rep.pixelsWide > 0, rep.pixelsHigh > 0 {
            return rep.pixelsWide * rep.pixelsHigh * 4
        }
        return max(1, Int(size.width * size.height * 4))
    }
}
