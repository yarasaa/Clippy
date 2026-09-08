//
//  SensitiveScanner.swift
//  Clippy
//
//  Finds the things in a picture you probably didn't mean to share, and
//  says exactly where they are.
//
//  Clippy already reads every image and already validates card numbers,
//  IBANs and national IDs against their real checksums. The screenshot
//  editor knew about none of it — it was a blind canvas, so covering a
//  leaked token meant noticing it yourself and dragging a box over it.
//  Not noticing is the actual failure mode.
//
//  This finds them and stops there. Nothing here changes a single pixel;
//  what to do about a finding is the user's call.
//

import AppKit
import Vision

struct SensitiveFinding: Identifiable, Equatable {
    enum Kind: Equatable {
        case sensitive(SensitiveHit.Kind)   // checksum-validated: card, IBAN, ID, API key
        case email
        case phone

        var label: String {
            switch self {
            case .sensitive(let k): return k.displayLabel
            case .email:            return "Email"
            case .phone:            return "Phone"
            }
        }

        var iconName: String {
            switch self {
            case .sensitive(let k): return k.iconName
            case .email:            return "envelope"
            case .phone:            return "phone"
            }
        }
    }

    let id = UUID()
    let kind: Kind
    /// What was matched. Shown in the review list so a finding can be
    /// judged without hunting for it in the picture.
    let text: String
    /// Where it sits, in image POINTS with a top-left origin — the space
    /// annotations already live in, so a finding can become a redaction
    /// rect without any further conversion.
    let rect: CGRect

    static func == (lhs: SensitiveFinding, rhs: SensitiveFinding) -> Bool {
        lhs.kind == rhs.kind && lhs.text == rhs.text && lhs.rect == rhs.rect
    }
}

enum SensitiveScanner {

    /// Scan an image. Returns findings in image points, top-left origin.
    ///
    /// Runs its own Vision pass rather than reusing the stored OCR text
    /// because it needs sub-line geometry: `boundingBox(for:)` gives the
    /// exact rect of the matched characters, so "call me on +1 …  after
    /// 3pm" covers the number and leaves the sentence readable. Redacting
    /// whole lines would be simpler and noticeably worse.
    static func scan(image: NSImage, primaryHint: String) -> [SensitiveFinding] {
        guard let cgImage = image.storageCGImage else { return [] }

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
            request.recognitionLanguages = VisionOCR.curatedLanguageList(primaryHint: primaryHint)
        }
        do {
            try VNImageRequestHandler(cgImage: cgImage, options: [:]).perform([request])
        } catch {
            NSLog("[Clippy] Sensitive scan failed: \(error.localizedDescription)")
            return []
        }
        guard let observations = request.results else { return [] }

        // Points, not pixels. The editor's annotations are in points, and a
        // Retina capture's bitmap is twice that — the distinction that put
        // the eyedropper's samples in the wrong place.
        let size = image.size
        var findings: [SensitiveFinding] = []

        for observation in observations {
            guard let candidate = observation.topCandidates(1).first else { continue }
            let line = candidate.string
            guard !line.isEmpty else { continue }

            // One detector, one set of rules — the same path the cards use,
            // so what counts as a phone number here is what counts there.
            let links = OCRLinkDetector.detect(in: line)

            var matches: [(SensitiveFinding.Kind, String)] = []
            matches += links.sensitiveHits.map { (.sensitive($0.kind), $0.snippet) }
            matches += links.emails.map { (.email, $0) }
            matches += links.phoneNumbers.map { (.phone, $0) }

            for (kind, snippet) in matches {
                guard let range = line.range(of: snippet),
                      let box = try? candidate.boundingBox(for: range) else { continue }
                let normalised = box.boundingBox
                let rect = CGRect(
                    x: normalised.minX * size.width,
                    y: (1 - normalised.maxY) * size.height,   // Vision counts up, we count down
                    width: normalised.width * size.width,
                    height: normalised.height * size.height
                )
                // A little breathing room: glyphs overhang their reported box
                // slightly, and a redaction that leaves a sliver of a digit
                // showing is worse than one that's a touch generous.
                findings.append(SensitiveFinding(
                    kind: kind,
                    text: snippet,
                    rect: rect.insetBy(dx: -3, dy: -2)
                ))
            }
        }

        return findings
    }
}
