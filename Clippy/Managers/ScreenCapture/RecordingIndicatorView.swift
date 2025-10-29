//
//  RecordingIndicatorView.swift
//  Clippy
//
//  Created by Mehmet Akbaba on 29.10.2025.
//

import AppKit

/// Kayıt sırasında seçilen alanı gösteren görsel gösterge
class RecordingIndicatorView: NSView {
    private var animationTimer: Timer?
    private var isVisible = true

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    private func setup() {
        // Yanıp sönen animasyon (0.5 saniyede bir)
        animationTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            self?.isVisible.toggle()
            self?.needsDisplay = true
        }
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        guard isVisible else { return }

        // Kırmızı çerçeve (ince)
        NSColor.systemRed.setStroke()
        let path = NSBezierPath(rect: bounds.insetBy(dx: 2, dy: 2))
        path.lineWidth = 3
        path.stroke()

        // Köşelerde kalın çizgiler (daha belirgin)
        let cornerLength: CGFloat = 30
        let cornerPath = NSBezierPath()
        cornerPath.lineWidth = 5

        // Sol üst köşe
        cornerPath.move(to: NSPoint(x: 5, y: cornerLength + 5))
        cornerPath.line(to: NSPoint(x: 5, y: 5))
        cornerPath.line(to: NSPoint(x: cornerLength + 5, y: 5))

        // Sağ üst köşe
        cornerPath.move(to: NSPoint(x: bounds.width - cornerLength - 5, y: 5))
        cornerPath.line(to: NSPoint(x: bounds.width - 5, y: 5))
        cornerPath.line(to: NSPoint(x: bounds.width - 5, y: cornerLength + 5))

        // Sağ alt köşe
        cornerPath.move(to: NSPoint(x: bounds.width - 5, y: bounds.height - cornerLength - 5))
        cornerPath.line(to: NSPoint(x: bounds.width - 5, y: bounds.height - 5))
        cornerPath.line(to: NSPoint(x: bounds.width - cornerLength - 5, y: bounds.height - 5))

        // Sol alt köşe
        cornerPath.move(to: NSPoint(x: cornerLength + 5, y: bounds.height - 5))
        cornerPath.line(to: NSPoint(x: 5, y: bounds.height - 5))
        cornerPath.line(to: NSPoint(x: 5, y: bounds.height - cornerLength - 5))

        NSColor.systemRed.setStroke()
        cornerPath.stroke()
    }

    deinit {
        animationTimer?.invalidate()
    }
}
