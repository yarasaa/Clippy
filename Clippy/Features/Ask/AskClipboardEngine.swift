//
//  AskClipboardEngine.swift
//  Clippy
//
//  "Ask your clipboard" — natural-language questions over your own
//  history, answered on-device.
//
//  Pipeline:
//    1. PLAN     — AskPlanner turns the question into a structured
//                  AskQuery (AI, with a deterministic heuristic fallback
//                  so it works with any model).
//    2. RETRIEVE — build CoreData predicates from the AskQuery, with
//                  tiered graceful degradation.
//    3. RANK     — on-device semantic re-rank (SemanticRanker) so the
//                  most relevant items lead, then keep the top few.
//    4. ANSWER   — hand the model just those items as numbered context
//                  and ask it to answer citing item numbers.
//

import Foundation
import CoreData

struct AskResult {
    let answer: String
    /// Items the engine surfaced as candidates, in the order shown to
    /// the model. `[n]` citations in `answer` are 1-based into this.
    let citedItems: [ClipboardItemEntity]
    /// A concrete value pulled deterministically from the top candidate
    /// (phone, email, address…), shown above the prose when present.
    let extractedValue: ExtractedValue?
}

@MainActor
enum AskClipboardEngine {

    enum AskError: LocalizedError {
        case notConfigured
        case noCandidates
        case failed(String)

        var errorDescription: String? {
            switch self {
            case .notConfigured: return "Turn on AI in Settings to ask your clipboard."
            case .noCandidates:  return "Couldn't find anything in your history matching that."
            case .failed(let m): return m
            }
        }
    }

    /// Final count handed to the model. Kept small: on-device 3B models
    /// cite indices far more reliably over ~10 items than over 20.
    private static let maxCandidates = 10
    /// How many items the filter may return *before* semantic ranking.
    /// Bounds the embedding cost while still giving the ranker a real
    /// pool to choose from.
    private static let prefilterLimit = 150

    static func ask(_ question: String) async throws -> AskResult {
        guard AIService.shared.isConfigured else { throw AskError.notConfigured }

        let q = question.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { throw AskError.noCandidates }

        // 1. PLAN
        let query = await AskPlanner.plan(q)

        // 2. RETRIEVE
        let pool = fetchCandidates(for: query, question: q)
        guard !pool.isEmpty else { throw AskError.noCandidates }

        // 3. RANK
        let candidates = SemanticRanker.rank(pool, for: q, keywords: query.keywords, limit: maxCandidates)

        // 3b. Deterministic extraction — reliable regardless of the model.
        let extracted = ValueExtractor.extract(for: query, from: candidates)

        // 4. ANSWER
        let context = buildContext(candidates)
        let prompt = """
        Below is the user's OWN clipboard history. This data is real and
        fully available to you — it is provided right here. Never say you
        lack access to it.

        \(context)

        Question: \(q)

        Answer in the same language as the question, in 1–3 short
        sentences, using ONLY the items above. Rules:
        • Summarise in your own words — do NOT copy an item line verbatim.
        • Right after a fact, cite the item with its exact number in
          square brackets, e.g. [2]. Never invent a number.
        • If the question broadly asks what was copied, mention the 2–4
          most relevant items, each cited.
        • If the items genuinely don't contain what's asked, say briefly
          that you didn't find it — do NOT describe unrelated items and do
          NOT claim you have no access.

        Answer:
        """

        do {
            let answer = try await AIService.shared.process(
                text: prompt,
                action: .freePrompt,
                customPrompt: "You are Clippy's on-device assistant. The user's clipboard items are ALWAYS supplied to you inside the prompt, so you always have full access to them. Answer only from those items, cite their numbers, summarise in your own words, and never reply that you lack access to the clipboard."
            )
            let clean = sanitizeAnswer(answer)
            // Two distinct failure modes, two distinct checks.
            //
            // `isRefusal` catches a capability refusal ("I don't have
            // access…") — wrong no matter what we retrieved, because the
            // items are sitting in the prompt.
            //
            // `claimsNothingFound` catches the model reporting an empty
            // search. That is only *provably* wrong when ValueExtractor has
            // already pulled the value verbatim out of an item, so it's
            // gated on holding that evidence. The gate is what makes it safe
            // to be liberal with the phrase list: with a deterministic value
            // in hand the replacement answer is exact, so a false positive
            // costs nothing — whereas without evidence, "I didn't find it"
            // may simply be true and is left alone.
            let contradicted = extracted != nil && claimsNothingFound(clean)
            let final = (isRefusal(clean) || contradicted)
                ? fallbackAnswer(candidates, extracted: extracted)
                : clean
            return AskResult(answer: final,
                             citedItems: candidates,
                             extractedValue: extracted)
        } catch {
            throw AskError.failed(error.localizedDescription)
        }
    }

