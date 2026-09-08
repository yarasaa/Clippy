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

    /// Items that count toward the history cap. The definition lives on
    /// the entity so bulk deletion elsewhere protects exactly the same
    /// set — see `ClipboardItemEntity.prunablePredicate`.
    private var historyPredicate: NSPredicate { ClipboardItemEntity.prunablePredicate }

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

    /// Where the disk space actually went, per category.
    ///
    /// The split that matters is prunable vs protected. Automatic pruning
    /// deliberately never touches pinned, starred, snippet or locked
    /// items — and "Clear Everything" deliberately won't either. So the
    /// protected bucket is the only part of Clippy that grows without any
    /// ceiling at all, and the only honest thing to do about that is show
    /// it to the person who created it.
    func storageBreakdown() async -> StorageBreakdown {
        let orphans = await orphanedImageStats()
        let context = persistence.newBackgroundContext()
        let imagesDir = imagesDirectory()

        return await context.perform { [self] in
            func bucket(_ predicate: NSPredicate, images: Bool) -> StorageBreakdown.Bucket {
                let request = NSFetchRequest<NSDictionary>(entityName: "ClipboardItemEntity")
                request.predicate = predicate
                request.resultType = .dictionaryResultType
                request.propertiesToFetch = ["content"]
                guard let rows = try? context.fetch(request) else {
                    return StorageBreakdown.Bucket(count: 0, bytes: 0)
                }
                var bytes: Int64 = 0
                for row in rows {
                    guard let content = row["content"] as? String else { continue }
                    if images {
                        // The row holds a filename; the weight is the file.
                        let url = imagesDir.appendingPathComponent(content)
                        bytes += (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize)
                            .map(Int64.init) ?? 0
                    } else {
                        bytes += Int64(content.utf8.count)
                    }
                }
                return StorageBreakdown.Bucket(count: rows.count, bytes: bytes)
            }

            let text = NSPredicate(format: "contentType != 'image'")
            let image = NSPredicate(format: "contentType == 'image'")
            let unprotected = self.historyPredicate
            let protected = NSCompoundPredicate(notPredicateWithSubpredicate: self.historyPredicate)

            func and(_ a: NSPredicate, _ b: NSPredicate) -> NSPredicate {
                NSCompoundPredicate(andPredicateWithSubpredicates: [a, b])
            }

            return StorageBreakdown(
                prunableText:    bucket(and(text, unprotected),  images: false),
                prunableImages:  bucket(and(image, unprotected), images: true),
                protectedText:   bucket(and(text, protected),    images: false),
                protectedImages: bucket(and(image, protected),   images: true),
                orphanFiles:     StorageBreakdown.Bucket(count: orphans.count, bytes: orphans.bytes),
                databaseBytes:   self.databaseBytes()
            )
        }
    }

    /// The store plus its write-ahead log and shared-memory file. The WAL
    /// is routinely larger than the database itself and is just as real on
    /// disk, so reporting only `.sqlite` would understate things.
    private func databaseBytes() -> Int64 {
        guard let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else { return 0 }
        let base = appSupport.appendingPathComponent("Clippy")
        return ["Clippy.sqlite", "Clippy.sqlite-wal", "Clippy.sqlite-shm"].reduce(0) { total, name in
            let url = base.appendingPathComponent(name)
            let size = (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize).map(Int64.init) ?? 0
            return total + size
        }
    }

    // MARK: - Images kept out of sight

    /// Every image item, whether or not a tab is showing it.
    ///
    /// Turning off the Images tab stops new screenshots being saved, but
    /// it does nothing about the ones already stored: no tab lists them,
    /// so they can't be selected or deleted, and automatic pruning never
    /// reaches them either — with nothing new arriving the count never
    /// crosses the limit, so the cap that would have evicted them is
    /// never hit. They just sit there. This is what lets Settings say so.
    func imageItemStats() async -> (count: Int, protectedCount: Int, bytes: Int64) {
        let context = persistence.newBackgroundContext()
        let imagesDir = imagesDirectory()

        return await context.perform {
            let request = NSFetchRequest<ClipboardItemEntity>(entityName: "ClipboardItemEntity")
            request.predicate = NSPredicate(format: "contentType == 'image'")
            guard let items = try? context.fetch(request) else { return (0, 0, 0) }

            var bytes: Int64 = 0
            var protectedCount = 0
            for item in items {
                if ClipboardItemEntity.protectedPredicate.evaluate(with: item) { protectedCount += 1 }
                guard let path = item.content else { continue }
                let url = imagesDir.appendingPathComponent(path)
                bytes += (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize).map(Int64.init) ?? 0
            }
            return (items.count, protectedCount, bytes)
        }
    }

    /// Delete every image item and its file.
    ///
    /// Unlike pruning and Clear Everything, this does remove pinned,
    /// starred and locked images. That looks like a contradiction and
    /// isn't: those two are bulk sweeps where protection means "don't
    /// take this without me saying so", and this is the user saying so —
    /// a targeted, confirmed action on exactly the images they just asked
    /// about. The confirmation names how many are protected.
    func deleteAllImages() async -> (count: Int, bytesFreed: Int64) {
        let context = persistence.newBackgroundContext()

        return await context.perform { [self] in
            let request = NSFetchRequest<ClipboardItemEntity>(entityName: "ClipboardItemEntity")
            request.predicate = NSPredicate(format: "contentType == 'image'")
            guard let items = try? context.fetch(request), !items.isEmpty else { return (0, 0) }

            var paths: [String] = []
            for item in items {
                if let path = item.content, !path.isEmpty { paths.append(path) }
                context.delete(item)
            }
            do {
                try context.save()
            } catch {
                NSLog("[Clippy] Could not delete stored images: \(error.localizedDescription)")
                return (0, 0)
            }
            let freed = self.deleteImageFiles(paths: paths)
            return (items.count, freed)
        }
    }

    // MARK: - Orphans

    /// Delete image files in `Images/` that no row refers to any more.
    ///
    /// Nothing did this before. `deleteImageFiles(paths:)` only removes
    /// the files belonging to rows it just deleted, so a crash between
    /// writing the file and saving the row, a failed delete, or a store
    /// reset left the file behind forever — invisible in the app and
    /// counted by nothing. A comment in AppDelegate claimed launch
    /// pruning cleared these. It did not.
    ///
    /// Deliberately not called automatically. Reading the whole directory
    /// and every image row is real work, and a file that looks orphaned
    /// during some future half-finished write should not be deleted out
    /// from under it. This runs when the user asks, from Settings.
    func reapOrphanedImages() async -> (count: Int, bytesFreed: Int64) {
        let referenced = await referencedImagePaths()
        let imagesDir = imagesDirectory()
        guard let files = try? fileManager.contentsOfDirectory(
            at: imagesDir,
            includingPropertiesForKeys: [.fileSizeKey]
        ) else { return (0, 0) }

        var count = 0
        var freed: Int64 = 0
        for file in files where !referenced.contains(file.lastPathComponent) {
            let size = (try? file.resourceValues(forKeys: [.fileSizeKey]).fileSize).map(Int64.init) ?? 0
            do {
                try fileManager.removeItem(at: file)
                count += 1
                freed += size
            } catch {
                NSLog("[Clippy] Could not delete orphaned image \(file.lastPathComponent): \(error.localizedDescription)")
            }
        }
        return (count, freed)
    }

    /// How much is sitting in `Images/` that nothing refers to, without
    /// deleting any of it — so Settings can say whether the button is
    /// worth pressing.
    func orphanedImageStats() async -> (count: Int, bytes: Int64) {
        let referenced = await referencedImagePaths()
        guard let files = try? fileManager.contentsOfDirectory(
            at: imagesDirectory(),
            includingPropertiesForKeys: [.fileSizeKey]
        ) else { return (0, 0) }

        var count = 0
        var bytes: Int64 = 0
        for file in files where !referenced.contains(file.lastPathComponent) {
            count += 1
            bytes += (try? file.resourceValues(forKeys: [.fileSizeKey]).fileSize).map(Int64.init) ?? 0
        }
        return (count, bytes)
    }

    /// Every image path any row still points at.
    private func referencedImagePaths() async -> Set<String> {
        let context = persistence.newBackgroundContext()
        return await context.perform {
            let request = NSFetchRequest<NSDictionary>(entityName: "ClipboardItemEntity")
            request.predicate = NSPredicate(format: "contentType == 'image'")
            request.resultType = .dictionaryResultType
            request.propertiesToFetch = ["content"]
            guard let rows = try? context.fetch(request) else { return [] }
            return Set(rows.compactMap { $0["content"] as? String })
        }
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

/// A per-category view of what Clippy is keeping on disk.
struct StorageBreakdown {
    struct Bucket {
        let count: Int
        let bytes: Int64
        var isEmpty: Bool { count == 0 }
        var formatted: String { ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file) }
    }

    /// Subject to automatic pruning — bounded by the history limits.
    let prunableText: Bucket
    let prunableImages: Bucket

    /// Pinned, starred, snippets and locked items. Nothing trims these,
    /// by design. This is the bucket that can grow forever.
    let protectedText: Bucket
    let protectedImages: Bucket

    /// Image files on disk that no row refers to. Pure waste.
    let orphanFiles: Bucket

    let databaseBytes: Int64

    var protectedBytes: Int64 { protectedText.bytes + protectedImages.bytes }
    var protectedCount: Int { protectedText.count + protectedImages.count }

    var databaseFormatted: String {
        ByteCountFormatter.string(fromByteCount: databaseBytes, countStyle: .file)
    }

    /// What removing Clippy would actually free: the store plus every
    /// image file, orphans included.
    var totalFormatted: String {
        let images = prunableImages.bytes + protectedImages.bytes + orphanFiles.bytes
        return ByteCountFormatter.string(fromByteCount: databaseBytes + images, countStyle: .file)
    }
}
