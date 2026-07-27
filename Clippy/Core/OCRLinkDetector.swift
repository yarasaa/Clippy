//
//  OCRLinkDetector.swift
//  Clippy
//
//  Scans OCR-extracted text (or any string) for actionable content:
//  phone numbers, email addresses, URLs, postal addresses. Powers the
//  tappable badges that appear on image cards after auto-OCR completes
//  — turning a screenshot into a one-tap launchpad for the things it
//  contains ("call this number", "open this URL", "show on Maps").
//
//  Uses NSDataDetector which is on-device, fast (sub-millisecond for
//  typical OCR output), and battle-tested by macOS Mail / Messages.
//

import Foundation

struct OCRLinks: Equatable {
    var phoneNumbers: [String] = []
    var emails: [String] = []
    var urls: [URL] = []
    var addresses: [String] = []
    /// Detected dates / times — pairs the displayed snippet
    /// (what was matched in the OCR) with the parsed Date and the
    /// event's duration. Snippet drives UI; (date, duration) drive
    /// the .ics generator that opens Calendar.app.
    var dates: [DateMatch] = []
    /// Possibly-sensitive matches (credit cards, IBANs, API keys,
    /// TC kimlik). Each is checksum-validated so badges don't
    /// false-fire on random long numbers.
    var sensitiveHits: [SensitiveHit] = []

    var isEmpty: Bool {
        phoneNumbers.isEmpty && emails.isEmpty && urls.isEmpty &&
        addresses.isEmpty && dates.isEmpty && sensitiveHits.isEmpty
    }

    static func == (lhs: OCRLinks, rhs: OCRLinks) -> Bool {
        lhs.phoneNumbers == rhs.phoneNumbers &&
        lhs.emails == rhs.emails &&
        lhs.urls == rhs.urls &&
        lhs.addresses == rhs.addresses &&
        lhs.dates.map(\.snippet) == rhs.dates.map(\.snippet) &&
        lhs.sensitiveHits == rhs.sensitiveHits
    }
}

struct DateMatch: Hashable {
    let snippet: String
    let date: Date
    let duration: TimeInterval
}

enum OCRLinkDetector {
    /// Cached detector — initializing NSDataDetector is non-trivial
    /// and the type set never changes, so we only pay it once.
    private static let detector: NSDataDetector? = {
        let types: NSTextCheckingResult.CheckingType = [.link, .phoneNumber, .address, .date]
        return try? NSDataDetector(types: types.rawValue)
    }()

    /// Extract all actionable items from a string. Returns
    /// deduplicated lists in document order. Empty `OCRLinks` if
    /// nothing is found or the input is empty.
    /// - Parameter isCode: when true, dates and addresses are skipped.
    ///   Source code is full of words the date parser treats as times —
    ///   `let today = Date()` reads as today's date, `deadline: Friday` in
    ///   a comment as next Friday — and a calendar badge on a code snippet
    ///   is noise regardless. Links and emails still count: a URL in a
    ///   comment is worth surfacing.
    static func detect(in text: String, isCode: Bool = false) -> OCRLinks {
        guard !text.isEmpty, let detector else { return OCRLinks() }

        var result = OCRLinks()
        var seenPhones = Set<String>()
        var seenEmails = Set<String>()
        var seenURLs = Set<String>()
        var seenAddresses = Set<String>()

        let range = NSRange(text.startIndex..., in: text)
        let matches = detector.matches(in: text, options: [], range: range)

        for match in matches {
            switch match.resultType {
            case .phoneNumber:
                if let phone = match.phoneNumber,
                   isPlausiblePhone(match: match, in: text) {
                    let normalized = normalizePhone(phone)
                    if seenPhones.insert(normalized).inserted {
                        result.phoneNumbers.append(phone)
                    }
                }

            case .link:
                guard let url = match.url else { break }
                // NSDataDetector classifies emails as `link` with a
                // `mailto:` scheme. Split them so the UI can show
                // distinct "email" vs "URL" badges.
                if url.scheme == "mailto" {
                    let address = url.absoluteString.replacingOccurrences(of: "mailto:", with: "")
                    if seenEmails.insert(address.lowercased()).inserted {
                        result.emails.append(address)
                    }
                } else {
                    let key = url.absoluteString.lowercased()
                    if seenURLs.insert(key).inserted {
                        result.urls.append(url)
                    }
                }

            case .address:
                // Skipped for code — see `isCode`.
                guard !isCode else { break }
                // NSDataDetector returns components in a dictionary;
                // we keep the matched substring so the user sees what
                // was actually written in the screenshot.
                if let range = Range(match.range, in: text) {
                    let snippet = String(text[range])
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                    if !snippet.isEmpty,
                       seenAddresses.insert(snippet.lowercased()).inserted {
                        result.addresses.append(snippet)
                    }
                }

            case .date:
                // Date matches need post-processing (merge step
                // below), so collect raw matches first.
                break

            default:
                break
            }
        }

        // Date post-processing: NSDataDetector splits "15 Temmuz
        // 2026 Salı, 14:30" into two matches when the Turkish day
        // name interrupts. Re-collect raw matches with range info
        // and merge a date-only + adjacent time-only pair into a
        // single combined event.
        result.dates = isCode ? [] : collectAndMergeDateMatches(text: text, matches: matches)

        // Sensitive patterns run on the same text afterward so we
        // have a single OCRLinks struct for all badge types.
        result.sensitiveHits = SensitiveDataDetector.scan(text)

        // Anything that passed a real checksum — a TC kimlik number, a
        // Luhn-valid card, an IBAN — is definitively that thing, and
        // therefore definitively not a phone number. Those algorithms are
        // exact, so they outrank the phone heuristic rather than competing
        // with it: an 11-digit TC kimlik was being offered as a number to
        // call.
        if !result.sensitiveHits.isEmpty {
            let sensitiveDigits = Set(result.sensitiveHits.map { $0.snippet.filter(\.isNumber) })
            result.phoneNumbers.removeAll { phone in
                sensitiveDigits.contains(phone.filter(\.isNumber))
            }
        }

        return result
    }

