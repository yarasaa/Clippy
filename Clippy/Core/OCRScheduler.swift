//
//  OCRScheduler.swift
//  Clippy
//
//  Serialises automatic (background) OCR.
//
//  Each image capture used to spawn its own detached task, so copying a
//  handful of screenshots in quick succession started that many Vision
//  recognitions at once — each holding its own full-resolution decode plus
//  Vision's internal IOSurface buffers. Measured on three 2400×1400
//  images: 158% CPU and a jump from 108 MB to 297 MB resident.
//
//  Running them one at a time caps peak memory at roughly one image's
//  worth. The only cost is that a burst finishes a little later, and
//  nothing is waiting on the result — the text lands in the item whenever
//  it's ready.
//
//  The interactive path (⇧⌘2 screen grab) deliberately does NOT go
//  through here: the user is waiting on that one, so it must never queue
//  behind background work.
//

import Foundation
import CoreGraphics
import ImageIO

actor OCRScheduler {
    static let shared = OCRScheduler()

    private init() {}

    /// Upper bound on the pixels handed to Vision.
    ///
    /// Text recognition doesn't get better once glyphs are comfortably
    /// resolved, but memory and time keep scaling with pixel count. A 6K
    /// screenshot decoded whole is ~80 MB; capped here it's ~36 MB. The
    /// bound is deliberately generous — at 4000px a 5120-wide screen is
    /// only scaled to 0.78x, so text that was 32px tall is still 25px,
    /// well inside what Vision reads reliably. Smaller images (the common
    /// case) are untouched.
    private static let maxPixelSize: CGFloat = 4000

    /// Decodes and recognises in one serialised step. Both halves are
    /// inside the actor on purpose: letting decodes run concurrently would
    /// reintroduce the memory spike this exists to prevent.
    func recognize(imageURL: URL, primaryHint: String) -> String {
        guard let source = CGImageSourceCreateWithURL(imageURL as CFURL, nil) else {
            return ""
        }

        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceThumbnailMaxPixelSize: Self.maxPixelSize
        ]
        // CGImageSourceCreateThumbnailAtIndex only downsamples; for an
        // image already under the cap it returns full resolution, so this
        // is a ceiling rather than a forced resize.
        guard let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
            return ""
        }

        return VisionOCR.recognizeText(in: cgImage, primaryHint: primaryHint)
    }
}
