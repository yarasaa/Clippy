//
//  ScreenshotEditorView.swift
//  Clippy
//
//  Created by Mehmet Akbaba on 11.10.2025.
//


import SwiftUI
import Combine
import Vision

struct ViewSizeKey: PreferenceKey {
    static var defaultValue: CGSize = .zero
    static func reduce(value: inout CGSize, nextValue: () -> CGSize) {
        value = nextValue()
    }
}

enum NumberShape: String, CaseIterable {
    case circle = "Circle"
    case square = "Square"
    case roundedSquare = "Rounded Square"
}

enum FillMode: String, CaseIterable {
    case stroke = "Stroke"
    case fill = "Fill"
    case both = "Both"

    var icon: String {
        switch self {
        case .stroke: return "square"
        case .fill: return "square.fill"
        case .both: return "square.inset.filled"
        }
    }
}

enum DrawingTool: String, CaseIterable, Identifiable {
    case select, move, arrow, rectangle, ellipse, line, text, pin, pixelate, eraser, highlighter, spotlight, emoji, pen

    var icon: String {
        switch self {
        case .select: return "cursorarrow.click"
        case .move: return "arrow.up.and.down.and.arrow.left.and.right"
        case .arrow: return "arrow.up.right"
        case .rectangle: return "square"
        case .ellipse: return "circle"
        case .line: return "line.diagonal"
        case .text: return "textformat"
        case .pin: return "mappin.and.ellipse"
        case .pixelate: return "square.grid.3x3.fill"
        case .eraser: return "eraser.line.dashed"
        case .highlighter: return "highlighter"
        case .spotlight: return "scope"
        case .emoji: return "face.smiling"
        case .pen: return "pencil.tip"
        }
    }

    var id: String {
        self.rawValue
    }

    var isShape: Bool {
        switch self {
        case .rectangle, .ellipse, .line:
            return true
        default:
            return false
        }
    }

    var displayName: String {
        switch self {
        case .select: return "Select"
        case .move: return "Move"
        case .arrow: return "Arrow"
        case .rectangle: return "Rectangle"
        case .ellipse: return "Ellipse"
        case .line: return "Line"
        case .text: return "Text"
        case .pin: return "Pin"
        case .pixelate: return "Redact"
        case .eraser: return "Eraser"
        case .highlighter: return "Highlighter"
        case .spotlight: return "Spotlight"
        case .emoji: return "Emoji"
        case .pen: return "Pen"
        }
    }

    var localizedName: String {
        let key: String
        switch self {
        case .select: key = "tool.select"
        case .move: key = "tool.move"
        case .arrow: key = "tool.arrow"
        case .rectangle: key = "tool.rectangle"
        case .ellipse: key = "tool.ellipse"
        case .line: key = "tool.line"
        case .text: key = "tool.text"
        case .pin: key = "tool.pin"
        case .pixelate: key = "tool.pixelate"
        case .eraser: key = "tool.eraser"
        case .highlighter: key = "tool.highlighter"
        case .spotlight: key = "tool.spotlight"
        case .emoji: key = "tool.emoji"
        case .pen: key = "tool.pen"
        }

        let localized = NSLocalizedString(key, tableName: nil, bundle: .main, value: displayName, comment: "")
        return localized
    }
}

enum BrushStyle: String, CaseIterable, Identifiable {
    case solid = "Düz"
    case dashed = "Kesikli"
    case marker = "Marker"

    var id: String { self.rawValue }

    var displayName: String {
        switch self {
        case .solid: return "Solid"
        case .dashed: return "Dashed"
        case .marker: return "Marker"
        }
    }

    var localizedName: String {
        let key: String
        switch self {
        case .solid: key = "brush.solid"
        case .dashed: key = "brush.dashed"
        case .marker: key = "brush.marker"
        }

        let localized = NSLocalizedString(key, tableName: nil, bundle: .main, value: displayName, comment: "")
        return localized
    }
}

struct Annotation: Identifiable {
    let id = UUID()
    var rect: CGRect
    var color: Color
    var lineWidth: CGFloat = 4
    var tool: DrawingTool
    var text: String = ""
    var number: Int?
    var numberShape: NumberShape?
    var startPoint: CGPoint?
    var endPoint: CGPoint?
    var cornerRadius: CGFloat = 0
    var fillMode: FillMode = .stroke
    var spotlightShape: SpotlightShape?
    var emoji: String?
    var path: [CGPoint]?
    var brushStyle: BrushStyle?
    var backgroundColor: Color?
}

enum SpotlightShape: String, CaseIterable {
    case ellipse
    case rectangle

    var displayName: String {
        switch self {
        case .ellipse: return "Ellipse"
        case .rectangle: return "Rectangle"
        }
    }
}

enum BackdropFillModel: Equatable {
    case solid(Color)
    case linearGradient(start: Color, end: Color, startPoint: UnitPoint, endPoint: UnitPoint)
}

class ScreenshotEditorViewModel: ObservableObject {
    @Published var annotations: [Annotation] = []
    @Published var currentNumber: Int = 1

    deinit {
        annotations.removeAll()
        print("🧹 ScreenshotEditorViewModel: Deinit - Bellek serbest bırakıldı")
    }

    func addAnnotation(_ annotation: Annotation, undoManager: UndoManager?) {
        annotations.append(annotation)
        undoManager?.registerUndo(withTarget: self) { target in
            target.removeLastAnnotation(undoManager: undoManager)
        }
        objectWillChange.send()
    }

    func removeLastAnnotation(undoManager: UndoManager?) {
        guard let lastAnnotation = annotations.popLast() else { return }
        undoManager?.registerUndo(withTarget: self) { target in
            target.addAnnotation(lastAnnotation, undoManager: undoManager)
        }
        objectWillChange.send()
    }

    func moveAnnotation(at index: Int, to newRect: CGRect, from oldRect: CGRect, undoManager: UndoManager?) {
        guard index < annotations.count else { return }
        let originalRect = annotations[index].rect
        annotations[index].rect = newRect
        undoManager?.registerUndo(withTarget: self) { target in
            target.moveAnnotation(at: index, to: originalRect, from: newRect, undoManager: undoManager)
        }
        objectWillChange.send()
    }

    func updateAnnotationRect(at index: Int, newRect: CGRect, oldRect: CGRect, undoManager: UndoManager?) {
        guard index < annotations.count else { return }
        annotations[index].rect = newRect

        if annotations[index].tool == .arrow || annotations[index].tool == .line {
            annotations[index].startPoint = CGPoint(x: newRect.minX, y: newRect.minY)
            annotations[index].endPoint = CGPoint(x: newRect.maxX, y: newRect.maxY)
        }

        if annotations[index].tool == .pen, let path = annotations[index].path {
            let scaledPath = path.map { point in
                let normalizedX = (point.x - oldRect.minX) / oldRect.width
                let normalizedY = (point.y - oldRect.minY) / oldRect.height

                return CGPoint(
                    x: newRect.minX + normalizedX * newRect.width,
                    y: newRect.minY + normalizedY * newRect.height
                )
            }
            annotations[index].path = scaledPath
        }

        undoManager?.registerUndo(withTarget: self) { target in
            target.updateAnnotationRect(at: index, newRect: oldRect, oldRect: newRect, undoManager: undoManager)
        }
        objectWillChange.send()
    }

    func removeAnnotation(with id: UUID, undoManager: UndoManager?) {
        guard let index = annotations.firstIndex(where: { $0.id == id }) else { return }
        let removedAnnotation = annotations.remove(at: index)

        undoManager?.registerUndo(withTarget: self) { target in
            target.insertAnnotation(removedAnnotation, at: index, undoManager: undoManager)
        }
        objectWillChange.send()
    }

    func insertAnnotation(_ annotation: Annotation, at index: Int, undoManager: UndoManager?) {
        guard index <= annotations.count else { return }
        annotations.insert(annotation, at: index)
        undoManager?.registerUndo(withTarget: self) { target in
            target.removeAnnotation(with: annotation.id, undoManager: undoManager)
        }
        objectWillChange.send()
    }

    func updateAnnotationText(at index: Int, newText: String, oldText: String, undoManager: UndoManager?) {
        guard index < annotations.count else { return }
        annotations[index].text = newText
        undoManager?.registerUndo(withTarget: self) { target in
            target.updateAnnotationText(at: index, newText: oldText, oldText: newText, undoManager: undoManager)
        }
        objectWillChange.send()
    }
}

struct ScreenshotEditorView: View {
    @State var image: NSImage
    @EnvironmentObject var settings: SettingsManager
    var clipboardMonitor: ClipboardMonitor

    @StateObject private var viewModel = ScreenshotEditorViewModel()
    @Environment(\.dismiss) private var dismiss
    @State private var selectedTool: DrawingTool = .select
    @State private var selectedColor: Color = .red
    @State private var selectedLineWidth: CGFloat = 4

    @State private var isEditingText: Bool = false
    @FocusState private var isTextFieldFocused: Bool
    @State private var editingTextIndex: Int?

    @State private var movingAnnotationID: UUID?
    @State private var dragOffset: CGSize = .zero

    @State private var ocrButtonIcon = "text.viewfinder"
    @State private var isPerformingOCR = false

    @State private var showColorCopied = false

    @State private var showColorInspector = false
    @State private var inspectedColor: Color?
    @State private var mouseLocation: CGPoint = .zero

    @State private var showShapePicker = false
    @State private var showLineWidthPicker = false
    @State private var showEmojiPicker = false

    @State private var showToolControls = false
    @State private var selectedAnnotationID: UUID?

    @State private var numberSize: CGFloat = 40
    @State private var numberShape: NumberShape = .circle
    @State private var shapeCornerRadius: CGFloat = 0
    @State private var shapeFillMode: FillMode = .stroke
    @State private var spotlightShape: SpotlightShape = .ellipse
    @State private var selectedEmoji: String = "✅"
    @State private var emojiSize: CGFloat = 48
    @State private var selectedBrushStyle: BrushStyle = .solid

    @State private var zoomScale: CGFloat = 1.0
    @State private var lastZoomScale: CGFloat = 1.0
    @State private var zoomAnchor: UnitPoint = .center
    @State private var contentSize: CGSize = .zero

    @State private var showEffectsPanel = false
    @State private var backdropPadding: CGFloat = 40
    @State private var screenshotShadowRadius: CGFloat = 25
    @State private var screenshotCornerRadius: CGFloat = 0

    @State private var backdropCornerRadius: CGFloat = 16
    @State private var backdropFill: AnyShapeStyle = AnyShapeStyle(Color(nsColor: .windowBackgroundColor).opacity(0.8))
    @State private var backdropModel: BackdropFillModel = .solid(Color(nsColor: .windowBackgroundColor).opacity(0.8))
    @State private var backdropColor: Color = Color(nsColor: .windowBackgroundColor).opacity(0.8)

    @State private var scrollWheelMonitor: Any?
    @State private var escKeyMonitor: Any?

    @Environment(\.undoManager) private var undoManager

