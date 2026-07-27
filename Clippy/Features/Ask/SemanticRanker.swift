//
//  SemanticRanker.swift
//  Clippy
//
//  Re-orders the filtered candidate set by *meaning*, not just recency,
//  so "araba" can surface an item that says "otomobil". Everything is
//  on-device and free — Apple's NLEmbedding word vectors — so it adds no
//  network cost and doesn't depend on any AI provider being configured.
//
//  Scoring blends three cheap signals:
//    • semantic  — cosine similarity of averaged word vectors
//    • lexical   — fraction of the query's keywords literally present
//    • recency   — a tiny tie-breaker so equal items stay newest-first
//
//  When word embeddings aren't available for the text's language, the
//  semantic term is simply 0 and the lexical + recency terms still give
//  a sensible ordering — it degrades, it never fails.
//
//  Note: NLEmbedding here is word-level. On macOS 14+ NLContextualEmbedding
//  would give stronger multilingual sentence vectors; left as a future
//  upgrade to avoid its heavier (async, asset-backed) load path.
//

import Foundation
import NaturalLanguage

@MainActor
enum SemanticRanker {

    /// Returns the `limit` most relevant items for `query`, best first.
    /// `keywords` are the planner's extracted content words (used for the
    /// lexical term). Falls back to the input order (recency) if there's
    /// nothing to rank on.
    static func rank(_ items: [ClipboardItemEntity],
                     for query: String,
                     keywords: [String],
                     limit: Int) -> [ClipboardItemEntity] {
        guard items.count > 1 else { return Array(items.prefix(limit)) }

        let qText = query.lowercased()
        let embedding = wordEmbedding(for: qText)
        let queryVector = embedding.flatMap { vector(for: qText, using: $0) }
        let lowerKeywords = keywords.map { $0.lowercased() }.filter { !$0.isEmpty }

        let now = Date()
        let newest = items.first?.date ?? now
        let oldest = items.last?.date ?? now
        let span = max(newest.timeIntervalSince(oldest), 1)

        let scored: [(item: ClipboardItemEntity, score: Double)] = items.map { item in
            let text = searchableText(for: item)

            // Semantic
            var semantic = 0.0
            if let qv = queryVector, let e = embedding,
               let iv = vector(for: text, using: e) {
                semantic = max(0, cosine(qv, iv))
            }

            // Lexical
            var lexical = 0.0
            if !lowerKeywords.isEmpty {
                let lowerText = text.lowercased()
                let hits = lowerKeywords.filter { lowerText.contains($0) }.count
                lexical = Double(hits) / Double(lowerKeywords.count)
            }

            // Recency (0…1)
            let recency = (item.date ?? oldest).timeIntervalSince(oldest) / span

            let score = 0.62 * semantic + 0.30 * lexical + 0.08 * recency
            return (item, score)
        }

        return scored
            .sorted { $0.score > $1.score }
            .prefix(limit)
            .map { $0.item }
    }

    // MARK: - Embedding

    /// Word embedding for the text's dominant language, falling back to
    /// English. Nil when neither is available on this OS.
    private static func wordEmbedding(for text: String) -> NLEmbedding? {
        let recognizer = NLLanguageRecognizer()
        recognizer.processString(text)
        if let lang = recognizer.dominantLanguage,
           let e = NLEmbedding.wordEmbedding(for: lang) {
            return e
        }
        return NLEmbedding.wordEmbedding(for: .english)
    }

    /// Averaged word vector for a string (a poor-man's sentence vector).
    private static func vector(for text: String, using embedding: NLEmbedding) -> [Double]? {
        let words = text.lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { $0.count >= 2 }
        guard !words.isEmpty else { return nil }

        var sum: [Double] = []
        var count = 0
        for word in words.prefix(40) {
            guard let v = embedding.vector(for: word) else { continue }
            if sum.isEmpty { sum = v }
            else { for i in 0..<min(sum.count, v.count) { sum[i] += v[i] } }
            count += 1
        }
        guard count > 0 else { return nil }
        return sum.map { $0 / Double(count) }
    }

    private static func cosine(_ a: [Double], _ b: [Double]) -> Double {
        let n = min(a.count, b.count)
        guard n > 0 else { return 0 }
        var dot = 0.0, na = 0.0, nb = 0.0
        for i in 0..<n {
            dot += a[i] * b[i]
            na += a[i] * a[i]
            nb += b[i] * b[i]
        }
        guard na > 0, nb > 0 else { return 0 }
        return dot / (na.squareRoot() * nb.squareRoot())
    }

    /// Best text to represent an item for matching.
    private static func searchableText(for item: ClipboardItemEntity) -> String {
        if item.contentType == "image" {
            return [item.autoTitle, item.extractedText, item.title]
                .compactMap { $0 }
                .first { !$0.isEmpty } ?? ""
        }
        let base = [item.autoTitle, item.title].compactMap { $0 }.first { !$0.isEmpty }
        let content = String((item.content ?? "").prefix(240))
        return [base, content].compactMap { $0 }.joined(separator: " ")
    }
}
