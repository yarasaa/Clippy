//
//  SupportedOCRLanguage.swift
//  Clippy
//
//  Display metadata for the languages Clippy can show as flag
//  badges. We pin a hand-curated list (14 entries) rather than
//  iterating every NLLanguage case so each flag + native display
//  name is correct and there are no "?? flag" gaps.
//

import Foundation

enum SupportedOCRLanguage: String, CaseIterable, Identifiable {
    case english = "en"
    case turkish = "tr"
    case german = "de"
    case french = "fr"
    case spanish = "es"
    case italian = "it"
    case portuguese = "pt"
    case dutch = "nl"
    case polish = "pl"
    case russian = "ru"
    case ukrainian = "uk"
    case chinese = "zh"
    case japanese = "ja"
    case korean = "ko"
    case arabic = "ar"

    var id: String { rawValue }

    var flag: String {
        switch self {
        case .english:    return "🇺🇸"
        case .turkish:    return "🇹🇷"
        case .german:     return "🇩🇪"
        case .french:     return "🇫🇷"
        case .spanish:    return "🇪🇸"
        case .italian:    return "🇮🇹"
        case .portuguese: return "🇧🇷"
        case .dutch:      return "🇳🇱"
        case .polish:     return "🇵🇱"
        case .russian:    return "🇷🇺"
        case .ukrainian:  return "🇺🇦"
        case .chinese:    return "🇨🇳"
        case .japanese:   return "🇯🇵"
        case .korean:     return "🇰🇷"
        case .arabic:     return "🇸🇦"
        }
    }

    var displayName: String {
        switch self {
        case .english:    return "English"
        case .turkish:    return "Türkçe"
        case .german:     return "Deutsch"
        case .french:     return "Français"
        case .spanish:    return "Español"
        case .italian:    return "Italiano"
        case .portuguese: return "Português"
        case .dutch:      return "Nederlands"
        case .polish:     return "Polski"
        case .russian:    return "Русский"
        case .ukrainian:  return "Українська"
        case .chinese:    return "中文"
        case .japanese:   return "日本語"
        case .korean:     return "한국어"
        case .arabic:     return "العربية"
        }
    }

    /// Look up the flag for a short language code ("tr", "en", "ja")
    /// — the format NLLanguageRecognizer returns. Falls back to nil
    /// so the UI can decide to hide the badge entirely rather than
    /// render a placeholder.
    static func flag(forCode code: String) -> String? {
        return SupportedOCRLanguage(rawValue: code.lowercased())?.flag
    }

    static func displayName(forCode code: String) -> String? {
        return SupportedOCRLanguage(rawValue: code.lowercased())?.displayName
    }
}
