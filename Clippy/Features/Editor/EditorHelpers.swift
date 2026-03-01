//
//  EditorHelpers.swift
//  Clippy
//

import SwiftUI

// MARK: - Path Smoothing

/// Build a smooth Path from points using Catmull-Rom splines
func smoothPath(from points: [CGPoint]) -> Path {
    guard points.count > 2 else {
        var p = Path()
        if let first = points.first {
            p.move(to: first)
            for i in 1..<points.count { p.addLine(to: points[i]) }
        }
        return p
    }

    var path = Path()
    path.move(to: points[0])

    for i in 0..<points.count - 1 {
        let p0 = points[max(i - 1, 0)]
        let p1 = points[i]
        let p2 = points[min(i + 1, points.count - 1)]
        let p3 = points[min(i + 2, points.count - 1)]

        let cp1 = CGPoint(
            x: p1.x + (p2.x - p0.x) / 6,
            y: p1.y + (p2.y - p0.y) / 6
        )
        let cp2 = CGPoint(
            x: p2.x - (p3.x - p1.x) / 6,
            y: p2.y - (p3.y - p1.y) / 6
        )
        path.addCurve(to: p2, control1: cp1, control2: cp2)
    }
    return path
}

/// Simplify a point array using Douglas-Peucker with given tolerance
func simplifyPoints(_ points: [CGPoint], tolerance: CGFloat = 1.0) -> [CGPoint] {
    guard points.count > 2 else { return points }

    func perpendicularDistance(_ point: CGPoint, lineStart: CGPoint, lineEnd: CGPoint) -> CGFloat {
        let dx = lineEnd.x - lineStart.x
        let dy = lineEnd.y - lineStart.y
        let lengthSq = dx * dx + dy * dy
        guard lengthSq > 0 else { return hypot(point.x - lineStart.x, point.y - lineStart.y) }
        let t = max(0, min(1, ((point.x - lineStart.x) * dx + (point.y - lineStart.y) * dy) / lengthSq))
        let projX = lineStart.x + t * dx
        let projY = lineStart.y + t * dy
        return hypot(point.x - projX, point.y - projY)
    }

    var maxDist: CGFloat = 0
    var maxIndex = 0
    let first = points.first!
    let last = points.last!

    for i in 1..<points.count - 1 {
        let d = perpendicularDistance(points[i], lineStart: first, lineEnd: last)
        if d > maxDist {
            maxDist = d
            maxIndex = i
        }
    }

    if maxDist > tolerance {
        let left = simplifyPoints(Array(points[0...maxIndex]), tolerance: tolerance)
        let right = simplifyPoints(Array(points[maxIndex...]), tolerance: tolerance)
        return Array(left.dropLast()) + right
    } else {
        return [first, last]
    }
}

// MARK: - CIFilter Helpers

func applyPixelateFilter(to sourceImage: NSImage, in rect: CGRect) -> NSImage? {
    let sourceRect = CGRect(origin: .zero, size: sourceImage.size)
    let rectInSource = rect.intersection(sourceRect)
    guard !rectInSource.isEmpty, rectInSource.width > 1, rectInSource.height > 1 else { return nil }

    guard let tiffData = sourceImage.tiffRepresentation,
          let ciImage = CIImage(data: tiffData) else {
        return nil
    }

    // Convert from image point coords to CIImage pixel coords (Retina 2x etc.)
    let pxScaleX = sourceImage.size.width > 0 ? ciImage.extent.width / sourceImage.size.width : 1
    let pxScaleY = sourceImage.size.height > 0 ? ciImage.extent.height / sourceImage.size.height : 1

    // CIImage uses bottom-left origin; annotation/image coords use top-left origin
    let ciRect = CGRect(
        x: rectInSource.origin.x * pxScaleX,
        y: ciImage.extent.height - (rectInSource.origin.y + rectInSource.height) * pxScaleY,
        width: rectInSource.width * pxScaleX,
        height: rectInSource.height * pxScaleY
    )

    let croppedImage = ciImage.cropped(to: ciRect)

    guard let filter = CIFilter(name: "CIPixellate") else { return nil }
    filter.setValue(croppedImage, forKey: kCIInputImageKey)
    let scale = max(8, min(40, rectInSource.width / 10))
    filter.setValue(scale, forKey: kCIInputScaleKey)
    filter.setValue(CIVector(x: ciRect.midX, y: ciRect.midY), forKey: kCIInputCenterKey)

    guard let outputImage = filter.outputImage else { return nil }
    let clipped = outputImage.cropped(to: ciRect)

    let rep = NSCIImageRep(ciImage: clipped)
    let nsImage = NSImage(size: rectInSource.size)
    nsImage.addRepresentation(rep)
    return nsImage
}