    var body: some View {
        VStack(spacing: 0) {
            topToolbar

            GeometryReader { geometry in
                ScrollView([.horizontal, .vertical], showsIndicators: zoomScale > 1.0) {
                    ZStack {
                        Color(nsColor: .textBackgroundColor)
                            .frame(
                                width: max(geometry.size.width, geometry.size.width * zoomScale),
                                height: max(geometry.size.height, geometry.size.height * zoomScale)
                            )

                        ZStack {
                    RoundedRectangle(cornerRadius: backdropCornerRadius)
                        .fill(backdropFill)
                        .shadow(radius: screenshotShadowRadius / 2)

                    Image(nsImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .clipShape(RoundedRectangle(cornerRadius: screenshotCornerRadius))
                        .shadow(radius: screenshotShadowRadius)
                        .overlay(
                            GeometryReader { overlayGeometry in
                                    ZStack {
                                        Image(nsImage: image)
                                            .resizable()
                                            .aspectRatio(contentMode: .fit)
                                        DrawingCanvasView(image: image, viewModel: viewModel, selectedTool: $selectedTool, selectedColor: $selectedColor, selectedLineWidth: $selectedLineWidth, numberSize: $numberSize, numberShape: $numberShape, shapeCornerRadius: $shapeCornerRadius, shapeFillMode: $shapeFillMode, spotlightShape: $spotlightShape, selectedEmoji: $selectedEmoji, emojiSize: $emojiSize, selectedBrushStyle: $selectedBrushStyle, movingAnnotationID: $movingAnnotationID, dragOffset: $dragOffset, editingTextIndex: $editingTextIndex, showToolControls: $showToolControls, selectedAnnotationID: $selectedAnnotationID, isEditingText: $isEditingText, backdropPadding: backdropPadding, canvasSize: overlayGeometry.size, onTextAnnotationCreated: { [weak viewModel] id in
                                            guard let viewModel = viewModel else { return }
                                            if let index = viewModel.annotations.lastIndex(where: { $0.id == id }) {
                                                startEditingText(at: index)
                                            }
                                        }, onStartEditingText: { index in
                                            startEditingText(at: index)
                                        }, onStopEditingText: {
                                            stopEditingText()
                                        })

                                        ForEach(viewModel.annotations.filter { $0.tool == .text }) { annotation in
                                            if let index = viewModel.annotations.firstIndex(where: { $0.id == annotation.id }) {
                                                let isEditing = isEditingText && index == editingTextIndex

                                            let imageSize = image.size
                                            let canvasSize = overlayGeometry.size

                                            let scale = min(canvasSize.width / imageSize.width, canvasSize.height / imageSize.height)

                                            let scaledImageSize = CGSize(
                                                width: imageSize.width * scale,
                                                height: imageSize.height * scale
                                            )

                                            let imageOffset = CGPoint(
                                                x: (canvasSize.width - scaledImageSize.width) / 2,
                                                y: (canvasSize.height - scaledImageSize.height) / 2
                                            )

                                            let canvasRect = CGRect(
                                                x: annotation.rect.origin.x * scale + imageOffset.x,
                                                y: annotation.rect.origin.y * scale + imageOffset.y,
                                                width: annotation.rect.width * scale,
                                                height: annotation.rect.height * scale
                                            )

                                            if isEditing {
                                                CustomTextEditor(
                                                    text: Binding(
                                                        get: { viewModel.annotations[index].text },
                                                        set: { newText in
                                                            let oldText = viewModel.annotations[index].text
                                                            if newText != oldText {
                                                                viewModel.updateAnnotationText(at: index, newText: newText, oldText: oldText, undoManager: undoManager)
                                                            }
                                                        }
                                                    ),
                                                    font: .systemFont(ofSize: annotation.lineWidth * 4 * scale),
                                                    textColor: NSColor(annotation.color),
                                                    backgroundColor: annotation.backgroundColor.map { NSColor($0) },
                                                    onHeightChange: { newHeight in
                                                        let imageHeight = newHeight / scale
                                                        if viewModel.annotations[index].rect.size.height != imageHeight {
                                                            viewModel.annotations[index].rect.size.height = imageHeight
                                                        }
                                                    },
                                                    onSizeChange: { newSize in
                                                        let imageSize = CGSize(width: newSize.width / scale, height: newSize.height / scale)
                                                        if viewModel.annotations[index].rect.size != imageSize {
                                                            viewModel.annotations[index].rect.size = imageSize
                                                        }
                                                    }
                                                )
                                                .focused($isTextFieldFocused)
                                                .frame(width: canvasRect.width, height: canvasRect.height)
                                                .position(x: canvasRect.midX, y: canvasRect.midY)
                                                .onSubmit { stopEditingText() }
                                                .onExitCommand { stopEditingText() }
                                            }
                                            }
                                        }
                                    }
                                }
                        )
                        .clipShape(RoundedRectangle(cornerRadius: screenshotCornerRadius))
                        .padding(backdropPadding)
                }
                .frame(width: geometry.size.width, height: geometry.size.height)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .scaleEffect(zoomScale, anchor: zoomAnchor)
                .coordinateSpace(name: "zoomableContent")
                .gesture(
                    MagnificationGesture()
                        .onChanged { value in
                            let newZoom = lastZoomScale * value
                            zoomScale = max(0.5, min(4.0, newZoom))
                        }
                        .onEnded { value in
                            lastZoomScale = zoomScale
                        }
                )
            }
            }
            .background(
                GeometryReader { scrollGeometry in
                    Color.clear.preference(key: ViewSizeKey.self, value: scrollGeometry.size)
                }
            )
            .onPreferenceChange(ViewSizeKey.self) { size in
                contentSize = size
            }
            .onAppear {
                scrollWheelMonitor = NSEvent.addLocalMonitorForEvents(matching: .scrollWheel) { event in
                    if event.modifierFlags.contains(.command) {
                        if let window = event.window,
                           contentSize.width > 0 && contentSize.height > 0 {
                            let mouseLocation = event.locationInWindow

                            if let contentView = window.contentView {
                                let locationInContent = contentView.convert(mouseLocation, from: nil)

                                let contentFrame = contentView.frame

                                let adjustedY = contentFrame.height - locationInContent.y

                                let toolbarHeight: CGFloat = 60
                                let relativeY = adjustedY - toolbarHeight

                                let normalizedX = locationInContent.x / contentSize.width
                                let normalizedY = relativeY / contentSize.height

                                zoomAnchor = UnitPoint(
                                    x: max(0, min(1, normalizedX)),
                                    y: max(0, min(1, normalizedY))
                                )
                            }
                        }

                        let delta = event.scrollingDeltaY
                        if delta > 0 {
                            zoomScale = min(4.0, zoomScale + 0.1)
                        } else if delta < 0 {
                            zoomScale = max(0.5, zoomScale - 0.1)
                        }
                        lastZoomScale = zoomScale
                        return nil
                    }
                    return event
                }
            }
            .onDisappear {
                cleanupResources()
            }
            }
            .cursor(currentCursor)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .overlay(
                VStack {
                    if showToolControls {
                        HStack {
                            Spacer()

                            ToolControlPanel(
                                isPresented: $showToolControls,
                                selectedAnnotationID: $selectedAnnotationID,
                                viewModel: viewModel,
                                selectedTool: selectedTool,
                                selectedColor: $selectedColor,
                                selectedLineWidth: $selectedLineWidth,
                                numberSize: $numberSize,
                                numberShape: $numberShape,
                                shapeCornerRadius: $shapeCornerRadius,
                                shapeFillMode: $shapeFillMode,
                                spotlightShape: $spotlightShape,
                                selectedEmoji: $selectedEmoji,
                                emojiSize: $emojiSize,
                                selectedBrushStyle: $selectedBrushStyle
                            )
                            .transition(.move(edge: .trailing).combined(with: .opacity))
                            .padding(.trailing, 20)
                        }
                        .padding(.top, 70)
                    }

                    Spacer()
                }
            )
        }
        .frame(minWidth: 900, minHeight: 500)
        .background(
            Button("") {
                if selectedTool != .select {
                    if isEditingText {
                        stopEditingText()
                    }

                    selectedTool = .select
                    showToolControls = false
                    selectedAnnotationID = nil
                    print("⌨️ ESC tuşuna basıldı - Select moduna dönüldü")
                }
            }
            .keyboardShortcut(.escape, modifiers: [])
            .opacity(0)
            .frame(width: 0, height: 0)
        )
    }

    private var currentCursor: NSCursor {
        switch selectedTool {
        case .select:
            return .arrow
        case .move:
            return movingAnnotationID != nil ? .closedHand : .openHand
        case .rectangle, .ellipse, .line, .arrow, .text, .pin, .pixelate, .eraser, .highlighter, .spotlight, .emoji, .pen:
            return .crosshair
        }
    }

    private var topToolbar: some View {
        HStack(spacing: 6) {
            HStack {
                Button(action: { undoManager?.undo() }) {
                    Image(systemName: "arrow.uturn.backward")
                }
                .disabled(!(undoManager?.canUndo ?? false))

                Button(action: { undoManager?.redo() }) {
                    Image(systemName: "arrow.uturn.forward")
                }
                .disabled(!(undoManager?.canRedo ?? false))
            }
            .buttonStyle(.plain)

            Divider()

            Button(action: { showShapePicker.toggle() }) {
                VStack(spacing: 2) {
                    Image(systemName: selectedTool.isShape ? selectedTool.icon : "square")
                        .font(.title3)
                        .foregroundColor(selectedTool.isShape ? .accentColor : .secondary)
                        .frame(width: 28, height: 28)
                    Text(L("Shapes", settings: settings))
                        .font(.system(size: 9))
                        .foregroundColor(selectedTool.isShape ? .accentColor : .secondary)
                }
                .background(selectedTool.isShape ? Color.accentColor.opacity(0.15) : Color.clear)
                .cornerRadius(6)
            }
            .buttonStyle(.plain)
            .popover(isPresented: $showShapePicker, arrowEdge: .bottom) {
                ShapePickerView(selectedTool: $selectedTool, isPresented: $showShapePicker, showToolControls: $showToolControls)
            }

            ForEach(DrawingTool.allCases.filter { !$0.isShape }) { tool in
                Button(action: {
                    if isEditingText {
                        stopEditingText()
                    }

                    selectedTool = tool

                    let toolsWithControlPanel: [DrawingTool] = [.text, .pin, .spotlight, .pen, .emoji]
                    if toolsWithControlPanel.contains(tool) {
                        showToolControls = true
                        selectedAnnotationID = nil
                        print("🔧 Tool seçildi: \(tool.rawValue), Control panel açıldı")
                    } else {
                        showToolControls = false
                        selectedAnnotationID = nil
                        print("🔧 Tool seçildi: \(tool.rawValue), Control panel kapatıldı")
                    }

                    if tool == .emoji {
                        showEmojiPicker = true
                    }
                }) {
                    VStack(spacing: 2) {
                        Image(systemName: tool.icon)
                            .font(.title3)
                            .foregroundColor(selectedTool == tool ? .accentColor : .secondary)
                            .frame(width: 28, height: 28)
                        Text(tool.localizedName)
                            .font(.system(size: 9))
                            .foregroundColor(selectedTool == tool ? .accentColor : .secondary)
                    }
                    .background(selectedTool == tool ? Color.accentColor.opacity(0.15) : Color.clear)
                    .cornerRadius(6)
                }
                .buttonStyle(.plain)
                .popover(isPresented: tool == .emoji ? $showEmojiPicker : .constant(false), arrowEdge: .bottom) {
                    if tool == .emoji {
                        EmojiPickerView(selectedEmoji: $selectedEmoji, isPresented: $showEmojiPicker)
                    }
                }
            }

            if selectedTool == .pin {
                Button(action: { viewModel.currentNumber = 1 }) {
                    HStack(spacing: 4) {
                        Text("\(viewModel.currentNumber)")
                            .font(.caption.bold())
                            .foregroundColor(.accentColor)
                        Image(systemName: "arrow.counterclockwise")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    .frame(width: 40, height: 28)
                    .background(Color.secondary.opacity(0.1))
                    .cornerRadius(6)
                }
                .buttonStyle(.plain)
                .help(L("Reset numbering", settings: settings))
            }

            Divider()

            Button(action: { startImageDrag() }) {
                VStack(spacing: 2) {
                    Image(systemName: "hand.raised.fill")
                        .font(.title3)
                        .foregroundColor(.accentColor)
                        .frame(width: 28, height: 28)
                    Text(L("Copy", settings: settings))
                        .font(.system(size: 9))
                        .foregroundColor(.accentColor)
                }
                .background(Color.accentColor.opacity(0.15))
                .cornerRadius(6)
            }
            .buttonStyle(.plain)

            Divider()

            ColorPicker("", selection: $selectedColor, supportsOpacity: false)
                .labelsHidden()
                .frame(width: 28, height: 28)

            Text(showColorCopied ? L("Copied!", settings: settings) : selectedColor.hexString)
                .font(.system(.caption, design: .monospaced))
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.secondary.opacity(0.1))
                .cornerRadius(6)
                .help(L("Click to copy Hex code", settings: settings))
                .onTapGesture {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(selectedColor.hexString, forType: .string)
                    showColorCopied = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        showColorCopied = false
                    }
                }

            Button(action: { showLineWidthPicker.toggle() }) {
                HStack(spacing: 4) {
                    Circle()
                        .fill(Color.secondary)
                        .frame(width: selectedLineWidth / 2, height: selectedLineWidth / 2)
                    Text(selectedLineWidth == 4 ? "S" : selectedLineWidth == 8 ? "M" : "L")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(width: 50, height: 28)
                .background(Color.secondary.opacity(0.1))
                .cornerRadius(6)
            }
            .buttonStyle(.plain)
            .help(L("Line Width", settings: settings))
            .popover(isPresented: $showLineWidthPicker, arrowEdge: .bottom) {
                LineWidthPickerView(selectedLineWidth: $selectedLineWidth, isPresented: $showLineWidthPicker)
            }

            Divider()

            Button(action: { showEffectsPanel.toggle() }) {
                Image(systemName: "wand.and.rays")
                    .font(.title3)
            }
            .buttonStyle(.plain)
            .popover(isPresented: $showEffectsPanel, arrowEdge: .bottom) {
                EffectsInspectorView(isPresented: $showEffectsPanel,
                                     backdropPadding: $backdropPadding,
                                     shadowRadius: $screenshotShadowRadius,
                                     screenshotCornerRadius: $screenshotCornerRadius,
                                     backdropCornerRadius: $backdropCornerRadius,
                                     backdropFill: $backdropFill,
                                     backdropModel: $backdropModel)
            }

            Spacer()

            HStack(spacing: 4) {
                Button(action: {
                    zoomScale = max(0.5, zoomScale - 0.25)
                    lastZoomScale = zoomScale
                }) {
                    Image(systemName: "minus.magnifyingglass")
                }
                .disabled(zoomScale <= 0.5)
                .buttonStyle(.plain)
                .help("Zoom Out")

                Text("\(Int(zoomScale * 100))%")
                    .font(.caption)
                    .frame(minWidth: 40)
                    .foregroundColor(.secondary)

                Button(action: {
                    zoomScale = min(4.0, zoomScale + 0.25)
                    lastZoomScale = zoomScale
                }) {
                    Image(systemName: "plus.magnifyingglass")
                }
                .disabled(zoomScale >= 4.0)
                .buttonStyle(.plain)
                .help("Zoom In")

                Button(action: {
                    zoomScale = 1.0
                    lastZoomScale = 1.0
                }) {
                    Image(systemName: "1.magnifyingglass")
                }
                .disabled(zoomScale == 1.0)
                .buttonStyle(.plain)
                .help("Reset Zoom (100%)")
            }

            Divider()

            HStack(spacing: 10) {
                Text("\(Int(image.size.width))x\(Int(image.size.height))")
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.secondary.opacity(0.1))
                    .cornerRadius(6)

                Button(action: performOCR) {
                    Image(systemName: ocrButtonIcon)
                }
                .buttonStyle(.plain)
                .help(L("Copy Text from Image (OCR)", settings: settings))
                .disabled(isPerformingOCR)

                if settings.showImagesTab {
                    Button(action: saveToClippy) {
                        Image(systemName: "internaldrive")
                    }
                    .buttonStyle(.plain)
                    .help(L("Save to Clippy History", settings: settings))
                }

                Divider()

                Button(action: applyAnnotations) {
                    Image(systemName: "checkmark.circle.fill")
                    Text(L("Apply", settings: settings))
                }
                .buttonStyle(.bordered)
                .help(L("Apply annotations to image", settings: settings))
                .disabled(viewModel.annotations.isEmpty)
                .keyboardShortcut("a", modifiers: .command)

                Button(action: clearAllAnnotations) {
                    Image(systemName: "trash")
                    Text(L("Clear All", settings: settings))
                }
                .buttonStyle(.bordered)
                .help(L("Remove all annotations", settings: settings))
                .disabled(viewModel.annotations.isEmpty)
                .keyboardShortcut("k", modifiers: [.command, .shift])

                Button(action: saveImage) {
                    Image(systemName: "square.and.arrow.down")
                    Text("Save")
                }
                .buttonStyle(.borderedProminent)
                .help(L("Save to a file...", settings: settings))
                .keyboardShortcut("s", modifiers: .command)

                Button(action: {
                    cleanupResources()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        NSApp.keyWindow?.close()
                    }
                }) {
                    Image(systemName: "xmark")
                }
                .buttonStyle(.plain)
                .help(L("Close Editor (⌘Q)", settings: settings))
                .keyboardShortcut("q", modifiers: .command)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(height: 52)
        .background(.bar)
    }

    private func drawAnnotations(context: inout GraphicsContext, canvasSize: CGSize) {
        print("🎨 [DEBUG] drawAnnotations called: \(viewModel.annotations.count) annotations, canvasSize: \(canvasSize)")
        for (index, annotation) in viewModel.annotations.enumerated() {
            var currentRect = annotation.rect
            print("🎨 [DEBUG] Annotation \(index): tool=\(annotation.tool), rect=\(currentRect)")
            if annotation.id == movingAnnotationID {
                currentRect = currentRect.offsetBy(dx: dragOffset.width, dy: dragOffset.height)
                context.addFilter(.shadow(color: .black.opacity(0.5), radius: 5))
            }
            drawSingleAnnotation(annotation, rect: currentRect, in: &context, canvasSize: canvasSize, nsImage: image)
        }
    }

    private func drawSingleAnnotation(_ annotation: Annotation, rect: CGRect, in context: inout GraphicsContext, canvasSize: CGSize, nsImage: NSImage? = nil) {
        switch annotation.tool {
        case .rectangle:
            context.stroke(Path(rect), with: .color(annotation.color), lineWidth: annotation.lineWidth)
        case .ellipse:
            context.stroke(Path(ellipseIn: rect), with: .color(annotation.color), lineWidth: annotation.lineWidth)
        case .line:
            if let start = annotation.startPoint, let end = annotation.endPoint {
                var path = Path()
                path.move(to: start)
                path.addLine(to: end)
                context.stroke(path, with: .color(annotation.color), lineWidth: annotation.lineWidth)
            }
        case .highlighter:
            context.fill(Path(rect), with: .color(annotation.color.opacity(0.3)))
        case .arrow:
            let startPoint = CGPoint(x: rect.minX, y: rect.minY)
            let endPoint = CGPoint(x: rect.maxX, y: rect.maxY)
            if hypot(endPoint.x - startPoint.x, endPoint.y - startPoint.y) > annotation.lineWidth * 2 {
                let path = Path.arrow(from: startPoint, to: endPoint, tailWidth: annotation.lineWidth, headWidth: annotation.lineWidth * 3, headLength: annotation.lineWidth * 3)
                context.fill(path, with: .color(annotation.color))
            }
        case .pixelate:
            context.fill(Path(rect), with: .color(.black))
        case .pin:
            let diameter = rect.width
            let shapeRect = CGRect(x: rect.minX, y: rect.minY, width: diameter, height: diameter)

            let shape = annotation.numberShape ?? .circle
            let shapePath: Path
            switch shape {
            case .circle:
                shapePath = Path(ellipseIn: shapeRect)
            case .square:
                shapePath = Path(shapeRect)
            case .roundedSquare:
                shapePath = Path(roundedRect: shapeRect, cornerRadius: diameter * 0.2)
            }
            context.fill(shapePath, with: .color(annotation.color))

            if annotation.number == nil {
                print("⚠️ drawAnnotations: Pin number is NIL!")
            }

            if let number = annotation.number {
                let fontSize = diameter * 0.55
                let numberText = "\(number)"

                let text = Text(numberText)
                    .font(.system(size: fontSize, weight: .bold))
                    .foregroundColor(.white)

                let resolved = context.resolve(text)

                context.draw(resolved, at: CGPoint(x: shapeRect.midX, y: shapeRect.midY), anchor: .center)
            }
        case .text:
            if !annotation.text.isEmpty {
                let text = Text(annotation.text)
                    .font(.system(size: annotation.lineWidth * 4))
                    .foregroundColor(annotation.color)
                context.draw(text, in: rect)
            } else if (editingTextIndex == viewModel.annotations.firstIndex(where: {$0.id == annotation.id})) {
                let path = Path(rect)
                context.stroke(path, with: .color(.gray), style: StrokeStyle(lineWidth: 1, dash: [4]))
            }
        case .emoji:
            if let emoji = annotation.emoji {
                let fontSize = rect.width * 0.8
                let emojiText = Text(emoji)
                    .font(.system(size: fontSize))

                let resolved = context.resolve(emojiText)

                context.draw(resolved, at: CGPoint(x: rect.midX, y: rect.midY), anchor: .center)
            }

        case .pen:
            if let path = annotation.path, path.count > 1 {
                var bezierPath = Path()
                bezierPath.move(to: path[0])
                for i in 1..<path.count {
                    bezierPath.addLine(to: path[i])
                }

                let brushStyle = annotation.brushStyle ?? .solid
                switch brushStyle {
                case .solid:
                    context.stroke(bezierPath, with: .color(annotation.color), lineWidth: annotation.lineWidth)
                case .dashed:
                    context.stroke(bezierPath, with: .color(annotation.color), style: StrokeStyle(lineWidth: annotation.lineWidth, dash: [10, 5]))
                case .marker:
                    context.stroke(bezierPath, with: .color(annotation.color.opacity(0.5)), style: StrokeStyle(lineWidth: annotation.lineWidth * 2, lineCap: .round, lineJoin: .round))
                }
            }

        case .spotlight:
            var fullScreenPath = Path(CGRect(origin: .zero, size: canvasSize))

            let spotPath: Path
            if annotation.spotlightShape == .rectangle {
                spotPath = Path(roundedRect: rect, cornerRadius: 8)
            } else {
                spotPath = Path(ellipseIn: rect)
            }
            fullScreenPath.addPath(spotPath)

            context.fill(fullScreenPath, with: .color(.black.opacity(0.6)), style: FillStyle(eoFill: true))

            context.stroke(spotPath, with: .color(.white.opacity(0.5)), lineWidth: 2)

        case .move, .eraser, .select:
            break
        }

    }

    private func renderFinalImage() -> NSImage {
        return autoreleasepool {
            let annotationsView = ZStack {
                Image(nsImage: image)
                    .resizable()

                Canvas { context, size in
                    drawAnnotations(context: &context, canvasSize: size)
                }
            }
            .frame(width: image.size.width, height: image.size.height)
            .clipped()

            let renderer = ImageRenderer(content: annotationsView)
            renderer.scale = NSScreen.main?.backingScaleFactor ?? 2.0

            guard let annotatedImage = renderer.nsImage else {
                print("❌ Annotation Renderer başarısız oldu, orijinal görüntü döndürülüyor.")
                return image
            }

            return createFinalImageWithBackdrop(annotatedImage: annotatedImage)
        }
    }

    private func createFinalImageWithBackdrop(annotatedImage: NSImage) -> NSImage {
        return autoreleasepool {
            let totalWidth = image.size.width + (backdropPadding * 2)
            let totalHeight = image.size.height + (backdropPadding * 2)
            let finalSize = NSSize(width: totalWidth, height: totalHeight)

            let finalImage = NSImage(size: finalSize)
            finalImage.cacheMode = .never
            finalImage.lockFocus()

        guard let context = NSGraphicsContext.current?.cgContext else {
            finalImage.unlockFocus()
            print("❌ CGContext alınamadı.")
            return annotatedImage
        }

        let backgroundRect = CGRect(origin: .zero, size: finalSize)
        let backgroundPath = NSBezierPath(roundedRect: NSRect(origin: .zero, size: finalSize),
                                            xRadius: backdropCornerRadius,
                                            yRadius: backdropCornerRadius)

        switch backdropModel {
        case .solid(let color):
            NSColor(color).setFill()
            backgroundPath.fill()

        case .linearGradient(let start, let end, let startPoint, let endPoint):
            let colors = [NSColor(start).cgColor, NSColor(end).cgColor] as CFArray
            guard let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: [0.0, 1.0]) else {
                NSColor(end).setFill()
                backgroundPath.fill()
                break
            }
            context.saveGState()
            let clipPath = NSBezierPath(roundedRect: backgroundRect, xRadius: backdropCornerRadius, yRadius: backdropCornerRadius)
            clipPath.addClip()

            let sp = CGPoint(x: backgroundRect.minX + startPoint.x * backgroundRect.width,
                             y: backgroundRect.minY + startPoint.y * backgroundRect.height)
            let ep = CGPoint(x: backgroundRect.minX + endPoint.x * backgroundRect.width,
                             y: backgroundRect.minY + endPoint.y * backgroundRect.height)
            context.drawLinearGradient(gradient, start: sp, end: ep, options: [])
            context.restoreGState()
        }

        let imageRect = NSRect(x: backdropPadding,
                               y: backdropPadding,
                               width: image.size.width,
                               height: image.size.height)

        context.saveGState()
        let imageClipPath = NSBezierPath(roundedRect: imageRect,
                                         xRadius: screenshotCornerRadius,
                                         yRadius: screenshotCornerRadius)
        imageClipPath.addClip()

        context.setShadow(offset: CGSize(width: 0, height: -screenshotShadowRadius / 2),
                          blur: screenshotShadowRadius,
                          color: NSColor.black.withAlphaComponent(0.5).cgColor)

        annotatedImage.draw(in: imageRect)

        context.restoreGState()

        finalImage.unlockFocus()

            return finalImage
        }
    }

