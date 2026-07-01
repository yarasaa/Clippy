//
//  SensitiveDataDetector.swift
//  Clippy
//
//  Pattern-based scan for sensitive data in OCR-extracted text:
//  credit card numbers, IBANs, API keys, Turkish national IDs.
//  Powers the "🔒 Encrypt this?" suggestion that appears on image
//  cards whose OCR turned up something the user probably shouldn't
//  leave in plain clipboard history.
//
//  Conservative by design: we'd rather miss a match than show false
//  "this looks like a credit card" prompts on every receipt or
//  product code. Each detector uses both a syntactic pattern AND a
//  validation step (Luhn for cards, IBAN checksum, etc.) so the
//  signal-to-noise stays high.
//

import Foundation

struct SensitiveHit: Equatable, Hashable {
    enum Kind: String {
        case creditCard
        case iban
        case apiKey
        case tcKimlik   // Turkish national identification number

        var displayLabel: String {
            switch self {
            case .creditCard: return "Credit card"
            case .iban:       return "IBAN"
            case .apiKey:     return "API key"
            case .tcKimlik:   return "TC kimlik"
            }
        }

        var iconName: String {
            switch self {
            case .creditCard: return "creditcard"
            case .iban:       return "building.columns"
            case .apiKey:     return "key"
            case .tcKimlik:   return "person.text.rectangle"
            }
        }
    }
    let kind: Kind
    let snippet: String
}

enum SensitiveDataDetector {
    static func scan(_ text: String) -> [SensitiveHit] {
        guard !text.isEmpty else { return [] }

        var hits: [SensitiveHit] = []
        var seen = Set<String>()

        // Credit cards: 13-19 digits, optionally with spaces or
        // dashes between groups of 4. Validated with Luhn so random
        // long numbers don't false-positive (order numbers, IMEIs).
        for snippet in matches(of: #"(?<!\d)(?:\d[ -]?){13,19}(?!\d)"#, in: text) {
            let digits = snippet.filter(\.isNumber)
            if (13...19).contains(digits.count), luhnValid(digits),
               seen.insert("cc:\(digits)").inserted {
                hits.append(SensitiveHit(kind: .creditCard, snippet: snippet))
            }
        }

        // IBANs: 2 letters + 2 digits + up to 30 alphanumerics.
        // Validated with the mod-97 checksum so "AB12CDEF..." junk
        // doesn't match.
        for snippet in matches(of: #"\b[A-Z]{2}\d{2}[A-Z0-9 ]{10,40}\b"#, in: text) {
            let normalized = snippet.replacingOccurrences(of: " ", with: "").uppercased()
            if ibanValid(normalized), seen.insert("iban:\(normalized)").inserted {
                hits.append(SensitiveHit(kind: .iban, snippet: snippet))
            }
        }

        // TC kimlik: 11 digits with a documented checksum. Pattern-
        // only matching would false-positive on any 11-digit number;
        // the checksum is what makes this reliable.
        for snippet in matches(of: #"(?<!\d)\d{11}(?!\d)"#, in: text) {
            if tcKimlikValid(snippet), seen.insert("tc:\(snippet)").inserted {
                hits.append(SensitiveHit(kind: .tcKimlik, snippet: snippet))
            }
        }

        // API keys / tokens. Two complementary patterns:
        //   - well-known prefixes (sk-, pk-, ghp_, AIza, AKIA, xoxb-)
        //   - key=value style assignments
        // The consequence of a false positive here is mild (an
        // unnecessary encrypt prompt), so the patterns are looser.
        for snippet in matches(of: #"\b(?:sk|pk|ghp|ghs|AIza|AKIA|xox[bp])[-_][A-Za-z0-9_-]{20,}\b"#, in: text) {
            if seen.insert("key:\(snippet)").inserted {
                hits.append(SensitiveHit(kind: .apiKey, snippet: snippet))
            }
        }
        for snippet in matches(of: #"(?i)\b(?:api[_-]?key|secret|token|password)\s*[:=]\s*['\"]?[A-Za-z0-9_+/=-]{20,}['\"]?"#, in: text) {
            if seen.insert("kvkey:\(snippet)").inserted {
                hits.append(SensitiveHit(kind: .apiKey, snippet: snippet))
            }
        }

        return hits
    }

    // MARK: - Regex helper

    private static func matches(of pattern: String, in text: String) -> [String] {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        let range = NSRange(text.startIndex..., in: text)
        return regex.matches(in: text, range: range).compactMap { match in
            guard let r = Range(match.range, in: text) else { return nil }
            return String(text[r])
        }
    }

    // MARK: - Validators

    /// Standard Luhn check for credit-card numbers.
    private static func luhnValid(_ digitsOnly: String) -> Bool {
        let digits = digitsOnly.reversed().compactMap { Int(String($0)) }
        guard digits.count == digitsOnly.count else { return false }
        var sum = 0
        for (i, d) in digits.enumerated() {
            if i % 2 == 1 {
                let doubled = d * 2
                sum += doubled > 9 ? doubled - 9 : doubled
            } else {
                sum += d
            }
        }
        return sum % 10 == 0
    }

    /// IBAN mod-97 checksum (ISO 13616). Moves first 4 chars to the
    /// end, converts letters to digits (A=10, B=11, …), the whole
    /// thing must be ≡ 1 (mod 97).
    private static func ibanValid(_ iban: String) -> Bool {
        guard iban.count >= 15, iban.count <= 34 else { return false }
        let rearranged = String(iban.dropFirst(4)) + String(iban.prefix(4))
        var numericString = ""
        for ch in rearranged {
            if ch.isLetter {
                guard let ascii = ch.asciiValue else { return false }
                numericString += String(Int(ascii) - 55) // A=10
            } else if ch.isNumber {
                numericString.append(ch)
            } else {
                return false
            }
        }
        // Streaming mod-97 — the assembled int can overflow Int64.
        var remainder = 0
        for ch in numericString {
            guard let d = ch.wholeNumberValue else { return false }
            remainder = (remainder * 10 + d) % 97
        }
        return remainder == 1
    }

    /// Documented Turkish national ID validation: 11 digits, first
    /// can't be 0, plus two checksum rules on digits 10 and 11.
    private static func tcKimlikValid(_ id: String) -> Bool {
        let digits = id.compactMap { Int(String($0)) }
        guard digits.count == 11, digits[0] != 0 else { return false }
        let oddSum = digits[0] + digits[2] + digits[4] + digits[6] + digits[8]
        let evenSum = digits[1] + digits[3] + digits[5] + digits[7]
        let check10 = ((oddSum * 7) - evenSum) % 10
        let check11 = (digits[0...9].reduce(0, +)) % 10
        return check10 == digits[9] && check11 == digits[10]
    }
}
