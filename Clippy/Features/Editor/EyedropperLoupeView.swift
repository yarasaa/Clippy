//
//  EyedropperLoupeView.swift
//  Clippy
//

import AppKit

class EyedropperLoupeController {
    static let shared = EyedropperLoupeController()

    private var panel: NSPanel?
    private var loupeView: EyedropperLoupeNSView?
    private var cachedBitmap: NSBitmapImageRep?

    var contrastMode: Bool = false {
        didSet { loupeView?.contrastMode = contrastMode }
    }
    var contrastForeground: NSColor? {
        didSet { loupeView?.contrastForeground = contrastForeground }
    }
    var contrastBackground: NSColor? {
        didSet { loupeView?.contrastBackground = contrastBackground }
    }

    func clearContrast() {
        contrastForeground = nil
        contrastBackground = nil
        loupeView?.needsDisplay = true
    }

    private init() {}

    func show(image: NSImage) {
        cachedBitmap = image.tiffRepresentation.flatMap { NSBitmapImageRep(data: $0) }

        if panel == nil {
            let loupeSize = NSSize(width: 160, height: 190)
            let newPanel = NSPanel(
                contentRect: NSRect(origin: .zero, size: loupeSize),
                styleMask: [.borderless, .nonactivatingPanel],
                backing: .buffered,
                defer: false
            )
            newPanel.isFloatingPanel = true
            newPanel.level = .popUpMenu
            newPanel.isOpaque = false
            newPanel.backgroundColor = .clear
            newPanel.hasShadow = true
            newPanel.hidesOnDeactivate = false
            newPanel.isReleasedWhenClosed = false
            newPanel.ignoresMouseEvents = true

            let view = EyedropperLoupeNSView(frame: NSRect(origin: .zero, size: loupeSize))
            newPanel.contentView = view
            loupeView = view
            panel = newPanel
        }

        loupeView?.contrastMode = contrastMode
        loupeView?.contrastForeground = contrastForeground
        loupeView?.contrastBackground = contrastBackground

        panel?.orderFront(nil)
    }

    func updatePosition(screenPoint: NSPoint, imagePoint: CGPoint) {
        guard let panel = panel, let loupeView = loupeView, let bitmap = cachedBitmap else { return }

        // Resize panel if contrast info needs to be shown
        let hasContrastInfo = contrastMode && contrastForeground != nil
        let targetHeight: CGFloat = hasContrastInfo ? 226 : 190
        if abs(panel.frame.height - targetHeight) > 1 {
            var frame = panel.frame
            frame.size.height = targetHeight
            panel.setFrame(frame, display: false)
            loupeView.frame = NSRect(origin: .zero, size: frame.size)
        }

        // Position panel offset from cursor
        let panelOrigin = NSPoint(x: screenPoint.x + 20, y: screenPoint.y - 10)
        panel.setFrameOrigin(panelOrigin)

        // Convert from image point coords to bitmap pixel coords (Retina 2x etc.)
        let scaleX = bitmap.size.width > 0 ? CGFloat(bitmap.pixelsWide) / bitmap.size.width : 1
        let scaleY = bitmap.size.height > 0 ? CGFloat(bitmap.pixelsHigh) / bitmap.size.height : 1
        let pixelX = imagePoint.x * scaleX
        let pixelY = imagePoint.y * scaleY
        // Both SwiftUI Canvas and NSBitmapImageRep use top-left origin — no Y flip needed
        let center = CGPoint(x: pixelX, y: pixelY)
        loupeView.updatePixels(from: bitmap, at: center)
        loupeView.needsDisplay = true
    }

    func hide() {
        panel?.orderOut(nil)
        cachedBitmap = nil
    }

    var isVisible: Bool {
        panel?.isVisible ?? false
    }
}

class EyedropperLoupeNSView: NSView {
    private let gridSize = 11
    private let pixelSize: CGFloat = 14
    private let infoBarHeight: CGFloat = 30
    private let contrastBarHeight: CGFloat = 36

    var pixels: [[NSColor]] = []
    var centerColor: NSColor = .clear
    var hexString: String = "#000000"

    var contrastMode: Bool = false
    var contrastForeground: NSColor?
    var contrastBackground: NSColor?

    override var isFlipped: Bool { true }

