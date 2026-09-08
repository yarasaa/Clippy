//
//  ClipboardMonitor+Security.swift
//  Clippy
//
//  Locking and unlocking items, and the one place anything reads the
//  plaintext of a locked one.
//
//  The old `toggleEncryption` flipped a boolean. The card drew a lock,
//  the title was hidden, the badges were hidden — and Copy, Paste and
//  Share handed over the text anyway, because nothing on those paths
//  ever looked at the flag. Routing every reader through
//  `revealedContent` is what makes the lock mean something: there is no
//  second way to get at the text.
//

import AppKit
import CoreData
import Foundation

extension ClipboardMonitor {

    // MARK: - Locking

    /// Encrypt an item's content in place.
    ///
    /// The flag is set *after* sealing succeeds, never before. Setting it
    /// first and hoping is precisely the old bug: a lock drawn over text
    /// that is still readable.
    func lock(itemID: UUID) -> Result<Void, Error> {
        guard let entity = findEntity(for: itemID) else { return .success(()) }
        if entity.contentType == "image" { return lockImage(entity) }

        let plaintext = entity.content ?? ""
        guard !SecureStore.isSealed(plaintext) else {
            entity.isEncrypted = true
            scheduleSave()
            return .success(())
        }

        do {
            entity.content = try SecureStore.seal(plaintext)
            // Both are derived from the content, so leaving them would
            // describe what the lock is meant to be hiding. They cost
            // nothing to regenerate once the item is unlocked again.
            entity.autoTitle = nil
            entity.extractedText = nil
            entity.isEncrypted = true
            scheduleSave()
            // Lock something and copy it a second later and you should be
            // asked, even if you authenticated a moment ago for something
            // else.
            ClipboardAuthenticator.shared.invalidate()
            return .success(())
        } catch {
            NSLog("[Clippy] Could not lock item: \(error.localizedDescription)")
            return .failure(error)
        }
    }

    /// Authenticate, then decrypt the item back to plain storage.
    func unlock(itemID: UUID) async -> Result<Void, Error> {
        guard let entity = findEntity(for: itemID) else { return .success(()) }

        guard await ClipboardAuthenticator.shared.authenticate(
            reason: "unlock this clipboard item"
        ) else {
            return .failure(ClipboardSecurityError.authenticationFailed)
        }

        if entity.contentType == "image" { return unlockImage(entity) }

        let stored = entity.content ?? ""
        // Items locked by a version that only set the flag are already
        // plaintext. Nothing to decrypt; just drop the flag.
        guard SecureStore.isSealed(stored) else {
            entity.isEncrypted = false
            scheduleSave()
            return .success(())
        }

        do {
            entity.content = try SecureStore.open(stored)
            entity.isEncrypted = false
            scheduleSave()
            return .success(())
        } catch {
            NSLog("[Clippy] Could not unlock item: \(error.localizedDescription)")
            return .failure(error)
        }
    }

    // MARK: - Images

    /// Encrypt the image file itself.
    ///
    /// The row only holds a filename, so sealing `content` would protect
    /// nothing and break image loading — the picture would still be
    /// sitting in `Images/` for anyone to open. What gets encrypted is
    /// the file.
    ///
    /// The sealed file keeps the original name with `.enc` appended, so
    /// unlocking restores the right extension without storing it anywhere.
    private func lockImage(_ entity: ClipboardItemEntity) -> Result<Void, Error> {
        guard let directory = getImagesDirectory(), let path = entity.content, !path.isEmpty else {
            return .failure(ClipboardSecurityError.imageFileMissing)
        }
        guard !SecureStore.isSealedFile(path) else {
            entity.isEncrypted = true
            scheduleSave()
            return .success(())
        }

        let source = directory.appendingPathComponent(path)
        let sealedPath = path + "." + SecureStore.sealedFileExtension
        let destination = directory.appendingPathComponent(sealedPath)

        do {
            let plaintext = try Data(contentsOf: source)
            try SecureStore.seal(data: plaintext).write(to: destination, options: .atomic)
            try FileManager.default.removeItem(at: source)

            entity.content = sealedPath
            // OCR text is the picture in words — the one field that would
            // describe exactly what the lock is covering.
            entity.extractedText = nil
            entity.autoTitle = nil
            entity.isEncrypted = true

            purgeImageCaches(for: path)
            scheduleSave()
            ClipboardAuthenticator.shared.invalidate()
            return .success(())
        } catch {
            // Leave the row untouched: a half-locked image whose file is
            // gone would be worse than one that never locked.
            try? FileManager.default.removeItem(at: destination)
            NSLog("[Clippy] Could not lock image: \(error.localizedDescription)")
            return .failure(error)
        }
    }