/// Apply CIGaussianBlur to a rectangular region of the source image
func applyGaussianBlurFilter(to sourceImage: NSImage, in rect: CGRect, radius: CGFloat = 10) -> NSImage? {
    let sourceRect = CGRect(origin: .zero, size: sourceImage.size)
    let rectInSource = rect.intersection(sourceRect)
    guard !rectInSource.isEmpty, rectInSource.width > 1, rectInSource.height > 1 else { return nil }

    guard let tiffData = sourceImage.tiffRepresentation,
          let ciImage = CIImage(data: tiffData) else {
        return nil
    }

    // Convert from image point coords to CIImage pixel coords (Retina 2x etc.)
    let pxScaleX = sourceImage.size.width > 0 ? ciImage.extent.width / sourceImage.size.width : 1
    let pxScaleY = sourceImage.size.height > 0 ? ciImage.extent.height / sourceImage.size.height : 1

    // CIImage uses bottom-left origin; annotation/image coords use top-left origin
    let ciRect = CGRect(
        x: rectInSource.origin.x * pxScaleX,
        y: ciImage.extent.height - (rectInSource.origin.y + rectInSource.height) * pxScaleY,
        width: rectInSource.width * pxScaleX,
        height: rectInSource.height * pxScaleY
    )

    let croppedImage = ciImage.cropped(to: ciRect)

    guard let filter = CIFilter(name: "CIGaussianBlur") else { return nil }
    filter.setValue(croppedImage, forKey: kCIInputImageKey)
    filter.setValue(radius, forKey: kCIInputRadiusKey)

    guard let outputImage = filter.outputImage else { return nil }
    let clipped = outputImage.cropped(to: ciRect)

    let rep = NSCIImageRep(ciImage: clipped)
    let nsImage = NSImage(size: rectInSource.size)
    nsImage.addRepresentation(rep)
    return nsImage
}

// MARK: - Pattern Tile

func createPatternTileImage(type: PatternType, color1: Color, color2: Color, spacing: CGFloat) -> NSImage {
    let tileSize = max(spacing * 2, 20)
    let size = NSSize(width: tileSize, height: tileSize)
    let image = NSImage(size: size)
    image.lockFocus()

    let c1 = NSColor(color1)
    let c2 = NSColor(color2)

    // Background
    c2.setFill()
    NSBezierPath(rect: NSRect(origin: .zero, size: size)).fill()

    // Foreground pattern
    c1.setFill()
    c1.setStroke()

    switch type {
    case .dots:
        var y = spacing / 2
        while y < tileSize {
            var x = spacing / 2
            while x < tileSize {
                NSBezierPath(ovalIn: NSRect(x: x - 2, y: y - 2, width: 4, height: 4)).fill()
                x += spacing
            }
            y += spacing
        }
    case .grid:
        let gridPath = NSBezierPath()
        gridPath.lineWidth = 0.5
        var gx: CGFloat = 0
        while gx <= tileSize {
            gridPath.move(to: NSPoint(x: gx, y: 0))
            gridPath.line(to: NSPoint(x: gx, y: tileSize))
            gx += spacing
        }
        var gy: CGFloat = 0
        while gy <= tileSize {
            gridPath.move(to: NSPoint(x: 0, y: gy))
            gridPath.line(to: NSPoint(x: tileSize, y: gy))
            gy += spacing
        }
        gridPath.stroke()
    case .stripes:
        let stripePath = NSBezierPath()
        stripePath.lineWidth = spacing / 3
        var sx: CGFloat = -tileSize
        while sx <= tileSize * 2 {
            stripePath.move(to: NSPoint(x: sx, y: 0))
            stripePath.line(to: NSPoint(x: sx + tileSize, y: tileSize))
            sx += spacing
        }
        stripePath.stroke()
    case .checkerboard:
        var row = 0
        var cy: CGFloat = 0
        while cy < tileSize {
            var col = 0
            var cx: CGFloat = 0
            while cx < tileSize {
                if (row + col).isMultiple(of: 2) {
                    NSBezierPath(rect: NSRect(x: cx, y: cy, width: spacing, height: spacing)).fill()
                }
                cx += spacing
                col += 1
            }
            cy += spacing
            row += 1
        }
    }

    image.unlockFocus()
    return image
}

