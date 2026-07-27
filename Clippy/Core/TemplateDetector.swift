//
//  TemplateDetector.swift
//  Clippy
//
//  Notices when you keep copying the *same shape* of text with only the
//  details changed — invoice lines, order confirmations, form answers,
//  standard replies — and offers to turn that shape into a reusable
//  template with fill-in blanks.
//
//  How it works, cheaply and locally:
//    1. Each captured text is reduced to a "skeleton" by replacing the
//       variable bits (numbers, dates, emails, URLs, money, times) with
//       placeholder tokens. "Invoice #1042 due 2026-07-01 — $250.00"
//       and "Invoice #1043 due 2026-08-15 — $99.50" both become
//       "Invoice #⟨num⟩ due ⟨date⟩ — ⟨money⟩".
//    2. The skeleton is hashed and counted in a small rolling store
//       (last 14 days, persisted to UserDefaults).
//    3. When a skeleton is seen ≥ 3 times, we fire a one-shot
//       notification so the UI can suggest making a template.
//
//  No network, no CoreData, no AI here — this is pure pattern bookkeeping.
//  The actual template text is generated later (TemplateDetector only
//  decides *when* to offer it).
//

import Foundation
import CryptoKit

extension Notification.Name {
    /// A repeated text structure crossed the threshold. userInfo:
    ///   "skeleton": String  — the placeholder-ified shape
    ///   "samples":  [String] — recent raw examples (most recent first)
    static let clippyTemplateCandidateDetected =
        Notification.Name("com.yarasa.Clippy.templateCandidateDetected")
}

@MainActor
final class TemplateDetector {
    static let shared = TemplateDetector()
    private init() { load() }

    // MARK: Tuning

    /// Fire once a skeleton has been copied this many times.
    private let threshold = 3
    /// Only remember occurrences within this window.
    private let windowDays = 14
    /// Ignore text outside this length — too short is noise (single
    /// words, numbers), too long is rarely a fill-in template.
    private let minLength = 24
    private let maxLength = 1200
    /// A skeleton must still carry this much fixed (non-placeholder,
    /// non-space) text after normalizing, or it's too generic to be a
    /// meaningful template (e.g. a bare number or date).
    private let minFixedChars = 12
    /// Cap the store so it can't grow unbounded.
    private let maxRecords = 200

    // MARK: Persisted store

    private struct Record: Codable {
        var timestamps: [Date]
        var skeleton: String
        var samples: [String]   // most recent first, capped
        var fired: Bool
    }

    private var store: [String: Record] = [:]
    private let storeKey = "templateDetectorStore.v1"

    /// A fired suggestion waiting to be shown. Persisted because the
    /// popover is almost always *closed* at capture time — a live-only
    /// notification would be missed, so the banner also drains this
    /// queue whenever the popover next opens.
    struct PendingSuggestion: Codable, Identifiable {
        var id: String { skeleton }
        let skeleton: String
        let samples: [String]
    }

    private var pending: [PendingSuggestion] = []
    private let pendingKey = "templateDetectorPending.v1"

    /// Skeletons the user dismissed, suppressed until the given date. A
    /// dismissed pattern shouldn't nag again for a while — but if it keeps
    /// recurring after the cooldown, we may offer it once more.
    private var suppressed: [String: Date] = [:]
    private let suppressedKey = "templateDetectorSuppressed.v1"
    private let suppressDays = 7

    /// The oldest suggestion the UI hasn't dealt with yet, if any.
    var nextPending: PendingSuggestion? { pending.first }

    // MARK: Public entry