    private func unlockImage(_ entity: ClipboardItemEntity) -> Result<Void, Error> {
        guard let directory = getImagesDirectory(), let path = entity.content, !path.isEmpty else {
            return .failure(ClipboardSecurityError.imageFileMissing)
        }
        guard SecureStore.isSealedFile(path) else {
            entity.isEncrypted = false
            scheduleSave()
            return .success(())
        }

        let source = directory.appendingPathComponent(path)
        let restoredPath = (path as NSString).deletingPathExtension
        let destination = directory.appendingPathComponent(restoredPath)

        do {
            let sealed = try Data(contentsOf: source)
            try SecureStore.open(data: sealed).write(to: destination, options: .atomic)
            try FileManager.default.removeItem(at: source)

            entity.content = restoredPath
            entity.isEncrypted = false
            purgeImageCaches(for: path)
            scheduleSave()
            return .success(())
        } catch {
            try? FileManager.default.removeItem(at: destination)
            NSLog("[Clippy] Could not unlock image: \(error.localizedDescription)")
            return .failure(error)
        }
    }

    /// Drop anything the caches are holding for a path whose file just
    /// changed identity. Without this the old bitmap keeps rendering and
    /// the card looks unlocked until something evicts it.
    private func purgeImageCaches(for path: String) {
        imageCache.removeObject(forKey: path as NSString)
        ThumbnailStore.purge()
    }

    // MARK: - Migration

    /// Seal items that earlier versions marked as encrypted but stored in
    /// the clear.
    ///
    /// Runs once at launch and needs no authentication: sealing only ever
    /// reduces what is readable, so there is nothing to authorise, and
    /// prompting for Touch ID during startup for a change the user never
    /// asked for would be worse than the problem.
    func migrateLegacyEncryptedItems() {
        let request: NSFetchRequest<ClipboardItemEntity> = ClipboardItemEntity.fetchRequest()
        request.predicate = NSPredicate(format: "isEncrypted == YES")

        guard let items = try? viewContext.fetch(request), !items.isEmpty else { return }

        var sealed = 0
        for item in items {
            let stored = item.content ?? ""

            if item.contentType == "image" {
                // A legacy locked image is a readable file on disk with a
                // lock icon drawn over it. Same treatment as the rest.
                guard !SecureStore.isSealedFile(stored) else { continue }
                if case .failure = lockImage(item) { return }
                sealed += 1
                continue
            }

            guard !SecureStore.isSealed(stored) else { continue }
            do {
                item.content = try SecureStore.seal(stored)
                item.autoTitle = nil
                item.extractedText = nil
                sealed += 1
            } catch {
                NSLog("[Clippy] Could not migrate locked item: \(error.localizedDescription)")
                return   // Keychain is unavailable; retry next launch.
            }
        }

        guard sealed > 0 else { return }
        scheduleSave()
        NSLog("[Clippy] Encrypted \(sealed) item(s) that were previously marked locked but stored in plain text.")
    }
}


/// The one place anything reads a locked item's plaintext.
///
/// Free-standing rather than a method on ClipboardMonitor because the
/// Quick Preview panel has no monitor and still has to pass through the
/// same gate. A lock with a second route around it isn't a lock.
enum ClipboardSecurity {

    /// The plaintext of an item, asking for authentication first if it is
    /// locked. `nil` means the caller must not proceed — either the user
    /// declined, or the content could not be decrypted.
    @MainActor
    static func revealedContent(for entity: ClipboardItemEntity) async -> String? {
        // An image row's `content` is a filename, not content. Returning
        // it here would hand a caller the path to a locked image's
        // ciphertext and look like a successful unlock. Images go through
        // `revealedImage`.
        guard entity.contentType != "image" else { return nil }

        let stored = entity.content ?? ""
        guard entity.isEncrypted else { return stored }

        guard await ClipboardAuthenticator.shared.authenticate(
            reason: "use this locked clipboard item"
        ) else { return nil }

        guard SecureStore.isSealed(stored) else { return stored }   // legacy, not yet migrated
        do {
            return try SecureStore.open(stored)
        } catch {
            NSLog("[Clippy] Could not read locked item: \(error.localizedDescription)")
            return nil
        }
    }

