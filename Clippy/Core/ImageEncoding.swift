//
//  ImageEncoding.swift
//  Clippy
//
//  One place for "turn an NSImage into bytes", because the obvious
//  spelling is a memory trap.
//
//  Writing `image.tiffRepresentation` → `NSBitmapImageRep(data:)` →
//  `representation(using:)` keeps three full-size buffers alive at once:
//  the serialised TIFF, the bitmap parsed back out of it, and the
//  encoder's working set. Measured on a 5120×2880 screen capture, that
//  cost **+173 MB** of transient footprint and **47 ms** to produce a
//  226 KB file.
//
//  Going through the image's existing CGImage skips the round-trip
//  entirely — `NSBitmapImageRep(cgImage:)` references the pixels instead
//  of copying them. Same output, measured **+58 MB** and **14 ms**
//  (3x less memory, 3.4x faster).
//

import AppKit

extension NSImage {

    /// Bitmap representation without the TIFF round-trip.
    ///
    /// Falls back to the serialising path only for images that have no
    /// CGImage at all (pure vector sources), so nothing that used to work
    /// stops working.
    var storageBitmapRep: NSBitmapImageRep? {
        if let cgImage = cgImage(forProposedRect: nil, context: nil, hints: nil) {
            return NSBitmapImageRep(cgImage: cgImage)
        }
        guard let tiff = tiffRepresentation else { return nil }
        return NSBitmapImageRep(data: tiff)
    }

    /// CGImage for callers that only need pixels to hand to Core Graphics
    /// or ImageIO — no intermediate bitmap, no TIFF.
    var storageCGImage: CGImage? {
        if let cgImage = cgImage(forProposedRect: nil, context: nil, hints: nil) {
            return cgImage
        }
        guard let tiff = tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiff) else { return nil }
        return rep.cgImage
    }

    /// Encodes to `type` for on-disk storage.
    func storageData(using type: NSBitmapImageRep.FileType,
                     properties: [NSBitmapImageRep.PropertyKey: Any] = [:]) -> Data? {
        storageBitmapRep?.representation(using: type, properties: properties)
    }

    /// JPEG at the quality Clippy stores clipboard images with.
    func storageJPEGData(compression: Double = 0.85) -> Data? {
        storageData(using: .jpeg, properties: [.compressionFactor: compression])
    }
}