    /// Feed a freshly-captured text item. Cheap and synchronous; safe to
    /// call on the capture path. Fires `.clippyTemplateCandidateDetected`
    /// at most once per skeleton.
    func observe(_ text: String, isCode: Bool) {
        guard SettingsManager.shared.enableTemplateDetection else { return }
        guard !isCode else { return }

        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= minLength, trimmed.count <= maxLength else { return }

        let skeleton = Self.skeletonize(trimmed)
        guard fixedCharCount(skeleton) >= minFixedChars else { return }

        let key = Self.hash(skeleton)
        let now = Date()

        var record = store[key] ?? Record(timestamps: [], skeleton: skeleton, samples: [], fired: false)
        record.timestamps.append(now)
        record.timestamps = prune(record.timestamps, now: now)
        // Keep a few distinct raw samples for the AI to learn the shape.
        if !record.samples.contains(trimmed) {
            record.samples.insert(trimmed, at: 0)
            if record.samples.count > 5 { record.samples.removeLast() }
        }

        if !record.fired && record.timestamps.count >= threshold && !isSuppressed(key, now: now) {
            record.fired = true
            store[key] = record
            // Queue it so the banner can pick it up even if nothing is
            // listening right now (popover closed).
            if !pending.contains(where: { $0.skeleton == record.skeleton }) {
                pending.append(PendingSuggestion(skeleton: record.skeleton, samples: record.samples))
                if pending.count > 5 { pending.removeFirst(pending.count - 5) }
                savePending()
            }
            save()
            NotificationCenter.default.post(
                name: .clippyTemplateCandidateDetected,
                object: nil,
                userInfo: ["skeleton": record.skeleton, "samples": record.samples]
            )
            return
        }

        store[key] = record
        pruneStore(now: now)
        save()
    }

    /// Remove a suggestion from the pending queue without wiping the
    /// pattern's history. Used when the user *engages* (opens the review
    /// sheet): the banner should stop showing immediately, but because
    /// the record keeps `fired == true` it also won't re-queue later.
    func dismissPending(skeleton: String) {
        pending.removeAll { $0.skeleton == skeleton }
        savePending()
    }

    /// User dismissed the banner (the ✕). Pull it from the queue and
    /// suppress this pattern for a cooldown so it stops nagging — but let
    /// its occurrence count keep building, so if it's still recurring
    /// after the cooldown we can offer it once more.
    func snooze(skeleton: String) {
        let key = Self.hash(skeleton)
        pending.removeAll { $0.skeleton == skeleton }
        suppressed[key] = Date().addingTimeInterval(Double(suppressDays) * 86_400)
        // Allow a future re-fire once the cooldown lapses.
        if var record = store[key] { record.fired = false; store[key] = record }
        savePending()
        saveSuppressed()
        save()
    }

    private func isSuppressed(_ key: String, now: Date) -> Bool {
        guard let until = suppressed[key] else { return false }
        if now >= until {
            suppressed.removeValue(forKey: key)   // cooldown lapsed
            saveSuppressed()
            return false
        }
        return true
    }

    /// Forget a skeleton entirely (e.g. after a template is made) so it
    /// doesn't nag again.
    func forget(skeleton: String) {
        let key = Self.hash(skeleton)
        store.removeValue(forKey: key)
        pending.removeAll { $0.skeleton == skeleton }
        suppressed.removeValue(forKey: key)
        savePending()
        saveSuppressed()
        save()
    }

    // MARK: Normalization

    private static let detector: NSDataDetector? = {
        let types: NSTextCheckingResult.CheckingType = [.date, .link, .phoneNumber, .address]
        return try? NSDataDetector(types: types.rawValue)
    }()

