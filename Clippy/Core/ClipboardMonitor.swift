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

extension Notification.Name {
    static let keywordsDidChange = Notification.Name("com.yarasa.Clippy.keywordsDidChange")
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

    private let imageCache = NSCache<NSString, NSImage>()
    private let thumbnailCache = NSCache<NSString, NSImage>()
    private let appIconCache = NSCache<NSString, NSImage>()

    // Cached arrays for code detection (performance optimization)
    private static let codeKeywords = ["func", "class", "struct", "let", "var", "const", "import", "return", "if", "else", "for", "while", "public", "private", "static", "async", "await", "try", "catch", "extension", "protocol"]
    private static let codeSymbols = ["{", "}", ";", "=>", "->", "==", "===", "!=", "()", "[]", "&&", "||"]

    private var changeCount: Int
    private var monitoringTask: Task<Void, Error>?
    private var saveTask: Task<Void, Never>?

    private let viewContext = PersistenceController.shared.container.viewContext

    init() {
        self.changeCount = NSPasteboard.general.changeCount
    }

    func startMonitoring(interval: TimeInterval = 0.5) {
        monitoringTask = Task {
            while !Task.isCancelled {
                await checkClipboard()
                try await Task.sleep(for: .seconds(interval))
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
        print("ℹ️ Pano izleme aralığı \(interval) saniye olarak ayarlandı.")
    }

    private func checkClipboard() async {
        let pb = NSPasteboard.general
        if pb.changeCount != changeCount {
            changeCount = pb.changeCount

            if pb.types?.contains(PasteManager.pasteFromClippyType) == true {
                return
            }

            let frontmostApp = NSWorkspace.shared.frontmostApplication
            let sourceAppName = frontmostApp?.localizedName
            let sourceAppBundleIdentifier = frontmostApp?.bundleIdentifier

            if let str = pb.string(forType: .string), !str.isEmpty, !isDuplicateText(str) {
                let isCode = self.isLikelyCode(str)
                let item = ClipboardItem(contentType: .text(str), date: Date(), isCode: isCode, sourceAppName: sourceAppName, sourceAppBundleIdentifier: sourceAppBundleIdentifier)
                addNewItem(item)

                return
            }

            if let image = pb.readObjects(forClasses: [NSImage.self], options: nil)?.first as? NSImage {
                guard SettingsManager.shared.showImagesTab else {
                    print("ℹ️ Resim kaydetme ayarı kapalı. Kopyalanan resim yoksayıldı.")
                    return
                }
                await self.saveImageInBackground(image, sourceAppName: sourceAppName, sourceAppBundleIdentifier: sourceAppBundleIdentifier)
            }
        }
    }

    private func saveImageInBackground(_ image: NSImage, sourceAppName: String?, sourceAppBundleIdentifier: String?) async {
        guard let imageData = image.tiffRepresentation,
              let imageRep = NSBitmapImageRep(data: imageData),
              let jpegData = imageRep.representation(using: .jpeg, properties: [.compressionFactor: 0.85]) else {
            return
        }

        let fileName = "\(UUID().uuidString).jpg"
        guard let imageDir = self.getImagesDirectory() else { return }
        let fileURL = imageDir.appendingPathComponent(fileName)

        do {
            try await Task(priority: .background) {
                try jpegData.write(to: fileURL)
            }.value

            print("🖼️ Resim diske kaydedildi: \(fileName)")
            let item = ClipboardItem(contentType: .image(imagePath: fileName), date: Date(), sourceAppName: sourceAppName, sourceAppBundleIdentifier: sourceAppBundleIdentifier)
            self.addNewItem(item)
        } catch {
            print("❌ Resim kaydetme hatası: \(error)")
        }
    }

    func addImageToHistory(image: NSImage) {
        guard let newImagePath = saveImage(image) else {
            print("❌ Görüntü diske kaydedilemedi ve geçmişe eklenemedi.")
            return
        }
        let newItem = ClipboardItem(contentType: .image(imagePath: newImagePath), date: Date(), sourceAppName: "Clippy Editor", sourceAppBundleIdentifier: "com.yarasa.Clippy.Editor")
        addNewItem(newItem)
    }

    func saveEditedImage(_ image: NSImage, from originalItem: ClipboardItemEntity) {
        guard let imageData = image.tiffRepresentation,
              let imageRep = NSBitmapImageRep(data: imageData),
              let jpegData = imageRep.representation(using: .jpeg, properties: [.compressionFactor: 0.85]),
              let imageDir = getImagesDirectory() else {
            print("❌ Düzenlenmiş resim verisi oluşturulamadı.")
            return
        }

        let fileName = "\(UUID().uuidString).jpg"
        let fileURL = imageDir.appendingPathComponent(fileName)

        do {
            try jpegData.write(to: fileURL)
            let newItem = ClipboardItem(contentType: .image(imagePath: fileName), date: Date(), sourceAppName: "Clippy Editor", sourceAppBundleIdentifier: "com.yarasa.Clippy.Editor")
            addNewItem(newItem)
            print("✅ Düzenlenmiş resim kaydedildi: \(fileName)")
        } catch {
            print("❌ Düzenlenmiş resmi kaydetme hatası: \(error)")
        }
    }

    func recognizeText(for item: ClipboardItemEntity) async {
        guard item.contentType == "image",
              let imagePath = item.content,
              let image = loadImage(from: imagePath) else {
            print("❌ OCR: Geçerli bir resim öğesi bulunamadı.")
            return
        }

        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            print("❌ OCR: NSImage, CGImage'e dönüştürülemedi.")
            return
        }
        let request = VNRecognizeTextRequest { (request, error) in
            guard let observations = request.results as? [VNRecognizedTextObservation], error == nil else {
                print("❌ OCR: Metin tanıma başarısız oldu - \(error?.localizedDescription ?? "Bilinmeyen hata")")
                return
            }

            let recognizedStrings = observations.compactMap { observation in
                return observation.topCandidates(1).first?.string
            }

            guard !recognizedStrings.isEmpty else {
                print("ℹ️ OCR: Resimde metin bulunamadı.")
                return
            }

            let fullText = recognizedStrings.joined(separator: "\n")

            let ocrItem = ClipboardItem(contentType: .text(fullText), date: Date(), isCode: self.isLikelyCode(fullText), sourceAppName: "Clippy OCR", sourceAppBundleIdentifier: "com.yarasa.Clippy.OCR")
            self.addNewItem(ocrItem)
            print("✅ OCR: Metin tanındı ve geçmişe eklendi.")
        }

        var languages: [String] = []
        let currentLanguageCode = SettingsManager.shared.appLanguage
        if currentLanguageCode == "tr" {
            languages.append("tr-TR")
        }
        languages.append("en-US")

        request.recognitionLevel = .accurate
        request.recognitionLanguages = languages
        print("ℹ️ OCR dilleri ayarlandı: \(languages)")

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
        case .image(let imagePath):
            newItemEntity.contentType = "image"
            newItemEntity.content = imagePath
        }

        applyLimits()
        scheduleSave()
    }

