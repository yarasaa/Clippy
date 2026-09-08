//
//  ShareStaging.swift
//  Clippy
//
//  Temporary files handed to the macOS share sheet.
//
//  Sharing text means writing it to a file first — NSSharingServicePicker
//  takes URLs, not strings. Both share paths did that straight into
//  `temporaryDirectory` and never looked back, leaving a plain-text copy
//  of clipboard content behind after every share. That was always untidy;
//  once locked items could be shared it became a way for decrypted text
//  to end up sitting on disk in the clear, which is exactly what the
//  encryption exists to prevent.
//
//  So: one directory, emptied at launch and again before each write.
//  The share sheet only needs the file while it is open, and no share
//  sheet survives a relaunch.
//

import Foundation

enum ShareStaging {

    /// Files older than this are gone the next time anything shares.
    /// Long enough that an open share sheet is never pulled out from
    /// under the user, short enough that nothing lingers.
    private static let maxAge: TimeInterval = 10 * 60

    private static var directory: URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("Clippy/Share", isDirectory: true)
    }

    /// Write `text` somewhere the share sheet can reach it.
    ///
    /// `filename` is the name the recipient sees, so it comes from the
    /// item rather than a timestamp — sharing a snippet called "invoice"
    /// should not arrive as `clippy-share-1757203841.txt`.
    static func stage(_ text: String, filename: String) -> URL? {
        purge()
        let fileManager = FileManager.default
        do {
            try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
            let url = directory.appendingPathComponent(sanitise(filename))
            try text.write(to: url, atomically: true, encoding: .utf8)
            return url
        } catch {
            NSLog("[Clippy] Could not stage a file for sharing: \(error.localizedDescription)")
            return nil
        }
    }

    /// The same, for bytes — a rendered screenshot on its way to the
    /// share sheet. `ext` is the file extension without the dot.
    static func stage(_ data: Data, filename: String, ext: String) -> URL? {
        purge()
        let fileManager = FileManager.default
        do {
            try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
            let url = directory.appendingPathComponent(sanitise(filename, ext: ext))
            try data.write(to: url)
            return url
        } catch {
            NSLog("[Clippy] Could not stage a file for sharing: \(error.localizedDescription)")
            return nil
        }
    }

    /// Delete staged files older than `maxAge`. Called before every
    /// share, and once at launch to clear anything a crash left behind.
    static func purge() {
        let fileManager = FileManager.default
        guard let files = try? fileManager.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.contentModificationDateKey]
        ) else { return }

        let cutoff = Date().addingTimeInterval(-maxAge)
        for file in files {
            let modified = (try? file.resourceValues(forKeys: [.contentModificationDateKey]))?
                .contentModificationDate
            // No date means we can't judge it, and a file we can't judge
            // is a file we shouldn't keep.
            if modified == nil || modified! < cutoff {
                try? fileManager.removeItem(at: file)
            }
        }
    }

    /// Everything, regardless of age. For quitting.
    static func purgeAll() {
        try? FileManager.default.removeItem(at: directory)
    }

    private static func sanitise(_ filename: String, ext: String = "txt") -> String {
        let trimmed = filename
            .components(separatedBy: CharacterSet(charactersIn: "/\\:\0"))
            .joined(separator: "-")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let base = trimmed.isEmpty ? "Clipboard" : String(trimmed.prefix(60))
        return base.hasSuffix("." + ext) ? base : base + "." + ext
    }
}
