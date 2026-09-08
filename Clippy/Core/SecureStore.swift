//
//  SecureStore.swift
//  Clippy
//
//  Encryption at rest for items the user locks.
//
//  Before this, "Encrypt" set a boolean and the UI drew a lock over the
//  card. The text stayed in the database in plain sight — readable by
//  anything that could open the sqlite file, and carried into every
//  Time Machine backup. The README promised authentication that did not
//  exist. This is the missing half.
//
//  Two protections, deliberately separate, because they defend against
//  different people:
//
//    * Encryption at rest — this file. Always on, no setting. Defends
//      against someone reading the database: another process, a backup,
//      a disk pulled out of a dead Mac.
//    * Authentication — ClipboardAuthenticator. Optional, because it is
//      a real trade-off. Defends against someone sitting at your
//      unlocked Mac.
//
//  Making encryption a setting would only ever weaken it — there is no
//  cost to leave it on — so it isn't one.
//

import CryptoKit
import Foundation
import Security

enum SecureStoreError: LocalizedError {
    case keychainFailure(OSStatus)
    case notSealed
    case corruptCiphertext

    var errorDescription: String? {
        switch self {
        case .keychainFailure(let status):
            let detail = SecCopyErrorMessageString(status, nil) as String? ?? "OSStatus \(status)"
            return "Keychain error: \(detail)"
        case .notSealed:
            return "This item is not encrypted."
        case .corruptCiphertext:
            return "The encrypted content could not be read."
        }
    }
}

enum SecureStore {

    /// Prefix on everything this writes.
    ///
    /// Earns its keep twice: it tells sealed content apart from the
    /// plaintext that shipped in earlier versions (so those items can be
    /// migrated in place rather than mangled), and the version number
    /// leaves room to change the cipher later without guessing at what
    /// an old row contains.
    private static let marker = "clippy-enc-v1:"

    private static let service = "com.yarasa.Clippy.contentKey"
    private static let account = "default"

    // MARK: - Sealing

    static func isSealed(_ stored: String) -> Bool {
        stored.hasPrefix(marker)
    }

    /// Encrypt `plaintext` for storage in the item's `content` field.
    ///
    /// AES-GCM, so the result is authenticated: tampering with the stored
    /// bytes makes `open` throw rather than return altered text.
    static func seal(_ plaintext: String) throws -> String {
        let key = try key()
        let box = try AES.GCM.seal(Data(plaintext.utf8), using: key)
        guard let combined = box.combined else { throw SecureStoreError.corruptCiphertext }
        return marker + combined.base64EncodedString()
    }

    /// Decrypt what `seal` produced.
    static func open(_ stored: String) throws -> String {
        guard isSealed(stored) else { throw SecureStoreError.notSealed }
        let encoded = String(stored.dropFirst(marker.count))
        guard let combined = Data(base64Encoded: encoded) else {
            throw SecureStoreError.corruptCiphertext
        }
        let key = try key()
        let box = try AES.GCM.SealedBox(combined: combined)
        let plaintext = try AES.GCM.open(box, using: key)
        guard let string = String(data: plaintext, encoding: .utf8) else {
            throw SecureStoreError.corruptCiphertext
        }
        return string
    }

    // MARK: - Sealing bytes

    /// File extension for a sealed image. Anything that decodes images
    /// checks for it and declines, so a locked picture can never be
    /// decoded straight off disk into a thumbnail cache.
    static let sealedFileExtension = "enc"

    /// Four bytes at the front of every sealed file, so a truncated or
    /// foreign file is rejected before it reaches AES-GCM.
    private static let fileMagic = Data([0x43, 0x4C, 0x50, 0x01])   // "CLP\u{01}"

    static func isSealedFile(_ path: String) -> Bool {
        (path as NSString).pathExtension.lowercased() == sealedFileExtension
    }

    /// Encrypt raw bytes — an image file on its way to disk.
    ///
    /// No base64 here, unlike `seal(_ plaintext:)`: that one has to fit
    /// through a CoreData String attribute, this one is written straight
    /// to a file and padding it by a third would be pure waste.
    static func seal(data: Data) throws -> Data {
        let box = try AES.GCM.seal(data, using: try key())
        guard let combined = box.combined else { throw SecureStoreError.corruptCiphertext }
        return fileMagic + combined
    }

    static func open(data: Data) throws -> Data {
        guard data.count > fileMagic.count, data.prefix(fileMagic.count) == fileMagic else {
            throw SecureStoreError.corruptCiphertext
        }
        let box = try AES.GCM.SealedBox(combined: data.dropFirst(fileMagic.count))
        return try AES.GCM.open(box, using: try key())
    }

    // MARK: - Key

    /// The item key, created on first use and kept in the Keychain.
    ///
    /// `kSecAttrAccessibleWhenUnlockedThisDeviceOnly`: readable only
    /// while the Mac is unlocked, and `ThisDeviceOnly` keeps it out of
    /// iCloud Keychain and out of backups — a key that travels with the
    /// backup would undo the point of encrypting the database that sits
    /// next to it.
    ///
    /// No biometry flag on the item itself. That is what makes the
    /// authentication setting a free toggle instead of a re-encryption:
    /// binding Touch ID to the key here would mean tearing the key down
    /// and rewrapping every item whenever the user changed their mind.
    /// Keychain items are already scoped to this app's code signature,
    /// so another process cannot read it either way.
    private static func key() throws -> SymmetricKey {
        if let existing = try loadKey() { return existing }
        let fresh = SymmetricKey(size: .bits256)
        try storeKey(fresh)
        return fresh
    }

    private static func loadKey() throws -> SymmetricKey? {
        var query: [String: Any] = baseQuery
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        switch status {
        case errSecSuccess:
            guard let data = result as? Data else { throw SecureStoreError.corruptCiphertext }
            return SymmetricKey(data: data)
        case errSecItemNotFound:
            return nil
        default:
            throw SecureStoreError.keychainFailure(status)
        }
    }

    private static func storeKey(_ key: SymmetricKey) throws {
        var attributes: [String: Any] = baseQuery
        attributes[kSecValueData as String] = key.withUnsafeBytes { Data($0) }
        attributes[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly

        let status = SecItemAdd(attributes as CFDictionary, nil)
        guard status == errSecSuccess else { throw SecureStoreError.keychainFailure(status) }
    }

    private static var baseQuery: [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
    }
}
