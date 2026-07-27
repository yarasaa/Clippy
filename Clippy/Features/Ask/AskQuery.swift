//
//  AskQuery.swift
//  Clippy
//
//  A small, closed structured filter for "Ask your clipboard", plus the
//  planner that produces it.
//
//  The key design idea: an AI *plans* the query (turns the free-text
//  question into this JSON-shaped filter), but correctness never depends
//  on the AI. If the model returns junk — or there's no capable model at
//  all — we fall back to deterministic heuristics. So the feature works
//  with every model: a good model widens coverage, a weak one just leans
//  on the heuristics.
//

import Foundation
import NaturalLanguage

struct AskQuery: Equatable {
    enum Timeframe: String, Codable {
        case today, yesterday
        case thisWeek = "this_week"
        case lastWeek = "last_week"
        case thisMonth = "this_month"
        case lastMonth = "last_month"
        case all
    }
    enum ItemType: String, Codable {
        case text, image, link, any
    }
    enum Status: String, Codable {
        case pinned, starred, snippet, code, none
    }

    var timeframe: Timeframe = .all
    var type: ItemType = .any
    var status: Status = .none
    var app: String = ""
    var keywords: [String] = []

    struct DateRange { let start: Date; let end: Date }

    /// Absolute window for `timeframe`, or nil for `.all`.
    func dateRange(now: Date = Date()) -> DateRange? {
        let cal = Calendar.current
        func startOfDay(_ d: Date) -> Date { cal.startOfDay(for: d) }

        switch timeframe {
        case .all:
            return nil
        case .today:
            return DateRange(start: startOfDay(now), end: now)
        case .yesterday:
            let y = cal.date(byAdding: .day, value: -1, to: now)!
            return DateRange(start: startOfDay(y), end: startOfDay(now))
        case .thisWeek:
            let start = cal.dateInterval(of: .weekOfYear, for: now)?.start
                ?? cal.date(byAdding: .day, value: -7, to: now)!
            return DateRange(start: start, end: now)
        case .lastWeek:
            let thisStart = cal.dateInterval(of: .weekOfYear, for: now)?.start ?? now
            let lastStart = cal.date(byAdding: .day, value: -7, to: thisStart)!
            return DateRange(start: lastStart, end: thisStart)
        case .thisMonth:
            let start = cal.dateInterval(of: .month, for: now)?.start
                ?? cal.date(byAdding: .day, value: -30, to: now)!
            return DateRange(start: start, end: now)
        case .lastMonth:
            let thisStart = cal.dateInterval(of: .month, for: now)?.start ?? now
            let lastStart = cal.date(byAdding: .month, value: -1, to: thisStart)!
            return DateRange(start: lastStart, end: thisStart)
        }
    }
}

// MARK: - Planner

@MainActor
enum AskPlanner {

    /// Turn a natural-language question into an `AskQuery`. Tries the AI
    /// first; on any failure, or when the output can't be validated,
    /// returns the deterministic heuristic parse instead.
    static func plan(_ question: String) async -> AskQuery {
        let heuristic = AskQuery.heuristic(from: question)

        guard AIService.shared.isConfigured else { return heuristic }

        let prompt = plannerPrompt(question)
        do {
            let raw = try await AIService.shared.process(
                text: prompt,
                action: .freePrompt,
                customPrompt: "You convert a question into a compact JSON filter for searching clipboard history. Output ONLY the JSON object — no prose, no code fences."
            )
            if let parsed = AskQuery.parse(raw) {
                // Merge: trust the model's structured fields, but keep the
                // heuristic keywords if the model returned none (small
                // models often drop them).
                var q = parsed
                if q.keywords.isEmpty { q.keywords = heuristic.keywords }
                return q
            }
        } catch {
            // fall through to heuristic
        }
        return heuristic
    }

    private static func plannerPrompt(_ question: String) -> String {
        """
        Convert the question into a JSON filter using EXACTLY these keys and allowed values:
        - "timeframe": today | yesterday | this_week | last_week | this_month | last_month | all
        - "type": text | image | link | any
        - "status": pinned | starred | snippet | code | none
        - "app": an app name mentioned in the question, else ""
        - "keywords": array of the important content words (nouns, names, topics); [] if none

        Examples:
        Q: bugün kopyaladığım linkler → {"timeframe":"today","type":"link","status":"none","app":"","keywords":[]}
        Q: pinlediklerim neler → {"timeframe":"all","type":"any","status":"pinned","app":"","keywords":[]}
        Q: Chrome'dan dün aldığım telefon numarası → {"timeframe":"yesterday","type":"text","status":"none","app":"Chrome","keywords":["telefon","numara"]}
        Q: geçen ay attığım adres → {"timeframe":"last_month","type":"text","status":"none","app":"","keywords":["adres"]}
        Q: show my starred screenshots → {"timeframe":"all","type":"image","status":"starred","app":"","keywords":[]}

        Q: \(question) →
        """
    }
}

