//
//  AutoTitleService.swift
//  Clippy
//
//  Generates short, scannable titles for long clipboard items using
//  the configured AI provider — so a wall of 50 cards reads like a
//  list of subjects instead of a list of first-lines.
//
//  Cost-safety design: automatic generation runs ONLY when the
//  provider is local (Apple Intelligence / Ollama). With a cloud
//  provider every copy would be a billable API call the user never
//  explicitly asked for — that's a surprise invoice, so cloud users
//  simply don't get auto-titles (manual AI actions still work).
//
//  Titles land in the separate `autoTitle` field. The user's own
//  `title` (editable in the detail window) always wins and is never
//  overwritten.
//

import Foundation
import CoreData

@MainActor
final class AutoTitleService {
    static let shared = AutoTitleService()

    /// Minimum content length before a title adds value. Short items
    /// ARE their own title.
    static let minTextLength = 200
    static let minOCRLength = 100

    /// Serial FIFO — a burst of copies must not fire N parallel
    /// requests at a 3B on-device model.
    private var queue: [UUID] = []
    private var enqueued: Set<UUID> = []
    private var isProcessing = false

    private init() {}

    /// True when auto-titling is allowed to run right now.
    /// Local providers only — see cost-safety note in the header.
    static var isEligible: Bool {
        let s = SettingsManager.shared
        guard s.enableAI, s.enableAutoTitle else { return false }
        guard s.aiProvider == "apple" || s.aiProvider == "ollama" else { return false }
        return AIService.shared.isConfigured
    }

    func requestTitle(for itemID: UUID) {
        guard Self.isEligible else { return }
        guard enqueued.insert(itemID).inserted else { return }
        queue.append(itemID)
        processNextIfIdle()
    }

    private func processNextIfIdle() {
        guard !isProcessing, !queue.isEmpty else { return }
        isProcessing = true
        let itemID = queue.removeFirst()

        Task {
            await self.generateAndStoreTitle(for: itemID)
            self.enqueued.remove(itemID)
            self.isProcessing = false
            self.processNextIfIdle()
        }
    }

    private func generateAndStoreTitle(for itemID: UUID) async {
        // The item is inserted on the view context with a debounced
        // save — same race auto-OCR has. Retry briefly until the row
        // is on disk.
        guard let source = await fetchSourceText(itemID: itemID) else { return }

        let capped = String(source.prefix(1_500))
        guard let raw = try? await AIService.shared.process(text: capped, action: .autoTitle) else {
            return
        }
        let title = Self.sanitize(raw)
        guard !title.isEmpty else { return }

        let bgContext = PersistenceController.shared.newBackgroundContext()
        await bgContext.perform {
            let fetch = NSFetchRequest<ClipboardItemEntity>(entityName: "ClipboardItemEntity")
            fetch.predicate = NSPredicate(format: "id == %@", itemID as CVarArg)
            fetch.fetchLimit = 1
            guard let entity = (try? bgContext.fetch(fetch))?.first else { return }
            // Re-check protections at write time: the user may have
            // set a title, encrypted, or snippet-ified the item while
            // the model was thinking.
            guard (entity.title ?? "").isEmpty,
                  (entity.autoTitle ?? "").isEmpty,
                  !entity.isEncrypted,
                  (entity.keyword ?? "").isEmpty else { return }
            entity.autoTitle = title
            try? bgContext.save()
        }
    }

    /// Fetches the AI-input text for the item (content for text items,
    /// OCR text for images), retrying while the debounced main-context
    /// save catches up. Returns nil when the item is ineligible.
    private func fetchSourceText(itemID: UUID) async -> String? {
        let backoffsMs: [UInt64] = [0, 150, 400, 800]
        for delayMs in backoffsMs {
            if delayMs > 0 {
                try? await Task.sleep(nanoseconds: delayMs * 1_000_000)
            }
            let bgContext = PersistenceController.shared.newBackgroundContext()
            let result: String?? = await bgContext.perform {
                let fetch = NSFetchRequest<ClipboardItemEntity>(entityName: "ClipboardItemEntity")
                fetch.predicate = NSPredicate(format: "id == %@", itemID as CVarArg)
                fetch.fetchLimit = 1
                guard let entity = (try? bgContext.fetch(fetch))?.first else {
                    return .none          // not on disk yet → retry
                }
                guard (entity.title ?? "").isEmpty,
                      (entity.autoTitle ?? "").isEmpty,
                      !entity.isEncrypted,
                      (entity.keyword ?? "").isEmpty else {
                    return .some(nil)     // found but ineligible → stop
                }
                if entity.contentType == "text",
                   let text = entity.content, text.count >= Self.minTextLength {
                    return .some(text)
                }
                if entity.contentType == "image",
                   let ocr = entity.extractedText, ocr.count >= Self.minOCRLength {
                    return .some(ocr)
                }
                return .some(nil)         // too short → stop
            }
            switch result {
            case .none: continue          // retry — row not visible yet
            case .some(let text): return text
            }
        }
        return nil
    }

    /// Model output → display-safe single-line title.
    static func sanitize(_ raw: String) -> String {
        var line = raw
            .components(separatedBy: .newlines)
            .first(where: { !$0.trimmingCharacters(in: .whitespaces).isEmpty }) ?? ""
        line = line.trimmingCharacters(in: .whitespacesAndNewlines)
        line = line.trimmingCharacters(in: CharacterSet(charactersIn: "\"'“”‘’«»"))
        while let last = line.last, ".!:;,".contains(last) {
            line.removeLast()
        }
        if line.count > 60 {
            line = String(line.prefix(60)).trimmingCharacters(in: .whitespaces)
        }
        return line
    }
}
