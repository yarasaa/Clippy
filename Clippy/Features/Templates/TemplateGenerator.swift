//
//  TemplateGenerator.swift
//  Clippy
//
//  Turns a set of repeatedly-copied, structurally-similar texts into a
//  reusable snippet template: the shared wording is kept verbatim and
//  the parts that changed between copies become `{{named}}` fill-in
//  fields — the same placeholder syntax Clippy's snippet expander
//  already understands.
//
//  Local-only, like auto-titling: this runs on Apple Intelligence or a
//  local Ollama model and never spends cloud API credits on its own.
//

import Foundation

@MainActor
enum TemplateGenerator {

    struct Draft {
        /// Template body with `{{field}}` placeholders.
        var template: String
        /// Suggested expansion keyword, including the `;` trigger.
        var keyword: String
    }

    enum GenError: LocalizedError {
        case notEligible
        case failed(String)

        var errorDescription: String? {
            switch self {
            case .notEligible:  return "Template suggestions need on-device AI (Apple Intelligence or Ollama)."
            case .failed(let m): return m
            }
        }
    }

    /// True when template generation is allowed — local providers only,
    /// mirroring AutoTitleService's cost-safety stance.
    static var isEligible: Bool {
        let s = SettingsManager.shared
        guard s.enableAI, s.enableTemplateDetection else { return false }
        guard s.aiProvider == "apple" || s.aiProvider == "ollama" else { return false }
        return AIService.shared.isConfigured
    }

    static func generate(from samples: [String]) async throws -> Draft {
        guard isEligible else { throw GenError.notEligible }

        let numbered = samples.prefix(5).enumerated()
            .map { "Example \($0.offset + 1):\n\($0.element)" }
            .joined(separator: "\n\n")

        let prompt = """
        These are examples of text I copy again and again, changing only
        some details each time:

        \(numbered)

        Produce ONE reusable template. Keep the wording that stays the
        same across the examples exactly as-is. Replace each part that
        varies with a placeholder written as {{short_field_name}} using a
        clear lowercase snake_case name (e.g. {{invoice_number}},
        {{amount}}, {{due_date}}). Do not invent extra fields. Output only
        the template text — no explanation, no code fences.
        """

        do {
            let raw = try await AIService.shared.process(
                text: prompt,
                action: .freePrompt,
                customPrompt: "You convert repeated text into a single fill-in-the-blank template. Reply with only the template."
            )
            let template = cleanTemplate(raw)
            return Draft(template: template, keyword: suggestKeyword(from: samples, template: template))
        } catch {
            throw GenError.failed(error.localizedDescription)
        }
    }

    // MARK: Cleanup

    private static func cleanTemplate(_ raw: String) -> String {
        var t = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        // Strip an accidental ``` fence if the model added one.
        if t.hasPrefix("```") {
            t = t.replacingOccurrences(of: "^```[a-zA-Z]*\\n?", with: "", options: .regularExpression)
            if let range = t.range(of: "```", options: .backwards) {
                t.removeSubrange(range.lowerBound..<t.endIndex)
            }
            t = t.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return t
    }

    /// Derive a short trigger keyword from the shared leading words of the
    /// samples, falling back to "template". Always prefixed with `;`.
    private static func suggestKeyword(from samples: [String], template: String) -> String {
        let source = samples.first ?? template
        let words = source
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { $0.count >= 3 }
        let base = (words.first ?? "template").lowercased()
        let safe = String(base.prefix(16))
        return ";" + safe
    }
}
