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

    // CIImage(cgImage:) wraps the existing pixels; going via
    // tiffRepresentation would serialise the whole image first. See
    // ImageEncoding.swift for the measurements.
    guard let cgSource = sourceImage.storageCGImage else { return nil }
    let ciImage = CIImage(cgImage: cgSource)

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

    // CIImage(cgImage:) wraps the existing pixels; going via
    // tiffRepresentation would serialise the whole image first. See
    // ImageEncoding.swift for the measurements.
    guard let cgSource = sourceImage.storageCGImage else { return nil }
    let ciImage = CIImage(cgImage: cgSource)

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

/// Single source of truth for how a text annotation's font is built.
///
/// The Inspector has offered a font-family picker (Default / Round /
/// Serif / Mono) for a while, but `Annotation.fontName` was never read by
/// either the canvas renderer or the live editor — picking "Serif" lit
/// the chip up and changed nothing on screen. Both sides now resolve the
/// font from here so they can't disagree again.
enum AnnotationFont {

    static func design(for fontName: String?) -> Font.Design {
        switch fontName {
        case "rounded": return .rounded
        case "serif":   return .serif
        case "mono":    return .monospaced
        default:        return .default
        }
    }

    /// Text annotations reuse the shared `lineWidth` field to carry their
    /// font size, scaled by this factor. Every conversion goes through the
    /// two helpers below so the ratio lives in exactly one place — the
    /// Inspector used to show the raw `lineWidth` as "SIZE", meaning it
    /// reported 10 for what was actually 40pt type.
    static let pointsPerLineWidth: CGFloat = 4

    static func pointSize(fromLineWidth lineWidth: CGFloat) -> CGFloat {
        lineWidth * pointsPerLineWidth
    }

    static func lineWidth(fromPointSize pointSize: CGFloat) -> CGFloat {
        pointSize / pointsPerLineWidth
    }

    /// Point size for an annotation.
    static func size(for annotation: Annotation, scale: CGFloat = 1) -> CGFloat {
        pointSize(fromLineWidth: annotation.lineWidth) * scale
    }

    /// SwiftUI font used by the canvas renderer.
    static func swiftUIFont(for annotation: Annotation) -> Font {
        var font = Font.system(
            size: size(for: annotation),
            weight: annotation.isBold ? .bold : .regular,
            design: design(for: annotation.fontName)
        )
        if annotation.isItalic { font = font.italic() }
        return font
    }

    /// AppKit font used by the live NSTextView, matched to the above.
    static func nsFont(for annotation: Annotation, scale: CGFloat = 1) -> NSFont {
        let pointSize = size(for: annotation, scale: scale)
        let base = annotation.isBold
            ? NSFont.boldSystemFont(ofSize: pointSize)
            : NSFont.systemFont(ofSize: pointSize)

        var descriptor = base.fontDescriptor
        switch design(for: annotation.fontName) {
        case .rounded:    descriptor = descriptor.withDesign(.rounded) ?? descriptor
        case .serif:      descriptor = descriptor.withDesign(.serif) ?? descriptor
        case .monospaced: descriptor = descriptor.withDesign(.monospaced) ?? descriptor
        default:          break
        }
        if annotation.isItalic {
            descriptor = descriptor.withSymbolicTraits(
                descriptor.symbolicTraits.union(.italic)
            )
        }
        return NSFont(descriptor: descriptor, size: pointSize) ?? base
    }
}

/// Builds the attributed string for a text annotation.
///
/// The canvas used to render text with SwiftUI's `Text`, which can't
/// express an outline, letter spacing or line height — so `textStrokeWidth`,
/// `textLetterSpacing`, `textLineHeight` and even `textAlignment` were all
/// stored, exposed in the Inspector, and then quietly ignored at draw time.
/// One attributed string covers every one of them.
enum AnnotationTextStyle {

    static func attributes(for annotation: Annotation, scale: CGFloat = 1) -> [NSAttributedString.Key: Any] {
        let font = AnnotationFont.nsFont(for: annotation, scale: scale)

        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = annotation.textAlignment.nsTextAlignment
        paragraph.lineBreakMode = .byWordWrapping
        if annotation.textLineHeight != 1.0 {
            paragraph.lineHeightMultiple = annotation.textLineHeight
        }

        var attrs: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: NSColor(annotation.color),
            .paragraphStyle: paragraph
        ]

        if annotation.textLetterSpacing != 0 {
            attrs[.kern] = annotation.textLetterSpacing * scale
        }

        if annotation.textStrokeWidth > 0 {
            // A NEGATIVE strokeWidth means "stroke *and* fill". A positive
            // value would draw only the outline, leaving hollow letters —
            // which is not what an outline control is asking for. The value
            // is a percentage of font size, hence the sign flip only.
            attrs[.strokeWidth] = -annotation.textStrokeWidth
            attrs[.strokeColor] = NSColor(annotation.textStrokeColor)
        }