    /// Reduce text to its structural skeleton by masking the parts that
    /// tend to vary between copies.
    static func skeletonize(_ text: String) -> String {
        var s = text

        // Data-detector passes first (dates, links, phones, addresses) —
        // replace from the end so ranges stay valid.
        if let detector = detector {
            let ns = s as NSString
            let matches = detector.matches(in: s, range: NSRange(location: 0, length: ns.length))
            let mutable = ns.mutableCopy() as! NSMutableString
            for match in matches.reversed() {
                let token: String
                switch match.resultType {
                case .date:        token = "⟨date⟩"
                case .link:        token = "⟨link⟩"
                case .phoneNumber: token = "⟨phone⟩"
                case .address:     token = "⟨addr⟩"
                default:           token = "⟨x⟩"
                }
                mutable.replaceCharacters(in: match.range, with: token)
            }
            s = mutable as String
        }

        // Regex passes for the bits data detectors miss.
        s = replace(s, pattern: "[\\w.+-]+@[\\w-]+\\.[\\w.-]+", with: "⟨email⟩")           // emails
        s = replace(s, pattern: "[$€£₺¥]\\s?\\d[\\d.,]*", with: "⟨money⟩")                 // currency
        s = replace(s, pattern: "\\d{1,2}:\\d{2}(?::\\d{2})?\\s?(?:[AaPp][Mm])?", with: "⟨time⟩") // times
        s = replace(s, pattern: "#?\\d[\\d.,/-]*", with: "⟨num⟩")                          // numbers / ids
        s = replace(s, pattern: "⟨num⟩(?:\\s*⟨num⟩)+", with: "⟨num⟩")                       // collapse runs
        s = replace(s, pattern: "\\s+", with: " ")                                          // whitespace

        return s.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private static func replace(_ text: String, pattern: String, with token: String) -> String {
        guard let re = try? NSRegularExpression(pattern: pattern) else { return text }
        let range = NSRange(text.startIndex..., in: text)
        return re.stringByReplacingMatches(in: text, range: range, withTemplate: token)
    }

    private static func hash(_ s: String) -> String {
        let digest = SHA256.hash(data: Data(s.utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    /// Count of characters that are neither placeholder tokens nor spaces
    /// — the "fixed" signal that makes a skeleton specific.
    private func fixedCharCount(_ skeleton: String) -> Int {
        let stripped = Self.replace(skeleton, pattern: "⟨[a-z]+⟩", with: "")
        return stripped.filter { !$0.isWhitespace }.count
    }

    // MARK: Pruning + persistence

    private func prune(_ timestamps: [Date], now: Date) -> [Date] {
        let cutoff = now.addingTimeInterval(-Double(windowDays) * 86_400)
        return timestamps.filter { $0 >= cutoff }
    }

    private func pruneStore(now: Date) {
        // Drop records whose occurrences all aged out.
        for (key, var record) in store {
            record.timestamps = prune(record.timestamps, now: now)
            if record.timestamps.isEmpty {
                store.removeValue(forKey: key)
            } else {
                store[key] = record
            }
        }
        // Hard cap: keep the most-recently-active records.
        if store.count > maxRecords {
            let keep = store.sorted { ($0.value.timestamps.last ?? .distantPast) > ($1.value.timestamps.last ?? .distantPast) }
                .prefix(maxRecords)
            store = Dictionary(uniqueKeysWithValues: keep.map { ($0.key, $0.value) })
        }
    }

    private func load() {
        if let data = UserDefaults.standard.data(forKey: storeKey),
           let decoded = try? JSONDecoder().decode([String: Record].self, from: data) {
            store = decoded
        }
        if let data = UserDefaults.standard.data(forKey: pendingKey),
           let decoded = try? JSONDecoder().decode([PendingSuggestion].self, from: data) {
            pending = decoded
        }
        if let data = UserDefaults.standard.data(forKey: suppressedKey),
           let decoded = try? JSONDecoder().decode([String: Date].self, from: data) {
            suppressed = decoded
        }
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(store) else { return }
        UserDefaults.standard.set(data, forKey: storeKey)
    }

    private func savePending() {
        guard let data = try? JSONEncoder().encode(pending) else { return }
        UserDefaults.standard.set(data, forKey: pendingKey)
    }

    private func saveSuppressed() {
        guard let data = try? JSONEncoder().encode(suppressed) else { return }
        UserDefaults.standard.set(data, forKey: suppressedKey)
    }
}