// MARK: - Extensions

extension Color {
    var hexString: String {
        guard let components = NSColor(self).usingColorSpace(.sRGB)?.cgColor.components, components.count >= 3 else { return "#000000" }
        let r = Int(components[0] * 255.0)
        let g = Int(components[1] * 255.0)
        let b = Int(components[2] * 255.0)
        return String(format: "#%02X%02X%02X", r, g, b)
    }

    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3:
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB, red: Double(r) / 255, green: Double(g) / 255, blue: Double(b) / 255, opacity: Double(a) / 255
        )
    }
}

extension CGRect {
    init(from: CGPoint, to: CGPoint) {
        self.init(x: min(from.x, to.x), y: min(from.y, to.y), width: abs(from.x - to.x), height: abs(from.y - to.y))
    }

    var center: CGPoint {
        CGPoint(x: midX, y: midY)
    }

    var endPoint: CGPoint {
        CGPoint(x: origin.x + size.width, y: origin.y + size.height)
    }
}

extension Path {
    static func arrow(from start: CGPoint, to end: CGPoint, tailWidth: CGFloat, headWidth: CGFloat, headLength: CGFloat) -> Path {
        let length = hypot(end.x - start.x, end.y - start.y)
        let tailLength = length - headLength

        let points: [CGPoint] = [
            CGPoint(x: 0, y: tailWidth / 2),
            CGPoint(x: tailLength, y: tailWidth / 2),
            CGPoint(x: tailLength, y: headWidth / 2),
            CGPoint(x: length, y: 0),
            CGPoint(x: tailLength, y: -headWidth / 2),
            CGPoint(x: tailLength, y: -tailWidth / 2),
            CGPoint(x: 0, y: -tailWidth / 2)
        ]

        let cosine = (end.x - start.x) / length
        let sine = (end.y - start.y) / length
        let transform = CGAffineTransform(a: cosine, b: sine, c: -sine, d: cosine, tx: start.x, ty: start.y)

        return Path { path in
            let transformedPoints = points.map { $0.applying(transform) }
            path.addLines(transformedPoints)
            path.closeSubpath()
        }
    }
}

extension Path {
    static func curvedArrow(from start: CGPoint, to end: CGPoint, control: CGPoint, tailWidth: CGFloat, headWidth: CGFloat, headLength: CGFloat) -> Path {
        // Tangent at end: derivative of quadratic Bezier at t=1 → 2*(end - control)
        let tangent = CGPoint(x: end.x - control.x, y: end.y - control.y)
        let tangentLen = hypot(tangent.x, tangent.y)
        guard tangentLen > 0.01 else {
            return Path.arrow(from: start, to: end, tailWidth: tailWidth, headWidth: headWidth, headLength: headLength)
        }
        let dir = CGPoint(x: tangent.x / tangentLen, y: tangent.y / tangentLen)
        let perp = CGPoint(x: -dir.y, y: dir.x)

        // Pull the arrowhead back along the tangent
        let headBase = CGPoint(x: end.x - dir.x * headLength, y: end.y - dir.y * headLength)

        return Path { path in
            // Tail: stroke along the Bezier curve (no fill, just the shaft line)
            // Left side of tail
            let leftStart = CGPoint(x: start.x + perp.x * tailWidth / 2, y: start.y + perp.y * tailWidth / 2)
            let leftControl = CGPoint(x: control.x + perp.x * tailWidth / 2, y: control.y + perp.y * tailWidth / 2)
            let leftEnd = CGPoint(x: headBase.x + perp.x * tailWidth / 2, y: headBase.y + perp.y * tailWidth / 2)

            let rightStart = CGPoint(x: start.x - perp.x * tailWidth / 2, y: start.y - perp.y * tailWidth / 2)
            let rightControl = CGPoint(x: control.x - perp.x * tailWidth / 2, y: control.y - perp.y * tailWidth / 2)
            let rightEnd = CGPoint(x: headBase.x - perp.x * tailWidth / 2, y: headBase.y - perp.y * tailWidth / 2)

            // Build filled shape: left side forward, arrowhead, right side backward
            path.move(to: leftStart)
            path.addQuadCurve(to: leftEnd, control: leftControl)

            // Arrowhead
            path.addLine(to: CGPoint(x: headBase.x + perp.x * headWidth / 2, y: headBase.y + perp.y * headWidth / 2))
            path.addLine(to: end)
            path.addLine(to: CGPoint(x: headBase.x - perp.x * headWidth / 2, y: headBase.y - perp.y * headWidth / 2))

            // Right side backward
            path.addLine(to: rightEnd)
            path.addQuadCurve(to: rightStart, control: rightControl)
            path.closeSubpath()
        }
    }
}