    private func applyAnnotations() {
        guard !viewModel.annotations.isEmpty else { return }

        let imageSize = image.size

        guard let tiffData = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData) else {
            print("❌ Failed to get bitmap")
            return
        }

        let newImage = NSImage(size: imageSize)
        newImage.cacheMode = .never
        newImage.addRepresentation(bitmap)
        newImage.lockFocus()

        let imageHeight = image.size.height

        for annotation in viewModel.annotations where annotation.tool != .spotlight {
            drawAnnotation(annotation, imageHeight: imageHeight)
        }

        let spotlights = viewModel.annotations.filter { $0.tool == .spotlight }
        if !spotlights.isEmpty {
            drawSpotlightsOverlay(spotlights, imageHeight: imageHeight)
        }

        newImage.unlockFocus()

        image = newImage

        // Clear annotations after applying them to the image
        viewModel.annotations.removeAll()
        selectedAnnotationID = nil

        // Reset pin number counter
        viewModel.currentNumber = 1
        print("🔢 Apply: Annotations applied and cleared, pin counter reset")

        undoManager?.removeAllActions()
    }

    private func clearAllAnnotations() {
        guard !viewModel.annotations.isEmpty else { return }

        viewModel.annotations.removeAll()

        viewModel.currentNumber = 1
        print("🔢 Clear All: Pin numarası sıfırlandı")
    }

    private func drawAnnotation(_ a: Annotation, imageHeight: CGFloat) {
        let c = NSColor(a.color)

        func flipY(_ y: CGFloat) -> CGFloat {
            return imageHeight - y
        }

        func flipRect(_ rect: CGRect) -> CGRect {
            return CGRect(x: rect.origin.x,
                         y: flipY(rect.origin.y + rect.height),
                         width: rect.width,
                         height: rect.height)
        }

        switch a.tool {
        case .rectangle:
            let flipped = flipRect(a.rect)
            let cornerRadius = a.cornerRadius
            let p = NSBezierPath(roundedRect: flipped, xRadius: cornerRadius, yRadius: cornerRadius)

            switch a.fillMode {
            case .fill:
                c.setFill()
                p.fill()
            case .stroke:
                c.setStroke()
                p.lineWidth = a.lineWidth
                p.stroke()
            case .both:
                c.withAlphaComponent(0.3).setFill()
                p.fill()
                c.setStroke()
                p.lineWidth = a.lineWidth
                p.stroke()
            }

        case .ellipse:
            let flipped = flipRect(a.rect)
            let p = NSBezierPath(ovalIn: flipped)

            switch a.fillMode {
            case .fill:
                c.setFill()
                p.fill()
            case .stroke:
                c.setStroke()
                p.lineWidth = a.lineWidth
                p.stroke()
            case .both:
                c.withAlphaComponent(0.3).setFill()
                p.fill()
                c.setStroke()
                p.lineWidth = a.lineWidth
                p.stroke()
            }

        case .line:
            guard let s = a.startPoint, let e = a.endPoint else { return }
            let flippedStart = CGPoint(x: s.x, y: flipY(s.y))
            let flippedEnd = CGPoint(x: e.x, y: flipY(e.y))

            c.setStroke()
            let p = NSBezierPath()
            p.move(to: flippedStart)
            p.line(to: flippedEnd)
            p.lineWidth = a.lineWidth
            p.stroke()

        case .highlighter:
            c.withAlphaComponent(0.3).setFill()
            NSBezierPath(rect: flipRect(a.rect)).fill()

        case .arrow:
            guard let s = a.startPoint, let e = a.endPoint else { return }
            let flippedStart = CGPoint(x: s.x, y: flipY(s.y))
            let flippedEnd = CGPoint(x: e.x, y: flipY(e.y))

            c.setFill()
            let len = hypot(flippedEnd.x - flippedStart.x, flippedEnd.y - flippedStart.y)
            guard len > a.lineWidth * 2 else { return }

            let w = a.lineWidth
            let t = NSAffineTransform()
            t.translateX(by: flippedStart.x, yBy: flippedStart.y)
            t.rotate(byRadians: atan2(flippedEnd.y - flippedStart.y, flippedEnd.x - flippedStart.x))

            let pts: [NSPoint] = [
                NSPoint(x: 0, y: w/2),
                NSPoint(x: len - w*3, y: w/2),
                NSPoint(x: len - w*3, y: w*1.5),
                NSPoint(x: len, y: 0),
                NSPoint(x: len - w*3, y: -w*1.5),
                NSPoint(x: len - w*3, y: -w/2),
                NSPoint(x: 0, y: -w/2)
            ]

            let p = NSBezierPath()
            p.move(to: t.transform(pts[0]))
            pts.dropFirst().forEach { p.line(to: t.transform($0)) }
            p.close()
            p.fill()

        case .pin:
            guard let number = a.number else { return }
            let flippedRect = flipRect(a.rect)
            let diameter = flippedRect.width
            let shapeRect = CGRect(x: flippedRect.minX, y: flippedRect.minY, width: diameter, height: diameter)

            c.setFill()
            let shape = a.numberShape ?? .circle
            let shapePath: NSBezierPath
            switch shape {
            case .circle:
                shapePath = NSBezierPath(ovalIn: shapeRect)
            case .square:
                shapePath = NSBezierPath(rect: shapeRect)
            case .roundedSquare:
                shapePath = NSBezierPath(roundedRect: shapeRect, xRadius: diameter * 0.2, yRadius: diameter * 0.2)
            }
            shapePath.fill()

            let numText = "\(number)"
            let paragraphStyle = NSMutableParagraphStyle()
            paragraphStyle.alignment = .center

            let attrs: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: diameter * 0.55, weight: .bold),
                .foregroundColor: NSColor.white,
                .paragraphStyle: paragraphStyle
            ]

            let textSize = numText.size(withAttributes: attrs)
            let textRect = CGRect(
                x: shapeRect.minX,
                y: shapeRect.midY - textSize.height / 2 + diameter * 0.05,
                width: diameter,
                height: textSize.height
            )
            numText.draw(in: textRect, withAttributes: attrs)

        case .text:
            guard !a.text.isEmpty else { return }
            let attrs: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: a.lineWidth * 4),
                .foregroundColor: c
            ]
            a.text.draw(in: flipRect(a.rect), withAttributes: attrs)

        case .pixelate:
            NSColor.black.setFill()
            NSBezierPath(rect: flipRect(a.rect)).fill()

        case .spotlight:
            break

        case .pen:
            guard let path = a.path, path.count > 1 else { return }

            let flippedPath = path.map { CGPoint(x: $0.x, y: flipY($0.y)) }

            c.setStroke()
            let bezierPath = NSBezierPath()
            bezierPath.move(to: flippedPath[0])
            for i in 1..<flippedPath.count {
                bezierPath.line(to: flippedPath[i])
            }

            let brushStyle = a.brushStyle ?? .solid
            switch brushStyle {
            case .solid:
                bezierPath.lineWidth = a.lineWidth
                bezierPath.stroke()
            case .dashed:
                bezierPath.lineWidth = a.lineWidth
                bezierPath.setLineDash([10, 5], count: 2, phase: 0)
                bezierPath.stroke()
            case .marker:
                c.withAlphaComponent(0.5).setStroke()
                bezierPath.lineWidth = a.lineWidth * 2
                bezierPath.lineCapStyle = .round
                bezierPath.lineJoinStyle = .round
                bezierPath.stroke()
                c.setStroke()
            }

        case .emoji:
            guard let emoji = a.emoji else { return }
            let flippedRect = flipRect(a.rect)
            let fontSize = flippedRect.width * 0.8

            let attrs: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: fontSize)
            ]

            let emojiSize = emoji.size(withAttributes: attrs)
            let emojiRect = CGRect(
                x: flippedRect.midX - emojiSize.width / 2,
                y: flippedRect.midY - emojiSize.height / 2,
                width: emojiSize.width,
                height: emojiSize.height
            )
            emoji.draw(in: emojiRect, withAttributes: attrs)

        default:
            break
        }
    }

    private func drawSpotlightsOverlay(_ spotlights: [Annotation], imageHeight: CGFloat) {
        guard !spotlights.isEmpty else { return }

        func flipRect(_ rect: CGRect) -> CGRect {
            return CGRect(x: rect.origin.x,
                         y: imageHeight - (rect.origin.y + rect.height),
                         width: rect.width,
                         height: rect.height)
        }

        let spotlightAreas = NSBezierPath()
        for spotlight in spotlights {
            let spotPath: NSBezierPath
            if spotlight.spotlightShape == .rectangle {
                spotPath = NSBezierPath(roundedRect: flipRect(spotlight.rect), xRadius: 8, yRadius: 8)
            } else {
                spotPath = NSBezierPath(ovalIn: flipRect(spotlight.rect))
            }
            spotlightAreas.append(spotPath)
        }

        let fullScreen = NSBezierPath(rect: CGRect(origin: .zero, size: image.size))

        fullScreen.append(spotlightAreas)
        fullScreen.windingRule = .evenOdd

        NSColor.black.withAlphaComponent(0.6).setFill()
        fullScreen.fill()

        for spotlight in spotlights {
            let spotPath: NSBezierPath
            if spotlight.spotlightShape == .rectangle {
                spotPath = NSBezierPath(roundedRect: flipRect(spotlight.rect), xRadius: 8, yRadius: 8)
            } else {
                spotPath = NSBezierPath(ovalIn: flipRect(spotlight.rect))
            }
            NSColor.white.withAlphaComponent(0.5).setStroke()
            spotPath.lineWidth = 2
            spotPath.stroke()
        }
    }

    private func saveImage() {
        autoreleasepool {
            let finalImage = renderFinalImage()

            let savePanel = NSSavePanel()
            savePanel.canCreateDirectories = true
            savePanel.showsTagField = false
            savePanel.nameFieldStringValue = "screenshot-\(Int(Date().timeIntervalSince1970)).jpg"
            savePanel.level = .modalPanel
            savePanel.begin { response in
                if response == .OK, let url = savePanel.url {
                    autoreleasepool {
                        guard let tiffData = finalImage.tiffRepresentation,
                              let bitmap = NSBitmapImageRep(data: tiffData),
                              let jpegData = bitmap.representation(using: .jpeg, properties: [.compressionFactor: 0.85]) else {
                            print("❌ Görüntü JPEG formatına dönüştürülemedi.")
                            return
                        }
                        do {
                            try jpegData.write(to: url)
                            print("✅ Görüntü şuraya kaydedildi: \(url.path)")
                        } catch {
                            print("❌ Görüntü kaydetme hatası: \(error.localizedDescription)")
                        }
                    }
                }
            }
        }
    }

    private func renderFinalImage_OLD() -> NSImage {
        let finalWidth = image.size.width + (backdropPadding * 2)
        let finalHeight = image.size.height + (backdropPadding * 2)

        let viewToRender = ZStack {
            RoundedRectangle(cornerRadius: backdropCornerRadius)
                .fill(backdropFill)
                .shadow(radius: screenshotShadowRadius / 2)

            ZStack {
                Image(nsImage: image)
                    .resizable()
                    .clipShape(RoundedRectangle(cornerRadius: screenshotCornerRadius))
                    .shadow(radius: screenshotShadowRadius)

                Canvas { context, size in
                    drawAnnotations(context: &context, canvasSize: image.size)
                }
            }
            .padding(backdropPadding)
        }
        .frame(width: finalWidth, height: finalHeight)

        let renderer = ImageRenderer(content: viewToRender)
        renderer.scale = NSScreen.main?.backingScaleFactor ?? 2.0
        return renderer.nsImage ?? image
    }

    private func saveToClippy() {
        autoreleasepool {
            let finalImage = renderFinalImage()
            clipboardMonitor.addImageToHistory(image: finalImage)
            print("✅ Görüntü Clippy geçmişine kaydedildi.")
        }

        cleanupResources()

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            NSApp.keyWindow?.close()
        }
    }

    private func performOCR() {
        guard !isPerformingOCR else { return }
        isPerformingOCR = true

        guard let cgImage = autoreleasepool(invoking: {
            image.cgImage(forProposedRect: nil, context: nil, hints: nil)
        }) else {
            isPerformingOCR = false
            return
        }

        let request = VNRecognizeTextRequest { (request, error) in
            guard let observations = request.results as? [VNRecognizedTextObservation], error == nil else {
                DispatchQueue.main.async { self.isPerformingOCR = false }
                return
            }

            let recognizedText = observations.compactMap { $0.topCandidates(1).first?.string }.joined(separator: "\n")

            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(recognizedText, forType: .string)

            DispatchQueue.main.async {
                self.ocrButtonIcon = "checkmark"
                self.isPerformingOCR = false
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    self.ocrButtonIcon = "text.viewfinder"
                }
            }
        }

        DispatchQueue.global(qos: .userInitiated).async {
            autoreleasepool {
                do {
                    try VNImageRequestHandler(cgImage: cgImage, options: [:]).perform([request])
                } catch {
                    print("❌ OCR hatası: \(error)")
                    DispatchQueue.main.async { self.isPerformingOCR = false }
                }
            }
        }
    }

    private func pixelate(image: NSImage, in rect: CGRect) -> NSImage? {
        guard let tiffData = image.tiffRepresentation,
              let ciImage = CIImage(data: tiffData) else {
            return nil
        }
        let sourceRect = CGRect(origin: .zero, size: image.size)
        let rectInSource = rect.intersection(sourceRect)
        if rectInSource.isEmpty { return nil }

        guard let filter = CIFilter(name: "CIPixellate") else { return nil }

        let ciRect = CGRect(x: rectInSource.origin.x, y: ciImage.extent.height - rectInSource.origin.y - rectInSource.size.height, width: rectInSource.size.width, height: rectInSource.size.height)

        let croppedImage = ciImage.cropped(to: ciRect)
        filter.setValue(croppedImage, forKey: kCIInputImageKey)
        filter.setValue(20, forKey: kCIInputScaleKey)

        guard let outputImage = filter.outputImage else { return nil }

        let rep = NSCIImageRep(ciImage: outputImage)
        let nsImage = NSImage(size: rectInSource.size)
        nsImage.addRepresentation(rep)
        return nsImage
    }

    private func findAnnotation(at point: CGPoint) -> (id: UUID, index: Int)? {
        if let index = viewModel.annotations.lastIndex(where: { $0.rect.contains(point) }) {
            return (viewModel.annotations[index].id, index)
        }
        return nil
    }

    private func startEditingText(at index: Int) {
        print("🚀 startEditingText çağrıldı, index: \(index)")
        print("   Annotation sayısı: \(viewModel.annotations.count)")
        if index < viewModel.annotations.count {
            print("   Annotation tool: \(viewModel.annotations[index].tool)")
            print("   Annotation rect: \(viewModel.annotations[index].rect)")
        }
        editingTextIndex = index
        isEditingText = true
        print("   isEditingText: \(isEditingText), editingTextIndex: \(String(describing: editingTextIndex))")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            self.isTextFieldFocused = true
            print("   ✅ Focus ayarlandı")
        }
    }

    private func stopEditingText() {
        isEditingText = false
        editingTextIndex = nil
    }

    private func startImageDrag() {
        let finalImage = renderFinalImage()

        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.writeObjects([finalImage])

        NSSound.beep()
    }
}

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

