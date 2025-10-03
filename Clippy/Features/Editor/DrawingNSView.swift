//
//  DrawingNSView.swift
//  Clippy
//
//  Created by Mehmet Akbaba on 28.09.2025.
//

import AppKit
protocol DrawingNSViewDelegate: AnyObject {
    func didAddShape(_ shape: DrawableShape)
}

class DrawingNSView: NSView {
    weak var delegate: DrawingNSViewDelegate?
    let image: NSImage
    var shapes: [DrawableShape] = [] {
        didSet { needsDisplay = true }
    }
    var selectedTool: ImageEditorView.Tool = .arrow
    var selectedColor: NSColor = .red
    var cropRect: CGRect?
    private var startPoint: CGPoint?
    private var currentShape: DrawableShape?
    private var activeTextView: NSTextView?

    init(image: NSImage) {
        self.image = image
        super.init(frame: .zero)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        image.draw(in: bounds)

        for shape in shapes {
            shape.draw(in: bounds)
        }

        currentShape?.draw(in: bounds)

    }

    // MARK: - Mouse Events

    override func mouseDown(with event: NSEvent) {
        startPoint = convert(event.locationInWindow, from: nil)
        
        if selectedTool == .text && activeTextView != nil {
            self.window?.makeFirstResponder(self)
        }

    }

    override func mouseDragged(with event: NSEvent) {
        guard let startPoint = startPoint else { return }
        let currentPoint = convert(event.locationInWindow, from: nil)

        switch selectedTool {
        case .arrow:
            currentShape = Arrow(start: startPoint, end: currentPoint, color: selectedColor)
        case .rectangle:
            let rect = CGRect(x: min(startPoint.x, currentPoint.x),
                              y: min(startPoint.y, currentPoint.y),
                              width: abs(currentPoint.x - startPoint.x),
                              height: abs(currentPoint.y - startPoint.y))
            currentShape = Rectangle(rect: rect, color: selectedColor)
        case .text:
            let rect = CGRect(x: min(startPoint.x, currentPoint.x),
                              y: min(startPoint.y, currentPoint.y),
                              width: abs(currentPoint.x - startPoint.x),
                              height: abs(currentPoint.y - startPoint.y))
            currentShape = Rectangle(rect: rect, color: .gray)
        }
        needsDisplay = true
    }

    override func mouseUp(with event: NSEvent) {
        guard let startPoint = self.startPoint else { return }
        let endPoint = convert(event.locationInWindow, from: nil)

        if selectedTool == .text {

            let rect = CGRect(x: min(startPoint.x, endPoint.x),
                              y: min(startPoint.y, endPoint.y),
                              width: abs(endPoint.x - startPoint.x),
                              height: abs(endPoint.y - startPoint.y))

            guard rect.width > 10 && rect.height > 10 else {
                self.startPoint = nil
                self.currentShape = nil
                needsDisplay = true
                return
            }

            let textView = NSTextView(frame: rect)
            textView.font = .systemFont(ofSize: 24, weight: .bold)
            textView.textColor = selectedColor
            textView.drawsBackground = false
            textView.isEditable = true
            textView.isSelectable = true
            
            textView.textContainerInset = .zero
            textView.textContainer?.lineFragmentPadding = 0
            
            let paragraphStyle = NSMutableParagraphStyle()
            paragraphStyle.paragraphSpacing = 0
            paragraphStyle.lineSpacing = 0
            textView.defaultParagraphStyle = paragraphStyle
            
            var observer: NSObjectProtocol?
            observer = NotificationCenter.default.addObserver(forName: NSText.didEndEditingNotification, object: textView, queue: .main) { [weak self] notification in
                guard let self = self, let tv = notification.object as? NSTextView, !tv.string.isEmpty else {
                    if let obs = observer { NotificationCenter.default.removeObserver(obs) }
                    return }

                (self.delegate as? DrawingCanvas.Coordinator)?.onAddText?(tv.string, tv.frame)
                self.currentShape = nil
                tv.removeFromSuperview()
                self.activeTextView = nil
                
                if let obs = observer { NotificationCenter.default.removeObserver(obs) }
                observer = nil

                self.needsDisplay = true
            }
            
            self.addSubview(textView)
            self.window?.makeFirstResponder(textView)
            self.activeTextView = textView
        } else if let finalShape = currentShape {
            delegate?.didAddShape(finalShape)
        }

        self.startPoint = nil
        self.currentShape = nil
    }
}