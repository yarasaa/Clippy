//
//  ColorConverter.swift
//  Clippy
//
//  Created by Mehmet Akbaba on 15.11.2025.
//

import Foundation
import AppKit

enum ColorFormat {
    case hex
    case rgb
    case hsl
}

struct ConvertedColor {
    let hex: String
    let hexWithAlpha: String
    let rgb: String
    let rgba: String
    let hsl: String
    let hsla: String
    let originalColor: NSColor
}

struct ColorConverter {
    // Cached regex patterns for performance
    private static let hexRegex = try! NSRegularExpression(pattern: "^#?([0-9A-Fa-f]{3}|[0-9A-Fa-f]{6}|[0-9A-Fa-f]{8})$")
    private static let rgbRegex = try! NSRegularExpression(pattern: "^rgba?\\s*\\(\\s*(\\d+)\\s*,\\s*(\\d+)\\s*,\\s*(\\d+)(?:\\s*,\\s*([0-9.]+))?\\s*\\)$")
    private static let hslRegex = try! NSRegularExpression(pattern: "^hsla?\\s*\\(\\s*(\\d+)\\s*,\\s*(\\d+)%\\s*,\\s*(\\d+)%(?:\\s*,\\s*([0-9.]+))?\\s*\\)$")

    /// Detects the color format from a string
    static func detectFormat(_ text: String) -> ColorFormat? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)

        if hexRegex.firstMatch(in: trimmed, range: NSRange(trimmed.startIndex..., in: trimmed)) != nil {
            return .hex
        }

        if rgbRegex.firstMatch(in: trimmed, range: NSRange(trimmed.startIndex..., in: trimmed)) != nil {
            return .rgb
        }

        if hslRegex.firstMatch(in: trimmed, range: NSRange(trimmed.startIndex..., in: trimmed)) != nil {
            return .hsl
        }

        return nil
    }

    /// Parses a color string and returns an NSColor
    static func parseColor(_ text: String) -> NSColor? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)

        guard let format = detectFormat(trimmed) else { return nil }

        switch format {
        case .hex:
            return parseHex(trimmed)
        case .rgb:
            return parseRGB(trimmed)
        case .hsl:
            return parseHSL(trimmed)
        }
    }

    /// Converts a color to all formats
    static func convertToAllFormats(_ color: NSColor) -> ConvertedColor {
        // Convert to RGB color space first
        guard let rgbColor = color.usingColorSpace(.deviceRGB) else {
            return ConvertedColor(
                hex: "#000000",
                hexWithAlpha: "#000000FF",
                rgb: "rgb(0, 0, 0)",
                rgba: "rgba(0, 0, 0, 1.0)",
                hsl: "hsl(0, 0%, 0%)",
                hsla: "hsla(0, 0%, 0%, 1.0)",
                originalColor: color
            )
        }

        let r = Int(rgbColor.redComponent * 255)
        let g = Int(rgbColor.greenComponent * 255)
        let b = Int(rgbColor.blueComponent * 255)
        let a = rgbColor.alphaComponent

        // HEX
        let hex = String(format: "#%02X%02X%02X", r, g, b)
        let hexWithAlpha = String(format: "#%02X%02X%02X%02X", r, g, b, Int(a * 255))

        // RGB
        let rgb = "rgb(\(r), \(g), \(b))"
        let rgba = String(format: "rgba(%d, %d, %d, %.2f)", r, g, b, a)

        // HSL
        let (h, s, l) = rgbToHSL(r: r, g: g, b: b)
        let hsl = String(format: "hsl(%d, %d%%, %d%%)", h, s, l)
        let hsla = String(format: "hsla(%d, %d%%, %d%%, %.2f)", h, s, l, a)

        return ConvertedColor(
            hex: hex,
            hexWithAlpha: hexWithAlpha,
            rgb: rgb,
            rgba: rgba,
            hsl: hsl,
            hsla: hsla,
            originalColor: color
        )
    }

    // MARK: - Private Parsing Methods

    private static func parseHex(_ hex: String) -> NSColor? {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")

        var rgb: UInt64 = 0
        guard Scanner(string: hexSanitized).scanHexInt64(&rgb) else { return nil }

        let length = hexSanitized.count
        let r, g, b, a: CGFloat

        if length == 3 {
            // #RGB -> #RRGGBB
            r = CGFloat((rgb & 0xF00) >> 8) / 15.0
            g = CGFloat((rgb & 0x0F0) >> 4) / 15.0
            b = CGFloat(rgb & 0x00F) / 15.0
            a = 1.0
        } else if length == 6 {
            // #RRGGBB
            r = CGFloat((rgb & 0xFF0000) >> 16) / 255.0
            g = CGFloat((rgb & 0x00FF00) >> 8) / 255.0
            b = CGFloat(rgb & 0x0000FF) / 255.0
            a = 1.0
        } else if length == 8 {
            // #RRGGBBAA
            r = CGFloat((rgb & 0xFF000000) >> 24) / 255.0
            g = CGFloat((rgb & 0x00FF0000) >> 16) / 255.0
            b = CGFloat((rgb & 0x0000FF00) >> 8) / 255.0
            a = CGFloat(rgb & 0x000000FF) / 255.0
        } else {
            return nil
        }

        return NSColor(red: r, green: g, blue: b, alpha: a)
    }

    private static func parseRGB(_ rgb: String) -> NSColor? {
        let matches = rgbRegex.matches(in: rgb, range: NSRange(rgb.startIndex..., in: rgb))
        guard let match = matches.first, match.numberOfRanges >= 4 else { return nil }

        guard let rRange = Range(match.range(at: 1), in: rgb),
              let gRange = Range(match.range(at: 2), in: rgb),
              let bRange = Range(match.range(at: 3), in: rgb),
              let r = Int(rgb[rRange]),
              let g = Int(rgb[gRange]),
              let b = Int(rgb[bRange]) else { return nil }

        var a: CGFloat = 1.0
        if match.numberOfRanges == 5, let aRange = Range(match.range(at: 4), in: rgb) {
            a = CGFloat(Double(rgb[aRange]) ?? 1.0)
        }

        return NSColor(red: CGFloat(r) / 255.0, green: CGFloat(g) / 255.0, blue: CGFloat(b) / 255.0, alpha: a)
    }

    private static func parseHSL(_ hsl: String) -> NSColor? {
        let matches = hslRegex.matches(in: hsl, range: NSRange(hsl.startIndex..., in: hsl))
        guard let match = matches.first, match.numberOfRanges >= 4 else { return nil }

        guard let hRange = Range(match.range(at: 1), in: hsl),
              let sRange = Range(match.range(at: 2), in: hsl),
              let lRange = Range(match.range(at: 3), in: hsl),
              let h = Int(hsl[hRange]),
              let s = Int(hsl[sRange]),
              let l = Int(hsl[lRange]) else { return nil }

        var a: CGFloat = 1.0
        if match.numberOfRanges == 5, let aRange = Range(match.range(at: 4), in: hsl) {
            a = CGFloat(Double(hsl[aRange]) ?? 1.0)
        }

        let (r, g, b) = hslToRGB(h: h, s: s, l: l)
        return NSColor(red: CGFloat(r) / 255.0, green: CGFloat(g) / 255.0, blue: CGFloat(b) / 255.0, alpha: a)
    }

    // MARK: - Color Space Conversion

    private static func rgbToHSL(r: Int, g: Int, b: Int) -> (h: Int, s: Int, l: Int) {
        let rNorm = Double(r) / 255.0
        let gNorm = Double(g) / 255.0
        let bNorm = Double(b) / 255.0

        let maxVal = max(rNorm, gNorm, bNorm)
        let minVal = min(rNorm, gNorm, bNorm)
        let delta = maxVal - minVal

        var h: Double = 0
        var s: Double = 0
        let l = (maxVal + minVal) / 2.0

        if delta != 0 {
            s = l > 0.5 ? delta / (2.0 - maxVal - minVal) : delta / (maxVal + minVal)

            switch maxVal {
            case rNorm:
                h = ((gNorm - bNorm) / delta) + (gNorm < bNorm ? 6 : 0)
            case gNorm:
                h = ((bNorm - rNorm) / delta) + 2
            case bNorm:
                h = ((rNorm - gNorm) / delta) + 4
            default:
                break
            }

            h /= 6
        }

        return (
            h: Int(h * 360),
            s: Int(s * 100),
            l: Int(l * 100)
        )
    }

    private static func hslToRGB(h: Int, s: Int, l: Int) -> (r: Int, g: Int, b: Int) {
        let hNorm = Double(h) / 360.0
        let sNorm = Double(s) / 100.0
        let lNorm = Double(l) / 100.0

        if sNorm == 0 {
            let gray = Int(lNorm * 255)
            return (r: gray, g: gray, b: gray)
        }

        let q = lNorm < 0.5 ? lNorm * (1 + sNorm) : lNorm + sNorm - lNorm * sNorm
        let p = 2 * lNorm - q

        let r = hueToRGB(p: p, q: q, t: hNorm + 1.0/3.0)
        let g = hueToRGB(p: p, q: q, t: hNorm)
        let b = hueToRGB(p: p, q: q, t: hNorm - 1.0/3.0)

        return (
            r: Int(r * 255),
            g: Int(g * 255),
            b: Int(b * 255)
        )
    }

    private static func hueToRGB(p: Double, q: Double, t: Double) -> Double {
        var tNorm = t
        if tNorm < 0 { tNorm += 1 }
        if tNorm > 1 { tNorm -= 1 }

        if tNorm < 1.0/6.0 { return p + (q - p) * 6 * tNorm }
        if tNorm < 1.0/2.0 { return q }
        if tNorm < 2.0/3.0 { return p + (q - p) * (2.0/3.0 - tNorm) * 6 }

        return p
    }
}