extension ScreenshotEditorView {
    private func cleanupResources() {
        print("🧹 ScreenshotEditor: Cleanup başladı...")

        if let monitor = scrollWheelMonitor {
            NSEvent.removeMonitor(monitor)
            scrollWheelMonitor = nil
            print("  ✓ Event monitor temizlendi")
        }

        undoManager?.removeAllActions()
        print("  ✓ Undo manager temizlendi")

        let annotationCount = viewModel.annotations.count
        viewModel.annotations.removeAll()
        print("  ✓ \(annotationCount) annotation temizlendi")

        selectedAnnotationID = nil
        editingTextIndex = nil
        movingAnnotationID = nil

        if isEditingText {
            isEditingText = false
        }

        // Aggressively clean up image memory with autoreleasepool
        autoreleasepool {
            let representations = image.representations
            for rep in representations {
                image.removeRepresentation(rep)
            }
            print("  ✓ Image representations temizlendi (\(representations.count) adet)")

            // Clear image cache and force deallocation
            image.recache()
        }

        // Create a tiny dummy image to replace the large one
        // This forces SwiftUI to release the large image from @State
        let tinyImage = autoreleasepool {
            let tiny = NSImage(size: NSSize(width: 1, height: 1))
            tiny.cacheMode = .never
            tiny.lockFocus()
            NSColor.clear.set()
            NSRect(x: 0, y: 0, width: 1, height: 1).fill()
            tiny.unlockFocus()
            return tiny
        }
        image = tinyImage
        print("  ✓ Image replaced with 1x1 placeholder")

        zoomScale = 1.0
        lastZoomScale = 1.0

        DispatchQueue.global(qos: .background).asyncAfter(deadline: .now() + 0.1) {
            autoreleasepool {
                print("  ✓ Background memory cleanup triggered")
            }
        }

        print("🧹 ScreenshotEditor: Bellek temizlendi - ARC cleanup triggered")
    }
}

struct NamedUnitPoint: Identifiable, Hashable {
    let id = UUID()
    let name: String
    let point: UnitPoint
}

struct EffectsInspectorView: View {
    @Binding var isPresented: Bool
    @Binding var backdropPadding: CGFloat
    @Binding var shadowRadius: CGFloat
    @Binding var screenshotCornerRadius: CGFloat
    @Binding var backdropCornerRadius: CGFloat
    @Binding var backdropFill: AnyShapeStyle
    @Binding var backdropModel: BackdropFillModel

    @EnvironmentObject var settings: SettingsManager
    @State private var selectedTab: Int = 0
    @State private var solidColor: Color = .white
    @State private var gradientStartColor: Color = .blue
    @State private var gradientEndColor: Color = .cyan
    @State private var gradientStartPoint: UnitPoint = .topLeading

    let solidColors: [Color] = [
        .blue, .green, .red, .orange, .purple, .yellow,
        .pink, .cyan, .indigo, .mint, .white, .black
    ]
    let presetGradients: [[Color]] = [
        [.blue, .cyan], [.pink, .purple], [.orange, .red],
        [.green, .mint], [.purple, .indigo], [.yellow, .orange],
        [Color(hex: "#833ab4"), Color(hex: "#fd1d1d"), Color(hex: "#fcb045")],
        [Color(hex: "#00c6ff"), Color(hex: "#0072ff")],
        [Color(hex: "#43e97b"), Color(hex: "#38f9d7")],
        [Color(hex: "#f857a6"), Color(hex: "#ff5858")],
        [Color(hex: "#e0c3fc"), Color(hex: "#8ec5fc")],
        [Color(hex: "#f093fb"), Color(hex: "#f5576c")]
    ]
    let gradientDirections: [NamedUnitPoint] = [
        .init(name: "Top Left", point: .topLeading), .init(name: "Top", point: .top), .init(name: "Top Right", point: .topTrailing),
        .init(name: "Left", point: .leading), .init(name: "Center", point: .center), .init(name: "Right", point: .trailing),
        .init(name: "Bottom Left", point: .bottomLeading), .init(name: "Bottom", point: .bottom), .init(name: "Bottom Right", point: .bottomTrailing)
    ]

    private var gradientEndPoint: UnitPoint {
        UnitPoint(x: 1.0 - gradientStartPoint.x, y: 1.0 - gradientStartPoint.y)
    }

    var body: some View {
        ScrollView {
        VStack(alignment: .leading, spacing: 12) {

            VStack(alignment: .leading, spacing: 8) {
                HStack { Text(L("Inset", settings: settings)).font(.caption); Spacer(); Text("\(Int(backdropPadding))").font(.caption2) }
                Slider(value: $backdropPadding, in: 0...150)

                HStack { Text(L("Shadow", settings: settings)).font(.caption); Spacer(); Text("\(Int(shadowRadius))").font(.caption2) }
                Slider(value: $shadowRadius, in: 0...100)

                HStack { Text(L("Outer Radius", settings: settings)).font(.caption); Spacer(); Text("\(Int(backdropCornerRadius))").font(.caption2) }
                Slider(value: $backdropCornerRadius, in: 0...100)

                HStack { Text(L("Inner Radius", settings: settings)).font(.caption); Spacer(); Text("\(Int(screenshotCornerRadius))").font(.caption2) }
                Slider(value: $screenshotCornerRadius, in: 0...100)
            }

            Divider()

            Picker(L("Color Type", settings: settings), selection: $selectedTab) {
                Text(L("Solid", settings: settings)).tag(0)
                Text(L("Colormix", settings: settings)).tag(1)
                Text(L("Image", settings: settings)).tag(2)
            }
            .pickerStyle(.segmented)
            .labelsHidden()

            Group {
                if selectedTab == 0 {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 24), spacing: 8)], spacing: 8) {
                        ForEach(solidColors, id: \.self) { color in
                            Button {
                                solidColor = color
                                backdropFill = AnyShapeStyle(solidColor)
                                backdropModel = .solid(solidColor)
                            } label: {
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(color)
                                    .frame(width: 24, height: 24)
                                    .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.primary.opacity(0.2), lineWidth: 1))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    ColorPicker(L("Custom Color", settings: settings), selection: $solidColor)
                        .padding(.top, 8)
                        .onChange(of: solidColor) {
                            backdropFill = AnyShapeStyle($0)
                            backdropModel = .solid($0)
                        }

                } else if selectedTab == 1 {
                    VStack(alignment: .leading) {
                        Text(L("Presets", settings: settings)).font(.caption)
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 24), spacing: 8)], spacing: 8) {
                            ForEach(presetGradients, id: \.self) { colors in
                                Button {
                                    gradientStartColor = colors.first ?? .white
                                    gradientEndColor = colors.count > 1 ? colors[1] : .black
                                    updateBackdropFillWithGradient()
                                } label: {
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing))
                                        .frame(width: 24, height: 24)
                                }
                                .buttonStyle(.plain)
                            }
                        }

                        Divider().padding(.vertical, 5)
                        Text(L("Custom Gradient", settings: settings)).font(.caption)
                        HStack {
                            ColorPicker(L("Start", settings: settings), selection: $gradientStartColor)
                            ColorPicker(L("End", settings: settings), selection: $gradientEndColor)
                            Spacer()
                        }

                        Picker(L("Direction", settings: settings), selection: $gradientStartPoint) {
                            ForEach(gradientDirections) { Text(L($0.name, settings: settings)).tag($0.point) }
                        }
                        .pickerStyle(.menu)

                        RoundedRectangle(cornerRadius: 6)
                            .fill(LinearGradient(gradient: Gradient(colors: [gradientStartColor, gradientEndColor]),
                                                 startPoint: gradientStartPoint,
                                                 endPoint: gradientEndPoint))
                            .frame(height: 30)
                            .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.primary.opacity(0.2)))
                            .onChange(of: gradientStartColor) { _ in updateBackdropFillWithGradient() }
                            .onChange(of: gradientEndColor) { _ in updateBackdropFillWithGradient() }
                            .onChange(of: gradientStartPoint) { _ in updateBackdropFillWithGradient() }
                    }
                } else {
                    VStack {
                        Image(systemName: "photo.on.rectangle.angled")
                            .font(.largeTitle).foregroundColor(.secondary)
                        Text(L("Select an image for the backdrop", settings: settings)).font(.caption).foregroundColor(.secondary)
                        Button(L("Browse...", settings: settings)) {  }
                    }
                    .frame(maxWidth: .infinity, minHeight: 100)
                }
            }
            .frame(maxHeight: .infinity)

            Spacer()

            HStack {
                Button(L("Remove", settings: settings), role: .destructive) {
                    backdropPadding = 0
                    shadowRadius = 0
                    screenshotCornerRadius = 0
                    backdropCornerRadius = 0
                    let defaultColor = Color(nsColor: .windowBackgroundColor).opacity(0.8)
                    backdropFill = AnyShapeStyle(defaultColor)
                    backdropModel = .solid(defaultColor)
                    solidColor = defaultColor
                }
                Spacer()
                Button(L("Ok", settings: settings)) { isPresented = false }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding()
        }
        .frame(width: 280, height: 500)
        .onAppear(perform: setupInitialStateFromFill)
    }

    private func updateBackdropFillWithGradient() {
        let gradient = LinearGradient(gradient: Gradient(colors: [gradientStartColor, gradientEndColor]), startPoint: gradientStartPoint, endPoint: gradientEndPoint)
        backdropFill = AnyShapeStyle(gradient)
        backdropModel = .linearGradient(start: gradientStartColor, end: gradientEndColor, startPoint: gradientStartPoint, endPoint: gradientEndPoint)
    }

    private func setupInitialStateFromFill() {
        switch backdropModel {
        case .solid(let color):
            solidColor = color
            selectedTab = 0
        case .linearGradient(let start, let end, let sp, _):
            gradientStartColor = start
            gradientEndColor = end
            gradientStartPoint = sp
            selectedTab = 1
        }
    }
}