    func updatePixels(from bitmap: NSBitmapImageRep, at center: CGPoint) {
        let radius = gridSize / 2
        var grid: [[NSColor]] = []

        for dy in -radius...radius {
            var row: [NSColor] = []
            for dx in -radius...radius {
                let x = Int(center.x) + dx
                let y = Int(center.y) + dy
                let clampedX = max(0, min(bitmap.pixelsWide - 1, x))
                let clampedY = max(0, min(bitmap.pixelsHigh - 1, y))
                let color = bitmap.colorAt(x: clampedX, y: clampedY) ?? .clear
                row.append(color)
            }
            grid.append(row)
        }

        pixels = grid
        centerColor = grid[radius][radius]

        if let rgb = centerColor.usingColorSpace(.sRGB) {
            let r = Int(rgb.redComponent * 255)
            let g = Int(rgb.greenComponent * 255)
            let b = Int(rgb.blueComponent * 255)
            hexString = String(format: "#%02X%02X%02X", r, g, b)
        }
    }

    override func draw(_ dirtyRect: NSRect) {
        guard !pixels.isEmpty else { return }

        let gridWidth = CGFloat(gridSize) * pixelSize
        let totalWidth = bounds.width
        let gridOffset = (totalWidth - gridWidth) / 2

        // Background
        let bgPath = NSBezierPath(roundedRect: bounds, xRadius: 10, yRadius: 10)
        NSColor(white: 0.15, alpha: 0.95).setFill()
        bgPath.fill()

        // Pixel grid
        let radius = gridSize / 2
        for row in 0..<gridSize {
            for col in 0..<gridSize {
                guard row < pixels.count, col < pixels[row].count else { continue }
                let color = pixels[row][col]
                let rect = NSRect(
                    x: gridOffset + CGFloat(col) * pixelSize,
                    y: 4 + CGFloat(row) * pixelSize,
                    width: pixelSize,
                    height: pixelSize
                )
                color.setFill()
                rect.fill()

                // Grid line
                NSColor(white: 0.3, alpha: 0.3).setStroke()
                let borderPath = NSBezierPath(rect: rect)
                borderPath.lineWidth = 0.5
                borderPath.stroke()
            }
        }

        // Center pixel highlight
        let centerRect = NSRect(
            x: gridOffset + CGFloat(radius) * pixelSize - 1,
            y: 4 + CGFloat(radius) * pixelSize - 1,
            width: pixelSize + 2,
            height: pixelSize + 2
        )
        NSColor.white.setStroke()
        let highlightPath = NSBezierPath(rect: centerRect)
        highlightPath.lineWidth = 2
        highlightPath.stroke()

        // Info bar at bottom
        let infoY = bounds.height - infoBarHeight
        let infoRect = NSRect(x: 0, y: infoY, width: totalWidth, height: infoBarHeight)

        // Separator
        NSColor(white: 0.3, alpha: 0.5).setFill()
        NSRect(x: 8, y: infoY, width: totalWidth - 16, height: 1).fill()

        // Color swatch
        let swatchSize: CGFloat = 16
        let swatchRect = NSRect(x: 12, y: infoY + (infoBarHeight - swatchSize) / 2, width: swatchSize, height: swatchSize)
        centerColor.setFill()
        let swatchPath = NSBezierPath(roundedRect: swatchRect, xRadius: 3, yRadius: 3)
        swatchPath.fill()
        NSColor.white.withAlphaComponent(0.5).setStroke()
        swatchPath.lineWidth = 1
        swatchPath.stroke()

        // Hex text
        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedSystemFont(ofSize: 12, weight: .medium),
            .foregroundColor: NSColor.white
        ]
        let textPoint = NSPoint(x: 36, y: infoY + (infoBarHeight - 14) / 2)
        (hexString as NSString).draw(at: textPoint, withAttributes: attrs)