// MARK: - JSON parsing

extension AskQuery {
    /// Tolerant parse of a planner reply. Extracts the first `{...}` block
    /// so surrounding prose/code-fences don't break it, then validates
    /// every field against its allowed values (unknown → default).
    static func parse(_ raw: String) -> AskQuery? {
        guard let start = raw.firstIndex(of: "{"),
              let end = raw.lastIndex(of: "}"),
              start < end else { return nil }
        let jsonSlice = String(raw[start...end])
        guard let data = jsonSlice.data(using: .utf8),
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }

        var q = AskQuery()
        if let s = (obj["timeframe"] as? String)?.lowercased(),
           let tf = Timeframe(rawValue: s) { q.timeframe = tf }
        if let s = (obj["type"] as? String)?.lowercased(),
           let t = ItemType(rawValue: s) { q.type = t }
        if let s = (obj["status"] as? String)?.lowercased(),
           let st = Status(rawValue: s) { q.status = st }
        if let a = obj["app"] as? String { q.app = a.trimmingCharacters(in: .whitespacesAndNewlines) }
        if let kws = obj["keywords"] as? [Any] {
            q.keywords = kws.compactMap { ($0 as? String)?.lowercased() }
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { $0.count >= 2 }
        }
        return q
    }
}

// MARK: - Heuristic fallback

extension AskQuery {
    /// Deterministic parse used when no capable model is available or the
    /// model's reply is unusable. Mirrors the closed vocabulary the app
    /// understands so behaviour degrades predictably.
    static func heuristic(from question: String) -> AskQuery {
        let lower = question.lowercased()
        var q = AskQuery()

        // Timeframe
        if lower.containsAny(["today", "bugün"]) { q.timeframe = .today }
        else if lower.containsAny(["yesterday", "dün"]) { q.timeframe = .yesterday }
        else if lower.containsAny(["this week", "bu hafta"]) { q.timeframe = .thisWeek }
        else if lower.containsAny(["last week", "geçen hafta"]) { q.timeframe = .lastWeek }
        else if lower.containsAny(["this month", "bu ay"]) { q.timeframe = .thisMonth }
        else if lower.containsAny(["last month", "geçen ay"]) { q.timeframe = .lastMonth }

        // Type
        if lower.containsAny(["screenshot", "image", "picture", "görsel", "ekran görüntüsü", "resim"]) {
            q.type = .image
        } else if lower.containsAny(["link", "url", "website", "site", "bağlantı"]) {
            q.type = .link
        }

        // Status (first match wins)
        if lower.containsAny(["pinned", "pinle", "pinledik", "pinlediğ", "sabitle", "sabitledik", "sabitlediğ", "iğneled"]) {
            q.status = .pinned
        } else if lower.containsAny(["starred", "favorite", "favourite", "favori", "yıldız", "beğendik", "beğendiğ"]) {
            q.status = .starred
        } else if lower.containsAny(["snippet", "kısayol", "şablon", "template"]) {
            q.status = .snippet
        } else if lower.containsAny(["code", "kod ", "kodu", "kodları", "kodlar"]) {
            q.status = .code
        }

        q.keywords = Self.meaningfulWords(from: lower)
        return q
    }

    private static let stopWords: Set<String> = [
        "what", "was", "the", "a", "an", "i", "my", "me", "from", "in",
        "on", "of", "did", "is", "are", "that", "this", "which", "list",
        "show", "find", "give", "copied", "copy", "clipboard",
        "ne", "neydi", "neler", "ben", "benim", "bir", "bu", "şu", "olan",
        "kopyaladığım", "kopyaladım", "listele", "göster", "hangi", "vardı"
    ]

    static func meaningfulWords(from lower: String) -> [String] {
        let words = lower
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { $0.count >= 3 && !stopWords.contains($0) }
        return Array(words.prefix(6))
    }
}

// MARK: - Small helpers

extension String {
    func containsAny(_ needles: [String]) -> Bool {
        needles.contains { self.contains($0) }
    }
}