    private func isDuplicateText(_ text: String) -> Bool {
        let fetchRequest: NSFetchRequest<ClipboardItemEntity> = ClipboardItemEntity.fetchRequest()
        fetchRequest.sortDescriptors = [NSSortDescriptor(keyPath: \ClipboardItemEntity.date, ascending: false)]

        fetchRequest.predicate = NSPredicate(format: "isFavorite == NO AND contentType == 'text'")

        fetchRequest.fetchLimit = 1

        do {
            let lastItem = try viewContext.fetch(fetchRequest).first
            return lastItem?.content == text
        } catch {
            print("❌ Yinelenen öğe kontrolü hatası: \(error)")
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
            print("❌ Core Data'da öğe bulunamadı: \(error)")
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
        print("➡️ Sıralı kopyalama için hazır. Bir sonraki kopyalama kuyruğa eklenecek.")
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
        print("🧹 Sıralı yapıştırma kuyruğu temizlendi.")
    }

    func addSelectionToSequentialQueue() {
        guard !selectedItemIDs.isEmpty else { return }

        self.sequentialPasteQueueIDs = self.selectedItemIDs

        self.sequentialPasteIndex = 0
        self.isPastingFromQueue = false

        print("✅ \(selectedItemIDs.count) öğe sıralı yapıştırma kuyruğuna eklendi.")

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
            print("✅ \(images.count) resim (\(orientation)) birleştirildi ve yeni öğe olarak geçmişe eklendi.")
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
            print("🗑️ \(itemsToDelete.count) öğe silindi.")
        } catch {
            print("❌ Çoklu silme için öğeleri getirme hatası: \(error)")
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
            predicates.append(NSPredicate(format: "contentType == 'text'"))
            if SettingsManager.shared.showCodeTab {
                predicates.append(NSPredicate(format: "isCode == NO"))
            }
        case .code:
            predicates.append(NSPredicate(format: "(keyword == nil OR keyword == '')"))
            predicates.append(NSPredicate(format: "isFavorite == NO"))
            predicates.append(NSPredicate(format: "isCode == YES"))
        case .images:
            predicates.append(NSPredicate(format: "(keyword == nil OR keyword == '')"))
            predicates.append(NSPredicate(format: "isFavorite == NO"))
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
            print("❌ Öğeleri silmek için fetch etme hatası: \(error)")
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
            print("❌ Yinelenenleri temizleme hatası: \(error)")
        }
        scheduleSave()
    }