struct DrawingCanvasView: View {
    let image: NSImage
    @ObservedObject var viewModel: ScreenshotEditorViewModel
    @Binding var selectedTool: DrawingTool
    @Binding var selectedColor: Color
    @Binding var selectedLineWidth: CGFloat
    @Binding var numberSize: CGFloat
    @Binding var numberShape: NumberShape
    @Binding var shapeCornerRadius: CGFloat
    @Binding var shapeFillMode: FillMode
    @Binding var spotlightShape: SpotlightShape
    @Binding var selectedEmoji: String
    @Binding var emojiSize: CGFloat
    @Binding var selectedBrushStyle: BrushStyle
    @Binding var movingAnnotationID: UUID?
    @Binding var dragOffset: CGSize
    @Binding var editingTextIndex: Int?
    @Binding var showToolControls: Bool
    @Binding var selectedAnnotationID: UUID?
    @Binding var isEditingText: Bool
    let backdropPadding: CGFloat
    let canvasSize: CGSize
    var onTextAnnotationCreated: (UUID) -> Void
    var onStartEditingText: (Int) -> Void
    var onStopEditingText: () -> Void

    @Environment(\.undoManager) private var undoManager

    @State private var liveDrawingStart: CGPoint?
    @State private var liveDrawingEnd: CGPoint?
    @State private var liveDrawingPath: [CGPoint]?

    @State private var resizingHandle: ResizeHandle?
    @State private var originalRect: CGRect?

    enum ResizeHandle {
        case topLeft, top, topRight
        case left, right
        case bottomLeft, bottom, bottomRight
    }

