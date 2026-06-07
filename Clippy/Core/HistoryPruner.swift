//
//  HistoryPruner.swift
//  Clippy
//
//  Removes old history items from CoreData (and their on-disk image
//  files) once the user-configured limit is exceeded. Protected
//  categories — pinned, starred, snippets, encrypted — are NEVER
//  pruned regardless of age: those are items the user explicitly
//  marked as "keep". Plain history beyond the cap is hard-deleted
//  along with any image files it references, so the
//  `Application Support/Clippy/Images/` folder doesn't grow forever.
//

import CoreData
import Foundation

/// Removes old history items from CoreData (and their on-disk image
/// files) once per-type user-configured limits are exceeded.
///
/// Concurrency note: this class is intentionally NOT `@MainActor`.
/// The actual prune work happens inside `NSManagedObjectContext.perform`,
/// which dispatches to that context's private queue (not the main
/// thread). If the wrapper method were `@MainActor`, the main
/// thread would `await` on that background work — a priority
/// inversion macOS flags as a hang risk ("User-interactive thread
/// waiting on a lower QoS thread"). Settings reads happen on the
/// MainActor up-front; the rest is queue-isolated and safe to call
/// from any context.
final class HistoryPruner: @unchecked Sendable {
    static let shared = HistoryPruner()

    private let persistence: PersistenceController
    private let fileManager = FileManager.default

    /// Tracks how many inserts have happened since the last prune.
    /// Pruning every N inserts (rather than every save) keeps the
    /// CoreData round-trip cheap on the hot path. Mutated only on
    /// the main actor via `notifyInsert`.
    private var insertsSinceLastPrune = 0
    private let pruneEveryNInserts = 25

    private init(persistence: PersistenceController = .shared) {
        self.persistence = persistence
    }

    /// Called by `ClipboardMonitor` after every successful insert.
    /// Triggers a prune in two cases:
    ///   1) Every 25 inserts — amortized cleanup during normal use.
    ///   2) Caller passes `force: true` — e.g. app launch, manual
    ///      "Clean now" button, settings change.
    @MainActor
    func notifyInsert(force: Bool = false) {
        insertsSinceLastPrune += 1
        let shouldPrune = force || insertsSinceLastPrune >= pruneEveryNInserts
        guard shouldPrune else { return }
        insertsSinceLastPrune = 0
        // Snapshot the settings here on the main actor, then hand
        // them to a detached utility task. The task does its work
        // on a background CoreData queue — no main-thread hop, no
        // priority inversion.
        let limits = readLimitsOnMain()
        Task.detached(priority: .utility) { [weak self] in
            _ = await self?.pruneIfNeeded(limits: limits)
        }
    }

    /// Always runs a prune, ignoring the insert counter. Use from
    /// the settings UI when the user taps "Clean now" or changes
    /// the maxHistoryItems value.
    func pruneNow() async -> PruneResult {
        let limits = await MainActor.run { self.readLimitsOnMain(force: true) }
        return await pruneIfNeeded(limits: limits)
    }

    /// Public read for the settings UI to show a "Current: X items,
    /// Y MB images" summary without running an actual prune.
    func currentStats() async -> HistoryStats {
        let context = persistence.newBackgroundContext()
        return await context.perform {
            let total = (try? context.count(for: ClipboardItemEntity.fetchRequest())) ?? 0

            let historyRequest = ClipboardItemEntity.fetchRequest()
            historyRequest.predicate = self.historyPredicate
            let historyCount = (try? context.count(for: historyRequest)) ?? 0

            let imagesDir = self.imagesDirectory()
            let imagesBytes = self.directorySize(at: imagesDir)
            return HistoryStats(
                totalItems: total,
                historyItems: historyCount,
                imageBytesOnDisk: imagesBytes
            )
        }
    }

    // MARK: - Settings snapshot

    /// Snapshot of the per-type limits + the auto-prune toggle, read
    /// on the main actor (where SettingsManager lives) so the rest
    /// of the pruner can run off-main without touching it.
    private struct Limits {
        let textLimit: Int
        let imageLimit: Int
        let isEnabled: Bool
        let forced: Bool
    }

    @MainActor
    private func readLimitsOnMain(force: Bool = false) -> Limits {
        let s = SettingsManager.shared
        return Limits(
            textLimit: s.historyTextLimit,
            imageLimit: s.historyImageLimit,
            isEnabled: s.enableHistoryAutoPrune,
            forced: force
        )
    }

    // MARK: - Implementation

    /// Items that count toward the history cap. Everything else is
    /// protected:
    ///   - keyword == non-empty → it's a snippet
    ///   - isPinned             → user pinned it
    ///   - isFavorite           → user starred it
    ///   - isEncrypted          → user explicitly secured it
    private var historyPredicate: NSPredicate {
        NSPredicate(format:
            "(keyword == nil OR keyword == '') AND isPinned == NO AND isFavorite == NO AND isEncrypted == NO"
        )
    }