    func loadImage(from path: String) -> NSImage? {
        if let cachedImage = imageCache.object(forKey: path as NSString) {
            return cachedImage
        }

        guard let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            return nil
        }
        let imageURL = appSupport
            .appendingPathComponent("Clippy/Images")
            .appendingPathComponent(path)

        if let image = NSImage(contentsOf: imageURL) {
            imageCache.setObject(image, forKey: path as NSString)
            return image
        }
        return nil
    }

    func loadThumbnail(from path: String) -> NSImage? {
        if let cachedThumbnail = thumbnailCache.object(forKey: path as NSString) {
            return cachedThumbnail
        }

        guard let originalImage = loadImage(from: path) else {
            return nil
        }

        let thumbnailSize = NSSize(width: 80, height: 80)
        let thumbnail = NSImage(size: thumbnailSize)
        thumbnail.lockFocus()
        originalImage.draw(in: NSRect(origin: .zero, size: thumbnailSize),
                           from: NSRect(origin: .zero, size: originalImage.size),
                           operation: .sourceOver,
                           fraction: 1.0)
        thumbnail.unlockFocus()

        thumbnailCache.setObject(thumbnail, forKey: path as NSString)
        return thumbnail
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
                self.appIconCache.setObject(finalIcon, forKey: bundleIdentifier as NSString)
                await MainActor.run { completion(finalIcon) }
            } else {
                let genericIcon = NSImage(systemSymbolName: "questionmark.app.dashed", accessibilityDescription: "Unknown App")!
                self.appIconCache.setObject(genericIcon, forKey: bundleIdentifier as NSString)
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
            print("🗑️ Resim dosyası diskten silindi: \(imagePath)")
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
        guard let imageData = image.tiffRepresentation,
              let imageRep = NSBitmapImageRep(data: imageData),
              let jpegData = imageRep.representation(using: .jpeg, properties: [.compressionFactor: 0.85]),
              let imageDir = getImagesDirectory() else {
            return nil
        }

        let fileName = "\(UUID().uuidString).jpg"
        let fileURL = imageDir.appendingPathComponent(fileName)

        do {
            try jpegData.write(to: fileURL)
            print("🖼️ Sıralı kopyalama için resim diske kaydedildi: \(fileName)")
            return fileName
        } catch {
            print("❌ Sıralı kopyalama için resim kaydetme hatası: \(error)")
            return nil
        }
    }

    func isLikelyCode(_ text: String) -> Bool {
        let content = text.trimmingCharacters(in: .whitespacesAndNewlines)

        if let url = URL(string: content),
           let scheme = url.scheme,
           ["http", "https"].contains(scheme) {
            return false
        }

        if content.count < 10 { return false }

        if !content.contains("\n") && (content.hasSuffix(".") || content.hasSuffix("?") || content.hasSuffix("!")) {
            return false
        }

        var score = 0

        // Use cached static arrays instead of creating new ones
        for keyword in Self.codeKeywords {
            if content.contains("\(keyword) ") || content.starts(with: keyword) {
                score += 2
            }
        }

        for symbol in Self.codeSymbols {
            if content.contains(symbol) {
                score += 1
            }
        }
        if content.filter({ $0 == ":" }).count > 1 { score += 1 }
        if content.contains("//") || content.contains("") || content.contains("# ") {
            score += 3
        }

        if (content.starts(with: "{") && content.hasSuffix("}")) || (content.starts(with: "[") && content.hasSuffix("]")) {
            score += 4
        }
        if content.contains("</") && content.contains("/>") {
            score += 4
        }

        let uuidPattern = "[A-F0-9a-f]{8}-[A-F0-9a-f]{4}-[A-F0-9a-f]{4}-[A-F0-9a-f]{4}-[A-F0-9a-f]{12}"
        if content.range(of: uuidPattern, options: .regularExpression) != nil {
            score += 5
        }
        let camelCaseOrSnakeCase = "[a-z]+[A-Z][a-zA-Z]*|[a-z]+_[a-z]+"
        if content.range(of: camelCaseOrSnakeCase, options: .regularExpression) != nil {
            score += 2
        }

        let lines = content.split(separator: "\n")
        let hasIndentation = lines.contains { $0.starts(with: "    ") || $0.starts(with: "\t") }
        if hasIndentation { score += 2 } 
        if lines.count > 2 { score += 1 }

        return score >= 4
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
    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd'T'HHmmss'Z'"
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        return formatter.string(from: date)
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
            print("✅ Core Data context kaydedildi.")
            NotificationCenter.default.post(name: .keywordsDidChange, object: nil)
        } catch {
            let nsError = error as NSError
            print("❌ Core Data kaydetme hatası: \(nsError), \(nsError.userInfo)")
        }
    }
    private func applyLimits() {
        let settings = SettingsManager.shared

        applyLimit(for: "text", isFavorite: false, limit: settings.historyLimit)

        applyLimit(for: "image", isFavorite: false, limit: settings.imagesLimit, deleteFiles: true)

        applyLimit(for: nil, isFavorite: true, limit: settings.favoritesLimit, deleteFiles: true)
    }

    private func applyLimit(for contentType: String?, isFavorite: Bool, limit: Int, deleteFiles: Bool = false) {
        let fetchRequest: NSFetchRequest<ClipboardItemEntity> = ClipboardItemEntity.fetchRequest()
        var predicates = [NSPredicate(format: "isFavorite == %@", NSNumber(value: isFavorite))]
        if let type = contentType {
            predicates.append(NSPredicate(format: "contentType == %@", type))
        }
        fetchRequest.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: predicates)
        fetchRequest.sortDescriptors = [NSSortDescriptor(keyPath: \ClipboardItemEntity.date, ascending: false)]

        do {
            let results = try viewContext.fetch(fetchRequest)
            if results.count > limit {
                let itemsToDelete = results.dropFirst(limit)
                for item in itemsToDelete {
                    if deleteFiles { deleteImageFile(for: item) }
                    viewContext.delete(item)
                }
            }
        } catch {
            print("❌ Limit uygulama hatası: \(error)")
        }
    }
}

extension Collection {
    subscript (safe index: Index) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
}
