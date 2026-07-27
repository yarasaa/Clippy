//
//  ValueExtractor.swift
//  Clippy
//
//  When the question targets a concrete datum — "what was that phone
//  number?", "the email I copied", "o adres neydi" — we don't want to
//  trust a small language model to transcribe digits correctly. Instead
//  we pull the literal value straight out of the top candidate with
//  NSDataDetector / a regex and show it verbatim above the prose answer.
//  Deterministic, exact, model-independent.
//

import Foundation

struct ExtractedValue: Equatable {
    let icon: String   // SF Symbol
    let label: String
    let value: String
    /// 1-based position of the item the value came from, matching the
    /// `[n]` numbering the answer uses. Without this the deterministic
    /// answer always cited `[1]`, pointing at the wrong card whenever the
    /// value lived anywhere but the top hit.
    let sourceIndex: Int
}

@MainActor
enum ValueExtractor {

    static func extract(for query: AskQuery, from items: [ClipboardItemEntity]) -> ExtractedValue? {
        guard let kind = desiredKind(for: query) else { return nil }

        for (offset, item) in items.prefix(5).enumerated() {
            let text = (item.contentType == "image" ? item.extractedText : item.content) ?? ""
            guard !text.isEmpty else { continue }
            if let value = firstMatch(kind: kind, in: text) {
                return ExtractedValue(icon: kind.icon,
                                      label: kind.label,
                                      value: value,
                                      sourceIndex: offset + 1)
            }
        }
        return nil
    }

    // MARK: Kind

    private enum Kind {
        case phone, email, address, link

        var icon: String {
            switch self {
            case .phone:   return "phone.fill"
            case .email:   return "envelope.fill"
            case .address: return "mappin.circle.fill"
            case .link:    return "link"
            }
        }
        var label: String {
            switch self {
            case .phone:   return "Phone"
            case .email:   return "Email"
            case .address: return "Address"
            case .link:    return "Link"
            }
        }
    }

    private static func desiredKind(for query: AskQuery) -> Kind? {
        let kws = query.keywords.map { $0.lowercased() }
        func has(_ needles: [String]) -> Bool {
            kws.contains { k in needles.contains { k.contains($0) } }
        }
        if has(["phone", "telefon", "numara", "number", "tel"]) { return .phone }
        if has(["email", "e-posta", "eposta", "mail"])          { return .email }
        if has(["address", "adres", "konum"])                    { return .address }
        if query.type == .link || has(["link", "url", "site", "website", "bağlant"]) { return .link }
        return nil
    }

    // MARK: Matching

    /// Goes through the same detector the cards use.
    ///
    /// This used to call NSDataDetector directly with no validation, so
    /// asking "what was that phone number" could come back with an order
    /// number or a line of code — the exact false positives OCRLinkDetector
    /// already filters out. One detector, one set of rules, one place to
    /// fix the next bad match.
    private static func firstMatch(kind: Kind, in text: String) -> String? {
        let links = OCRLinkDetector.detect(in: text)
        switch kind {
        case .email:   return links.emails.first
        case .phone:   return links.phoneNumbers.first
        case .address: return links.addresses.first
        case .link:    return links.urls.first?.absoluteString
        }
    }
}