// MARK: - Sketch / Hand-drawn Style

struct SketchRenderer {
    /// Generates a hand-drawn looking path for a rectangle
    static func sketchRect(_ rect: CGRect, seed: Int) -> Path {
        var rng = SeededRNG(seed: UInt64(abs(seed)))
        let jitter: CGFloat = max(1.5, min(rect.width, rect.height) * 0.015)

        func j() -> CGFloat { CGFloat.random(in: -jitter...jitter, using: &rng) }

        return Path { path in
            // Draw each edge with slight wobble, 2 passes for sketch feel
            for pass in 0..<2 {
                let offset = CGFloat(pass) * 0.7
                let tl = CGPoint(x: rect.minX + j() + offset, y: rect.minY + j() + offset)
                let tr = CGPoint(x: rect.maxX + j() - offset, y: rect.minY + j() + offset)
                let br = CGPoint(x: rect.maxX + j() - offset, y: rect.maxY + j() - offset)
                let bl = CGPoint(x: rect.minX + j() + offset, y: rect.maxY + j() - offset)

                path.move(to: tl)
                let mid1 = CGPoint(x: (tl.x + tr.x) / 2 + j(), y: (tl.y + tr.y) / 2 + j())
                path.addQuadCurve(to: tr, control: mid1)
                let mid2 = CGPoint(x: (tr.x + br.x) / 2 + j(), y: (tr.y + br.y) / 2 + j())
                path.addQuadCurve(to: br, control: mid2)
                let mid3 = CGPoint(x: (br.x + bl.x) / 2 + j(), y: (br.y + bl.y) / 2 + j())
                path.addQuadCurve(to: bl, control: mid3)
                let mid4 = CGPoint(x: (bl.x + tl.x) / 2 + j(), y: (bl.y + tl.y) / 2 + j())
                path.addQuadCurve(to: tl, control: mid4)
            }
        }
    }

    /// Generates a hand-drawn looking path for an ellipse
    static func sketchEllipse(_ rect: CGRect, seed: Int) -> Path {
        var rng = SeededRNG(seed: UInt64(abs(seed)))
        let jitter: CGFloat = max(1.5, min(rect.width, rect.height) * 0.02)

        func j() -> CGFloat { CGFloat.random(in: -jitter...jitter, using: &rng) }

        let cx = rect.midX
        let cy = rect.midY
        let rx = rect.width / 2
        let ry = rect.height / 2
        let segments = 24

        return Path { path in
            for pass in 0..<2 {
                let rOffset = CGFloat(pass) * 0.5
                for i in 0...segments {
                    let angle = CGFloat(i) / CGFloat(segments) * 2 * .pi
                    let x = cx + (rx + rOffset + j()) * cos(angle)
                    let y = cy + (ry + rOffset + j()) * sin(angle)
                    if i == 0 {
                        path.move(to: CGPoint(x: x, y: y))
                    } else {
                        path.addLine(to: CGPoint(x: x, y: y))
                    }
                }
            }
        }
    }

    /// Generates a hand-drawn looking line between two points
    static func sketchLine(from start: CGPoint, to end: CGPoint, seed: Int) -> Path {
        var rng = SeededRNG(seed: UInt64(abs(seed)))
        let length = hypot(end.x - start.x, end.y - start.y)
        let jitter: CGFloat = max(1, length * 0.012)

        func j() -> CGFloat { CGFloat.random(in: -jitter...jitter, using: &rng) }

        return Path { path in
            for _ in 0..<2 {
                path.move(to: CGPoint(x: start.x + j(), y: start.y + j()))
                let mid = CGPoint(x: (start.x + end.x) / 2 + j(), y: (start.y + end.y) / 2 + j())
                path.addQuadCurve(to: CGPoint(x: end.x + j(), y: end.y + j()), control: mid)
            }
        }
    }
}