    var body: some View {
        Canvas { context, size in
            let imageSize = image.size
            let scale = min(canvasSize.width / imageSize.width, canvasSize.height / imageSize.height)

            let scaledImageSize = CGSize(
                width: imageSize.width * scale,
                height: imageSize.height * scale
            )

            let imageOffset = CGPoint(
                x: (canvasSize.width - scaledImageSize.width) / 2,
                y: (canvasSize.height - scaledImageSize.height) / 2
            )

                for annotation in viewModel.annotations {
                    var displayRect = CGRect(
                        x: annotation.rect.origin.x * scale + imageOffset.x,
                        y: annotation.rect.origin.y * scale + imageOffset.y,
                        width: annotation.rect.width * scale,
                        height: annotation.rect.height * scale
                    )

                    let isMoving = annotation.id == movingAnnotationID
                    if isMoving {
                        displayRect = displayRect.offsetBy(dx: dragOffset.width, dy: dragOffset.height)
                        context.addFilter(.shadow(color: .black.opacity(0.5), radius: 5))
                    }

                    var displayAnnotation = annotation
                    displayAnnotation.rect = displayRect
                    displayAnnotation.lineWidth = annotation.lineWidth * scale
                    if let start = annotation.startPoint {
                        var displayStart = CGPoint(
                            x: start.x * scale + imageOffset.x,
                            y: start.y * scale + imageOffset.y
                        )
                        if isMoving {
                            displayStart.x += dragOffset.width
                            displayStart.y += dragOffset.height
                        }
                        displayAnnotation.startPoint = displayStart
                    }
                    if let end = annotation.endPoint {
                        var displayEnd = CGPoint(
                            x: end.x * scale + imageOffset.x,
                            y: end.y * scale + imageOffset.y
                        )
                        if isMoving {
                            displayEnd.x += dragOffset.width
                            displayEnd.y += dragOffset.height
                        }
                        displayAnnotation.endPoint = displayEnd
                    }
                    if let path = annotation.path {
                        displayAnnotation.path = path.map { point in
                            var displayPoint = CGPoint(
                                x: point.x * scale + imageOffset.x,
                                y: point.y * scale + imageOffset.y
                            )
                            if isMoving {
                                displayPoint.x += dragOffset.width
                                displayPoint.y += dragOffset.height
                            }
                            return displayPoint
                        }
                    }

                    drawSingleAnnotation(displayAnnotation, rect: displayRect, in: &context, canvasSize: size, nsImage: image)
                }

                if let start = liveDrawingStart, let end = liveDrawingEnd {
                    let rect = CGRect(from: start, to: end)
                    var liveAnnotation = Annotation(rect: rect, color: selectedColor, lineWidth: selectedLineWidth, tool: selectedTool)
                    liveAnnotation.startPoint = start
                    liveAnnotation.endPoint = end

                    if selectedTool == .spotlight {
                        liveAnnotation.spotlightShape = spotlightShape
                    }

                    drawSingleAnnotation(liveAnnotation, rect: rect, in: &context, canvasSize: size, nsImage: image)
                }

                if let path = liveDrawingPath, path.count > 1 {
                    let canvasPath = path.map { point in
                        CGPoint(
                            x: point.x * scale + imageOffset.x,
                            y: point.y * scale + imageOffset.y
                        )
                    }

                    var bezierPath = Path()
                    bezierPath.move(to: canvasPath[0])
                    for i in 1..<canvasPath.count {
                        bezierPath.addLine(to: canvasPath[i])
                    }

                    let scaledLineWidth = selectedLineWidth * scale
                    switch selectedBrushStyle {
                    case .solid:
                        context.stroke(bezierPath, with: .color(selectedColor), lineWidth: scaledLineWidth)
                    case .dashed:
                        context.stroke(bezierPath, with: .color(selectedColor), style: StrokeStyle(lineWidth: scaledLineWidth, dash: [10, 5]))
                    case .marker:
                        context.stroke(bezierPath, with: .color(selectedColor.opacity(0.5)), style: StrokeStyle(lineWidth: scaledLineWidth * 2, lineCap: .round, lineJoin: .round))
                    }
                }

                if let selectedID = selectedAnnotationID,
                   let selectedAnnotation = viewModel.annotations.first(where: { $0.id == selectedID }) {

                    var originalRect = selectedAnnotation.rect

                    if selectedAnnotation.tool == .text && !selectedAnnotation.text.isEmpty {
                        let font = NSFont.systemFont(ofSize: selectedAnnotation.lineWidth * 4)
                        let textAttributes: [NSAttributedString.Key: Any] = [.font: font]
                        let textSize = (selectedAnnotation.text as NSString).boundingRect(
                            with: CGSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude),
                            options: [.usesLineFragmentOrigin, .usesFontLeading],
                            attributes: textAttributes
                        ).size

                        let paddedWidth = textSize.width + 16
                        let paddedHeight = textSize.height + 8

                        originalRect = CGRect(
                            x: originalRect.origin.x,
                            y: originalRect.origin.y,
                            width: paddedWidth,
                            height: paddedHeight
                        )
                    }

                    let displayRect = CGRect(
                        x: originalRect.minX * scale + imageOffset.x,
                        y: originalRect.minY * scale + imageOffset.y,
                        width: originalRect.width * scale,
                        height: originalRect.height * scale
                    )

                    let handlePositions = getHandlePositions(for: displayRect, tool: selectedAnnotation.tool)
                    let handleSize: CGFloat = 8

                    for (_, position) in handlePositions {
                        let handleRect = CGRect(x: position.x - handleSize / 2,
                                               y: position.y - handleSize / 2,
                                               width: handleSize,
                                               height: handleSize)

                        context.fill(Path(ellipseIn: handleRect), with: .color(.white))
                        context.stroke(Path(ellipseIn: handleRect), with: .color(.blue), lineWidth: 2)
                    }
                }
            }
            .gesture(drawingGesture(in: canvasSize))
            .onTapGesture(count: 2) { location in
                handleDoubleTap(at: location, in: canvasSize)
            }
            .onContinuousHover { phase in
                switch phase {
                case .active(let location):
                    updateCursor(at: location, in: canvasSize)
                case .ended:
                    NSCursor.arrow.set()
                }
            }
    }

    private func handleDoubleTap(at location: CGPoint, in canvasSize: CGSize) {
        let imageSize = image.size
        let scale = min(canvasSize.width / imageSize.width, canvasSize.height / imageSize.height)
        let scaledImageSize = CGSize(width: imageSize.width * scale, height: imageSize.height * scale)
        let imageOffset = CGPoint(
            x: (canvasSize.width - scaledImageSize.width) / 2,
            y: (canvasSize.height - scaledImageSize.height) / 2
        )

        let imageLocation = CGPoint(
            x: (location.x - imageOffset.x) / scale,
            y: (location.y - imageOffset.y) / scale
        )

        if let (id, index) = findAnnotation(at: imageLocation) {
            let annotation = viewModel.annotations[index]
            if annotation.tool == .text {
                selectedAnnotationID = id
                selectedTool = .select
                onStartEditingText(index)
                showToolControls = true
            }
        }
    }

    private func updateCursor(at location: CGPoint, in canvasSize: CGSize) {
        let imageSize = image.size
        let scale = min(canvasSize.width / imageSize.width, canvasSize.height / imageSize.height)
        let scaledImageSize = CGSize(width: imageSize.width * scale, height: imageSize.height * scale)
        let imageOffset = CGPoint(
            x: (canvasSize.width - scaledImageSize.width) / 2,
            y: (canvasSize.height - scaledImageSize.height) / 2
        )

        let imageLocation = CGPoint(
            x: (location.x - imageOffset.x) / scale,
            y: (location.y - imageOffset.y) / scale
        )

        if selectedTool != .eraser {
            if (selectedTool == .select || selectedTool == .move) {
                if let selectedID = selectedAnnotationID,
                   let annotation = viewModel.annotations.first(where: { $0.id == selectedID }),
                   !isEditingText {
                    if let _ = detectHandle(at: imageLocation, for: annotation.rect, tool: annotation.tool) {
                        NSCursor.crosshair.set()
                        return
                    }
                }
            }

            if let _ = findAnnotation(at: imageLocation) {
                NSCursor.openHand.set()
                return
            }
        }

        switch selectedTool {
        case .pen:
            NSCursor.crosshair.set()
        case .eraser:
            NSCursor.crosshair.set()
        default:
            NSCursor.arrow.set()
        }
    }

    private func drawingGesture(in canvasSize: CGSize) -> some Gesture {
        let imageSize = image.size
        let scale = min(canvasSize.width / imageSize.width, canvasSize.height / imageSize.height)

        let scaledImageSize = CGSize(
            width: imageSize.width * scale,
            height: imageSize.height * scale
        )

        let imageOffset = CGPoint(
            x: (canvasSize.width - scaledImageSize.width) / 2,
            y: (canvasSize.height - scaledImageSize.height) / 2
        )

        func toImageCoords(_ point: CGPoint) -> CGPoint {
            return CGPoint(
                x: (point.x - imageOffset.x) / scale,
                y: (point.y - imageOffset.y) / scale
            )
        }

        func toImageSize(_ size: CGSize) -> CGSize {
            return CGSize(width: size.width / scale, height: size.height / scale)
        }

        return DragGesture(minimumDistance: 0, coordinateSpace: .local)
            .onChanged { value in
                let imageLocation = toImageCoords(value.location)

                if movingAnnotationID != nil {
                    dragOffset = value.translation
                    return
                }

                switch selectedTool {
                case .select:
                    if resizingHandle == nil, movingAnnotationID == nil {
                        if let selectedID = selectedAnnotationID,
                           let annotation = viewModel.annotations.first(where: { $0.id == selectedID }) {
                            let isEditingThisText = isEditingText && viewModel.annotations.firstIndex(where: { $0.id == selectedID }) == editingTextIndex

                            if !isEditingThisText {
                                if let handle = detectHandle(at: imageLocation, for: annotation.rect, tool: annotation.tool) {
                                    resizingHandle = handle
                                    originalRect = annotation.rect
                                } else if annotation.rect.contains(imageLocation) {
                                    movingAnnotationID = selectedID
                                    dragOffset = .zero
                                } else if let (id, index) = findAnnotation(at: imageLocation) {
                                    let clickedAnnotation = viewModel.annotations[index]
                                    selectedAnnotationID = id

                                    let isEditingThisText = clickedAnnotation.tool == .text && isEditingText && editingTextIndex == index
                                    if !isEditingThisText {
                                        movingAnnotationID = id
                                        dragOffset = .zero
                                    }
                                }
                            }
                        } else if let (id, index) = findAnnotation(at: imageLocation) {
                            let clickedAnnotation = viewModel.annotations[index]
                            selectedAnnotationID = id

                            let isEditingThisText = clickedAnnotation.tool == .text && isEditingText && editingTextIndex == index
                            if !isEditingThisText {
                                movingAnnotationID = id
                                dragOffset = .zero
                            }
                        }
                    }

                    if let handle = resizingHandle, let original = originalRect,
                       let selectedID = selectedAnnotationID,
                       let index = viewModel.annotations.firstIndex(where: { $0.id == selectedID }) {
                        let newRect = calculateResizedRect(originalRect: original, handle: handle, dragTo: imageLocation)
                        viewModel.annotations[index].rect = newRect

                        if viewModel.annotations[index].tool == .arrow || viewModel.annotations[index].tool == .line {
                            viewModel.annotations[index].startPoint = CGPoint(x: newRect.minX, y: newRect.minY)
                            viewModel.annotations[index].endPoint = CGPoint(x: newRect.maxX, y: newRect.maxY)
                        }
                    } else if movingAnnotationID != nil {
                        dragOffset = value.translation
                    }
                case .move:
                    if resizingHandle == nil, movingAnnotationID == nil {
                        if let selectedID = selectedAnnotationID,
                           let annotation = viewModel.annotations.first(where: { $0.id == selectedID }) {
                            if let handle = detectHandle(at: imageLocation, for: annotation.rect, tool: annotation.tool) {
                                resizingHandle = handle
                                originalRect = annotation.rect
                            } else if let (id, _) = findAnnotation(at: imageLocation) {
                                movingAnnotationID = id
                                dragOffset = .zero
                            }
                        } else if let (id, _) = findAnnotation(at: imageLocation) {
                            movingAnnotationID = id
                            dragOffset = .zero
                        }
                    }

                    if let handle = resizingHandle, let original = originalRect,
                       let selectedID = selectedAnnotationID,
                       let index = viewModel.annotations.firstIndex(where: { $0.id == selectedID }) {
                        let newRect = calculateResizedRect(originalRect: original, handle: handle, dragTo: imageLocation)
                        viewModel.annotations[index].rect = newRect

                        if viewModel.annotations[index].tool == .arrow || viewModel.annotations[index].tool == .line {
                            viewModel.annotations[index].startPoint = CGPoint(x: newRect.minX, y: newRect.minY)
                            viewModel.annotations[index].endPoint = CGPoint(x: newRect.maxX, y: newRect.maxY)
                        }
                    } else if movingAnnotationID != nil {
                        dragOffset = value.translation
                    }
                case .eraser:
                     if let (id, _) = findAnnotation(at: imageLocation) {
                        viewModel.removeAnnotation(with: id, undoManager: undoManager)
                    }
                case .pin, .emoji:
                    if resizingHandle == nil,
                       let selectedID = selectedAnnotationID,
                       let annotation = viewModel.annotations.first(where: { $0.id == selectedID }) {
                        if let handle = detectHandle(at: imageLocation, for: annotation.rect, tool: annotation.tool) {
                            resizingHandle = handle
                            originalRect = annotation.rect
                        }
                    } else if resizingHandle != nil {
                        if let handle = resizingHandle, let original = originalRect,
                           let selectedID = selectedAnnotationID,
                           let index = viewModel.annotations.firstIndex(where: { $0.id == selectedID }) {
                            let newRect = calculateResizedRect(originalRect: original, handle: handle, dragTo: imageLocation)
                            viewModel.annotations[index].rect = newRect
                        }
                    }
                case .text:
                    break

                case .pen:
                    if movingAnnotationID != nil {
                        break
                    }

                    if liveDrawingPath == nil {
                        liveDrawingPath = [imageLocation]
                    } else {
                        liveDrawingPath?.append(imageLocation)
                    }
                default:
                    if movingAnnotationID != nil {
                        break
                    }

                    if resizingHandle == nil, liveDrawingStart == nil,
                       let selectedID = selectedAnnotationID,
                       let annotation = viewModel.annotations.first(where: { $0.id == selectedID }) {
                        if let handle = detectHandle(at: imageLocation, for: annotation.rect, tool: annotation.tool) {
                            resizingHandle = handle
                            originalRect = annotation.rect
                        } else if annotation.tool == selectedTool {
                            liveDrawingStart = value.location
                            liveDrawingEnd = value.location
                        } else {
                            liveDrawingStart = value.location
                            liveDrawingEnd = value.location
                        }
                    } else if resizingHandle != nil {
                        if let handle = resizingHandle, let original = originalRect,
                           let selectedID = selectedAnnotationID,
                           let index = viewModel.annotations.firstIndex(where: { $0.id == selectedID }) {
                            let newRect = calculateResizedRect(originalRect: original, handle: handle, dragTo: imageLocation)
                            viewModel.annotations[index].rect = newRect

                            if viewModel.annotations[index].tool == .arrow || viewModel.annotations[index].tool == .line {
                                viewModel.annotations[index].startPoint = CGPoint(x: newRect.minX, y: newRect.minY)
                                viewModel.annotations[index].endPoint = CGPoint(x: newRect.maxX, y: newRect.maxY)
                            }
                        }
                    } else {
                        if liveDrawingStart == nil {
                            liveDrawingStart = value.location
                        }
                        liveDrawingEnd = value.location
                    }
                }
            }
            .onEnded { value in
                let imageLocation = toImageCoords(value.location)
                let imageTranslation = toImageSize(value.translation)
                let dragDistance = hypot(value.translation.width, value.translation.height)

                if resizingHandle != nil, let original = originalRect,
                   let selectedID = selectedAnnotationID,
                   let index = viewModel.annotations.firstIndex(where: { $0.id == selectedID }) {

                    if dragDistance >= 5 {
                        let finalRect = viewModel.annotations[index].rect
                        viewModel.updateAnnotationRect(at: index, newRect: finalRect, oldRect: original, undoManager: undoManager)
                        resizingHandle = nil
                        self.originalRect = nil
                        return
                    } else {
                        resizingHandle = nil
                        self.originalRect = nil
                    }
                }

                if let movingID = movingAnnotationID, let index = viewModel.annotations.firstIndex(where: { $0.id == movingID }) {
                    if dragDistance >= 5 {
                        let oldRect = viewModel.annotations[index].rect
                        let newRect = oldRect.offsetBy(dx: imageTranslation.width, dy: imageTranslation.height)
                        viewModel.moveAnnotation(at: index, to: newRect, from: oldRect, undoManager: undoManager)

                        let tool = viewModel.annotations[index].tool
                        if tool == .arrow || tool == .line {
                            if let start = viewModel.annotations[index].startPoint,
                               let end = viewModel.annotations[index].endPoint {
                                viewModel.annotations[index].startPoint = CGPoint(
                                    x: start.x + imageTranslation.width,
                                    y: start.y + imageTranslation.height
                                )
                                viewModel.annotations[index].endPoint = CGPoint(
                                    x: end.x + imageTranslation.width,
                                    y: end.y + imageTranslation.height
                                )
                            }
                        }

                        selectedAnnotationID = movingID
                        showToolControls = true
                        movingAnnotationID = nil
                        dragOffset = .zero

                        liveDrawingStart = nil
                        liveDrawingEnd = nil
                        liveDrawingPath = nil
                        resizingHandle = nil
                        self.originalRect = nil

                        return
                    } else {
                        selectedAnnotationID = movingID
                        showToolControls = true
                        movingAnnotationID = nil
                        dragOffset = .zero

                        liveDrawingStart = nil
                        liveDrawingEnd = nil
                        liveDrawingPath = nil

                        return
                    }
                }

                if selectedTool == .select || selectedTool == .move {
                    if let (id, _) = findAnnotation(at: imageLocation) {
                        selectedAnnotationID = id
                        showToolControls = true
                        return
                    } else {
                        selectedAnnotationID = nil
                        showToolControls = false
                        resizingHandle = nil
                        self.originalRect = nil
                        movingAnnotationID = nil
                        dragOffset = .zero
                        if isEditingText {
                            onStopEditingText()
                        }
                    }
                } else if selectedTool == .eraser {
                    if dragDistance < 5 {
                        selectedAnnotationID = nil
                        showToolControls = false
                    }
                }

                switch selectedTool {
                case .select:
                    break
                case .move:
                    break
                case .eraser:
                    break
                case .pin:
                    let rect = CGRect(
                        x: imageLocation.x - numberSize / 2,
                        y: imageLocation.y - numberSize / 2,
                        width: numberSize,
                        height: numberSize
                    )

                    var newAnnotation = Annotation(rect: rect, color: selectedColor, lineWidth: selectedLineWidth, tool: .pin)
                    newAnnotation.number = viewModel.currentNumber
                    newAnnotation.numberShape = numberShape
                    print("🔢 Pin oluşturuldu: number=\(viewModel.currentNumber), shape=\(numberShape)")
                    viewModel.currentNumber += 1
                    viewModel.addAnnotation(newAnnotation, undoManager: undoManager)

                    selectedAnnotationID = newAnnotation.id
                    print("📌 Pin eklendi ve seçildi, tool aktif kalıyor. ESC ile çıkabilirsiniz.")

                case .pen:
                    if movingAnnotationID != nil {
                        break
                    }

                    if let path = liveDrawingPath, path.count > 1 {
                        let minX = path.map { $0.x }.min() ?? 0
                        let maxX = path.map { $0.x }.max() ?? 0
                        let minY = path.map { $0.y }.min() ?? 0
                        let maxY = path.map { $0.y }.max() ?? 0
                        let rect = CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)

                        var newAnnotation = Annotation(rect: rect, color: selectedColor, lineWidth: selectedLineWidth, tool: .pen)
                        newAnnotation.path = path
                        newAnnotation.brushStyle = selectedBrushStyle
                        viewModel.addAnnotation(newAnnotation, undoManager: undoManager)

                    }

                    liveDrawingPath = nil

                case .emoji:
                    if movingAnnotationID != nil {
                        break
                    }

                    if resizingHandle != nil, let original = originalRect,
                       let selectedID = selectedAnnotationID,
                       let index = viewModel.annotations.firstIndex(where: { $0.id == selectedID }) {
                        let finalRect = viewModel.annotations[index].rect
                        viewModel.updateAnnotationRect(at: index, newRect: finalRect, oldRect: original, undoManager: undoManager)
                        resizingHandle = nil
                        originalRect = nil
                    } else {
                        let rect = CGRect(
                            x: imageLocation.x - emojiSize / 2,
                            y: imageLocation.y - emojiSize / 2,
                            width: emojiSize,
                            height: emojiSize
                        )

                        var newAnnotation = Annotation(rect: rect, color: selectedColor, lineWidth: selectedLineWidth, tool: .emoji)
                        newAnnotation.emoji = selectedEmoji
                        viewModel.addAnnotation(newAnnotation, undoManager: undoManager)

                        selectedAnnotationID = newAnnotation.id
                        showToolControls = true

                        selectedTool = .select
                    }

                case .text:
                    if movingAnnotationID != nil {
                        break
                    }

                    if resizingHandle == nil && liveDrawingStart == nil {
                        let initialWidth: CGFloat = 50
                        let initialHeight: CGFloat = 30
                        let rect = CGRect(
                            x: imageLocation.x,
                            y: imageLocation.y,
                            width: initialWidth,
                            height: initialHeight
                        )

                        var newAnnotation = Annotation(rect: rect, color: selectedColor, lineWidth: selectedLineWidth, tool: .text)
                        newAnnotation.backgroundColor = Color(red: 1.0, green: 0.38, blue: 0.27)
                        viewModel.addAnnotation(newAnnotation, undoManager: undoManager)

                        selectedAnnotationID = newAnnotation.id
                        showToolControls = true

                        selectedTool = .select

                        if let index = viewModel.annotations.lastIndex(where: { $0.id == newAnnotation.id }) {
                            onStartEditingText(index)
                        }
                    }

                default:
                    if resizingHandle != nil, let original = originalRect,
                       let selectedID = selectedAnnotationID,
                       let index = viewModel.annotations.firstIndex(where: { $0.id == selectedID }) {
                        let finalRect = viewModel.annotations[index].rect
                        viewModel.updateAnnotationRect(at: index, newRect: finalRect, oldRect: original, undoManager: undoManager)
                        resizingHandle = nil
                        originalRect = nil
                    } else if let start = liveDrawingStart {
                        let imageStart = toImageCoords(start)
                        let imageEnd = imageLocation
                        let rect = CGRect(from: imageStart, to: imageEnd)

                        if rect.width > 2 || rect.height > 2 {
                            var newAnnotation = Annotation(rect: rect, color: selectedColor, lineWidth: selectedLineWidth, tool: selectedTool)
                            newAnnotation.startPoint = imageStart
                            newAnnotation.endPoint = imageEnd

                            if selectedTool == .rectangle {
                                newAnnotation.cornerRadius = shapeCornerRadius
                                newAnnotation.fillMode = shapeFillMode
                            } else if selectedTool == .ellipse {
                                newAnnotation.fillMode = shapeFillMode
                            } else if selectedTool == .spotlight {
                                newAnnotation.spotlightShape = spotlightShape
                            }

                            viewModel.addAnnotation(newAnnotation, undoManager: undoManager)

                            selectedAnnotationID = newAnnotation.id
                            showToolControls = true

                            selectedTool = .select
                        }
                    }
                }
                liveDrawingStart = nil
                liveDrawingEnd = nil
                resizingHandle = nil
                originalRect = nil
            }
    }

    private func findAnnotation(at point: CGPoint) -> (id: UUID, index: Int)? {
        for (index, annotation) in viewModel.annotations.enumerated().reversed() {
            if annotation.tool == .arrow || annotation.tool == .line {
                if let start = annotation.startPoint, let end = annotation.endPoint {
                    let distance = distanceFromPointToLine(point: point, lineStart: start, lineEnd: end)
                    let threshold: CGFloat = 10
                    if distance < threshold {
                        return (annotation.id, index)
                    }
                }
            }

            if annotation.tool == .text && !annotation.text.isEmpty {
                if annotation.rect.contains(point) {
                    return (annotation.id, index)
                }

                let font = NSFont.systemFont(ofSize: annotation.lineWidth * 4)
                let textAttributes: [NSAttributedString.Key: Any] = [.font: font]
                let textSize = (annotation.text as NSString).boundingRect(
                    with: CGSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude),
                    options: [.usesLineFragmentOrigin, .usesFontLeading],
                    attributes: textAttributes
                ).size

                let paddedWidth = textSize.width + 16
                let paddedHeight = textSize.height + 8

                let textRect = CGRect(
                    x: annotation.rect.origin.x,
                    y: annotation.rect.origin.y,
                    width: paddedWidth,
                    height: paddedHeight
                )

                if textRect.contains(point) {
                    return (annotation.id, index)
                }
                continue
            }

            if annotation.rect.contains(point) {
                return (annotation.id, index)
            }
        }
        return nil
    }

    private func distanceFromPointToLine(point: CGPoint, lineStart: CGPoint, lineEnd: CGPoint) -> CGFloat {
        let x0 = point.x
        let y0 = point.y
        let x1 = lineStart.x
        let y1 = lineStart.y
        let x2 = lineEnd.x
        let y2 = lineEnd.y

        let numerator = abs((y2 - y1) * x0 - (x2 - x1) * y0 + x2 * y1 - y2 * x1)
        let denominator = sqrt(pow(y2 - y1, 2) + pow(x2 - x1, 2))

        if denominator == 0 {
            return sqrt(pow(x0 - x1, 2) + pow(y0 - y1, 2))
        }

        return numerator / denominator
    }

    private func getHandlePositions(for rect: CGRect, tool: DrawingTool) -> [ResizeHandle: CGPoint] {
        switch tool {
        case .line, .arrow:
            return [
                .topLeft: CGPoint(x: rect.minX, y: rect.minY),
                .bottomRight: CGPoint(x: rect.maxX, y: rect.maxY)
            ]
        case .text:
            return [:]
        case .emoji:
            return [
                .topLeft: CGPoint(x: rect.minX, y: rect.minY),
                .topRight: CGPoint(x: rect.maxX, y: rect.minY),
                .bottomLeft: CGPoint(x: rect.minX, y: rect.maxY),
                .bottomRight: CGPoint(x: rect.maxX, y: rect.maxY)
            ]
        case .pin:
            return [:]
        case .pen:
            return [
                .topLeft: CGPoint(x: rect.minX, y: rect.minY),
                .top: CGPoint(x: rect.midX, y: rect.minY),
                .topRight: CGPoint(x: rect.maxX, y: rect.minY),
                .left: CGPoint(x: rect.minX, y: rect.midY),
                .right: CGPoint(x: rect.maxX, y: rect.midY),
                .bottomLeft: CGPoint(x: rect.minX, y: rect.maxY),
                .bottom: CGPoint(x: rect.midX, y: rect.maxY),
                .bottomRight: CGPoint(x: rect.maxX, y: rect.maxY)
            ]
        case .rectangle, .ellipse, .highlighter, .pixelate, .spotlight:
            return [
                .topLeft: CGPoint(x: rect.minX, y: rect.minY),
                .top: CGPoint(x: rect.midX, y: rect.minY),
                .topRight: CGPoint(x: rect.maxX, y: rect.minY),
                .left: CGPoint(x: rect.minX, y: rect.midY),
                .right: CGPoint(x: rect.maxX, y: rect.midY),
                .bottomLeft: CGPoint(x: rect.minX, y: rect.maxY),
                .bottom: CGPoint(x: rect.midX, y: rect.maxY),
                .bottomRight: CGPoint(x: rect.maxX, y: rect.maxY)
            ]
        case .select, .move, .eraser:
            return [:]
        }
    }

    private func detectHandle(at point: CGPoint, for rect: CGRect, tool: DrawingTool) -> ResizeHandle? {
        let handleSize: CGFloat = 12
        let positions = getHandlePositions(for: rect, tool: tool)

        for (handle, position) in positions {
            let handleRect = CGRect(x: position.x - handleSize / 2,
                                   y: position.y - handleSize / 2,
                                   width: handleSize,
                                   height: handleSize)
            if handleRect.contains(point) {
                return handle
            }
        }
        return nil
    }

    private func calculateResizedRect(originalRect: CGRect, handle: ResizeHandle, dragTo point: CGPoint) -> CGRect {
        var newRect = originalRect

        switch handle {
        case .topLeft:
            newRect = CGRect(x: point.x, y: point.y,
                           width: originalRect.maxX - point.x,
                           height: originalRect.maxY - point.y)
        case .top:
            newRect = CGRect(x: originalRect.minX, y: point.y,
                           width: originalRect.width,
                           height: originalRect.maxY - point.y)
        case .topRight:
            newRect = CGRect(x: originalRect.minX, y: point.y,
                           width: point.x - originalRect.minX,
                           height: originalRect.maxY - point.y)
        case .left:
            newRect = CGRect(x: point.x, y: originalRect.minY,
                           width: originalRect.maxX - point.x,
                           height: originalRect.height)
        case .right:
            newRect = CGRect(x: originalRect.minX, y: originalRect.minY,
                           width: point.x - originalRect.minX,
                           height: originalRect.height)
        case .bottomLeft:
            newRect = CGRect(x: point.x, y: originalRect.minY,
                           width: originalRect.maxX - point.x,
                           height: point.y - originalRect.minY)
        case .bottom:
            newRect = CGRect(x: originalRect.minX, y: originalRect.minY,
                           width: originalRect.width,
                           height: point.y - originalRect.minY)
        case .bottomRight:
            newRect = CGRect(x: originalRect.minX, y: originalRect.minY,
                           width: point.x - originalRect.minX,
                           height: point.y - originalRect.minY)
        }

        let minSize: CGFloat = 20
        if abs(newRect.width) < minSize || abs(newRect.height) < minSize {
            return originalRect
        }

        return newRect.standardized
    }

    private func drawSingleAnnotation(_ annotation: Annotation, rect: CGRect, in context: inout GraphicsContext, canvasSize: CGSize, nsImage: NSImage? = nil) {
        switch annotation.tool {
        case .rectangle:
            let cornerRadius = annotation.cornerRadius
            let rectPath = Path(roundedRect: rect, cornerRadius: cornerRadius)

            switch annotation.fillMode {
            case .fill:
                context.fill(rectPath, with: .color(annotation.color))
            case .stroke:
                context.stroke(rectPath, with: .color(annotation.color), lineWidth: annotation.lineWidth)
            case .both:
                context.fill(rectPath, with: .color(annotation.color.opacity(0.3)))
                context.stroke(rectPath, with: .color(annotation.color), lineWidth: annotation.lineWidth)
            }

        case .ellipse:
            let ellipsePath = Path(ellipseIn: rect)

            switch annotation.fillMode {
            case .fill:
                context.fill(ellipsePath, with: .color(annotation.color))
            case .stroke:
                context.stroke(ellipsePath, with: .color(annotation.color), lineWidth: annotation.lineWidth)
            case .both:
                context.fill(ellipsePath, with: .color(annotation.color.opacity(0.3)))
                context.stroke(ellipsePath, with: .color(annotation.color), lineWidth: annotation.lineWidth)
            }

        case .line:
            if let start = annotation.startPoint, let end = annotation.endPoint {
                var path = Path()
                path.move(to: start)
                path.addLine(to: end)
                context.stroke(path, with: .color(annotation.color), lineWidth: annotation.lineWidth)
            }
        case .highlighter:
            context.blendMode = .multiply
            context.fill(Path(rect), with: .color(annotation.color.opacity(0.5)))
        case .arrow:
            let start = annotation.startPoint ?? rect.origin
            let end = annotation.endPoint ?? rect.endPoint
            if hypot(end.x - start.x, end.y - start.y) > annotation.lineWidth * 2 {
                let path = Path.arrow(from: start, to: end, tailWidth: annotation.lineWidth, headWidth: annotation.lineWidth * 3, headLength: annotation.lineWidth * 3)
                context.fill(path, with: .color(annotation.color))
            }
        case .pixelate:
            context.fill(Path(rect), with: .color(.black.opacity(0.85)))

        case .pin:
            let diameter = rect.width
            let shapeRect = CGRect(x: rect.minX, y: rect.minY, width: diameter, height: diameter)

            let shape = annotation.numberShape ?? .circle
            let shapePath: Path
            switch shape {
            case .circle:
                shapePath = Path(ellipseIn: shapeRect)
            case .square:
                shapePath = Path(shapeRect)
            case .roundedSquare:
                shapePath = Path(roundedRect: shapeRect, cornerRadius: diameter * 0.2)
            }
            context.fill(shapePath, with: .color(annotation.color))

            if let number = annotation.number {
                let fontSize = diameter * 0.55
                let numberText = "\(number)"

                let text = Text(numberText)
                    .font(.system(size: fontSize, weight: .bold))
                    .foregroundColor(.white)

                let resolved = context.resolve(text)

                context.draw(resolved, at: CGPoint(x: shapeRect.midX, y: shapeRect.midY), anchor: .center)
            }

        case .text:
            let isEditing = editingTextIndex == viewModel.annotations.firstIndex(where: { $0.id == annotation.id })

            if !isEditing && !annotation.text.isEmpty {
                if let bgColor = annotation.backgroundColor {
                    let bgPath = Path(roundedRect: rect, cornerRadius: 6)
                    context.fill(bgPath, with: .color(bgColor))
                }

                let text = Text(annotation.text)
                    .font(.system(size: annotation.lineWidth * 4))
                    .foregroundColor(annotation.color)

                let resolved = context.resolve(text)
                context.draw(resolved, in: CGRect(
                    x: rect.minX + 8,
                    y: rect.minY + 4,
                    width: rect.width,
                    height: rect.height
                ))
            } else if annotation.text.isEmpty && isEditing {
                let path = Path(rect)
                context.stroke(path, with: .color(.gray), style: StrokeStyle(lineWidth: 1, dash: [4]))
            }
        case .emoji:
            if let emoji = annotation.emoji {
                let fontSize = rect.width * 0.8
                let emojiText = Text(emoji)
                    .font(.system(size: fontSize))

                let resolved = context.resolve(emojiText)

                context.draw(resolved, at: CGPoint(x: rect.midX, y: rect.midY), anchor: .center)
            }

        case .pen:
            if let path = annotation.path, path.count > 1 {
                var bezierPath = Path()
                bezierPath.move(to: path[0])
                for i in 1..<path.count {
                    bezierPath.addLine(to: path[i])
                }

                let brushStyle = annotation.brushStyle ?? .solid
                switch brushStyle {
                case .solid:
                    context.stroke(bezierPath, with: .color(annotation.color), lineWidth: annotation.lineWidth)
                case .dashed:
                    context.stroke(bezierPath, with: .color(annotation.color), style: StrokeStyle(lineWidth: annotation.lineWidth, dash: [10, 5]))
                case .marker:
                    context.stroke(bezierPath, with: .color(annotation.color.opacity(0.5)), style: StrokeStyle(lineWidth: annotation.lineWidth * 2, lineCap: .round, lineJoin: .round))
                }
            }

        case .spotlight:
            var fullScreenPath = Path(CGRect(origin: .zero, size: canvasSize))

            let spotPath: Path
            if annotation.spotlightShape == .rectangle {
                spotPath = Path(roundedRect: rect, cornerRadius: 8)
            } else {
                spotPath = Path(ellipseIn: rect)
            }
            fullScreenPath.addPath(spotPath)

            context.fill(fullScreenPath, with: .color(.black.opacity(0.6)), style: FillStyle(eoFill: true))

            context.stroke(spotPath, with: .color(.white.opacity(0.5)), lineWidth: 2)

        case .move, .eraser, .select:
            break
        }

    }
}

