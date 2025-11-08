//
//  DrawingNSView.swift
//  Clippy


import AppKit
protocol DrawingNSViewDelegate: AnyObject {
    func didPickColor(_ color: NSColor)
    func didUpdateZoom(scale: CGFloat, offset: CGVector)
}

class DrawingNSView: NSView {
    weak var delegate: DrawingNSViewDelegate?
    let image: NSImage
    var zoomScale: CGFloat = 1.0
    var viewOffset: CGVector = .zero

    private var trackingArea: NSTrackingArea?
    private var currentMouseLocation: NSPoint?

    init(image: NSImage) {
        self.image = image
        super.init(frame: .zero)
        self.wantsLayer = true
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let trackingArea = self.trackingArea {
            removeTrackingArea(trackingArea)
        }
        let options: NSTrackingArea.Options = [.mouseMoved, .activeInKeyWindow, .mouseEnteredAndExited]
        trackingArea = NSTrackingArea(rect: self.bounds, options: options, owner: self, userInfo: nil)
        if let trackingArea = trackingArea {
            addTrackingArea(trackingArea)
        }
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        resetViewToFit()
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        NSGraphicsContext.saveGraphicsState()

        NSBezierPath(rect: self.bounds).addClip()

        NSGraphicsContext.current?.imageInterpolation = .high

        let transform = NSAffineTransform()
        transform.translateX(by: viewOffset.dx, yBy: viewOffset.dy)
        transform.scale(by: zoomScale)
        transform.concat()

        image.draw(in: CGRect(origin: .zero, size: image.size))

        NSGraphicsContext.restoreGraphicsState()

        if let location = currentMouseLocation, let color = getColor(at: location) {
            drawColorPickerLoupe(at: location, color: color, hex: colorToHex(color))
        }
    }

    override func mouseDown(with event: NSEvent) {
        let viewPoint = convert(event.locationInWindow, from: nil)
        if let color = getColor(at: viewPoint) {
            delegate?.didPickColor(color)
        }
    }

    override func mouseMoved(with event: NSEvent) {
        currentMouseLocation = convert(event.locationInWindow, from: nil)
        needsDisplay = true
    }

    override func mouseExited(with event: NSEvent) {
        currentMouseLocation = nil
        needsDisplay = true
    }

    override func scrollWheel(with event: NSEvent) {
        if event.modifierFlags.contains(.command) {
            let zoomFactor: CGFloat = 0.1
            let zoomDelta = event.scrollingDeltaY * zoomFactor
            let newScale = max(0.2, min(10.0, zoomScale + zoomDelta))

            let mouseLocationInView = convert(event.locationInWindow, from: nil)

            let pointToZoom = CGPoint(x: mouseLocationInView.x - viewOffset.dx, y: mouseLocationInView.y - viewOffset.dy)

            viewOffset.dx = mouseLocationInView.x - pointToZoom.x * (newScale / zoomScale)
            viewOffset.dy = mouseLocationInView.y - pointToZoom.y * (newScale / zoomScale)

            zoomScale = newScale

        } else {
            viewOffset.dx += event.scrollingDeltaX
            viewOffset.dy -= event.scrollingDeltaY
        }
        needsDisplay = true
        delegate?.didUpdateZoom(scale: zoomScale, offset: viewOffset)
    }

    private func drawColorPickerLoupe(at location: NSPoint, color: NSColor, hex: String) {        
        let loupeSize: CGFloat = 100
        let yOffset: CGFloat = 25
        let loupeRect = CGRect(x: location.x - (loupeSize / 2), y: location.y + yOffset, width: loupeSize, height: loupeSize)

        let path = NSBezierPath(roundedRect: loupeRect, xRadius: 8, yRadius: 8)
        NSColor.black.withAlphaComponent(0.6).setFill()
        path.fill()

        let colorBoxRect = CGRect(x: loupeRect.minX + 10, y: loupeRect.minY + 35, width: loupeSize - 20, height: loupeSize - 45)
        color.drawSwatch(in: colorBoxRect)
        NSColor.white.withAlphaComponent(0.5).setStroke()
        NSBezierPath(rect: colorBoxRect).stroke()

        let textRect = CGRect(x: loupeRect.minX, y: loupeRect.minY + 10, width: loupeSize, height: 20)
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = .center
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedSystemFont(ofSize: 14, weight: .bold),
            .foregroundColor: NSColor.white,
            .paragraphStyle: paragraphStyle
        ]
        hex.draw(in: textRect, withAttributes: attributes)
    }

    private func getColor(at point: NSPoint) -> NSColor? {
        let modelPoint = convertToModelPoint(point)

        let imageBounds = CGRect(origin: .zero, size: image.size)
        guard imageBounds.contains(modelPoint) else { return nil }

        var imageRect = CGRect(origin: .zero, size: image.size)
        guard let cgImage = image.cgImage(forProposedRect: &imageRect, context: nil, hints: nil) else { return nil }

        let bitmapRep = NSBitmapImageRep(cgImage: cgImage)

        let invertedY = image.size.height - modelPoint.y

        return bitmapRep.colorAt(x: Int(modelPoint.x), y: Int(invertedY))
    }

    private func colorToHex(_ color: NSColor) -> String {
        guard let rgbColor = color.usingColorSpace(.sRGB) else { return "N/A" }
        let red = Int(round(rgbColor.redComponent * 255))
        let green = Int(round(rgbColor.greenComponent * 255))
        let blue = Int(round(rgbColor.blueComponent * 255))

        return String(format: "#%02X%02X%02X", red, green, blue)
    }

    private func convertToModelPoint(_ viewPoint: NSPoint) -> NSPoint {
        let x = (viewPoint.x - viewOffset.dx) / zoomScale
        let y = (viewPoint.y - viewOffset.dy) / zoomScale

        return NSPoint(x: x, y: y)
    }

    private func updateCursor() {
        NSCursor.crosshair.set()
    }

    private func resetViewToFit() {
        guard bounds.width > 0, bounds.height > 0 else { return }

        let viewSize = bounds.size
        let imageSize = image.size

        let scaleX = viewSize.width / imageSize.width
        let scaleY = viewSize.height / imageSize.height
        zoomScale = min(scaleX, scaleY)

        viewOffset = CGVector(dx: (viewSize.width - imageSize.width * zoomScale) / 2, dy: (viewSize.height - imageSize.height * zoomScale) / 2)

        needsDisplay = true
        delegate?.didUpdateZoom(scale: zoomScale, offset: viewOffset)
    }
}