        return attrs
    }

    static func attributedString(for annotation: Annotation, scale: CGFloat = 1) -> NSAttributedString {
        NSAttributedString(string: annotation.text, attributes: attributes(for: annotation, scale: scale))
    }

    /// Y offset that places the text block according to the annotation's
    /// vertical alignment inside `containerHeight`.
    static func verticalOffset(for annotation: Annotation,
                               textHeight: CGFloat,
                               containerHeight: CGFloat) -> CGFloat {
        let slack = max(0, containerHeight - textHeight)
        switch annotation.textVerticalAlignment {
        case .top:    return 0
        case .center: return slack / 2
        case .bottom: return slack
        }
    }
}

/// NSTextView that reports the two "I'm done" gestures back to SwiftUI.
///
/// Needed because `.onSubmit` / `.onExitCommand` don't fire for an
/// NSViewRepresentable — the text view consumes key events itself, so
/// those SwiftUI modifiers were silently dead and there was no reliable
/// way to finish editing except clicking somewhere else.
///
/// Return still inserts a newline (annotations are multi-line); ⌘Return
/// commits, matching the convention in Notes, Mail and Xcode comments.
final class AnnotationTextView: NSTextView {
    var onCommit: (() -> Void)?
    /// ⌘+ / ⌘− : +1 or −1 step of font size.
    var onAdjustSize: ((CGFloat) -> Void)?
    /// ⌘B / ⌘I.
    var onToggleBold: (() -> Void)?
    var onToggleItalic: (() -> Void)?

    override func cancelOperation(_ sender: Any?) {
        onCommit?()
    }

    override func keyDown(with event: NSEvent) {
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)

        if flags.contains(.command) {
            let isReturn = event.keyCode == 36 || event.keyCode == 76
            if isReturn {
                onCommit?()
                return
            }
            // Font-size and style shortcuts have to be intercepted here:
            // NSTextView is a plain-text field, so it doesn't implement
            // them itself, and SwiftUI `.keyboardShortcut` never sees keys
            // while an AppKit responder has focus.
            switch event.charactersIgnoringModifiers {
            case "+", "=":
                onAdjustSize?(2)
                return
            case "-", "_":
                onAdjustSize?(-2)
                return
            case "b", "B":
                onToggleBold?()
                return
            case "i", "I":
                onToggleItalic?()
                return
            default:
                break
            }
        }

        super.keyDown(with: event)
    }
}

struct CustomTextEditor: NSViewRepresentable {
    @Binding var text: String
    var font: NSFont
    var textColor: NSColor
    var backgroundColor: NSColor?
    var maxWidth: CGFloat = 400
    var onHeightChange: ((CGFloat) -> Void)?
    var onSizeChange: ((CGSize) -> Void)?
    /// Esc or ⌘Return — the user is finished with this annotation.
    var onCommit: (() -> Void)?
    /// Typing attributes mirrored from the annotation (outline, kerning,
    /// line height, alignment) so what you type looks like what you get.
    var typingAttributes: [NSAttributedString.Key: Any] = [:]
    /// Where the text sits vertically in the box. The canvas offsets the
    /// rendered text for this; without matching it here the text would
    /// move the moment editing ended — the same jump the shared
    /// `contentInset` was introduced to remove.
    var verticalAlignment: VerticalTextAlignment = .top
    /// ⌘+ / ⌘− while typing. Delta is in points.
    var onAdjustSize: ((CGFloat) -> Void)?
    var onToggleBold: (() -> Void)?
    var onToggleItalic: (() -> Void)?

    /// Padding around the text. Kept identical to the inset the canvas
    /// renderer uses so the text doesn't visibly jump the moment editing
    /// ends; previously the editor used (0,0) when there was no background
    /// while the renderer always drew at +8/+4.
    static let contentInset = NSSize(width: 8, height: 4)

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        let textView = AnnotationTextView()

