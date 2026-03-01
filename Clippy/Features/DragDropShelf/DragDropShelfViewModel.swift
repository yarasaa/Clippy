//
//  DragDropShelfViewModel.swift
//  Clippy
//

import SwiftUI
import Combine
import UniformTypeIdentifiers

struct ShelfItem: Identifiable, Equatable {
    let id = UUID()
    let content: String
    let image: NSImage?
    let contentType: ShelfContentType
    let dateAdded: Date = Date()

    static func == (lhs: ShelfItem, rhs: ShelfItem) -> Bool {
        lhs.id == rhs.id
    }

    var displayText: String {
        switch contentType {
        case .text:
            let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
            let firstLine = trimmed.components(separatedBy: .newlines).first ?? trimmed
            let preview = firstLine.prefix(60)
            return preview.count < firstLine.count ? "\(preview)…" : String(preview)
        case .image:
            if let img = image {
                return "\(Int(img.size.width)) × \(Int(img.size.height))"
            }
            return "Image"
        case .file:
            return (content as NSString).lastPathComponent
        }
    }

    var thumbnail: NSImage? {
        switch contentType {
        case .image: return image
        case .text: return nil
        case .file: return NSWorkspace.shared.icon(forFile: content)
        }
    }
}

enum ShelfContentType {
    case text, image, file
}

// MARK: - File Promise Delegate

/// Handles both on-disk files (copies them) and in-memory images (writes PNG).
/// This is the ONLY approach that lets Finder accept multi-item drops consistently.
class ShelfFilePromiseDelegate: NSObject, NSFilePromiseProviderDelegate {
    private let writeQueue: OperationQueue = {
        let q = OperationQueue()
        q.qualityOfService = .userInitiated
        return q
    }()

    func filePromiseProvider(_ provider: NSFilePromiseProvider, fileNameForType fileType: String) -> String {
        if let sourceURL = provider.userInfo as? URL {
            return sourceURL.lastPathComponent
        }
        let ext = UTType(fileType)?.preferredFilenameExtension ?? "png"
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HHmmss"
        return "Image_\(formatter.string(from: Date())).\(ext)"
    }

    func filePromiseProvider(_ provider: NSFilePromiseProvider,
                             writePromiseTo url: URL,
                             completionHandler: @escaping (Error?) -> Void) {
        if let sourceURL = provider.userInfo as? URL {
            do {
                try FileManager.default.copyItem(at: sourceURL, to: url)
                completionHandler(nil)
            } catch {
                completionHandler(error)
            }
        } else if let image = provider.userInfo as? NSImage {
            guard let tiffData = image.tiffRepresentation,
                  let bitmap = NSBitmapImageRep(data: tiffData),
                  let pngData = bitmap.representation(using: .png, properties: [:]) else {
                completionHandler(NSError(domain: "ShelfDrag", code: 1))
                return
            }
            do {
                try pngData.write(to: url)
                completionHandler(nil)
            } catch {
                completionHandler(error)
            }
        } else {
            completionHandler(NSError(domain: "ShelfDrag", code: 2))
        }
    }

    func operationQueue(for provider: NSFilePromiseProvider) -> OperationQueue {
        writeQueue
    }
}

// MARK: - ViewModel

class DragDropShelfViewModel: ObservableObject {
    @Published var items: [ShelfItem] = []
    @Published var selectedIDs: Set<UUID> = []
    @Published var focusedID: UUID?
    @Published var internalDragIDs: Set<UUID>?
    @Published var dropTargetID: UUID?

    let filePromiseDelegate = ShelfFilePromiseDelegate()

    /// Called by PanelController for double-click paste
    var onPasteToApp: ((ShelfItem) -> Void)?

