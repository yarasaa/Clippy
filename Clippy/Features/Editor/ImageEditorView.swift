//
//  ImageEditorView.swift
//  Clippy
//
//  Created by Mehmet Akbaba on 28.09.2025.
//

import SwiftUI

struct ImageEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var settings: SettingsManager

    let image: NSImage
    let onSave: (NSImage) -> Void

    @State private var shapes: [DrawableShape] = []
    @State private var selectedTool: Tool = .arrow
    @State private var selectedColor: Color = .red
    
    private static let availableColors: [Color] = [
        .red,
        .orange,
        .yellow,
        .green,
        .blue,
        .purple,
        .black,
        .white
    ]
    enum Tool {
        case arrow, rectangle, text
    }

    var body: some View {
        VStack(spacing: 0) {
            editorToolbar
                .padding()
                .background(.bar)

            DrawingCanvas(image: image, shapes: $shapes, selectedTool: $selectedTool, selectedColor: $selectedColor) { text, rect in
                let newTextShape = TextShape(text: text, rect: rect, color: NSColor(selectedColor))
                shapes.append(newTextShape)
            }
        }
        .frame(minWidth: 600, idealWidth: max(600, image.size.width),
               minHeight: 400, idealHeight: max(400, image.size.height + 100))
    }

    private var editorToolbar: some View {
        HStack {
            Picker("Tool", selection: $selectedTool) {
                Image(systemName: "arrow.up.right").tag(Tool.arrow)
                Image(systemName: "square").tag(Tool.rectangle)
                Image(systemName: "textformat").tag(Tool.text)
            }
            .pickerStyle(.segmented)
            .frame(width: 160)

            Button {
                undoLastAction()
            } label: {
                Image(systemName: "arrow.uturn.backward")
            }
            .disabled(shapes.isEmpty)
            .keyboardShortcut("z", modifiers: .command)
            .help(L("Undo last action", settings: settings))

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(ImageEditorView.availableColors, id: \.self) { color in
                        Button {
                            selectedColor = color
                        } label: {
                            Circle()
                                .fill(color)
                                .frame(width: 24, height: 24)
                                .overlay(
                                    Circle().stroke(selectedColor == color ? Color.accentColor : Color.gray, lineWidth: selectedColor == color ? 2 : 1)
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            
            Spacer()

            Button(L("Cancel", settings: settings)) {
                dismiss()
            }
            .keyboardShortcut(.escape, modifiers: [])

            Button(L("Save", settings: settings)) {
                saveImage()
            }
            .buttonStyle(.borderedProminent)
        }
    }

    private func undoLastAction() {
        if !shapes.isEmpty {
            _ = shapes.popLast()
        }
    }

    private func saveImage() {
        let finalImage = renderImage()
        onSave(finalImage)
        dismiss()
    }

    private func renderImage() -> NSImage {
        let newImage = NSImage(size: image.size, flipped: false) { rect in
            self.image.draw(in: rect)

            for shape in self.shapes {
                shape.draw(in: rect)
            }
            return true
        }
        return newImage
    }
}

// MARK: - Drawing Canvas

struct DrawingCanvas: NSViewRepresentable {
    let image: NSImage
    @Binding var shapes: [DrawableShape]
    @Binding var selectedTool: ImageEditorView.Tool
    @Binding var selectedColor: Color
    let onAddText: (String, CGRect) -> Void

    func makeNSView(context: Context) -> DrawingNSView {
        let view = DrawingNSView(image: image)
        view.delegate = context.coordinator
        context.coordinator.onAddText = onAddText
        return view
    }

    func updateNSView(_ nsView: DrawingNSView, context: Context) {
        nsView.shapes = shapes
        nsView.selectedTool = selectedTool
        nsView.selectedColor = NSColor(selectedColor)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    // MARK: - Coordinator
    class Coordinator: NSObject, DrawingNSViewDelegate {
        var parent: DrawingCanvas
        var onAddText: ((String, CGRect) -> Void)?

        init(parent: DrawingCanvas) {
            self.parent = parent
        }

        func didAddShape(_ shape: DrawableShape) {
            parent.shapes.append(shape)
        }
    }
}

// MARK: - Shape Definitions

protocol DrawableShape {
    func draw(in rect: CGRect)
}

struct Arrow: DrawableShape {
    let start: CGPoint
    let end: CGPoint
    let color: NSColor

    func draw(in rect: CGRect) {
        let path = NSBezierPath()
        path.move(to: start)
        path.line(to: end)

        let angle = atan2(start.y - end.y, start.x - end.x)
        let arrowLength: CGFloat = 15
        let arrowAngle = CGFloat.pi / 6

        let p1 = CGPoint(x: end.x + arrowLength * cos(angle + arrowAngle), y: end.y + arrowLength * sin(angle + arrowAngle))
        let p2 = CGPoint(x: end.x + arrowLength * cos(angle - arrowAngle), y: end.y + arrowLength * sin(angle - arrowAngle))

        path.move(to: p1)
        path.line(to: end)
        path.line(to: p2)

        color.setStroke()
        path.lineWidth = 2
        path.stroke()
    }
}
struct TextShape: DrawableShape {
    let text: String
    let rect: CGRect
    let color: NSColor

    func draw(in contextRect: CGRect) {
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.paragraphSpacing = 0
        paragraphStyle.lineSpacing = 0
               let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 24, weight: .bold),
            .foregroundColor: color,
            .paragraphStyle: paragraphStyle
        ]
        let attributedString = NSAttributedString(string: text, attributes: attributes)
        attributedString.draw(with: rect, options: .usesLineFragmentOrigin)
    }
}

struct Rectangle: DrawableShape {
    let rect: CGRect
    let color: NSColor

    func draw(in contextRect: CGRect) {
        let path = NSBezierPath(rect: rect)
        color.setStroke()
        path.lineWidth = 2
        path.stroke()
    }
}