//
//  VisionOCR.swift
//  Clippy
//
//  Shared Vision text-recognition utility used by both the auto-OCR
//  pipeline (ClipboardMonitor) and the screen-text grabber (⇧⌘2).
//  One implementation, one language-ordering strategy — no drift
//  between the two call sites.
//

import Foundation
import Vision
import CoreGraphics

enum VisionOCR {

    /// Single Vision text-recognition pass. Returns the joined
    /// extracted text, or an empty string on any failure (no
    /// observations, Vision error). Caller decides what an empty
    /// result means.
    static func recognizeText(in cgImage: CGImage, primaryHint: String) -> String {
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.recognitionLanguages = curatedLanguageList(primaryHint: primaryHint)
        do {
            try VNImageRequestHandler(cgImage: cgImage, options: [:]).perform([request])
        } catch {
            return ""
        }
        guard let observations = request.results, !observations.isEmpty else { return "" }
        return observations
            .compactMap { $0.topCandidates(1).first?.string }
            .joined(separator: "\n")
    }

    /// Detects the first QR / barcode in the image and returns its
    /// string payload. Lets the screen grabber copy WiFi passwords,
    /// links, and ticket codes straight off any QR on screen.
    static func detectBarcodePayload(in cgImage: CGImage) -> String? {
        let request = VNDetectBarcodesRequest()
        do {
            try VNImageRequestHandler(cgImage: cgImage, options: [:]).perform([request])
        } catch {
            return nil
        }
        return request.results?
            .compactMap { $0.payloadStringValue }
            .first(where: { !$0.isEmpty })
    }

    /// Returns every Vision-supported language on this Mac, ordered
    /// for accurate recognition. Vision biases toward languages
    /// earlier in the list — feeding it `Set`-derived random order
    /// caused 0 observations for CJK screenshots even when the right
    /// language was somewhere in the list.
    ///
    /// Order:
    ///   1. Script-distinct (CJK, Arabic, Cyrillic, Thai) — these
    ///      can't be confused with Latin scripts, so leading with
    ///      them costs nothing for Latin captures but gives non-Latin
    ///      ones a real chance to match.
    ///   2. The user's primary language + English fallback.
    ///   3. Major Western Latin languages by speaker count.
    ///   4. Everything else Vision lists, alphabetically.
    static func curatedLanguageList(primaryHint: String) -> [String] {
        let supported: Set<String> = {
            let req = VNRecognizeTextRequest()
            req.recognitionLevel = .accurate
            return Set((try? req.supportedRecognitionLanguages()) ?? ["en-US"])
        }()

        let scriptDistinctOrder = [
            "ja-JP", "ko-KR", "zh-Hans", "zh-Hant",
            "ar-SA", "ru-RU", "uk-UA", "th-TH"
        ]
        let primaryBCP47: String? = {
            switch primaryHint.lowercased() {
            case "tr": return "tr-TR"
            case "de": return "de-DE"
            case "fr": return "fr-FR"
            case "es": return "es-ES"
            case "it": return "it-IT"
            case "pt": return "pt-BR"
            case "nl": return "nl-NL"
            case "pl": return "pl-PL"
            case "ja": return "ja-JP"
            case "ko": return "ko-KR"
            case "zh": return "zh-Hans"
            case "ar": return "ar-SA"
            case "ru": return "ru-RU"
            default:   return nil
            }
        }()
        let primaryOrder = [primaryBCP47, "en-US"].compactMap { $0 }
        let latinPriorityOrder = [
            "fr-FR", "de-DE", "es-ES", "it-IT", "pt-BR", "nl-NL", "pl-PL"
        ]

        var result: [String] = []
        var seen = Set<String>()
        for lang in scriptDistinctOrder + primaryOrder + latinPriorityOrder {
            guard supported.contains(lang), seen.insert(lang).inserted else { continue }
            result.append(lang)
        }
        let remaining = supported.subtracting(seen).sorted()
        result.append(contentsOf: remaining)
        return result.isEmpty ? ["en-US"] : result
    }
}