    /// Temp directory for clipboard image copies
    private lazy var clipboardTempDir: URL = {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("ClippyShelfClipboard", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }()

    // MARK: - Undo

    private struct UndoState {
        let items: [ShelfItem]
        let selectedIDs: Set<UUID>
        let focusedID: UUID?
    }

    private var undoStack: [UndoState] = []
    private let maxUndoLevels = 20

    var canUndo: Bool { !undoStack.isEmpty }

    private func saveStateForUndo() {
        undoStack.append(UndoState(items: items, selectedIDs: selectedIDs, focusedID: focusedID))
        if undoStack.count > maxUndoLevels { undoStack.removeFirst() }
    }

    func undo() {
        guard let state = undoStack.popLast() else { return }
        items = state.items
        selectedIDs = state.selectedIDs
        focusedID = state.focusedID
    }

    // MARK: - Computed

    var allSelected: Bool {
        !items.isEmpty && selectedIDs.count == items.count
    }

    // MARK: - Add Items

    func addFromPasteboard() {
        let pb = NSPasteboard.general
        if let image = NSImage(pasteboard: pb) {
            items.insert(ShelfItem(content: "", image: image, contentType: .image), at: 0)
        } else if let string = pb.string(forType: .string), !string.isEmpty {
            items.insert(ShelfItem(content: string, image: nil, contentType: .text), at: 0)
        } else if let urls = pb.readObjects(forClasses: [NSURL.self], options: nil) as? [URL], let url = urls.first {
            items.insert(ShelfItem(content: url.path, image: nil, contentType: .file), at: 0)
        }
    }

    func addText(_ text: String) {
        guard !text.isEmpty else { return }
        items.insert(ShelfItem(content: text, image: nil, contentType: .text), at: 0)
    }

    func addImage(_ image: NSImage) {
        items.insert(ShelfItem(content: "", image: image, contentType: .image), at: 0)
    }

    func addFile(_ path: String) {
        items.insert(ShelfItem(content: path, image: nil, contentType: .file), at: 0)
    }

    // MARK: - Remove Items (with undo)

    func removeItem(_ id: UUID) {
        saveStateForUndo()
        items.removeAll { $0.id == id }
        selectedIDs.remove(id)
        if focusedID == id { focusedID = nil }
    }

    func clearAll() {
        saveStateForUndo()
        items.removeAll()
        selectedIDs.removeAll()
        focusedID = nil
    }

    func removeSelected() {
        saveStateForUndo()
        items.removeAll { selectedIDs.contains($0.id) }
        selectedIDs.removeAll()
    }

    // MARK: - Selection

    func toggleSelection(_ id: UUID) {
        if selectedIDs.contains(id) {
            selectedIDs.remove(id)
        } else {
            selectedIDs.insert(id)
        }
    }

    func selectOnly(_ id: UUID) {
        if selectedIDs == [id] {
            selectedIDs.removeAll()
        } else {
            selectedIDs = [id]
        }
    }

    func selectAll() {
        selectedIDs = Set(items.map(\.id))
    }

    func deselectAll() {
        selectedIDs.removeAll()
    }

    // MARK: - Keyboard Navigation

    func moveFocusUp() {
        guard !items.isEmpty else { return }
        guard let current = focusedID,
              let idx = items.firstIndex(where: { $0.id == current }) else {
            focusedID = items.first?.id
            return
        }
        if idx > 0 { focusedID = items[idx - 1].id }
    }

    func moveFocusDown() {
        guard !items.isEmpty else { return }
        guard let current = focusedID,
              let idx = items.firstIndex(where: { $0.id == current }) else {
            focusedID = items.first?.id
            return
        }
        if idx < items.count - 1 { focusedID = items[idx + 1].id }
    }

    func toggleFocusedSelection() {
        guard let id = focusedID else { return }
        toggleSelection(id)
    }

    // MARK: - Reorder

    func moveItem(from source: IndexSet, to destination: Int) {
        items.move(fromOffsets: source, toOffset: destination)
    }

    func reorderItems(moving movingIDs: Set<UUID>, before targetID: UUID) {
        let movingItems = items.filter { movingIDs.contains($0.id) }
        guard !movingItems.isEmpty else { return }

        saveStateForUndo()
        items.removeAll { movingIDs.contains($0.id) }

        if let targetIndex = items.firstIndex(where: { $0.id == targetID }) {
            items.insert(contentsOf: movingItems, at: targetIndex)
        } else {
            items.append(contentsOf: movingItems)
        }
    }

    // MARK: - External Drop Handler

    func handleExternalDrop(_ providers: [NSItemProvider]) {
        for provider in providers {
            if provider.canLoadObject(ofClass: NSImage.self) {
                _ = provider.loadObject(ofClass: NSImage.self) { [weak self] image, _ in
                    if let image = image as? NSImage {
                        DispatchQueue.main.async {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                self?.addImage(image)
                            }
                        }
                    }
                }
            } else if provider.canLoadObject(ofClass: URL.self) {
                _ = provider.loadObject(ofClass: URL.self) { [weak self] url, _ in
                    if let url = url {
                        DispatchQueue.main.async {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                self?.addFile(url.path)
                            }
                        }
                    }
                }
            } else if provider.canLoadObject(ofClass: String.self) {
                _ = provider.loadObject(ofClass: String.self) { [weak self] string, _ in
                    if let string = string {
                        DispatchQueue.main.async {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                self?.addText(string)
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: - Clipboard Copy

    func copySelectedToClipboard() {
        let selected = items.filter { selectedIDs.contains($0.id) }
        guard !selected.isEmpty else { return }

        let pb = NSPasteboard.general
        pb.clearContents()
        cleanClipboardTemp()

        var urls: [NSURL] = []
        var textParts: [String] = []

        for item in selected {
            switch item.contentType {
            case .file:
                urls.append(NSURL(fileURLWithPath: item.content))
            case .image:
                if let url = writeImageToTemp(item.image) {
                    urls.append(url as NSURL)
                }
            case .text:
                textParts.append(item.content)
            }
        }

        if !urls.isEmpty {
            pb.writeObjects(urls)
        }

        if !textParts.isEmpty {
            let combined = textParts.joined(separator: "\n")
            if urls.isEmpty {
                pb.setString(combined, forType: .string)
            } else {
                pb.addTypes([.string], owner: nil)
                pb.setString(combined, forType: .string)
            }
        }
    }

    func copyItemToClipboard(_ item: ShelfItem) {
        let pb = NSPasteboard.general
        pb.clearContents()
        switch item.contentType {
        case .text:
            pb.setString(item.content, forType: .string)
        case .image:
            if let img = item.image { pb.writeObjects([img]) }
        case .file:
            pb.writeObjects([NSURL(fileURLWithPath: item.content)])
        }
    }

    // MARK: - File Actions

    func revealInFinder(_ item: ShelfItem) {
        switch item.contentType {
        case .file:
            NSWorkspace.shared.selectFile(item.content, inFileViewerRootedAtPath: "")
        case .image:
            if let url = writeImageToTemp(item.image) {
                NSWorkspace.shared.selectFile(url.path, inFileViewerRootedAtPath: "")
            }
        case .text: break
        }
    }

    func openFile(_ item: ShelfItem) {
        switch item.contentType {
        case .file:
            NSWorkspace.shared.open(URL(fileURLWithPath: item.content))
        case .image:
            if let url = writeImageToTemp(item.image) {
                NSWorkspace.shared.open(url)
            }
        case .text: break
        }
    }

    // MARK: - Quick Look

    func quickLookURLs() -> [URL] {
        let targets: [ShelfItem]
        if let fid = focusedID, selectedIDs.isEmpty,
           let item = items.first(where: { $0.id == fid }) {
            targets = [item]
        } else if !selectedIDs.isEmpty {
            targets = items.filter { selectedIDs.contains($0.id) }
        } else if let first = items.first {
            targets = [first]
        } else {
            return []
        }

        var urls: [URL] = []
        for item in targets {
            switch item.contentType {
            case .file:
                urls.append(URL(fileURLWithPath: item.content))
            case .image:
                if let url = writeImageToTemp(item.image) {
                    urls.append(url)
                }
            case .text:
                let name = "ShelfText_\(item.id.uuidString.prefix(8)).txt"
                let url = clipboardTempDir.appendingPathComponent(name)
                try? item.content.write(to: url, atomically: true, encoding: .utf8)
                urls.append(url)
            }
        }
        return urls
    }

    // MARK: - Temp Image Helpers

    private func writeImageToTemp(_ image: NSImage?) -> URL? {
        guard let image = image,
              let tiffData = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData),
              let pngData = bitmap.representation(using: .png, properties: [:]) else { return nil }

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HHmmss"
        let name = "Image_\(formatter.string(from: Date()))_\(UUID().uuidString.prefix(4)).png"
        let url = clipboardTempDir.appendingPathComponent(name)

        do {
            try pngData.write(to: url)
            return url
        } catch {
            return nil
        }
    }

    private func cleanClipboardTemp() {
        let fm = FileManager.default
        guard let files = try? fm.contentsOfDirectory(at: clipboardTempDir, includingPropertiesForKeys: nil) else { return }
        for file in files {
            try? fm.removeItem(at: file)
        }
    }

    // MARK: - Multi-Drag (ALL items use NSFilePromiseProvider)

    func makeDragItems(for item: ShelfItem, mousePosition: NSPoint) -> [NSDraggingItem] {
        let itemsToDrag: [ShelfItem]
        if selectedIDs.contains(item.id) && selectedIDs.count > 1 {
            itemsToDrag = items.filter { selectedIDs.contains($0.id) }
        } else {
            itemsToDrag = [item]
        }

        // Mark as internal drag for reorder detection
        internalDragIDs = Set(itemsToDrag.map(\.id))

        var results: [NSDraggingItem] = []
        let iconSize = NSSize(width: 48, height: 48)

        for (index, shelfItem) in itemsToDrag.enumerated() {
            let writer: NSPasteboardWriting

            switch shelfItem.contentType {
            case .file:
                let fileURL = URL(fileURLWithPath: shelfItem.content)
                let uti = UTType(filenameExtension: fileURL.pathExtension) ?? .data
                let promise = NSFilePromiseProvider(fileType: uti.identifier, delegate: filePromiseDelegate)
                promise.userInfo = fileURL
                writer = promise

            case .image:
                guard let image = shelfItem.image else { continue }
                let promise = NSFilePromiseProvider(fileType: UTType.png.identifier, delegate: filePromiseDelegate)
                promise.userInfo = image
                writer = promise

            case .text:
                writer = shelfItem.content as NSString
            }

            let dragItem = NSDraggingItem(pasteboardWriter: writer)
            var icon = Self.dragIcon(for: shelfItem, size: iconSize)

            if index == 0 && itemsToDrag.count > 1 {
                icon = Self.addCountBadge(to: icon, count: itemsToDrag.count)
            }

            let offset = CGFloat(index) * 5.0
            let frame = NSRect(
                x: mousePosition.x - iconSize.width / 2 + offset,
                y: mousePosition.y - iconSize.height / 2 - offset,
                width: iconSize.width,
                height: iconSize.height
            )
            dragItem.setDraggingFrame(frame, contents: icon)
            results.append(dragItem)
        }

        return results
    }

    private static func dragIcon(for item: ShelfItem, size: NSSize) -> NSImage {
        switch item.contentType {
        case .image:
            return item.image ?? NSWorkspace.shared.icon(for: .image)
        case .file:
            let icon = NSWorkspace.shared.icon(forFile: item.content)
            icon.size = size
            return icon
        case .text:
            let icon = NSWorkspace.shared.icon(for: .plainText)
            icon.size = size
            return icon
        }
    }

    private static func addCountBadge(to image: NSImage, count: Int) -> NSImage {
        let size = image.size
        return NSImage(size: size, flipped: false) { rect in
            image.draw(in: rect)

            let badgeText = "\(count)"
            let attrs: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: 11, weight: .bold),
                .foregroundColor: NSColor.white
            ]
            let textSize = badgeText.size(withAttributes: attrs)
            let badgeDiameter = max(textSize.width + 8, 20.0)
            let badgeRect = NSRect(
                x: rect.width - badgeDiameter + 4,
                y: rect.height - badgeDiameter + 4,
                width: badgeDiameter,
                height: badgeDiameter
            )

            NSColor.systemRed.setFill()
            NSBezierPath(ovalIn: badgeRect).fill()

            let textRect = NSRect(
                x: badgeRect.midX - textSize.width / 2,
                y: badgeRect.midY - textSize.height / 2,
                width: textSize.width,
                height: textSize.height
            )
            badgeText.draw(in: textRect, withAttributes: attrs)

            return true
        }
    }
}