extension CGRect {
    init(from: CGPoint, to: CGPoint) {
        self.init(x: min(from.x, to.x), y: min(from.y, to.y), width: abs(from.x - to.x), height: abs(from.y - to.y))
    }
}

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

struct CustomTextEditor: NSViewRepresentable {
    @Binding var text: String
    var font: NSFont
    var textColor: NSColor
    var backgroundColor: NSColor?
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

        textView.textContainer?.widthTracksTextView = false
        textView.textContainer?.containerSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.isHorizontallyResizable = true
        textView.isVerticallyResizable = true
        textView.autoresizingMask = []

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
            let horizontalInset = inset.width * 2
            let verticalInset = inset.height * 2

            let minWidth: CGFloat = 50
            let minHeight: CGFloat = 20
            let newWidth = max(minWidth, usedRect.width + horizontalInset)
            let newHeight = max(minHeight, usedRect.height + verticalInset)

            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.parent.onHeightChange?(usedRect.height)
                self.parent.onSizeChange?(CGSize(width: newWidth, height: newHeight))
            }
        }
    }
}

extension CGRect {
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

struct ShapePickerView: View {
    @Binding var selectedTool: DrawingTool
    @Binding var isPresented: Bool
    @Binding var showToolControls: Bool
    @EnvironmentObject var settings: SettingsManager

    let shapes: [DrawingTool] = [.rectangle, .ellipse, .line]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(L("Shapes", settings: settings))
                .font(.headline)
                .padding(.horizontal, 12)
                .padding(.top, 12)
                .padding(.bottom, 8)

            ForEach(shapes) { shape in
                Button(action: {
                    selectedTool = shape
                    showToolControls = true
                    print("🔧 Shape seçildi: \(shape.rawValue), Control panel açıldı")
                    isPresented = false
                }) {
                    HStack(spacing: 12) {
                        ZStack {
                            if shape == .rectangle {
                                RoundedRectangle(cornerRadius: 2)
                                    .stroke(Color.accentColor, lineWidth: 2)
                                    .frame(width: 32, height: 24)
                            } else if shape == .ellipse {
                                Ellipse()
                                    .stroke(Color.accentColor, lineWidth: 2)
                                    .frame(width: 32, height: 24)
                            } else if shape == .line {
                                Path { path in
                                    path.move(to: CGPoint(x: 0, y: 12))
                                    path.addLine(to: CGPoint(x: 32, y: 12))
                                }
                                .stroke(Color.accentColor, lineWidth: 2)
                                .frame(width: 32, height: 24)
                            }
                        }
                        .frame(width: 40, height: 32)

                        Text(shape.localizedName)
                            .font(.body)

                        Spacer()

                        if selectedTool == shape {
                            Image(systemName: "checkmark")
                                .foregroundColor(.accentColor)
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .background(selectedTool == shape ? Color.accentColor.opacity(0.1) : Color.clear)
            }
        }
        .frame(width: 200)
        .padding(.bottom, 8)
    }
}

struct EmojiPickerView: View {
    @Binding var selectedEmoji: String
    @Binding var isPresented: Bool
    @State private var selectedCategory: EmojiCategory = .symbols

    enum EmojiCategory: String, CaseIterable {
        case symbols = "Semboller"
        case smileys = "Yüzler"
        case hands = "Eller"
        case arrows = "Oklar"
        case nature = "Doğa"

        var icon: String {
            switch self {
            case .symbols: return "checkmark.seal.fill"
            case .smileys: return "face.smiling"
            case .hands: return "hand.thumbsup.fill"
            case .arrows: return "arrow.right.circle.fill"
            case .nature: return "leaf.fill"
            }
        }

        var emojis: [String] {
            switch self {
            case .symbols:
                return ["✅", "❌", "⚠️", "⭐️", "💯", "📌", "🔴", "🟢", "🟡", "🔵", "🟣", "🟠", "⚫️", "⚪️", "🟤", "✏️", "📝", "🎯", "⚡️", "🔥", "💥", "✨", "💫", "⭕️", "❗️", "❓", "➕", "➖", "✖️", "➗"]
            case .smileys:
                return ["😀", "😃", "😄", "😁", "😅", "😂", "🤣", "😊", "😇", "🙂", "😉", "😍", "🥰", "😘", "😋", "😎", "🤓", "🧐", "🤔", "🤨", "😐", "😑", "😶", "🙄", "😏", "😣", "😥", "😮", "🤐", "😯"]
            case .hands:
                return ["👍", "👎", "👌", "✌️", "🤞", "🤟", "🤘", "🤙", "👈", "👉", "👆", "👇", "☝️", "✋", "🤚", "🖐", "🖖", "👋", "🤝", "👏", "🙌", "👐", "🤲", "🤜", "🤛", "✊", "👊", "🤏", "💪", "🦾"]
            case .arrows:
                return ["➡️", "⬅️", "⬆️", "⬇️", "↗️", "↘️", "↙️", "↖️", "↕️", "↔️", "↩️", "↪️", "⤴️", "⤵️", "🔄", "🔃", "🔁", "🔂", "▶️", "◀️", "🔼", "🔽", "⏸", "⏯", "⏹", "⏺", "⏭", "⏮", "⏩", "⏪"]
            case .nature:
                return ["🌱", "🌿", "☘️", "🍀", "🌾", "🌵", "🌲", "🌳", "🌴", "🌻", "🌼", "🌷", "🌹", "🥀", "🌺", "🌸", "💐", "🌰", "🍁", "🍂", "🍃", "🌍", "🌎", "🌏", "🌐", "🌑", "🌒", "🌓", "🌔", "🌕"]
            }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            Text("Emoji Seç")
                .font(.headline)
                .padding(.horizontal, 12)
                .padding(.top, 12)
                .padding(.bottom, 8)

            HStack(spacing: 4) {
                ForEach(EmojiCategory.allCases, id: \.self) { category in
                    Button(action: {
                        selectedCategory = category
                    }) {
                        VStack(spacing: 2) {
                            Image(systemName: category.icon)
                                .font(.system(size: 16))
                                .foregroundColor(selectedCategory == category ? .accentColor : .secondary)
                        }
                        .frame(width: 44, height: 32)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(selectedCategory == category ? Color.accentColor.opacity(0.15) : Color.clear)
                        )
                    }
                    .buttonStyle(.plain)
                    .help(category.rawValue)
                }
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 8)

            Divider()