        // Contrast mode indicator
        if contrastMode {
            let indicatorY = infoY + 2
            let label = contrastForeground == nil ? "FG" : "BG"
            let labelAttrs: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: 8, weight: .bold),
                .foregroundColor: NSColor.white.withAlphaComponent(0.6)
            ]
            (label as NSString).draw(at: NSPoint(x: totalWidth - 24, y: indicatorY + 6), withAttributes: labelAttrs)
        }

        // Contrast result bar
        if contrastMode, let fg = contrastForeground {
            let contrastY = infoY + infoBarHeight

            // Separator
            NSColor(white: 0.3, alpha: 0.5).setFill()
            NSRect(x: 8, y: contrastY, width: totalWidth - 16, height: 1).fill()

            let barY = contrastY + 4

            // Foreground swatch
            let fgSwatchRect = NSRect(x: 12, y: barY + 4, width: 14, height: 14)
            fg.setFill()
            let fgPath = NSBezierPath(roundedRect: fgSwatchRect, xRadius: 3, yRadius: 3)
            fgPath.fill()
            NSColor.white.withAlphaComponent(0.5).setStroke()
            fgPath.lineWidth = 0.5
            fgPath.stroke()

            // Background swatch (or placeholder)
            let bgSwatchRect = NSRect(x: 30, y: barY + 4, width: 14, height: 14)
            if let bg = contrastBackground {
                bg.setFill()
            } else {
                NSColor.gray.withAlphaComponent(0.3).setFill()
            }
            let bgPath = NSBezierPath(roundedRect: bgSwatchRect, xRadius: 3, yRadius: 3)
            bgPath.fill()
            NSColor.white.withAlphaComponent(0.5).setStroke()
            bgPath.lineWidth = 0.5
            bgPath.stroke()

            if let bg = contrastBackground {
                // Calculate contrast ratio
                let ratio = Self.contrastRatio(between: fg, and: bg)
                let ratioStr = String(format: "%.1f:1", ratio)

                let ratioAttrs: [NSAttributedString.Key: Any] = [
                    .font: NSFont.monospacedSystemFont(ofSize: 11, weight: .bold),
                    .foregroundColor: NSColor.white
                ]
                (ratioStr as NSString).draw(at: NSPoint(x: 50, y: barY + 5), withAttributes: ratioAttrs)

                // AA/AAA badges
                let aaPass = ratio >= 4.5
                let aaaPass = ratio >= 7.0
                let aaLargePass = ratio >= 3.0

                drawBadge("AA", pass: aaPass, at: NSPoint(x: 100, y: barY + 2))
                drawBadge("AAA", pass: aaaPass, at: NSPoint(x: 130, y: barY + 2))

                // Large text note
                if !aaPass && aaLargePass {
                    let noteAttrs: [NSAttributedString.Key: Any] = [
                        .font: NSFont.systemFont(ofSize: 7, weight: .medium),
                        .foregroundColor: NSColor.white.withAlphaComponent(0.5)
                    ]
                    ("AA Large" as NSString).draw(at: NSPoint(x: 100, y: barY + 20), withAttributes: noteAttrs)
                }
            } else {
                let pickAttrs: [NSAttributedString.Key: Any] = [
                    .font: NSFont.systemFont(ofSize: 10, weight: .medium),
                    .foregroundColor: NSColor.white.withAlphaComponent(0.5)
                ]
                ("Click for BG" as NSString).draw(at: NSPoint(x: 50, y: barY + 6), withAttributes: pickAttrs)
            }
        }
    }

    private func drawBadge(_ text: String, pass: Bool, at origin: NSPoint) {
        let badgeRect = NSRect(x: origin.x, y: origin.y, width: text == "AAA" ? 28 : 22, height: 16)
        let bgColor = pass ? NSColor.systemGreen.withAlphaComponent(0.8) : NSColor.systemRed.withAlphaComponent(0.6)
        bgColor.setFill()
        let path = NSBezierPath(roundedRect: badgeRect, xRadius: 3, yRadius: 3)
        path.fill()

        let badgeAttrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 8, weight: .bold),
            .foregroundColor: NSColor.white
        ]
        let textSize = (text as NSString).size(withAttributes: badgeAttrs)
        let textX = badgeRect.midX - textSize.width / 2
        let textY = badgeRect.midY - textSize.height / 2
        (text as NSString).draw(at: NSPoint(x: textX, y: textY), withAttributes: badgeAttrs)
    }

    // MARK: - WCAG Contrast Calculation

    static func contrastRatio(between color1: NSColor, and color2: NSColor) -> CGFloat {
        let l1 = relativeLuminance(of: color1)
        let l2 = relativeLuminance(of: color2)
        let lighter = max(l1, l2)
        let darker = min(l1, l2)
        return (lighter + 0.05) / (darker + 0.05)
    }

    static func relativeLuminance(of color: NSColor) -> CGFloat {
        guard let rgb = color.usingColorSpace(.sRGB) else { return 0 }
        let r = linearize(rgb.redComponent)
        let g = linearize(rgb.greenComponent)
        let b = linearize(rgb.blueComponent)
        return 0.2126 * r + 0.7152 * g + 0.0722 * b
    }

    private static func linearize(_ component: CGFloat) -> CGFloat {
        if component <= 0.03928 {
            return component / 12.92
        }
        return pow((component + 0.055) / 1.055, 2.4)
    }
}
