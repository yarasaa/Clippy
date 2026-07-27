//
//  QRCodeGenerator.swift
//  Clippy
//
//  Turns clipboard text into a QR code the user can scan with their
//  phone camera — the 80% of "send to phone" with 2% of the effort:
//  no account, no server, no sync, no network. Everything is drawn
//  locally with CoreImage's built-in CIQRCodeGenerator.
//
//  QR codes have a hard capacity limit (~2-3KB at the lowest error
//  correction, far less at readable module sizes), so callers should
//  gate on a sane character cap before offering the action.
//

import CoreImage
import CoreImage.CIFilterBuiltins
import AppKit

enum QRCodeGenerator {
    /// Above this the QR becomes too dense for a phone camera to read
    /// reliably at a comfortable on-screen size. Callers disable the
    /// "Send to Phone" action beyond it.
    static let maxPayloadLength = 1500

    /// Renders `string` as a crisp QR NSImage at the requested point
    /// size. Returns nil if the payload is empty or too large to encode.
    static func image(for string: String, size: CGFloat = 240) -> NSImage? {
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed.count <= maxPayloadLength else { return nil }
        guard let data = trimmed.data(using: .utf8) else { return nil }

        let filter = CIFilter.qrCodeGenerator()
        filter.message = data
        // Medium error correction: good scan reliability without
        // bloating module count.
        filter.correctionLevel = "M"

        guard let output = filter.outputImage else { return nil }

        // The generator emits a tiny image (one pixel per module).
        // Scale it up with nearest-neighbor so modules stay razor-sharp
        // instead of blurred.
        let scale = size / output.extent.width
        let scaled = output.transformed(by: CGAffineTransform(scaleX: scale, y: scale))

        let context = CIContext()
        guard let cgImage = context.createCGImage(scaled, from: scaled.extent) else {
            return nil
        }
        return NSImage(cgImage: cgImage, size: NSSize(width: size, height: size))
    }
}