            ScrollView {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 44))], spacing: 8) {
                    ForEach(selectedCategory.emojis, id: \.self) { emoji in
                        Button(action: {
                            selectedEmoji = emoji
                            isPresented = false
                        }) {
                            Text(emoji)
                                .font(.system(size: 28))
                                .frame(width: 44, height: 44)
                                .background(
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(selectedEmoji == emoji ? Color.accentColor.opacity(0.15) : Color.clear)
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(selectedEmoji == emoji ? Color.accentColor : Color.clear, lineWidth: 2)
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 12)
            }
            .frame(height: 280)
        }
        .frame(width: 280)
    }
}

struct LineWidthPickerView: View {
    @Binding var selectedLineWidth: CGFloat
    @Binding var isPresented: Bool
    @EnvironmentObject var settings: SettingsManager

    let widths: [(label: String, value: CGFloat)] = [
        ("width.small", 4),
        ("width.medium", 8),
        ("width.large", 12)
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(L("Line Width", settings: settings))
                .font(.headline)
                .padding(.horizontal, 12)
                .padding(.top, 12)
                .padding(.bottom, 8)

            ForEach(widths, id: \.value) { width in
                Button(action: {
                    selectedLineWidth = width.value
                    isPresented = false
                }) {
                    HStack(spacing: 12) {
                        ZStack {
                            Capsule()
                                .fill(Color.accentColor)
                                .frame(width: 40, height: width.value)
                        }
                        .frame(width: 50, height: 32)

                        Text(L(width.label, settings: settings))
                            .font(.body)

                        Spacer()

                        if selectedLineWidth == width.value {
                            Image(systemName: "checkmark")
                                .foregroundColor(.accentColor)
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .background(selectedLineWidth == width.value ? Color.accentColor.opacity(0.1) : Color.clear)
            }
        }
        .frame(width: 220)
        .padding(.bottom, 8)
    }
}

struct ToolControlPanel: View {
    @Binding var isPresented: Bool
    @Binding var selectedAnnotationID: UUID?
    @ObservedObject var viewModel: ScreenshotEditorViewModel
    let selectedTool: DrawingTool
    @EnvironmentObject var settings: SettingsManager
    @Binding var selectedColor: Color
    @Binding var selectedLineWidth: CGFloat

    @Binding var numberSize: CGFloat
    @Binding var numberShape: NumberShape

    @Binding var shapeCornerRadius: CGFloat
    @Binding var shapeFillMode: FillMode

    @Binding var spotlightShape: SpotlightShape

    @Binding var selectedEmoji: String
    @Binding var emojiSize: CGFloat

    @Binding var selectedBrushStyle: BrushStyle

    var currentAnnotation: Annotation? {
        guard let id = selectedAnnotationID else { return nil }
        return viewModel.annotations.first(where: { $0.id == id })
    }

    var body: some View {
        HStack(spacing: 12) {
            Button(action: { isPresented = false }) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.secondary)
                    .frame(width: 28, height: 28)
            }
            .buttonStyle(.plain)
            .help(L("Close", settings: settings))

            if selectedTool != .move && selectedTool != .eraser {
                ColorPicker("", selection: Binding(
                    get: { currentAnnotation?.color ?? selectedColor },
                    set: { newColor in
                        selectedColor = newColor
                        if let id = selectedAnnotationID,
                           let index = viewModel.annotations.firstIndex(where: { $0.id == id }) {
                            viewModel.annotations[index].color = newColor
                        }
                    }
                ), supportsOpacity: false)
                .labelsHidden()
                .frame(width: 32, height: 32)
                .help(L("Color", settings: settings))
            }

            if let currentAnnotation = currentAnnotation {
                switch currentAnnotation.tool {
                case .text:
                    textControls
                case .pin:
                    numberControls
                case .rectangle:
                    rectangleControls
                case .ellipse:
                    ellipseControls
                case .arrow, .line:
                    lineWidthControl
                case .spotlight:
                    spotlightControls
                case .emoji:
                    emojiControls
                case .pen:
                    penControls
                default:
                    EmptyView()
                }
            } else {
                switch selectedTool {
                case .text:
                    textControls
                case .pin:
                    numberControls
                case .rectangle:
                    rectangleControls
                case .ellipse:
                    ellipseControls
                case .arrow, .line:
                    lineWidthControl
                case .spotlight:
                    spotlightControls
                case .emoji:
                    emojiControls
                case .pen:
                    penControls
                default:
                    EmptyView()
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(nsColor: .windowBackgroundColor))
                .shadow(color: .black.opacity(0.2), radius: 12, y: 6)
        )
    }

    @ViewBuilder
    var numberControls: some View {
        HStack(spacing: 8) {
            Image(systemName: "circle.fill")
                .font(.system(size: 10))
                .foregroundColor(.secondary)

            Slider(value: Binding(
                get: {
                    if let annotation = currentAnnotation {
                        return annotation.rect.width
                    }
                    return numberSize
                },
                set: { newSize in
                    numberSize = newSize
                    if let id = selectedAnnotationID,
                       let index = viewModel.annotations.firstIndex(where: { $0.id == id }) {
                        let center = CGPoint(
                            x: viewModel.annotations[index].rect.midX,
                            y: viewModel.annotations[index].rect.midY
                        )
                        viewModel.annotations[index].rect = CGRect(
                            x: center.x - newSize / 2,
                            y: center.y - newSize / 2,
                            width: newSize,
                            height: newSize
                        )
                    }
                }
            ), in: 20...120, step: 5)
            .frame(width: 100)

            Image(systemName: "circle.fill")
                .font(.system(size: 16))
                .foregroundColor(.secondary)

            Divider()
                .frame(height: 20)

            Menu {
                ForEach(NumberShape.allCases, id: \.self) { shape in
                    Button(action: {
                        numberShape = shape
                        if let id = selectedAnnotationID,
                           let index = viewModel.annotations.firstIndex(where: { $0.id == id }) {
                            viewModel.annotations[index].numberShape = shape
                        }
                    }) {
                        HStack {
                            Text(shape.rawValue)
                            if (currentAnnotation?.numberShape ?? numberShape) == shape {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "shape")
                        .font(.system(size: 12))
                    Text((currentAnnotation?.numberShape ?? numberShape).rawValue)
                        .font(.system(size: 11))
                }
                .foregroundColor(.secondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.secondary.opacity(0.1))
                )
            }
            .menuStyle(.borderlessButton)
            .help(L("Shape", settings: settings))
        }
    }

    @ViewBuilder
    var lineWidthControl: some View {
        HStack(spacing: 6) {
            Image(systemName: "line.diagonal")
                .font(.system(size: 10))
                .foregroundColor(.secondary)

            Slider(value: Binding(
                get: { currentAnnotation?.lineWidth ?? selectedLineWidth },
                set: { newWidth in
                    selectedLineWidth = newWidth
                    if let id = selectedAnnotationID,
                       let index = viewModel.annotations.firstIndex(where: { $0.id == id }) {
                        viewModel.annotations[index].lineWidth = newWidth
                    }
                }
            ), in: 1...20, step: 1)
            .frame(width: 100)

            Text("\(Int(currentAnnotation?.lineWidth ?? selectedLineWidth))")
                .font(.caption2)
                .foregroundColor(.secondary)
                .frame(width: 20)
        }
    }

    @ViewBuilder
    var rectangleControls: some View {
        fillModeButtons

        HStack(spacing: 6) {
            Image(systemName: "square")
                .font(.system(size: 10))
                .foregroundColor(.secondary)

            Slider(value: Binding(
                get: { currentAnnotation?.cornerRadius ?? shapeCornerRadius },
                set: { newValue in
                    shapeCornerRadius = newValue
                    if let id = selectedAnnotationID,
                       let index = viewModel.annotations.firstIndex(where: { $0.id == id }) {
                        viewModel.annotations[index].cornerRadius = newValue
                    }
                }
            ), in: 0...50, step: 2)
            .frame(width: 80)

            Image(systemName: "square")
                .font(.system(size: 16))
                .foregroundColor(.secondary)
        }
    }

    @ViewBuilder
    var ellipseControls: some View {
        fillModeButtons
    }

    @ViewBuilder
    var fillModeButtons: some View {
        HStack(spacing: 6) {
            ForEach(FillMode.allCases, id: \.self) { mode in
                Button(action: {
                    shapeFillMode = mode
                    if let id = selectedAnnotationID,
                       let index = viewModel.annotations.firstIndex(where: { $0.id == id }) {
                        viewModel.annotations[index].fillMode = mode
                    }
                }) {
                    Image(systemName: mode.icon)
                        .font(.system(size: 14))
                        .foregroundColor((currentAnnotation?.fillMode ?? shapeFillMode) == mode ? .accentColor : .secondary)
                        .frame(width: 28, height: 28)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill((currentAnnotation?.fillMode ?? shapeFillMode) == mode ? Color.accentColor.opacity(0.15) : Color.clear)
                        )
                }
                .buttonStyle(.plain)
                .help(L(mode.rawValue, settings: settings))
            }
        }
    }

    @ViewBuilder
    var emojiControls: some View {
        HStack(spacing: 6) {
            Image(systemName: "textformat.size.smaller")
                .font(.system(size: 10))
                .foregroundColor(.secondary)

            Slider(value: Binding(
                get: {
                    if let annotation = currentAnnotation {
                        return annotation.rect.width
                    }
                    return emojiSize
                },
                set: { newSize in
                    emojiSize = newSize
                    if let id = selectedAnnotationID,
                       let index = viewModel.annotations.firstIndex(where: { $0.id == id }) {
                        let center = CGPoint(
                            x: viewModel.annotations[index].rect.midX,
                            y: viewModel.annotations[index].rect.midY
                        )
                        viewModel.annotations[index].rect = CGRect(
                            x: center.x - newSize / 2,
                            y: center.y - newSize / 2,
                            width: newSize,
                            height: newSize
                        )
                    }
                }
            ), in: 24...120, step: 4)
            .frame(width: 120)

            Image(systemName: "textformat.size.larger")
                .font(.system(size: 14))
                .foregroundColor(.secondary)
        }
    }

    @ViewBuilder
    var penControls: some View {
        HStack(spacing: 6) {
            Image(systemName: "line.diagonal")
                .font(.system(size: 8))
                .foregroundColor(.secondary)

            Slider(value: Binding(
                get: {
                    if let annotation = currentAnnotation {
                        return annotation.lineWidth
                    }
                    return selectedLineWidth
                },
                set: { newWidth in
                    selectedLineWidth = newWidth
                    if let id = selectedAnnotationID,
                       let index = viewModel.annotations.firstIndex(where: { $0.id == id }) {
                        viewModel.annotations[index].lineWidth = newWidth
                    }
                }
            ), in: 1...20, step: 1)
            .frame(width: 80)

            Image(systemName: "line.diagonal")
                .font(.system(size: 14))
                .foregroundColor(.secondary)

            Divider()
                .frame(height: 20)

            Menu {
                ForEach(BrushStyle.allCases, id: \.self) { style in
                    Button(action: {
                        selectedBrushStyle = style
                        if let id = selectedAnnotationID,
                           let index = viewModel.annotations.firstIndex(where: { $0.id == id }) {
                            viewModel.annotations[index].brushStyle = style
                        }
                    }) {
                        HStack {
                            Text(style.localizedName)
                            if (currentAnnotation?.brushStyle ?? selectedBrushStyle) == style {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "paintbrush.fill")
                        .font(.system(size: 12))
                    Text((currentAnnotation?.brushStyle ?? selectedBrushStyle).localizedName)
                        .font(.system(size: 11))
                }
                .foregroundColor(.secondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.secondary.opacity(0.1))
                )
            }
            .menuStyle(.borderlessButton)
        }
    }

    var spotlightControls: some View {
        HStack(spacing: 6) {
            ForEach(SpotlightShape.allCases, id: \.self) { shape in
                Button(action: {
                    spotlightShape = shape
                    if let id = selectedAnnotationID,
                       let index = viewModel.annotations.firstIndex(where: { $0.id == id }) {
                        viewModel.annotations[index].spotlightShape = shape
                    }
                }) {
                    Image(systemName: shape == .ellipse ? "circle" : "square")
                        .font(.system(size: 14))
                        .foregroundColor((currentAnnotation?.spotlightShape ?? spotlightShape) == shape ? .accentColor : .secondary)
                        .frame(width: 28, height: 28)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill((currentAnnotation?.spotlightShape ?? spotlightShape) == shape ? Color.accentColor.opacity(0.15) : Color.clear)
                        )
                }
                .buttonStyle(.plain)
                .help(shape.displayName)
            }
        }
    }

    @ViewBuilder
    var textControls: some View {
        HStack(spacing: 8) {
            Button(action: {
                if let id = selectedAnnotationID,
                   let index = viewModel.annotations.firstIndex(where: { $0.id == id }) {
                    if viewModel.annotations[index].backgroundColor != nil {
                        viewModel.annotations[index].backgroundColor = nil
                    } else {
                        viewModel.annotations[index].backgroundColor = .white
                    }
                }
            }) {
                Image(systemName: currentAnnotation?.backgroundColor == nil ? "circle.slash" : "circle.fill")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
                    .frame(width: 28, height: 28)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color.secondary.opacity(0.1))
                    )
            }
            .buttonStyle(.plain)
            .help(currentAnnotation?.backgroundColor == nil ? "Add Background" : "Remove Background")

            if currentAnnotation?.backgroundColor != nil {
                ColorPicker("", selection: Binding(
                    get: {
                        if let id = selectedAnnotationID,
                           let annotation = viewModel.annotations.first(where: { $0.id == id }),
                           let bgColor = annotation.backgroundColor {
                            return bgColor
                        }
                        return .white
                    },
                    set: { newColor in
                        if let id = selectedAnnotationID,
                           let index = viewModel.annotations.firstIndex(where: { $0.id == id }) {
                            viewModel.annotations[index].backgroundColor = newColor
                        }
                    }
                ), supportsOpacity: true)
                .labelsHidden()
                .frame(width: 32, height: 32)
                .help("Background Color")
            }

            Divider()
                .frame(height: 24)

            Image(systemName: "textformat.size")
                .font(.system(size: 12))
                .foregroundColor(.secondary)

            Slider(value: Binding(
                get: {
                    if let annotation = currentAnnotation {
                        return annotation.lineWidth
                    }
                    return selectedLineWidth
                },
                set: { newSize in
                    selectedLineWidth = newSize
                    if let id = selectedAnnotationID,
                       let index = viewModel.annotations.firstIndex(where: { $0.id == id }) {
                        viewModel.annotations[index].lineWidth = newSize

                        let annotation = viewModel.annotations[index]
                        if annotation.tool == .text && !annotation.text.isEmpty {
                            let font = NSFont.systemFont(ofSize: newSize * 4)
                            let textAttributes: [NSAttributedString.Key: Any] = [.font: font]
                            let textSize = (annotation.text as NSString).boundingRect(
                                with: CGSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude),
                                options: [.usesLineFragmentOrigin, .usesFontLeading],
                                attributes: textAttributes
                            ).size

                            let paddedWidth = textSize.width + 16
                            let paddedHeight = textSize.height + 8

                            viewModel.annotations[index].rect.size = CGSize(width: paddedWidth, height: paddedHeight)
                        }
                    }
                }
            ), in: 3...12, step: 1)
            .frame(width: 100)
        }
    }
}