/// Deterministic random number generator seeded by annotation ID hash
struct SeededRNG: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) {
        state = seed == 0 ? 1 : seed
    }

    mutating func next() -> UInt64 {
        state &+= 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }
}

extension View {
    func cursor(_ cursor: NSCursor) -> some View {
        self.onHover { inside in
            if inside {
                cursor.push()
            } else {
                NSCursor.pop()
            }
        }
    }
}

// MARK: - Utility Views

struct CheckerboardView: View {
    let squareSize: CGFloat = 16
    let lightColor = Color(nsColor: .windowBackgroundColor).opacity(0.8)
    let darkColor = Color(nsColor: .underPageBackgroundColor)

    var body: some View {
        GeometryReader { geometry in
            let columns = Int(ceil(geometry.size.width / squareSize))
            let rows = Int(ceil(geometry.size.height / squareSize))

            Canvas { context, size in
                for row in 0..<rows {
                    for col in 0..<columns {
                        let rect = CGRect(x: CGFloat(col) * squareSize, y: CGFloat(row) * squareSize, width: squareSize, height: squareSize)
                        let color = (row + col).isMultiple(of: 2) ? lightColor : darkColor
                        context.fill(Path(rect), with: .color(color))
                    }
                }
            }
        }
    }
}

struct ScrollEventModifier: ViewModifier {
    var onScroll: (NSEvent) -> Void

    func body(content: Content) -> some View {
        content.background(
            ScrollEventView(onScroll: onScroll)
        )
    }
}

private struct ScrollEventView: NSViewRepresentable {
    var onScroll: (NSEvent) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onScroll: onScroll)
    }

    func makeNSView(context: Context) -> EventHandlingView {
        let view = EventHandlingView()
        view.coordinator = context.coordinator
        return view
    }

    func updateNSView(_ nsView: EventHandlingView, context: Context) {
        context.coordinator.onScroll = onScroll
    }

    class Coordinator {
        var onScroll: (NSEvent) -> Void
        init(onScroll: @escaping (NSEvent) -> Void) {
            self.onScroll = onScroll
        }
    }

    class EventHandlingView: NSView {
        weak var coordinator: Coordinator?

        override var acceptsFirstResponder: Bool { true }

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            window?.makeFirstResponder(self)
        }

        override func scrollWheel(with event: NSEvent) {
            coordinator?.onScroll(event)
        }
    }
}

// MARK: - Custom Text Editor

struct CustomTextEditor: NSViewRepresentable {
    @Binding var text: String
    var font: NSFont
    var textColor: NSColor
    var backgroundColor: NSColor?
    var maxWidth: CGFloat = 400
    var onHeightChange: ((CGFloat) -> Void)?
    var onSizeChange: ((CGSize) -> Void)?

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSTextView.scrollableTextView()
        let textView = scrollView.documentView as! NSTextView

        textView.delegate = context.coordinator
        scrollView.hasVerticalScroller = false
        scrollView.drawsBackground = false
        scrollView.borderType = .noBorder

        textView.isRichText = false
        textView.font = font
        textView.textColor = textColor

        if let bgColor = backgroundColor {
            textView.drawsBackground = true
            textView.backgroundColor = bgColor
            textView.wantsLayer = true
            textView.layer?.cornerRadius = 6
            textView.layer?.masksToBounds = true
            textView.textContainerInset = NSSize(width: 8, height: 4)
        } else {
            textView.drawsBackground = false
            textView.backgroundColor = .clear
            textView.textContainerInset = NSSize(width: 0, height: 0)
        }

        textView.isSelectable = true
        textView.isEditable = true

        textView.textContainer?.lineFragmentPadding = 0
        textView.insertionPointColor = textColor

        // Load existing text so re-editing preserves content
        textView.string = text