    @discardableResult
    private func pruneIfNeeded(limits: Limits) async -> PruneResult {
        guard limits.isEnabled || limits.forced else {
            return .skippedDisabled
        }

        let textLimit = limits.textLimit
        let imageLimit = limits.imageLimit
        let context = persistence.newBackgroundContext()

        return await context.perform { [self] in
            // Two independent passes: text and image have their own
            // caps because images are dramatically larger on disk.
            // Each pass: fetch newest-first, delete anything past
            // the cap, capture image paths for disk cleanup.
            var totalDeleted = 0
            var imagePathsToDelete: [String] = []

            // --- Text history ---------------------------------------
            do {
                let textRequest = NSFetchRequest<ClipboardItemEntity>(entityName: "ClipboardItemEntity")
                textRequest.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
                    self.historyPredicate,
                    NSPredicate(format: "contentType == 'text'")
                ])
                textRequest.sortDescriptors = [
                    NSSortDescriptor(keyPath: \ClipboardItemEntity.date, ascending: false)
                ]
                let texts = try context.fetch(textRequest)
                if texts.count > textLimit {
                    let toDelete = Array(texts.suffix(texts.count - textLimit))
                    for item in toDelete { context.delete(item) }
                    totalDeleted += toDelete.count
                }
            } catch {
                return .failed(error)
            }

            // --- Image history --------------------------------------
            do {
                let imageRequest = NSFetchRequest<ClipboardItemEntity>(entityName: "ClipboardItemEntity")
                imageRequest.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
                    self.historyPredicate,
                    NSPredicate(format: "contentType == 'image'")
                ])
                imageRequest.sortDescriptors = [
                    NSSortDescriptor(keyPath: \ClipboardItemEntity.date, ascending: false)
                ]
                let images = try context.fetch(imageRequest)
                if images.count > imageLimit {
                    let toDelete = Array(images.suffix(images.count - imageLimit))
                    for item in toDelete {
                        if let path = item.content, !path.isEmpty {
                            imagePathsToDelete.append(path)
                        }
                        context.delete(item)
                    }
                    totalDeleted += toDelete.count
                }
            } catch {
                return .failed(error)
            }

            guard totalDeleted > 0 else {
                let currentCount = (try? context.count(for: {
                    let r = NSFetchRequest<ClipboardItemEntity>(entityName: "ClipboardItemEntity")
                    r.predicate = self.historyPredicate
                    return r
                }())) ?? 0
                return .noWorkNeeded(currentCount: currentCount)
            }

            do {
                try context.save()
            } catch {
                return .failed(error)
            }

            let bytesFreed = self.deleteImageFiles(paths: imagePathsToDelete)
            let remaining = (try? context.count(for: {
                let r = NSFetchRequest<ClipboardItemEntity>(entityName: "ClipboardItemEntity")
                r.predicate = self.historyPredicate
                return r
            }())) ?? 0

            return .pruned(
                deletedCount: totalDeleted,
                bytesFreed: bytesFreed,
                remaining: remaining
            )
        }
    }

    /// Delete image files from `Application Support/Clippy/Images/`.
    /// Returns the total bytes freed (best-effort — files that fail
    /// to delete are silently skipped; not worth surfacing per-file).
    @discardableResult
    private func deleteImageFiles(paths: [String]) -> Int64 {
        let imagesDir = imagesDirectory()
        guard fileManager.fileExists(atPath: imagesDir.path) else { return 0 }

        var freed: Int64 = 0
        for path in paths {
            let fileURL = imagesDir.appendingPathComponent(path)
            if let attrs = try? fileManager.attributesOfItem(atPath: fileURL.path),
               let size = attrs[.size] as? Int64 {
                freed += size
            }
            try? fileManager.removeItem(at: fileURL)
        }
        return freed
    }

    private func imagesDirectory() -> URL {
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return appSupport.appendingPathComponent("Clippy/Images", isDirectory: true)
    }

    private func directorySize(at url: URL) -> Int64 {
        guard let enumerator = fileManager.enumerator(at: url,
                                                      includingPropertiesForKeys: [.fileSizeKey],
                                                      options: [.skipsHiddenFiles]) else {
            return 0
        }
        var total: Int64 = 0
        for case let fileURL as URL in enumerator {
            if let size = try? fileURL.resourceValues(forKeys: [.fileSizeKey]).fileSize {
                total += Int64(size)
            }
        }
        return total
    }
}

// MARK: - Result types

enum PruneResult {
    case pruned(deletedCount: Int, bytesFreed: Int64, remaining: Int)
    case noWorkNeeded(currentCount: Int)
    case skippedDisabled
    case failed(Error)
}

struct HistoryStats {
    let totalItems: Int        // every CoreData row
    let historyItems: Int      // rows subject to pruning
    let imageBytesOnDisk: Int64

    var imagesFormatted: String {
        ByteCountFormatter.string(fromByteCount: imageBytesOnDisk, countStyle: .file)
    }
}
