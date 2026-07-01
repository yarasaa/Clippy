//
//  AppleFoundationModelsClient.swift
//  Clippy
//
//  Thin wrapper around Apple's on-device language model (introduced
//  in macOS 26 via the `FoundationModels` framework). Adds a fifth
//  AI provider to Clippy that needs zero configuration: no API key,
//  no network, no signup. Everything runs locally on Apple Silicon
//  and never leaves the user's Mac.
//
//  Trade-off vs cloud providers: the on-device model is smaller
//  (~3B params) so it's less capable on complex tasks. Good enough
//  for summarize / fix-grammar / explain / rename / short
//  translations, which covers most of Clippy's AI surface area.
//
//  All FoundationModels imports are gated by `canImport` so the
//  build still succeeds on older Xcode toolchains and SDKs.
//

import Foundation

#if canImport(FoundationModels)
import FoundationModels
#endif

enum AppleFoundationModelsClient {
    /// Is the on-device model available right now?
    /// False on macOS < 26, on Macs without Apple Intelligence
    /// support, when Apple Intelligence is disabled in System
    /// Settings, or when the model is still downloading.
    static var isReady: Bool {
        #if canImport(FoundationModels)
        if #available(macOS 26.0, *) {
            return SystemLanguageModel.default.availability == .available
        }
        #endif
        return false
    }

    /// Returns nil when the model is ready, or a user-readable
    /// reason it isn't (so Settings → AI can show a helpful
    /// "Apple Intelligence is still downloading" message instead
    /// of a generic failure).
    static func availabilityMessage() -> String? {
        #if canImport(FoundationModels)
        if #available(macOS 26.0, *) {
            switch SystemLanguageModel.default.availability {
            case .available:
                return nil
            case .unavailable(let reason):
                switch reason {
                case .deviceNotEligible:
                    return "This Mac doesn't support Apple Intelligence. Use Ollama or a cloud provider instead."
                case .appleIntelligenceNotEnabled:
                    return "Apple Intelligence is off. Enable it in System Settings → Apple Intelligence & Siri."
                case .modelNotReady:
                    return "Apple Intelligence model is still downloading. Try again in a few minutes."
                @unknown default:
                    return "Apple Intelligence is unavailable."
                }
            @unknown default:
                return "Apple Intelligence is unavailable."
            }
        }
        return "Apple Intelligence requires macOS 26 or later. Use Ollama or a cloud provider instead."
        #else
        return "Apple Intelligence is unavailable on this build of Clippy."
        #endif
    }

    /// Run a single text-generation request against the on-device
    /// model. Throws when the framework isn't available or the
    /// session errors out (timeout, guardrail rejection, etc.).
    static func generate(system: String, user: String) async throws -> String {
        #if canImport(FoundationModels)
        if #available(macOS 26.0, *) {
            guard SystemLanguageModel.default.availability == .available else {
                throw AIError.notConfigured
            }
            // FoundationModels takes a single instructions string;
            // we glue our system + user prompts via the session's
            // instructions + the `respond(to:)` user message.
            let session = LanguageModelSession(instructions: system)
            do {
                let response = try await session.respond(to: user)
                return response.content
            } catch {
                throw AIError.apiError("Apple Intelligence: \(error.localizedDescription)")
            }
        }
        throw AIError.notConfigured
        #else
        throw AIError.notConfigured
        #endif
    }
}