    /// The picture behind a locked image item.
    ///
    /// Decrypted in memory and handed straight back — it never touches
    /// disk and never enters `imageCache` or the thumbnail cache, so
    /// locking an image and reopening the popover shows the lock again
    /// rather than a bitmap someone left lying in a cache.
    @MainActor
    static func revealedImage(for entity: ClipboardItemEntity) async -> NSImage? {
        guard let path = entity.content, !path.isEmpty else { return nil }

        guard let url = ThumbnailStore.imageURL(for: path) else { return nil }

        guard entity.isEncrypted, SecureStore.isSealedFile(path) else {
            return NSImage(contentsOf: url)
        }

        guard await ClipboardAuthenticator.shared.authenticate(
            reason: "use this locked image"
        ) else { return nil }

        do {
            let sealed = try Data(contentsOf: url)
            return NSImage(data: try SecureStore.open(data: sealed))
        } catch {
            NSLog("[Clippy] Could not read locked image: \(error.localizedDescription)")
            return nil
        }
    }

    /// Put an item on the general pasteboard, unlocking first if needed.
    ///
    /// The one entry point for copying, because a locked image cannot go
    /// through a path-carrying `ClipboardItem`: the only path a locked
    /// image has is the encrypted one. The picture is
    /// decrypted into memory and written to the pasteboard directly.
    ///
    /// Returns false when the user declined or the content was
    /// unreadable — callers must not carry on as if a copy happened.
    @MainActor
    @discardableResult
    static func copyToPasteboard(for entity: ClipboardItemEntity) async -> Bool {
        let pasteboard = NSPasteboard.general

        if entity.contentType == "image" {
            guard let image = await revealedImage(for: entity) else { return false }
            pasteboard.clearContents()
            pasteboard.writeObjects([image])
        } else {
            guard let text = await revealedContent(for: entity) else { return false }
            pasteboard.clearContents()
            pasteboard.setString(text, forType: .string)
        }

        pasteboard.addTypes([PasteManager.pasteFromClippyType], owner: nil)

        // Tell other clipboard managers not to keep this. It is a hint,
        // not a guarantee — but a locked item ending up in someone else's
        // unencrypted history would undo the point of locking it.
        if entity.isEncrypted {
            pasteboard.setData(Data(), forType: NSPasteboard.PasteboardType("org.nspasteboard.ConcealedType"))
        }
        return true
    }

    /// A file URL the share sheet can hand to another app, unlocking
    /// first if needed.
    ///
    /// A locked image is decrypted in memory and re-encoded to a staged
    /// PNG; sharing its file straight off disk would hand over the
    /// ciphertext, which is useless to the recipient and confusing to
    /// everyone. Staged files are purged on the next share and at quit.
    @MainActor
    static func shareableURL(for entity: ClipboardItemEntity) async -> URL? {
        let name = entity.title ?? entity.autoTitle ?? "Clipboard"

        if entity.contentType == "image" {
            guard let path = entity.content else { return nil }
            // An unlocked image is already a perfectly good file on disk;
            // copying it would only duplicate it.
            if !entity.isEncrypted, !SecureStore.isSealedFile(path) {
                guard let url = ThumbnailStore.imageURL(for: path),
                      FileManager.default.fileExists(atPath: url.path) else { return nil }
                return url
            }
            guard let image = await revealedImage(for: entity),
                  let bitmap = image.storageBitmapRep,
                  let png = bitmap.representation(using: .png, properties: [:]) else { return nil }
            return ShareStaging.stage(png, filename: name, ext: "png")
        }

        guard let text = await revealedContent(for: entity), !text.isEmpty else { return nil }
        return ShareStaging.stage(text, filename: name)
    }

    /// Copy, then paste into `targetApp` (or the frontmost app).
    @MainActor
    @discardableResult
    static func paste(entity: ClipboardItemEntity, into targetApp: NSRunningApplication? = nil) async -> Bool {
        guard await copyToPasteboard(for: entity) else { return false }
        PasteManager.shared.performPaste(into: targetApp)
        return true
    }
}


enum ClipboardSecurityError: LocalizedError, Equatable {
    case authenticationFailed
    case imageFileMissing

    var errorDescription: String? {
        switch self {
        case .authenticationFailed:
            return "Authentication was cancelled or failed."
        case .imageFileMissing:
            return "The image file for this item couldn't be found."
        }
    }
}

/// Report a lock/unlock failure to the user.
///
/// Cancelling Touch ID is a decision, not a fault — it passes silently.
/// Anything else says what went wrong, because a lock button that
/// quietly does nothing is how "Encrypt" came to mean nothing in the
/// first place.
@MainActor
func presentSecurityFailure(_ error: Error) {
    if let securityError = error as? ClipboardSecurityError,
       securityError == .authenticationFailed { return }

    let alert = NSAlert()
    alert.alertStyle = .warning
    alert.messageText = "Couldn't change this item's lock"
    alert.informativeText = error.localizedDescription
    alert.addButton(withTitle: "OK")
    alert.runModal()
}
