//
//  AreaSelectionView.swift
//  Clippy
//
//  Created by Mehmet Akbaba on 29.10.2025.
//

import AppKit

/// Alan seçim penceresi
class SelectionWindow: NSWindow {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

/// Kullanıcının ekrandan bir alan seçmesini sağlayan view
class AreaSelectionView: NSView {
    var onSelectionComplete: ((CGRect) -> Void)?
    var onCancel: (() -> Void)?

    private var startPoint: NSPoint?
    private var currentRect: NSRect?
    private let instructionLabel: NSTextField

    override init(frame frameRect: NSRect) {
        // DÜZELTME: Metinleri yerelleştirilebilir hale getir.
        self.instructionLabel = {
            let label = NSTextField(labelWithString: L("Select an area to record\nESC to cancel", settings: SettingsManager.shared))
            label.textColor = .white
            label.alignment = .center
            label.font = .systemFont(ofSize: 16, weight: .medium)
            label.drawsBackground = true
            label.backgroundColor = NSColor.black.withAlphaComponent(0.7)
            label.isBordered = false
            return label
        }()
        super.init(frame: frameRect)
        setup()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setup() {
        instructionLabel.sizeToFit()
        instructionLabel.frame.size.width += 40
        instructionLabel.frame.size.height += 20
        instructionLabel.frame.origin = NSPoint(
            x: (bounds.width - instructionLabel.frame.width) / 2,
            y: bounds.height - instructionLabel.frame.height - 50
        )
        addSubview(instructionLabel)
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        // Koyu overlay
        NSColor.black.withAlphaComponent(0.4).setFill()
        bounds.fill()

        // Seçili alan (transparan)
        if let rect = currentRect {
            NSColor.clear.setFill()
            rect.fill(using: .copy)

            // Çerçeve
            NSColor.systemBlue.setStroke()
            let path = NSBezierPath(rect: rect)
            path.lineWidth = 3
            path.stroke()

            // Boyut etiketi
            let sizeText = "\(Int(rect.width)) × \(Int(rect.height))"
            let attrs: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: 12),
                .foregroundColor: NSColor.white
            ]
            let size = sizeText.size(withAttributes: attrs)
            let labelRect = NSRect(
                x: rect.maxX - size.width - 10,
                y: rect.maxY + 5,
                width: size.width + 10,
                height: size.height + 4
            )

            NSColor.black.withAlphaComponent(0.7).setFill()
            labelRect.fill()
            sizeText.draw(at: NSPoint(x: labelRect.minX + 5, y: labelRect.minY + 2), withAttributes: attrs)
        }
    }

    override func mouseDown(with event: NSEvent) {
        startPoint = convert(event.locationInWindow, from: nil)
        currentRect = nil
        instructionLabel.isHidden = true
    }

    override func mouseDragged(with event: NSEvent) {
        guard let start = startPoint else { return }
        let current = convert(event.locationInWindow, from: nil)

        let x = min(start.x, current.x)
        let y = min(start.y, current.y)
        let w = abs(current.x - start.x)
        let h = abs(current.y - start.y)

        currentRect = NSRect(x: x, y: y, width: w, height: h)
        needsDisplay = true
    }

    override func mouseUp(with event: NSEvent) {
        guard let rect = currentRect, rect.width > 10, rect.height > 10 else {
            instructionLabel.isHidden = false
            needsDisplay = true
            return
        }

        // Koordinatları ekran koordinatlarına çevir
        guard let screen = NSScreen.main else { return }
        let flippedY = screen.frame.height - rect.origin.y - rect.height
        let screenRect = CGRect(x: rect.origin.x, y: flippedY, width: rect.width, height: rect.height)

        onSelectionComplete?(screenRect)
    }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 { // ESC
            onCancel?()
        }
    }

    override var acceptsFirstResponder: Bool { true }
}
