//
//  ClipboardAuthenticator.swift
//  Clippy
//
//  The Touch ID / password gate in front of locked items.
//
//  Separate from SecureStore on purpose. Encryption defends the database
//  against anything that can read the file; this defends against a person
//  at your already-unlocked Mac. Only the second one is a trade-off worth
//  offering as a setting, which is why only the second one is optional.
//

import Foundation
import LocalAuthentication

@MainActor
final class ClipboardAuthenticator {
    static let shared = ClipboardAuthenticator()

    /// One context, held, because that is the only way the reuse window
    /// works: `touchIDAuthenticationAllowableReuseDuration` is a property
    /// of a context instance, so a fresh `LAContext` per call would
    /// prompt every single time no matter what the user chose.
    private var context: LAContext?

    /// The reuse duration the held context was built with. When the user
    /// changes the setting the old context is thrown away, otherwise it
    /// would keep honouring the previous window.
    private var contextReuseDuration: TimeInterval = -1

    private init() {}

    /// Whether this Mac can authenticate at all.
    ///
    /// `.deviceOwnerAuthentication` rather than
    /// `.deviceOwnerAuthenticationWithBiometrics`: it uses Touch ID where
    /// there is Touch ID and falls back to the login password everywhere
    /// else, so Macs without a sensor need no separate code path.
    var isAvailable: Bool {
        LAContext().canEvaluatePolicy(.deviceOwnerAuthentication, error: nil)
    }

    /// Ask the user to prove they're them.
    ///
    /// Returns `true` when the gate is satisfied — including when the
    /// user has the setting switched off, which is the whole point of it
    /// being a setting.
    func authenticate(reason: String) async -> Bool {
        guard SettingsManager.shared.requireAuthForEncrypted else { return true }

        // A Mac with no password set can't evaluate the policy. Refusing
        // here would lock people out of their own clipboard with no way
        // back, so the gate opens and says why. The content stays
        // encrypted at rest regardless — that half never depended on this.
        guard isAvailable else {
            NSLog("[Clippy] Authentication unavailable on this Mac; unlocking without it.")
            return true
        }

        let reuse = SettingsManager.shared.encryptedAuthReuseDuration
        let context = contextForReuse(reuse)

        do {
            return try await context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reason)
        } catch let error as LAError where error.code == .userCancel || error.code == .appCancel || error.code == .systemCancel {
            // Cancelling is an answer, not a fault. No log, no alarm.
            return false
        } catch {
            NSLog("[Clippy] Authentication failed: \(error.localizedDescription)")
            return false
        }
    }

    /// Drop the held context so the next unlock prompts again. Called
    /// when an item is locked, so locking something and immediately
    /// copying it doesn't sail through on the authentication that was
    /// still warm from a moment ago.
    func invalidate() {
        context?.invalidate()
        context = nil
        contextReuseDuration = -1
    }

    private func contextForReuse(_ duration: TimeInterval) -> LAContext {
        if let context, contextReuseDuration == duration { return context }

        self.context?.invalidate()
        let fresh = LAContext()
        // Capped by the system at 300 seconds; the settings UI offers
        // nothing longer rather than pretending a longer window is
        // enforced when it isn't.
        fresh.touchIDAuthenticationAllowableReuseDuration = min(duration, LATouchIDAuthenticationMaximumAllowableReuseDuration)
        self.context = fresh
        self.contextReuseDuration = duration
        return fresh
    }
}
