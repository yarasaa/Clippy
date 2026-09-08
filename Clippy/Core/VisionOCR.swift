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

/// One recognised line, with where it sits.
///
/// `boundingBox` is Vision's own: normalised 0…1, **bottom-left origin**.
/// It is kept in that form deliberately rather than converted on the way
/// out — the useful target differs per caller (image points for the
/// editor's annotations, pixels for anything sampling the bitmap), and
/// baking one in is how a conversion ends up silently wrong somewhere
/// else. Use `rect(in:)` and say which space you want.
struct RecognizedTextBox {
    let text: String
    let boundingBox: CGRect
    let confidence: Float

    /// Convert to a top-left-origin rect in whatever space `size` describes.
    ///
    /// Pass `image.size` for image points, or the bitmap's pixel dimensions
    /// for pixels — but pass the one you actually mean. Mixing the two is
    /// exactly what put the eyedropper's samples nowhere near the cursor:
    /// `NSBitmapImageRep(cgImage:)` reports its size in pixels while
    /// `NSImage.size` is in points, and on a Retina capture those differ by
    /// a factor of two.
    func rect(in size: CGSize) -> CGRect {
        CGRect(
            x: boundingBox.minX * size.width,
            y: (1 - boundingBox.maxY) * size.height,   // Vision counts up; we count down
            width: boundingBox.width * size.width,
            height: boundingBox.height * size.height
        )
    }
}

enum VisionOCR {

    /// Single Vision text-recognition pass. Returns the joined
    /// extracted text, or an empty string on any failure (no
    /// observations, Vision error). Caller decides what an empty
    /// result means.
    static func recognizeText(in cgImage: CGImage, primaryHint: String) -> String {
        recognizeTextBoxes(in: cgImage, primaryHint: primaryHint)
            .map(\.text)
            .joined(separator: "\n")
    }

    /// The same pass, keeping where each line was found.
    ///
    /// The observations always carried this; the text-only path threw it
    /// away. Holding on to it is what lets the editor propose a redaction
    /// over the right words, or snap a highlight to a block of text,
    /// without running Vision a second time.
    ///
    /// Order is Vision's own, left untouched: `recognizeText` is built on
    /// this, and re-sorting here would quietly change the stored OCR text
    /// that search, titles and the Ask engine all read.
    static func recognizeTextBoxes(in cgImage: CGImage, primaryHint: String) -> [RecognizedTextBox] {
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        // Let Vision pick the language rather than ranking them ourselves.
        //
        // Measured both ways: identical on single-language captures (98
        // percent across eight languages, short snippets included), and
        // clearly better on mixed content — 97 against 85 — where it was
        // also the only setting that returned the Japanese line at all when
        // four languages shared one image.
        //
        // The curated ordering below stays as the fallback. It is what fixed
        // the original fault, and it still matters wherever automatic
        // detection isn't available.
        if #available(macOS 13.0, *) {
            request.automaticallyDetectsLanguage = true
        } else {
            request.recognitionLanguages = curatedLanguageList(primaryHint: primaryHint)
        }
        do {
            try VNImageRequestHandler(cgImage: cgImage, options: [:]).perform([request])
        } catch {
            return []
        }
        guard let observations = request.results, !observations.isEmpty else { return [] }
        return observations.compactMap { observation in
            guard let candidate = observation.topCandidates(1).first else { return nil }
            return RecognizedTextBox(
                text: candidate.string,
                boundingBox: observation.boundingBox,
                confidence: candidate.confidence
            )
        }
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

    /// Vision languages for this Mac, ordered so the ones the user actually
    /// reads come first.
    ///
    /// Order matters more than anything else here. Vision biases hard toward
    /// languages early in the list, and this used to lead with the
    /// script-distinct block (CJK, Arabic, Cyrillic) on the theory that it
    /// "costs nothing for Latin captures". Measured against Turkish text, it
    /// cost plenty: 75% of characters correct, with `ç` coming back as `s`,
    /// `ı` as `l`, and commas as the full-width CJK `，`. Putting the user's
    /// own languages first took the same image to 100%.
    ///
    /// So: what the user reads, then English, then everything else. A Turkish
    /// user gets `tr-TR` first; a Japanese user gets `ja-JP` first, because
    /// that is what their system reports — the script-distinct block never
    /// needed to be hardcoded ahead of everyone.
    static func curatedLanguageList(primaryHint: String) -> [String] {
        let supported: Set<String> = {
            let req = VNRecognizeTextRequest()
            req.recognitionLevel = .accurate
            return Set((try? req.supportedRecognitionLanguages()) ?? ["en-US"])
        }()

        var ordered: [String] = []
        var seen = Set<String>()
        func add(_ languages: [String]) {
            for language in languages where supported.contains(language) && seen.insert(language).inserted {
                ordered.append(language)
            }
        }

        // 1. An explicit choice in Settings, when there is one. "system" is
        //    the default and is not a language — the old switch had no case
        //    for it and quietly fell through to nil, which is why the user's
        //    language was never prioritised at all.
        if primaryHint != "system" {
            add(regionVariants(of: primaryHint, in: supported))
        }

        // 2. What macOS says the user reads, in their own order. Matching
        //    against the supported list rather than a hardcoded table means
        //    every language Vision knows is covered, not the thirteen someone
        //    remembered to type out.
        for identifier in Locale.preferredLanguages {
            let code = String(identifier.split(separator: "-").first ?? "")
            add(regionVariants(of: code, in: supported))
        }

        // 3. English regardless: interfaces, code and error messages are
        //    usually English even on a machine that isn't.
        add(["en-US"])

        // 4. Everything else, so an unexpected script still has a chance.
        ordered += supported.subtracting(seen).sorted()

        return ordered.isEmpty ? ["en-US"] : ordered
    }

    /// Supported languages for a bare code — "tr" → ["tr-TR"], "zh" →
    /// ["zh-Hans", "zh-Hant"].
    private static func regionVariants(of code: String, in supported: Set<String>) -> [String] {
        let lower = code.lowercased()
        guard !lower.isEmpty else { return [] }
        return supported
            .filter { $0.lowercased() == lower || $0.lowercased().hasPrefix(lower + "-") }
            .sorted()
    }

}