    /// Strips a leading "Answer:"/"Cevap:" label the small model sometimes
    /// echoes from the prompt.
    private static func sanitizeAnswer(_ raw: String) -> String {
        var a = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        for prefix in ["Answer:", "A:", "Cevap:"] where a.hasPrefix(prefix) {
            a = String(a.dropFirst(prefix.count)).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return a
    }

    private static let refusalMarkers = [
        "don't have access", "do not have access", "no access to",
        "can't provide", "cannot provide", "i'm unable", "i am unable",
        "unable to access", "don't have the ability", "as an ai",
        "erişimim yok", "erişemiyorum", "erişim yok", "sağlayamam"
    ]

    private static func isRefusal(_ answer: String) -> Bool {
        let a = answer.lowercased()
        // Only treat as a refusal when it's short and matches — a long
        // real answer that happens to contain "erişim" shouldn't trip it.
        guard a.count < 240 else { return false }
        return refusalMarkers.contains { a.contains($0) }
    }

    /// Phrases in which the model reports finding nothing. Only consulted
    /// when we hold a deterministically extracted value that proves
    /// otherwise — see the call site.
    private static let notFoundMarkers = [
        "didn't find", "did not find", "couldn't find", "could not find",
        "not find", "wasn't found", "was not found", "isn't in", "is not in",
        "not present", "no such", "nothing matching",
        "bulamadım", "bulamadim", "bulunamadı", "bulunamadi", "mevcut değil",
        "yer almıyor", "geçmiyor"
    ]

    private static func claimsNothingFound(_ answer: String) -> Bool {
        let a = answer.lowercased()
        guard a.count < 240 else { return false }
        return notFoundMarkers.contains { a.contains($0) }
    }

    /// Deterministic answer built from the retrieved items, used when the
    /// model refuses. Lists the top few so the SOURCES panel stays useful.
    private static func fallbackAnswer(_ items: [ClipboardItemEntity], extracted: ExtractedValue?) -> String {
        if let extracted {
            return "\(extracted.label): \(extracted.value) [\(extracted.sourceIndex)]"
        }
        let top = items.prefix(3).enumerated().map { i, item -> String in
            "[\(i + 1)] \(shortLabel(item))"
        }.joined(separator: ", ")
        return top.isEmpty ? "Nothing matched in your clipboard history."
                           : "Most relevant items: \(top)."
    }

    private static func shortLabel(_ item: ClipboardItemEntity) -> String {
        if let t = item.autoTitle, !t.isEmpty { return t }
        if let t = item.title, !t.isEmpty { return t }
        if item.contentType == "image" { return "Screenshot" }
        let body = (item.content ?? "").replacingOccurrences(of: "\n", with: " ")
        return String(body.prefix(40))
    }

    // MARK: - Retrieval

    private static func fetchCandidates(for query: AskQuery, question: String) -> [ClipboardItemEntity] {
        let ctx = PersistenceController.shared.container.viewContext

        // Never surface protected/secret items in an AI prompt.
        let notEncrypted = NSPredicate(format: "isEncrypted == NO")

        // Each signal is optional and independently relaxable — a brittle
        // one (a fuzzy date boundary, a keyword that doesn't literally
        // appear) shouldn't sink the whole query.
        let dateP: NSPredicate? = query.dateRange().map {
            NSPredicate(format: "date >= %@ AND date <= %@", $0.start as NSDate, $0.end as NSDate)
        }

        let typeP: NSPredicate?
        switch query.type {
        case .image:
            typeP = NSPredicate(format: "contentType == 'image'")
        case .link:
            // Real link markers only — no bare "." (which matches almost
            // any text and defeats the point of a link filter).
            typeP = NSPredicate(format: "content CONTAINS[c] 'http' OR content CONTAINS[c] 'www.' OR content CONTAINS[c] '.com' OR content CONTAINS[c] '.org' OR content CONTAINS[c] '.net' OR content CONTAINS[c] '.io' OR content CONTAINS[c] '.dev' OR content CONTAINS[c] '.app'")
        case .text:
            typeP = NSPredicate(format: "contentType == 'text'")
        case .any:
            typeP = nil
        }

        // Status intents map to entity flags (not content search) and are
        // authoritative — a "what did I pin?" query must never answer with
        // unpinned items.
        let flagP: NSPredicate?
        switch query.status {
        case .pinned:  flagP = NSPredicate(format: "isPinned == YES")
        case .starred: flagP = NSPredicate(format: "isFavorite == YES")
        case .snippet: flagP = NSPredicate(format: "keyword != nil AND keyword != ''")
        case .code:    flagP = NSPredicate(format: "isCode == YES")
        case .none:    flagP = nil
        }

        // App name: planner value first, else match a known source app in
        // the question text.
        let appName = query.app.isEmpty ? matchedAppName(in: question, context: ctx) : query.app
        let appP: NSPredicate? = (appName?.isEmpty == false)
            ? NSPredicate(format: "sourceAppName CONTAINS[c] %@", appName!)
            : nil

        let kwP: NSPredicate? = query.keywords.isEmpty ? nil : NSCompoundPredicate(
            orPredicateWithSubpredicates: query.keywords.map {
                NSPredicate(format: "content CONTAINS[c] %@ OR extractedText CONTAINS[c] %@ OR autoTitle CONTAINS[c] %@",
                            $0, $0, $0)
            }
        )

        // Tiers from most specific to least; first non-empty wins.
        let tiers: [[NSPredicate?]]
        if let flagP = flagP {
            tiers = [
                [flagP, dateP, typeP, appP, kwP],
                [flagP, dateP, typeP, appP],
                [flagP, typeP, appP],
                [flagP, dateP, appP],
                [flagP, typeP],
                [flagP, appP],
                [flagP, dateP],
                [flagP],
            ]
        } else {
            tiers = [
                [dateP, typeP, appP, kwP],
                [dateP, typeP, appP],
                [typeP, appP, kwP],
                [dateP, typeP],
                [typeP, appP],
                [typeP],
                [dateP, appP],
                [dateP],
                [appP],
                [],
            ]
        }

        for tier in tiers {
            let preds = [notEncrypted] + tier.compactMap { $0 }
            let compound = NSCompoundPredicate(andPredicateWithSubpredicates: preds)
            if let hits = runFetch(compound, ctx: ctx), !hits.isEmpty {
                return hits
            }
        }
        return []
    }

    private static func runFetch(_ predicate: NSPredicate, ctx: NSManagedObjectContext) -> [ClipboardItemEntity]? {
        let request = NSFetchRequest<ClipboardItemEntity>(entityName: "ClipboardItemEntity")
        request.predicate = predicate
        request.sortDescriptors = [NSSortDescriptor(keyPath: \ClipboardItemEntity.date, ascending: false)]
        request.fetchLimit = prefilterLimit
        return try? ctx.fetch(request)
    }

    private static func matchedAppName(in question: String, context ctx: NSManagedObjectContext) -> String? {
        let request = NSFetchRequest<NSDictionary>(entityName: "ClipboardItemEntity")
        request.resultType = .dictionaryResultType
        request.propertiesToFetch = ["sourceAppName"]
        request.returnsDistinctResults = true
        guard let rows = try? ctx.fetch(request) else { return nil }
        let names = rows.compactMap { $0["sourceAppName"] as? String }.filter { !$0.isEmpty }
        let lowerQ = question.lowercased()
        // Longest match first so "Google Chrome" beats "Google".
        return names.sorted { $0.count > $1.count }
            .first { lowerQ.contains($0.lowercased()) }
    }

    // MARK: - Context building

    private static func buildContext(_ items: [ClipboardItemEntity]) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        let now = Date()

        return items.enumerated().map { i, item in
            let when = formatter.localizedString(for: item.date ?? now, relativeTo: now)
            let app = item.sourceAppName ?? "?"
            let type = item.contentType == "image" ? "screenshot" : "text"
            let body: String = {
                if item.contentType == "image" {
                    return (item.autoTitle ?? item.extractedText ?? "(image)")
                }
                return item.content ?? ""
            }()
            let excerpt = String(body.replacingOccurrences(of: "\n", with: " ").prefix(200))
            return "[\(i + 1)] \(when) · \(app) · \(type): \(excerpt)"
        }.joined(separator: "\n")
    }
}