        // Text wraps at maxWidth, only height grows
        let insetW = textView.textContainerInset.width * 2
        let containerWidth = max(100, maxWidth - insetW)
        textView.textContainer?.widthTracksTextView = false
        textView.textContainer?.containerSize = NSSize(width: containerWidth, height: CGFloat.greatestFiniteMagnitude)
        textView.isHorizontallyResizable = false
        textView.isVerticallyResizable = true
        textView.autoresizingMask = [.height]

        return scrollView
    }

    func updateNSView(_ nsView: NSScrollView, context: Context) {
        let textView = nsView.documentView as! NSTextView
        if textView.font != font {
            textView.font = font
        }
        if textView.textColor != textColor {
            textView.textColor = textColor
        }

        if let bgColor = backgroundColor {
            if textView.backgroundColor != bgColor {
                textView.drawsBackground = true
                textView.backgroundColor = bgColor
                textView.wantsLayer = true
                textView.layer?.cornerRadius = 6
                textView.layer?.masksToBounds = true
                textView.textContainerInset = NSSize(width: 8, height: 4)
            }
        } else {
            if textView.drawsBackground {
                textView.drawsBackground = false
                textView.backgroundColor = .clear
                textView.textContainerInset = NSSize(width: 0, height: 0)
            }
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    static func dismantleNSView(_ nsView: NSScrollView, coordinator: Coordinator) {
        if let textView = nsView.documentView as? NSTextView {
            textView.delegate = nil
            textView.string = ""
        }
    }

    class Coordinator: NSObject, NSTextViewDelegate {
        var parent: CustomTextEditor

        init(_ parent: CustomTextEditor) {
            self.parent = parent
        }

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            self.parent.text = textView.string

            guard let layoutManager = textView.layoutManager,
                  let textContainer = textView.textContainer else { return }
            layoutManager.ensureLayout(for: textContainer)
            let usedRect = layoutManager.usedRect(for: textContainer)

            let inset = textView.textContainerInset
            let verticalInset = inset.height * 2

            let minHeight: CGFloat = 20
            let newHeight = max(minHeight, usedRect.height + verticalInset)

            // Width is fixed (container width + insets), only height grows
            let newWidth = self.parent.maxWidth

            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.parent.onHeightChange?(newHeight)
                self.parent.onSizeChange?(CGSize(width: newWidth, height: newHeight))
            }
        }
    }
}

// MARK: - Export Accessory View

struct ExportAccessoryView: View {
    @Binding var format: ExportFormat
    @Binding var jpegQuality: CGFloat

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Format:").font(.caption)
                Picker("", selection: $format) {
                    ForEach(ExportFormat.allCases) { fmt in
                        Text(fmt.rawValue).tag(fmt)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 180)
            }

            if format == .jpeg {
                HStack {
                    Text("Quality:").font(.caption)
                    Slider(value: $jpegQuality, in: 0.1...1.0)
                    Text("\(Int(jpegQuality * 100))%").font(.caption2).frame(width: 32)
                }
            }
        }
        .padding(8)
    }
}

// MARK: - Text Detection for Blur/Erase

import Vision

struct TextRegionDetector {
    /// Detect text bounding boxes within a region of an image.
    /// Returns rects in image coordinates (origin top-left).
    static func detectTextRegions(in image: NSImage, within region: CGRect) -> [CGRect] {
        guard let tiffData = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData),
              let cgImage = bitmap.cgImage else { return [] }

        let imageWidth = CGFloat(cgImage.width)
        let imageHeight = CGFloat(cgImage.height)

        var textRects: [CGRect] = []
        let request = VNRecognizeTextRequest { request, _ in
            guard let observations = request.results as? [VNRecognizedTextObservation] else { return }
            for observation in observations {
                // VNRecognizedTextObservation.boundingBox is in normalized coords (origin bottom-left)
                let box = observation.boundingBox
                let imgRect = CGRect(
                    x: box.origin.x * imageWidth,
                    y: (1 - box.origin.y - box.height) * imageHeight,
                    width: box.width * imageWidth,
                    height: box.height * imageHeight
                )
                // Only include if it intersects with the region
                if imgRect.intersects(region) {
                    textRects.append(imgRect.intersection(region))
                }
            }
        }
        request.recognitionLevel = .fast
        request.usesLanguageCorrection = false

        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        try? handler.perform([request])

        return textRects
    }
}