    private static func collectAndMergeDateMatches(text: String,
                                                   matches: [NSTextCheckingResult]) -> [DateMatch] {
        struct RawMatch {
            let date: Date
            let duration: TimeInterval
            let range: NSRange
            let snippet: String
        }
        var raw: [RawMatch] = []
        for match in matches where match.resultType == .date {
            guard let d = match.date, let r = Range(match.range, in: text) else { continue }
            raw.append(RawMatch(
                date: d,
                duration: match.duration,
                range: match.range,
                snippet: String(text[r]).trimmingCharacters(in: .whitespacesAndNewlines)
            ))
        }

        let cal = Calendar.current
        var merged: [DateMatch] = []
        var i = 0
        while i < raw.count {
            let current = raw[i]
            // Look ahead one slot — date-only followed by a nearby
            // time-only is the only merge case we handle.
            if i + 1 < raw.count {
                let next = raw[i + 1]
                let gap = next.range.location - (current.range.location + current.range.length)
                if gap >= 0, gap <= 15,
                   isDateOnly(current.date, calendar: cal),
                   isTimeOnly(next.date, calendar: cal) {
                    let timeComps = cal.dateComponents([.hour, .minute, .second], from: next.date)
                    if let combined = cal.date(bySettingHour: timeComps.hour ?? 0,
                                               minute: timeComps.minute ?? 0,
                                               second: timeComps.second ?? 0,
                                               of: current.date) {
                        merged.append(DateMatch(
                            snippet: current.snippet + " " + next.snippet,
                            date: combined,
                            duration: 3600
                        ))
                        i += 2
                        continue
                    }
                }
            }
            merged.append(DateMatch(
                snippet: current.snippet,
                date: current.date,
                duration: current.duration > 0 ? current.duration : 3600
            ))
            i += 1
        }
        return merged
    }

    /// True when a NSDataDetector-produced Date has zeroed-out time
    /// components — the "tarih bölümü" of a split match.
    private static func isDateOnly(_ date: Date, calendar: Calendar) -> Bool {
        let comps = calendar.dateComponents([.hour, .minute, .second], from: date)
        return (comps.hour ?? 0) == 0 && (comps.minute ?? 0) == 0 && (comps.second ?? 0) == 0
    }

    /// True when a NSDataDetector-produced Date falls on TODAY —
    /// which is how it represents a bare "14:30" with no date context.
    private static func isTimeOnly(_ date: Date, calendar: Calendar) -> Bool {
        return calendar.isDate(date, inSameDayAs: Date())
    }

    /// Strip everything except digits and a leading + so two
    /// formattings of the same number ("(555) 123-4567" vs
    /// "+1 555-123-4567") don't both appear as separate badges.
    /// Words that, sitting just before a number, say it isn't a phone.
    private static let nonPhoneContext = [
        "sku", "order", "sipariş", "siparis", "invoice", "fatura",
        "seri", "serial", "tracking", "takip", "ref", "id:", "no:", "nr:",
        "code", "kod", "version", "versiyon", "port", "line", "satır", "satir",
        "isbn", "iban", "account", "hesap", "card", "kart", "pin", "otp"
    ]

    /// Second opinion on NSDataDetector's phone matches.
    ///
    /// The detector is reliable at *rejecting* version numbers, dates, IP
    /// addresses and UUIDs, but it happily reports any bare run of digits:
    /// order numbers, SKUs, card numbers and even `let x = 100000000` all
    /// came back as phone numbers. Three cheap checks remove those without
    /// costing a single real number:
    ///
    ///   1. Digit count outside 7…15 isn't a phone (E.164 caps at 15), and
    ///      exactly 16 is card-shaped — that belongs to the sensitive-data
    ///      path, not here.
    ///   2. A disqualifying word immediately before it ("SKU", "sipariş
    ///      no", "takip") means the number was already labelled as
    ///      something else.
    ///   3. With no phone-ish punctuation at all — no `+`, no parentheses,
    ///      no leading trunk `0`, no separators — a digit blob is just a
    ///      number.
    private static func isPlausiblePhone(match: NSTextCheckingResult, in text: String) -> Bool {
        let ns = text as NSString
        guard match.range.location != NSNotFound,
              NSMaxRange(match.range) <= ns.length else { return false }

        let matched = ns.substring(with: match.range)
        let digitCount = matched.filter(\.isNumber).count
        guard (7...15).contains(digitCount) else { return false }

        let contextStart = max(0, match.range.location - 16)
        let context = ns.substring(
            with: NSRange(location: contextStart, length: match.range.location - contextStart)
        ).lowercased()
        if nonPhoneContext.contains(where: { context.contains($0) }) { return false }

        let trimmed = matched.trimmingCharacters(in: .whitespaces)
        if trimmed.hasPrefix("+") || trimmed.contains("(") || trimmed.hasPrefix("0") {
            return true
        }
        return matched.contains(" ") || matched.contains("-") || matched.contains(".")
    }

    private static func normalizePhone(_ raw: String) -> String {
        var result = ""
        for (i, ch) in raw.enumerated() {
            if i == 0, ch == "+" { result.append(ch); continue }
            if ch.isNumber { result.append(ch) }
        }
        return result
    }
}