        textView.onCommit = onCommit
        textView.onAdjustSize = onAdjustSize
        textView.onToggleBold = onToggleBold
        textView.onToggleItalic = onToggleItalic
        textView.delegate = context.coordinator
        textView.minSize = .zero
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude,
                                  height: CGFloat.greatestFiniteMagnitude)

        scrollView.documentView = textView
        scrollView.hasVerticalScroller = false
        scrollView.drawsBackground = false
        scrollView.borderType = .noBorder

        textView.isRichText = false
        textView.font = font
        textView.textColor = textColor
        textView.textContainerInset = Self.contentInset

        if let bgColor = backgroundColor {
            textView.drawsBackground = true
            textView.backgroundColor = bgColor
            textView.wantsLayer = true
            textView.layer?.cornerRadius = 6
            textView.layer?.masksToBounds = true
        } else {
            textView.drawsBackground = false
            textView.backgroundColor = .clear
        }

        textView.isSelectable = true
        textView.isEditable = true

        textView.textContainer?.lineFragmentPadding = 0
        textView.insertionPointColor = textColor

        // Load existing text so re-editing preserves content
        textView.string = text
        applyStyle(to: textView)

        // Put the caret in the box straight away. `.focused()` in the
        // SwiftUI layer does nothing for an NSViewRepresentable, so
        // without this the user had to click into a box they had just
        // created before they could type a single character.
        DispatchQueue.main.async {
            guard textView.window != nil else { return }
            textView.window?.makeFirstResponder(textView)
            textView.setSelectedRange(NSRange(location: (textView.string as NSString).length, length: 0))
        }

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
        guard let textView = nsView.documentView as? AnnotationTextView else { return }
        textView.onCommit = onCommit
        textView.onAdjustSize = onAdjustSize
        textView.onToggleBold = onToggleBold
        textView.onToggleItalic = onToggleItalic
        if textView.font != font {
            textView.font = font
        }
        if textView.textColor != textColor {
            textView.textColor = textColor
            textView.insertionPointColor = textColor
        }

        if let bgColor = backgroundColor {
            if textView.backgroundColor != bgColor {
                textView.drawsBackground = true
                textView.backgroundColor = bgColor
                textView.wantsLayer = true
                textView.layer?.cornerRadius = 6
                textView.layer?.masksToBounds = true
            }
        } else if textView.drawsBackground {
            textView.drawsBackground = false
            textView.backgroundColor = .clear
        }
        // Inset stays constant either way — see `contentInset`.
        applyStyle(to: textView)
        applyVerticalAlignment(to: textView)
    }

    /// NSTextView always lays text out from the top, so vertical alignment
    /// is expressed by padding the top inset with whatever slack the box
    /// has left over.
    private func applyVerticalAlignment(to textView: NSTextView) {
        guard verticalAlignment != .top else {
            if textView.textContainerInset.height != Self.contentInset.height {
                textView.textContainerInset = Self.contentInset
            }
            return
        }
        guard let layoutManager = textView.layoutManager,
              let container = textView.textContainer else { return }

        layoutManager.ensureLayout(for: container)
        let textHeight = layoutManager.usedRect(for: container).height
        let available = textView.bounds.height - Self.contentInset.height * 2
        let slack = max(0, available - textHeight)
        let top = Self.contentInset.height + (verticalAlignment == .center ? slack / 2 : slack)

        if abs(textView.textContainerInset.height - top) > 0.5 {
            textView.textContainerInset = NSSize(width: Self.contentInset.width, height: top)
        }
    }

    /// Pushes the annotation's typography onto the live text view, so an
    /// outline or letter spacing is visible while typing rather than only
    /// appearing once editing ends.
    private func applyStyle(to textView: NSTextView) {
        guard !typingAttributes.isEmpty else { return }
        var attrs = typingAttributes
        attrs[.font] = font
        attrs[.foregroundColor] = textColor
        textView.typingAttributes = attrs

        let full = NSRange(location: 0, length: (textView.string as NSString).length)
        guard full.length > 0 else { return }

        // Detach the delegate first. Re-styling the storage posts
        // NSTextDidChange, and this runs from updateNSView — so the
        // delegate would write straight back into the SwiftUI binding
        // *during a view update*, which is exactly the "Publishing changes
        // from within view updates is not allowed" case. The text isn't
        // changing here, only its attributes, so there's nothing for the
        // delegate to report.
        let delegate = textView.delegate
        textView.delegate = nil
        textView.textStorage?.setAttributes(attrs, range: full)
        textView.delegate = delegate
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
            let minHeight: CGFloat = 20
            let newHeight = max(minHeight, usedRect.height + inset.height * 2)

            // Natural width = the longest line if nothing were wrapping.
            // `usedRect` is clamped to the container, so it can only ever
            // report the box we already have — measuring unconstrained is
            // what lets a click-placed box hug its content instead of
            // staying at the width it was guessed to need.
            let attributes = textView.typingAttributes.isEmpty
                ? [NSAttributedString.Key.font: textView.font ?? NSFont.systemFont(ofSize: 12)]
                : textView.typingAttributes
            let natural = (textView.string as NSString).boundingRect(
                with: NSSize(width: CGFloat.greatestFiniteMagnitude,
                             height: CGFloat.greatestFiniteMagnitude),
                options: [.usesLineFragmentOrigin, .usesFontLeading],
                attributes: attributes
            )
            // +2 covers the sub-pixel the layout manager rounds off, which
            // otherwise clips the last glyph.
            let newWidth = ceil(natural.width) + inset.width * 2 + 2

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
        guard let bitmap = image.storageBitmapRep,
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
