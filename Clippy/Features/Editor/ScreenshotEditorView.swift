//
//  ScreenshotEditorView.swift
//  Clippy
//
//  Created by Mehmet Akbaba on 11.10.2025.
//

import SwiftUI
import Combine
import Vision

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

    // Crop state
    @State private var cropRect: CGRect?
    @State private var cropAspectRatio: CropAspectRatio = .free

    // Canvas expansion state
    @State private var showExpandCanvasPopover = false
    @State private var expandTop: String = "0"
    @State private var expandBottom: String = "0"
    @State private var expandLeft: String = "0"
    @State private var expandRight: String = "0"
    @State private var expandColor: Color = .white

    // Blur state
    @State private var blurRadius: CGFloat = 10
    @State private var blurMode: BlurMode = .full

    // Contrast checker state
    @State private var contrastMode: Bool = false

    // Export state
    @State private var exportFormat: ExportFormat = .png
    @State private var jpegQuality: CGFloat = 0.85

    // Phase 5 state
    @State private var annotationOpacity: CGFloat = 1.0
    @State private var dashedStroke: Bool = false
    @State private var textIsBold: Bool = false
    @State private var textIsItalic: Bool = false
    @State private var textAlignment: TextAlignment = .left
    @State private var calloutTailDirection: CalloutTailDirection = .bottomLeft
    @State private var recentColors: [Color] = []
    @State private var annotationClipboard: Annotation?

    // Border config
    @State private var borderConfig = ImageBorderConfig()

    // Watermark
    @State private var watermarkConfig = WatermarkConfig()

    // Quick copy banner
    @State private var showCopiedBanner = false

    @Environment(\.undoManager) private var undoManager

    var body: some View {
        VStack(spacing: 0) {
            // MARK: Top Context Bar
            EditorContextBar(
                viewModel: viewModel,
                selectedTool: $selectedTool,
                selectedColor: $selectedColor,
                selectedLineWidth: $selectedLineWidth,
                selectedAnnotationID: $selectedAnnotationID,
                numberSize: $numberSize,
                numberShape: $numberShape,
                shapeCornerRadius: $shapeCornerRadius,
                shapeFillMode: $shapeFillMode,
                spotlightShape: $spotlightShape,
                selectedEmoji: $selectedEmoji,
                emojiSize: $emojiSize,
                selectedBrushStyle: $selectedBrushStyle,
                showEffectsPanel: $showEffectsPanel,
                showColorCopied: $showColorCopied,
                showLineWidthPicker: $showLineWidthPicker,
                backdropPadding: $backdropPadding,
                screenshotShadowRadius: $screenshotShadowRadius,
                screenshotCornerRadius: $screenshotCornerRadius,
                backdropCornerRadius: $backdropCornerRadius,
                backdropFill: $backdropFill,
                backdropModel: $backdropModel,
                cropAspectRatio: $cropAspectRatio,
                blurRadius: $blurRadius,
                annotationOpacity: $annotationOpacity,
                dashedStroke: $dashedStroke,
                textIsBold: $textIsBold,
                textIsItalic: $textIsItalic,
                textAlignment: $textAlignment,
                calloutTailDirection: $calloutTailDirection,
                recentColors: $recentColors,
                contrastMode: $contrastMode,
                blurMode: $blurMode,
                borderConfig: $borderConfig,
                imageSize: image.size,
                isPerformingOCR: isPerformingOCR,
                ocrButtonIcon: ocrButtonIcon,
                showImagesTab: settings.showImagesTab,
                annotationsEmpty: viewModel.annotations.isEmpty,
                undoManager: undoManager,
                isCropping: cropRect != nil,
                onUndo: { undoManager?.undo() },
                onRedo: { undoManager?.redo() },
                onApply: { applyAnnotations() },
                onClearAll: { clearAllAnnotations() },
                onSave: { saveImage() },
                onSaveToClippy: { saveToClippy() },
                onPerformOCR: { performOCR() },
                onCopyImage: { startImageDrag() },
                onClose: {
                    cleanupResources()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        NSApp.keyWindow?.close()
                    }
                },
                onApplyCrop: { applyCrop() },
                onCancelCrop: { cancelCrop() },
                onShare: { shareImage() },
                onBringToFront: { bringToFront() },
                onSendToBack: { sendToBack() },
                onMoveUp: { moveAnnotationUp() },
                onMoveDown: { moveAnnotationDown() }
            )

            HStack(spacing: 0) {
                // MARK: Left Sidebar
                EditorSidebar(
                    selectedTool: $selectedTool,
                    isEditingText: $isEditingText,
                    showToolControls: $showToolControls,
                    selectedAnnotationID: $selectedAnnotationID,
                    showShapePicker: $showShapePicker,
                    showEmojiPicker: $showEmojiPicker,
                    selectedEmoji: $selectedEmoji,
                    onStopEditingText: { stopEditingText() },
                    onRotateLeft: { rotateImage(clockwise: false) },
                    onRotateRight: { rotateImage(clockwise: true) },
                    onFlipHorizontal: { flipImage(horizontal: true) },
                    onFlipVertical: { flipImage(horizontal: false) },
                    onExpandCanvas: { showExpandCanvasPopover = true }
                )
                .popover(isPresented: $showExpandCanvasPopover, arrowEdge: .trailing) {
                    expandCanvasPopover
                }

                Divider()

                // MARK: Canvas Area
                canvasArea
            }

            // MARK: Bottom Status Bar
            EditorStatusBar(
                imageSize: image.size,
                zoomScale: $zoomScale,
                lastZoomScale: $lastZoomScale,
                selectedTool: selectedTool,
                annotationCount: viewModel.annotations.count,
                onFitToWindow: { fitToWindow() }
            )
        }
        .overlay(alignment: .top) {
            if showCopiedBanner {
                Text("Copied to Clipboard!")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Capsule().fill(Color.accentColor))
                    .shadow(radius: 4)
                    .padding(.top, 50)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .frame(minWidth: 900, minHeight: 500)
        .onChange(of: selectedColor) { _ in
            addToRecentColors(selectedColor)
        }
        .onChange(of: selectedTool) { newTool in
            if newTool == .eyedropper {
                let controller = EyedropperLoupeController.shared
                controller.contrastMode = contrastMode
                controller.show(image: image)
            } else {
                EyedropperLoupeController.shared.hide()
            }
        }
        .onChange(of: contrastMode) { newValue in
            let controller = EyedropperLoupeController.shared
            controller.contrastMode = newValue
            if !newValue {
                controller.clearContrast()
            }
        }
        .background(
            Group {
                // ESC → select tool
                Button("") {
                    if selectedTool != .select {
                        if isEditingText {
                            stopEditingText()
                        }
                        selectedTool = .select
                        showToolControls = false
                        selectedAnnotationID = nil
                    }
                }
                .keyboardShortcut(.escape, modifiers: [])

                // Cmd+= → zoom in
                Button("") {
                    withAnimation(.easeInOut(duration: 0.15)) {
                        zoomScale = min(4.0, zoomScale + 0.25)
                        lastZoomScale = zoomScale
                    }
                }
                .keyboardShortcut("=", modifiers: .command)

                // Cmd+- → zoom out
                Button("") {
                    withAnimation(.easeInOut(duration: 0.15)) {
                        zoomScale = max(0.5, zoomScale - 0.25)
                        lastZoomScale = zoomScale
                    }
                }
                .keyboardShortcut("-", modifiers: .command)

                // Cmd+0 → fit to window
                Button("") {
                    withAnimation(.easeInOut(duration: 0.15)) {
                        fitToWindow()
                    }
                }
                .keyboardShortcut("0", modifiers: .command)

                // Cmd+1 → actual size
                Button("") {
                    withAnimation(.easeInOut(duration: 0.15)) {
                        zoomScale = 1.0
                        lastZoomScale = 1.0
                    }
                }
                .keyboardShortcut("1", modifiers: .command)

                // Delete → remove selected annotation
                Button("") {
                    if let id = selectedAnnotationID {
                        viewModel.removeAnnotation(with: id, undoManager: undoManager)
                        selectedAnnotationID = nil
                        showToolControls = false
                    }
                }
                .keyboardShortcut(.delete, modifiers: [])

                // Cmd+D → duplicate selected annotation
                Button("") {
                    guard let id = selectedAnnotationID,
                          let annotation = viewModel.annotations.first(where: { $0.id == id }) else { return }
                    let dup = annotation.duplicating()
                    viewModel.addAnnotation(dup, undoManager: undoManager)
                    selectedAnnotationID = dup.id
                }
                .keyboardShortcut("d", modifiers: .command)

                // Cmd+C → copy selected annotation
                Button("") {
                    guard let id = selectedAnnotationID,
                          let annotation = viewModel.annotations.first(where: { $0.id == id }) else { return }
                    annotationClipboard = annotation.duplicating(offset: .zero)
                }
                .keyboardShortcut("c", modifiers: .command)

                // Cmd+V → paste annotation
                Button("") {
                    guard let clipboard = annotationClipboard else { return }
                    let pasted = clipboard.duplicating(offset: CGSize(width: 20, height: 20))
                    viewModel.addAnnotation(pasted, undoManager: undoManager)
                    selectedAnnotationID = pasted.id
                    annotationClipboard = pasted
                }
                .keyboardShortcut("v", modifiers: .command)
            }
            .opacity(0)
            .frame(width: 0, height: 0)
        )
    }

    // MARK: - Canvas Area

    private var canvasArea: some View {
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
                            .overlay(
                                Group {
                                    if borderConfig.style == .solid {
                                        RoundedRectangle(cornerRadius: backdropCornerRadius)
                                            .stroke(borderConfig.color, lineWidth: borderConfig.width)
                                    } else if borderConfig.style == .dashed {
                                        RoundedRectangle(cornerRadius: backdropCornerRadius)
                                            .stroke(borderConfig.color, style: StrokeStyle(lineWidth: borderConfig.width, dash: [8, 4]))
                                    } else if borderConfig.style == .double {
                                        ZStack {
                                            RoundedRectangle(cornerRadius: backdropCornerRadius)
                                                .stroke(borderConfig.color, lineWidth: borderConfig.width)
                                            RoundedRectangle(cornerRadius: max(0, backdropCornerRadius - borderConfig.width))
                                                .stroke(borderConfig.color, lineWidth: borderConfig.width)
                                                .padding(borderConfig.width * 1.5)
                                        }
                                    }
                                }
                            )
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
                                        DrawingCanvasView(
                                            image: image,
                                            viewModel: viewModel,
                                            selectedTool: $selectedTool,
                                            selectedColor: $selectedColor,
                                            selectedLineWidth: $selectedLineWidth,
                                            numberSize: $numberSize,
                                            numberShape: $numberShape,
                                            shapeCornerRadius: $shapeCornerRadius,
                                            shapeFillMode: $shapeFillMode,
                                            spotlightShape: $spotlightShape,
                                            selectedEmoji: $selectedEmoji,
                                            emojiSize: $emojiSize,
                                            selectedBrushStyle: $selectedBrushStyle,
                                            movingAnnotationID: $movingAnnotationID,
                                            dragOffset: $dragOffset,
                                            editingTextIndex: $editingTextIndex,
                                            showToolControls: $showToolControls,
                                            selectedAnnotationID: $selectedAnnotationID,
                                            isEditingText: $isEditingText,
                                            backdropPadding: backdropPadding,
                                            canvasSize: overlayGeometry.size,
                                            blurRadius: blurRadius,
                                            blurMode: blurMode,
                                            cropRect: $cropRect,
                                            cropAspectRatio: cropAspectRatio,
                                            annotationOpacity: annotationOpacity,
                                            dashedStroke: dashedStroke,
                                            textIsBold: textIsBold,
                                            textIsItalic: textIsItalic,
                                            textAlignment: textAlignment,
                                            calloutTailDirection: calloutTailDirection,
                                            onTextAnnotationCreated: { [weak viewModel] id in
                                                guard let viewModel = viewModel else { return }
                                                if let index = viewModel.annotations.lastIndex(where: { $0.id == id }) {
                                                    startEditingText(at: index)
                                                }
                                            },
                                            onStartEditingText: { index in
                                                startEditingText(at: index)
                                            },
                                            onStopEditingText: {
                                                stopEditingText()
                                            },
                                            onPickColor: { point in
                                                pickColorFromImage(at: point)
                                            },
                                            onEyedropperHover: { imagePoint, screenPoint in
                                                EyedropperLoupeController.shared.updatePosition(
                                                    screenPoint: screenPoint,
                                                    imagePoint: imagePoint
                                                )
                                            },
                                            zoomScale: zoomScale
                                        )

                                        ForEach(viewModel.annotations.filter { $0.tool == .text }) { annotation in
                                            if let index = viewModel.annotations.firstIndex(where: { $0.id == annotation.id }) {
                                                let isEditing = isEditingText && index == editingTextIndex

                                                let imgSize = image.size
                                                let cvSize = overlayGeometry.size

                                                let scale = min(cvSize.width / imgSize.width, cvSize.height / imgSize.height)

                                                let scaledImageSize = CGSize(
                                                    width: imgSize.width * scale,
                                                    height: imgSize.height * scale
                                                )

                                                let imageOffset = CGPoint(
                                                    x: (cvSize.width - scaledImageSize.width) / 2,
                                                    y: (cvSize.height - scaledImageSize.height) / 2
                                                )

                                                let canvasRect = CGRect(
                                                    x: annotation.rect.origin.x * scale + imageOffset.x,
                                                    y: annotation.rect.origin.y * scale + imageOffset.y,
                                                    width: annotation.rect.width * scale,
                                                    height: annotation.rect.height * scale
                                                )

                                                if isEditing {
                                                    let maxTextWidth = annotation.rect.width * scale

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
                                                        maxWidth: maxTextWidth,
                                                        onHeightChange: { newHeight in
                                                            let imageHeight = newHeight / scale
                                                            if abs(viewModel.annotations[index].rect.size.height - imageHeight) > 1 {
                                                                viewModel.annotations[index].rect.size.height = imageHeight
                                                            }
                                                        },
                                                        onSizeChange: { newSize in
                                                            let imageHeight = newSize.height / scale
                                                            if abs(viewModel.annotations[index].rect.size.height - imageHeight) > 1 {
                                                                viewModel.annotations[index].rect.size.height = imageHeight
                                                            }
                                                        }
                                                    )
                                                    .focused($isTextFieldFocused)
                                                    .frame(width: canvasRect.width, height: max(canvasRect.height, 24))
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

                                let toolbarHeight: CGFloat = 64
                                let sidebarWidth: CGFloat = 45
                                let relativeY = adjustedY - toolbarHeight
                                let relativeX = locationInContent.x - sidebarWidth

                                let normalizedX = relativeX / contentSize.width
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

                escKeyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
                    guard !isEditingText else { return event }

                    // Arrow key nudging for selected annotation
                    if let id = selectedAnnotationID,
                       let index = viewModel.annotations.firstIndex(where: { $0.id == id }) {
                        let nudge: CGFloat = event.modifierFlags.contains(.shift) ? 10 : 1
                        var dx: CGFloat = 0
                        var dy: CGFloat = 0

                        switch event.keyCode {
                        case 123: dx = -nudge  // Left
                        case 124: dx = nudge   // Right
                        case 125: dy = nudge   // Down
                        case 126: dy = -nudge  // Up
                        default: return event
                        }

                        viewModel.nudgeAnnotation(at: index, dx: dx, dy: dy, undoManager: undoManager)
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
    }

    private var currentCursor: NSCursor {
        switch selectedTool {
        case .select:
            return .arrow
        case .move:
            return movingAnnotationID != nil ? .closedHand : .openHand
        case .rectangle, .ellipse, .line, .arrow, .text, .pin, .pixelate, .eraser, .highlighter, .spotlight, .emoji, .pen, .crop, .blur, .eyedropper, .callout, .magnifier, .ruler:
            return .crosshair
        }
    }


    // MARK: - Annotation Drawing (for renderFinalImage)

    private func drawAnnotations(context: inout GraphicsContext, canvasSize: CGSize) {
        for annotation in viewModel.annotations {
            var currentRect = annotation.rect
            if annotation.id == movingAnnotationID {
                currentRect = currentRect.offsetBy(dx: dragOffset.width, dy: dragOffset.height)
                context.addFilter(.shadow(color: .black.opacity(0.5), radius: 5))
            }
            drawSingleAnnotation(annotation, rect: currentRect, in: &context, canvasSize: canvasSize, nsImage: image)
        }
    }

    private func drawSingleAnnotation(_ annotation: Annotation, rect: CGRect, in context: inout GraphicsContext, canvasSize: CGSize, nsImage: NSImage? = nil) {
        let opacity = annotation.opacity
        let dashed = annotation.dashedStroke

        func strokeStyle(lineWidth: CGFloat) -> StrokeStyle {
            if dashed {
                return StrokeStyle(lineWidth: lineWidth, dash: [8, 4])
            }
            return StrokeStyle(lineWidth: lineWidth)
        }

        context.opacity = opacity

        let sketch = annotation.sketchStyle
        let seed = annotation.id.hashValue

        switch annotation.tool {
        case .rectangle:
            if sketch {
                context.stroke(SketchRenderer.sketchRect(rect, seed: seed), with: .color(annotation.color), lineWidth: annotation.lineWidth)
            } else {
                context.stroke(Path(rect), with: .color(annotation.color), style: strokeStyle(lineWidth: annotation.lineWidth))
            }
        case .ellipse:
            if sketch {
                context.stroke(SketchRenderer.sketchEllipse(rect, seed: seed), with: .color(annotation.color), lineWidth: annotation.lineWidth)
            } else {
                context.stroke(Path(ellipseIn: rect), with: .color(annotation.color), style: strokeStyle(lineWidth: annotation.lineWidth))
            }
        case .line:
            if let start = annotation.startPoint, let end = annotation.endPoint {
                if sketch {
                    context.stroke(SketchRenderer.sketchLine(from: start, to: end, seed: seed), with: .color(annotation.color), lineWidth: annotation.lineWidth)
                } else {
                    var path = Path()
                    path.move(to: start)
                    path.addLine(to: end)
                    context.stroke(path, with: .color(annotation.color), style: strokeStyle(lineWidth: annotation.lineWidth))
                }
            }
        case .highlighter:
            context.fill(Path(rect), with: .color(annotation.color.opacity(0.3)))
        case .arrow:
            let startPoint = annotation.startPoint ?? CGPoint(x: rect.minX, y: rect.minY)
            let endPoint = annotation.endPoint ?? CGPoint(x: rect.maxX, y: rect.maxY)
            if hypot(endPoint.x - startPoint.x, endPoint.y - startPoint.y) > annotation.lineWidth * 2 {
                let headW = max(8, min(30, annotation.lineWidth * 3))
                let headL = max(8, min(30, annotation.lineWidth * 3))
                let path: Path
                if let cp = annotation.controlPoint {
                    path = Path.curvedArrow(from: startPoint, to: endPoint, control: cp, tailWidth: annotation.lineWidth, headWidth: headW, headLength: headL)
                } else {
                    path = Path.arrow(from: startPoint, to: endPoint, tailWidth: annotation.lineWidth, headWidth: headW, headLength: headL)
                }
                if dashed {
                    context.stroke(path, with: .color(annotation.color), style: StrokeStyle(lineWidth: 1, dash: [6, 3]))
                } else {
                    context.fill(path, with: .color(annotation.color))
                }
            }
        case .pixelate:
            if let nsImage = nsImage,
               let pixelatedImg = applyPixelateFilter(to: nsImage, in: rect) {
                context.draw(Image(nsImage: pixelatedImg), in: rect)
            } else {
                context.fill(Path(rect), with: .color(.gray.opacity(0.7)))
            }
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
            if !annotation.text.isEmpty {
                if let bgColor = annotation.backgroundColor {
                    let bgPath = Path(roundedRect: rect, cornerRadius: 6)
                    context.fill(bgPath, with: .color(bgColor))
                }

                let font: Font = {
                    let size = annotation.lineWidth * 4
                    if annotation.isBold && annotation.isItalic {
                        return .system(size: size, weight: .bold).italic()
                    } else if annotation.isBold {
                        return .system(size: size, weight: .bold)
                    } else if annotation.isItalic {
                        return .system(size: size).italic()
                    }
                    return .system(size: size)
                }()

                let text = Text(annotation.text)
                    .font(font)
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
            if let points = annotation.path, points.count > 1 {
                let simplified = simplifyPoints(points, tolerance: 1.0)
                let bezierPath = smoothPath(from: simplified)

                let brushStyle = annotation.brushStyle ?? .solid
                switch brushStyle {
                case .solid:
                    context.stroke(bezierPath, with: .color(annotation.color), style: StrokeStyle(lineWidth: annotation.lineWidth, lineCap: .round, lineJoin: .round))
                case .dashed:
                    context.stroke(bezierPath, with: .color(annotation.color), style: StrokeStyle(lineWidth: annotation.lineWidth, lineCap: .round, lineJoin: .round, dash: [10, 5]))
                case .marker:
                    context.stroke(bezierPath, with: .color(annotation.color.opacity(0.5)), style: StrokeStyle(lineWidth: annotation.lineWidth * 2, lineCap: .round, lineJoin: .round))
                }
            }

        case .spotlight:
            context.opacity = 1.0
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

        case .blur:
            context.opacity = 1.0
            switch annotation.blurMode {
            case .full:
                if let nsImage = nsImage,
                   let blurredImg = applyGaussianBlurFilter(to: nsImage, in: rect, radius: annotation.blurRadius) {
                    context.draw(Image(nsImage: blurredImg), in: rect)
                } else {
                    context.fill(Path(rect), with: .color(.gray.opacity(0.3)))
                }
            case .textOnly:
                if let nsImage = nsImage {
                    let textRects = TextRegionDetector.detectTextRegions(in: nsImage, within: annotation.rect)
                    for textRect in textRects {
                        let displayTextRect = CGRect(
                            x: textRect.origin.x * (rect.width / annotation.rect.width) + rect.origin.x - annotation.rect.origin.x * (rect.width / annotation.rect.width),
                            y: textRect.origin.y * (rect.height / annotation.rect.height) + rect.origin.y - annotation.rect.origin.y * (rect.height / annotation.rect.height),
                            width: textRect.width * (rect.width / annotation.rect.width),
                            height: textRect.height * (rect.height / annotation.rect.height)
                        )
                        if let blurredImg = applyGaussianBlurFilter(to: nsImage, in: displayTextRect, radius: annotation.blurRadius) {
                            context.draw(Image(nsImage: blurredImg), in: displayTextRect)
                        }
                    }
                }
            case .erase:
                let bgColor = sampleBackgroundColor(in: annotation.rect)
                context.fill(Path(rect), with: .color(bgColor))
            case .textErase:
                if let nsImage = nsImage {
                    let textRects = TextRegionDetector.detectTextRegions(in: nsImage, within: annotation.rect)
                    let bgColor = sampleBackgroundColor(in: annotation.rect)
                    for textRect in textRects {
                        let displayTextRect = CGRect(
                            x: textRect.origin.x * (rect.width / annotation.rect.width) + rect.origin.x - annotation.rect.origin.x * (rect.width / annotation.rect.width),
                            y: textRect.origin.y * (rect.height / annotation.rect.height) + rect.origin.y - annotation.rect.origin.y * (rect.height / annotation.rect.height),
                            width: textRect.width * (rect.width / annotation.rect.width),
                            height: textRect.height * (rect.height / annotation.rect.height)
                        )
                        context.fill(Path(displayTextRect), with: .color(bgColor))
                    }
                }
            }

        case .callout:
            let cornerRadius = annotation.cornerRadius
            let bodyRect = rect
            let tailPath = calloutTailPath(for: bodyRect, direction: annotation.calloutTailDirection)
            let bodyPath = Path(roundedRect: bodyRect, cornerRadius: cornerRadius)

            switch annotation.fillMode {
            case .fill:
                context.fill(bodyPath, with: .color(annotation.color))
                context.fill(tailPath, with: .color(annotation.color))
            case .stroke:
                context.stroke(bodyPath, with: .color(annotation.color), style: strokeStyle(lineWidth: annotation.lineWidth))
                context.stroke(tailPath, with: .color(annotation.color), style: strokeStyle(lineWidth: annotation.lineWidth))
            case .both:
                context.fill(bodyPath, with: .color(annotation.color.opacity(0.3)))
                context.fill(tailPath, with: .color(annotation.color.opacity(0.3)))
                context.stroke(bodyPath, with: .color(annotation.color), style: strokeStyle(lineWidth: annotation.lineWidth))
                context.stroke(tailPath, with: .color(annotation.color), style: strokeStyle(lineWidth: annotation.lineWidth))
            }

            if !annotation.text.isEmpty {
                let textInset = CGRect(x: bodyRect.minX + 8, y: bodyRect.minY + 4, width: bodyRect.width - 16, height: bodyRect.height - 8)
                let text = Text(annotation.text)
                    .font(.system(size: annotation.lineWidth * 3))
                    .foregroundColor(annotation.fillMode == .fill ? .white : annotation.color)
                context.draw(text, in: textInset)
            }

        case .magnifier:
            let mag = annotation.magnification
            let sourceW = rect.width / mag
            let sourceH = rect.height / mag
            let imgSourceRect = CGRect(
                x: rect.midX - sourceW / 2,
                y: rect.midY - sourceH / 2,
                width: sourceW,
                height: sourceH
            )

            context.drawLayer { layerCtx in
                layerCtx.clip(to: Path(ellipseIn: rect))
                if let tiffData = image.tiffRepresentation,
                   let bitmap = NSBitmapImageRep(data: tiffData),
                   let cgFull = bitmap.cgImage {
                    // Convert from image point coords to pixel coords (Retina 2x etc.)
                    let pxScaleX = image.size.width > 0 ? CGFloat(cgFull.width) / image.size.width : 1
                    let pxScaleY = image.size.height > 0 ? CGFloat(cgFull.height) / image.size.height : 1
                    let clampedX = max(0, min(Int(imgSourceRect.origin.x * pxScaleX), cgFull.width - 1))
                    let clampedY = max(0, min(Int(imgSourceRect.origin.y * pxScaleY), cgFull.height - 1))
                    let clampedW = max(1, min(Int(imgSourceRect.width * pxScaleX), cgFull.width - clampedX))
                    let clampedH = max(1, min(Int(imgSourceRect.height * pxScaleY), cgFull.height - clampedY))
                    let cropRect = CGRect(x: clampedX, y: clampedY, width: clampedW, height: clampedH)
                    if let croppedCG = cgFull.cropping(to: cropRect) {
                        let croppedNS = NSImage(cgImage: croppedCG, size: NSSize(width: clampedW, height: clampedH))
                        layerCtx.draw(Image(nsImage: croppedNS), in: rect)
                    }
                }
            }
            context.stroke(Path(ellipseIn: rect), with: .color(.white), lineWidth: 3)

        case .ruler:
            let start = annotation.startPoint ?? CGPoint(x: rect.minX, y: rect.minY)
            let end = annotation.endPoint ?? CGPoint(x: rect.maxX, y: rect.maxY)
            let dx = end.x - start.x
            let dy = end.y - start.y
            let distance = sqrt(dx * dx + dy * dy)
            let angle = atan2(dy, dx)

            var linePath = Path()
            linePath.move(to: start)
            linePath.addLine(to: end)
            context.stroke(linePath, with: .color(annotation.color), style: StrokeStyle(lineWidth: annotation.lineWidth))

            let tickLen: CGFloat = 10
            let perpX = -sin(angle) * tickLen
            let perpY = cos(angle) * tickLen
            var tickPath = Path()
            tickPath.move(to: CGPoint(x: start.x + perpX, y: start.y + perpY))
            tickPath.addLine(to: CGPoint(x: start.x - perpX, y: start.y - perpY))
            tickPath.move(to: CGPoint(x: end.x + perpX, y: end.y + perpY))
            tickPath.addLine(to: CGPoint(x: end.x - perpX, y: end.y - perpY))
            context.stroke(tickPath, with: .color(annotation.color), style: StrokeStyle(lineWidth: annotation.lineWidth))

            let labelText = Text("\(Int(distance))px")
                .font(.system(size: max(10, annotation.lineWidth * 3), weight: .bold, design: .rounded))
                .foregroundColor(annotation.color)
            let resolvedLabel = context.resolve(labelText)
            let midPoint = CGPoint(x: (start.x + end.x) / 2, y: (start.y + end.y) / 2)
            let labelOffset: CGFloat = 14
            let labelPos = CGPoint(x: midPoint.x - sin(angle) * labelOffset, y: midPoint.y + cos(angle) * labelOffset)
            let labelSize = resolvedLabel.measure(in: CGSize(width: 200, height: 50))
            let pillRect = CGRect(x: labelPos.x - labelSize.width / 2 - 4, y: labelPos.y - labelSize.height / 2 - 2, width: labelSize.width + 8, height: labelSize.height + 4)
            context.fill(Path(roundedRect: pillRect, cornerRadius: 4), with: .color(.black.opacity(0.6)))
            context.draw(resolvedLabel, at: labelPos, anchor: .center)

        case .crop, .move, .eraser, .select, .eyedropper:
            break
        }

        context.opacity = 1.0
    }

    private func calloutTailPath(for rect: CGRect, direction: CalloutTailDirection) -> Path {
        let tailWidth: CGFloat = min(20, rect.width * 0.2)
        let tailHeight: CGFloat = min(16, rect.height * 0.4)

        var path = Path()

        switch direction {
        case .bottomLeft:
            let baseX = rect.minX + rect.width * 0.2
            path.move(to: CGPoint(x: baseX, y: rect.maxY))
            path.addLine(to: CGPoint(x: baseX - tailWidth * 0.3, y: rect.maxY + tailHeight))
            path.addLine(to: CGPoint(x: baseX + tailWidth, y: rect.maxY))
        case .bottomCenter:
            let baseX = rect.midX
            path.move(to: CGPoint(x: baseX - tailWidth / 2, y: rect.maxY))
            path.addLine(to: CGPoint(x: baseX, y: rect.maxY + tailHeight))
            path.addLine(to: CGPoint(x: baseX + tailWidth / 2, y: rect.maxY))
        case .bottomRight:
            let baseX = rect.maxX - rect.width * 0.2
            path.move(to: CGPoint(x: baseX - tailWidth, y: rect.maxY))
            path.addLine(to: CGPoint(x: baseX + tailWidth * 0.3, y: rect.maxY + tailHeight))
            path.addLine(to: CGPoint(x: baseX, y: rect.maxY))
        case .topLeft:
            let baseX = rect.minX + rect.width * 0.2
            path.move(to: CGPoint(x: baseX, y: rect.minY))
            path.addLine(to: CGPoint(x: baseX - tailWidth * 0.3, y: rect.minY - tailHeight))
            path.addLine(to: CGPoint(x: baseX + tailWidth, y: rect.minY))
        case .topCenter:
            let baseX = rect.midX
            path.move(to: CGPoint(x: baseX - tailWidth / 2, y: rect.minY))
            path.addLine(to: CGPoint(x: baseX, y: rect.minY - tailHeight))
            path.addLine(to: CGPoint(x: baseX + tailWidth / 2, y: rect.minY))
        case .topRight:
            let baseX = rect.maxX - rect.width * 0.2
            path.move(to: CGPoint(x: baseX - tailWidth, y: rect.minY))
            path.addLine(to: CGPoint(x: baseX + tailWidth * 0.3, y: rect.minY - tailHeight))
            path.addLine(to: CGPoint(x: baseX, y: rect.minY))
        }
        path.closeSubpath()
        return path
    }

    // MARK: - Rendering & Export

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

        case .radialGradient(let centerColor, let edgeColor, let centerPoint, let startRadius, let endRadius):
            let colors = [NSColor(centerColor).cgColor, NSColor(edgeColor).cgColor] as CFArray
            guard let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: [0.0, 1.0]) else {
                NSColor(edgeColor).setFill()
                backgroundPath.fill()
                break
            }
            context.saveGState()
            let clipPath = NSBezierPath(roundedRect: backgroundRect, xRadius: backdropCornerRadius, yRadius: backdropCornerRadius)
            clipPath.addClip()
            let cp = CGPoint(x: backgroundRect.minX + centerPoint.x * backgroundRect.width,
                             y: backgroundRect.minY + centerPoint.y * backgroundRect.height)
            let maxDim = max(backgroundRect.width, backgroundRect.height)
            let scaledEndRadius = endRadius * (maxDim / 400.0)
            context.drawRadialGradient(gradient, startCenter: cp, startRadius: startRadius, endCenter: cp, endRadius: scaledEndRadius, options: [.drawsAfterEndLocation])
            context.restoreGState()

        case .pattern(let patternType, let color1, let color2, let spacing):
            context.saveGState()
            let clipPath = NSBezierPath(roundedRect: backgroundRect, xRadius: backdropCornerRadius, yRadius: backdropCornerRadius)
            clipPath.addClip()
            // Fill background color
            NSColor(color2).setFill()
            backgroundPath.fill()
            // Draw pattern
            let fg = NSColor(color1)
            fg.setFill()
            fg.setStroke()
            switch patternType {
            case .dots:
                var y = spacing / 2
                while y < backgroundRect.height {
                    var x = spacing / 2
                    while x < backgroundRect.width {
                        let dotRect = NSRect(x: x - 2, y: y - 2, width: 4, height: 4)
                        NSBezierPath(ovalIn: dotRect).fill()
                        x += spacing
                    }
                    y += spacing
                }
            case .grid:
                let gridPath = NSBezierPath()
                gridPath.lineWidth = 0.5
                var x: CGFloat = 0
                while x <= backgroundRect.width {
                    gridPath.move(to: NSPoint(x: x, y: 0))
                    gridPath.line(to: NSPoint(x: x, y: backgroundRect.height))
                    x += spacing
                }
                var y2: CGFloat = 0
                while y2 <= backgroundRect.height {
                    gridPath.move(to: NSPoint(x: 0, y: y2))
                    gridPath.line(to: NSPoint(x: backgroundRect.width, y: y2))
                    y2 += spacing
                }
                gridPath.stroke()
            case .stripes:
                let stripePath = NSBezierPath()
                stripePath.lineWidth = spacing / 3
                var x2: CGFloat = 0
                while x2 <= backgroundRect.width + backgroundRect.height {
                    stripePath.move(to: NSPoint(x: x2, y: 0))
                    stripePath.line(to: NSPoint(x: x2 - backgroundRect.height, y: backgroundRect.height))
                    x2 += spacing
                }
                stripePath.stroke()
            case .checkerboard:
                var row = 0
                var y3: CGFloat = 0
                while y3 < backgroundRect.height {
                    var col = 0
                    var x3: CGFloat = 0
                    while x3 < backgroundRect.width {
                        if (row + col).isMultiple(of: 2) {
                            NSBezierPath(rect: NSRect(x: x3, y: y3, width: spacing, height: spacing)).fill()
                        }
                        x3 += spacing
                        col += 1
                    }
                    y3 += spacing
                    row += 1
                }
            }
            context.restoreGState()

        case .image(let data, let fillMode):
            context.saveGState()
            let clipPath = NSBezierPath(roundedRect: backgroundRect, xRadius: backdropCornerRadius, yRadius: backdropCornerRadius)
            clipPath.addClip()
            if let nsImage = NSImage(data: data) {
                let imgSize = nsImage.size
                var drawRect = backgroundRect
                switch fillMode {
                case .stretch:
                    drawRect = backgroundRect
                case .fit:
                    let scale = min(backgroundRect.width / imgSize.width, backgroundRect.height / imgSize.height)
                    let w = imgSize.width * scale
                    let h = imgSize.height * scale
                    drawRect = NSRect(x: (backgroundRect.width - w) / 2, y: (backgroundRect.height - h) / 2, width: w, height: h)
                case .fill:
                    let scale = max(backgroundRect.width / imgSize.width, backgroundRect.height / imgSize.height)
                    let w = imgSize.width * scale
                    let h = imgSize.height * scale
                    drawRect = NSRect(x: (backgroundRect.width - w) / 2, y: (backgroundRect.height - h) / 2, width: w, height: h)
                case .tile:
                    var y: CGFloat = 0
                    while y < backgroundRect.height {
                        var x: CGFloat = 0
                        while x < backgroundRect.width {
                            nsImage.draw(in: NSRect(x: x, y: y, width: imgSize.width, height: imgSize.height))
                            x += imgSize.width
                        }
                        y += imgSize.height
                    }
                    drawRect = .zero // skip the single draw below
                }
                if drawRect != .zero {
                    nsImage.draw(in: drawRect)
                }
            } else {
                // Fallback
                NSColor.gray.setFill()
                backgroundPath.fill()
            }
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

        // Draw border if configured
        if borderConfig.style != .none {
            let borderPath = NSBezierPath(roundedRect: backgroundRect.insetBy(dx: borderConfig.width / 2, dy: borderConfig.width / 2),
                                           xRadius: backdropCornerRadius,
                                           yRadius: backdropCornerRadius)
            NSColor(borderConfig.color).setStroke()
            borderPath.lineWidth = borderConfig.width
            switch borderConfig.style {
            case .dashed:
                let pattern: [CGFloat] = [8, 4]
                borderPath.setLineDash(pattern, count: pattern.count, phase: 0)
            case .double:
                borderPath.stroke()
                let innerPath = NSBezierPath(roundedRect: backgroundRect.insetBy(dx: borderConfig.width * 1.5, dy: borderConfig.width * 1.5),
                                              xRadius: max(0, backdropCornerRadius - borderConfig.width),
                                              yRadius: max(0, backdropCornerRadius - borderConfig.width))
                innerPath.lineWidth = borderConfig.width
                NSColor(borderConfig.color).setStroke()
                innerPath.stroke()
            default:
                break
            }
            borderPath.stroke()
        }

        finalImage.unlockFocus()

            return finalImage
        }
    }

    // MARK: - Apply Annotations (NSBezierPath rendering)

    private func applyAnnotations() {
        guard !viewModel.annotations.isEmpty else { return }

        let imageSize = image.size

        guard let tiffData = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData) else {
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

        viewModel.annotations.removeAll()
        selectedAnnotationID = nil

        viewModel.currentNumber = 1

        undoManager?.removeAllActions()
    }

    private func clearAllAnnotations() {
        guard !viewModel.annotations.isEmpty else { return }

        let savedAnnotations = viewModel.annotations
        let savedNumber = viewModel.currentNumber
        viewModel.annotations.removeAll()
        viewModel.currentNumber = 1

        undoManager?.registerUndo(withTarget: viewModel) { target in
            target.annotations = savedAnnotations
            target.currentNumber = savedNumber
            target.objectWillChange.send()
        }
    }

    private func drawAnnotation(_ a: Annotation, imageHeight: CGFloat) {
        let c = NSColor(a.color)
        let opacity = a.opacity

        func flipY(_ y: CGFloat) -> CGFloat {
            return imageHeight - y
        }

        func flipRect(_ rect: CGRect) -> CGRect {
            return CGRect(x: rect.origin.x,
                         y: flipY(rect.origin.y + rect.height),
                         width: rect.width,
                         height: rect.height)
        }

        func applyDash(to path: NSBezierPath) {
            if a.dashedStroke {
                path.setLineDash([8, 4], count: 2, phase: 0)
            }
        }

        NSGraphicsContext.current?.cgContext.saveGState()
        NSGraphicsContext.current?.cgContext.setAlpha(opacity)

        func drawSketchPath(_ sketchPath: Path, lineWidth: CGFloat) {
            guard let ctx = NSGraphicsContext.current?.cgContext else { return }
            c.setStroke()
            ctx.setLineWidth(lineWidth)
            ctx.addPath(sketchPath.cgPath)
            ctx.strokePath()
        }

        let sketch = a.sketchStyle
        let seed = a.id.hashValue

        switch a.tool {
        case .rectangle:
            let flipped = flipRect(a.rect)
            if sketch {
                let sketchPath = SketchRenderer.sketchRect(flipped, seed: seed)
                switch a.fillMode {
                case .fill:
                    c.setFill()
                    NSBezierPath(rect: flipped).fill()
                case .stroke:
                    drawSketchPath(sketchPath, lineWidth: a.lineWidth)
                case .both:
                    c.withAlphaComponent(0.3).setFill()
                    NSBezierPath(rect: flipped).fill()
                    drawSketchPath(sketchPath, lineWidth: a.lineWidth)
                }
            } else {
                let cornerRadius = a.cornerRadius
                let p = NSBezierPath(roundedRect: flipped, xRadius: cornerRadius, yRadius: cornerRadius)
                applyDash(to: p)

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
            }

        case .ellipse:
            let flipped = flipRect(a.rect)
            if sketch {
                let sketchPath = SketchRenderer.sketchEllipse(flipped, seed: seed)
                switch a.fillMode {
                case .fill:
                    c.setFill()
                    NSBezierPath(ovalIn: flipped).fill()
                case .stroke:
                    drawSketchPath(sketchPath, lineWidth: a.lineWidth)
                case .both:
                    c.withAlphaComponent(0.3).setFill()
                    NSBezierPath(ovalIn: flipped).fill()
                    drawSketchPath(sketchPath, lineWidth: a.lineWidth)
                }
            } else {
                let p = NSBezierPath(ovalIn: flipped)
                applyDash(to: p)

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
            }

        case .line:
            guard let s = a.startPoint, let e = a.endPoint else { return }
            let flippedStart = CGPoint(x: s.x, y: flipY(s.y))
            let flippedEnd = CGPoint(x: e.x, y: flipY(e.y))

            if sketch {
                let sketchPath = SketchRenderer.sketchLine(from: flippedStart, to: flippedEnd, seed: seed)
                drawSketchPath(sketchPath, lineWidth: a.lineWidth)
            } else {
                c.setStroke()
                let p = NSBezierPath()
                p.move(to: flippedStart)
                p.line(to: flippedEnd)
                p.lineWidth = a.lineWidth
                applyDash(to: p)
                p.stroke()
            }

        case .highlighter:
            c.withAlphaComponent(0.3).setFill()
            NSBezierPath(rect: flipRect(a.rect)).fill()

        case .arrow:
            guard let s = a.startPoint, let e = a.endPoint else { return }
            let flippedStart = CGPoint(x: s.x, y: flipY(s.y))
            let flippedEnd = CGPoint(x: e.x, y: flipY(e.y))
            let len = hypot(flippedEnd.x - flippedStart.x, flippedEnd.y - flippedStart.y)
            guard len > a.lineWidth * 2 else { return }

            let headW = max(8, min(30, a.lineWidth * 3))
            let headL = max(8, min(30, a.lineWidth * 3))

            if let cp = a.controlPoint {
                let flippedCP = CGPoint(x: cp.x, y: flipY(cp.y))
                let arrowPath = Path.curvedArrow(from: flippedStart, to: flippedEnd, control: flippedCP, tailWidth: a.lineWidth, headWidth: headW, headLength: headL)
                if let ctx = NSGraphicsContext.current?.cgContext {
                    ctx.addPath(arrowPath.cgPath)
                    if a.dashedStroke {
                        c.setStroke()
                        ctx.setLineWidth(1)
                        ctx.setLineDash(phase: 0, lengths: [8, 4])
                        ctx.strokePath()
                    } else {
                        c.setFill()
                        ctx.fillPath()
                    }
                }
            } else {
                c.setFill()
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
                if a.dashedStroke {
                    c.setStroke()
                    p.lineWidth = 1
                    applyDash(to: p)
                    p.stroke()
                } else {
                    p.fill()
                }
            }

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
                x: shapeRect.midX - textSize.width / 2,
                y: shapeRect.midY - textSize.height / 2,
                width: textSize.width,
                height: textSize.height
            )
            numText.draw(in: textRect, withAttributes: attrs)

        case .text:
            guard !a.text.isEmpty else { return }
            let fontSize = a.lineWidth * 4
            let font: NSFont = {
                if a.isBold && a.isItalic {
                    let descriptor = NSFontDescriptor.preferredFontDescriptor(forTextStyle: .body)
                        .withSymbolicTraits([.bold, .italic])
                    return NSFont(descriptor: descriptor, size: fontSize) ?? NSFont.systemFont(ofSize: fontSize, weight: .bold)
                } else if a.isBold {
                    return NSFont.boldSystemFont(ofSize: fontSize)
                } else if a.isItalic {
                    let descriptor = NSFontDescriptor.preferredFontDescriptor(forTextStyle: .body)
                        .withSymbolicTraits(.italic)
                    return NSFont(descriptor: descriptor, size: fontSize) ?? NSFont.systemFont(ofSize: fontSize)
                }
                return NSFont.systemFont(ofSize: fontSize)
            }()
            let paragraphStyle = NSMutableParagraphStyle()
            paragraphStyle.alignment = a.textAlignment.nsTextAlignment
            let attrs: [NSAttributedString.Key: Any] = [
                .font: font,
                .foregroundColor: c,
                .paragraphStyle: paragraphStyle
            ]
            let flippedTextRect = flipRect(a.rect)

            // Draw background color if present
            if let bgColor = a.backgroundColor {
                let maxDrawWidth = a.rect.width - 16
                let boundingRect = (a.text as NSString).boundingRect(
                    with: NSSize(width: maxDrawWidth, height: CGFloat.greatestFiniteMagnitude),
                    options: [.usesLineFragmentOrigin, .usesFontLeading],
                    attributes: attrs
                )
                let bgRect = CGRect(
                    x: flippedTextRect.minX,
                    y: flippedTextRect.minY,
                    width: min(flippedTextRect.width, boundingRect.width + 20),
                    height: min(flippedTextRect.height, boundingRect.height + 12)
                )
                let bgPath = NSBezierPath(roundedRect: bgRect, xRadius: 6, yRadius: 6)
                NSColor(bgColor).setFill()
                bgPath.fill()
            }

            a.text.draw(in: flippedTextRect, withAttributes: attrs)

        case .pixelate:
            if let pixelatedImg = applyPixelateFilter(to: image, in: a.rect) {
                let flipped = flipRect(a.rect)
                pixelatedImg.draw(in: flipped, from: .zero, operation: .sourceOver, fraction: 1.0)
            } else {
                NSColor.black.setFill()
                NSBezierPath(rect: flipRect(a.rect)).fill()
            }

        case .spotlight:
            break

        case .pen:
            guard let points = a.path, points.count > 1 else { return }

            let simplified = simplifyPoints(points, tolerance: 1.0)
            let flippedPoints = simplified.map { CGPoint(x: $0.x, y: flipY($0.y)) }

            c.setStroke()
            let bezierPath = NSBezierPath()
            bezierPath.lineCapStyle = .round
            bezierPath.lineJoinStyle = .round

            if flippedPoints.count > 2 {
                bezierPath.move(to: flippedPoints[0])
                for i in 0..<flippedPoints.count - 1 {
                    let p0 = flippedPoints[max(i - 1, 0)]
                    let p1 = flippedPoints[i]
                    let p2 = flippedPoints[min(i + 1, flippedPoints.count - 1)]
                    let p3 = flippedPoints[min(i + 2, flippedPoints.count - 1)]
                    let cp1 = CGPoint(x: p1.x + (p2.x - p0.x) / 6, y: p1.y + (p2.y - p0.y) / 6)
                    let cp2 = CGPoint(x: p2.x - (p3.x - p1.x) / 6, y: p2.y - (p3.y - p1.y) / 6)
                    bezierPath.curve(to: p2, controlPoint1: cp1, controlPoint2: cp2)
                }
            } else {
                bezierPath.move(to: flippedPoints[0])
                for i in 1..<flippedPoints.count { bezierPath.line(to: flippedPoints[i]) }
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

        case .blur:
            switch a.blurMode {
            case .full:
                if let blurredImg = applyGaussianBlurFilter(to: image, in: a.rect, radius: a.blurRadius) {
                    let flipped = flipRect(a.rect)
                    blurredImg.draw(in: flipped, from: .zero, operation: .sourceOver, fraction: 1.0)
                }
            case .textOnly:
                let textRects = TextRegionDetector.detectTextRegions(in: image, within: a.rect)
                for textRect in textRects {
                    if let blurredImg = applyGaussianBlurFilter(to: image, in: textRect, radius: a.blurRadius) {
                        let flipped = flipRect(textRect)
                        blurredImg.draw(in: flipped, from: .zero, operation: .sourceOver, fraction: 1.0)
                    }
                }
            case .erase:
                let flipped = flipRect(a.rect)
                let bgColor = sampleBackgroundColor(in: a.rect)
                NSColor(bgColor).setFill()
                flipped.fill()
            case .textErase:
                let textRects = TextRegionDetector.detectTextRegions(in: image, within: a.rect)
                let bgColor = sampleBackgroundColor(in: a.rect)
                for textRect in textRects {
                    let flipped = flipRect(textRect)
                    NSColor(bgColor).setFill()
                    flipped.fill()
                }
            }

        case .callout:
            let flipped = flipRect(a.rect)
            let cornerRadius = a.cornerRadius
            let bodyPath = NSBezierPath(roundedRect: flipped, xRadius: cornerRadius, yRadius: cornerRadius)

            let tailWidth: CGFloat = min(20, flipped.width * 0.2)
            let tailHeight: CGFloat = min(16, flipped.height * 0.4)

            let tailPath = NSBezierPath()
            // For NSBezierPath (flipped Y): bottom in SwiftUI = top in AppKit, etc
            switch a.calloutTailDirection {
            case .bottomLeft:
                let baseX = flipped.minX + flipped.width * 0.2
                tailPath.move(to: NSPoint(x: baseX, y: flipped.minY))
                tailPath.line(to: NSPoint(x: baseX - tailWidth * 0.3, y: flipped.minY - tailHeight))
                tailPath.line(to: NSPoint(x: baseX + tailWidth, y: flipped.minY))
            case .bottomCenter:
                let baseX = flipped.midX
                tailPath.move(to: NSPoint(x: baseX - tailWidth / 2, y: flipped.minY))
                tailPath.line(to: NSPoint(x: baseX, y: flipped.minY - tailHeight))
                tailPath.line(to: NSPoint(x: baseX + tailWidth / 2, y: flipped.minY))
            case .bottomRight:
                let baseX = flipped.maxX - flipped.width * 0.2
                tailPath.move(to: NSPoint(x: baseX - tailWidth, y: flipped.minY))
                tailPath.line(to: NSPoint(x: baseX + tailWidth * 0.3, y: flipped.minY - tailHeight))
                tailPath.line(to: NSPoint(x: baseX, y: flipped.minY))
            case .topLeft:
                let baseX = flipped.minX + flipped.width * 0.2
                tailPath.move(to: NSPoint(x: baseX, y: flipped.maxY))
                tailPath.line(to: NSPoint(x: baseX - tailWidth * 0.3, y: flipped.maxY + tailHeight))
                tailPath.line(to: NSPoint(x: baseX + tailWidth, y: flipped.maxY))
            case .topCenter:
                let baseX = flipped.midX
                tailPath.move(to: NSPoint(x: baseX - tailWidth / 2, y: flipped.maxY))
                tailPath.line(to: NSPoint(x: baseX, y: flipped.maxY + tailHeight))
                tailPath.line(to: NSPoint(x: baseX + tailWidth / 2, y: flipped.maxY))
            case .topRight:
                let baseX = flipped.maxX - flipped.width * 0.2
                tailPath.move(to: NSPoint(x: baseX - tailWidth, y: flipped.maxY))
                tailPath.line(to: NSPoint(x: baseX + tailWidth * 0.3, y: flipped.maxY + tailHeight))
                tailPath.line(to: NSPoint(x: baseX, y: flipped.maxY))
            }
            tailPath.close()

            applyDash(to: bodyPath)
            applyDash(to: tailPath)

            switch a.fillMode {
            case .fill:
                c.setFill()
                bodyPath.fill()
                tailPath.fill()
            case .stroke:
                c.setStroke()
                bodyPath.lineWidth = a.lineWidth
                bodyPath.stroke()
                tailPath.lineWidth = a.lineWidth
                tailPath.stroke()
            case .both:
                c.withAlphaComponent(0.3).setFill()
                bodyPath.fill()
                tailPath.fill()
                c.setStroke()
                bodyPath.lineWidth = a.lineWidth
                bodyPath.stroke()
                tailPath.lineWidth = a.lineWidth
                tailPath.stroke()
            }

            if !a.text.isEmpty {
                let textFont = NSFont.systemFont(ofSize: a.lineWidth * 3)
                let textColor = a.fillMode == .fill ? NSColor.white : c
                let attrs: [NSAttributedString.Key: Any] = [.font: textFont, .foregroundColor: textColor]
                let textInset = CGRect(x: flipped.minX + 8, y: flipped.minY + 4, width: flipped.width - 16, height: flipped.height - 8)
                a.text.draw(in: textInset, withAttributes: attrs)
            }

        case .magnifier:
            guard let ctx = NSGraphicsContext.current?.cgContext else { break }
            let flipped = flipRect(a.rect)
            let mag = a.magnification

            let sourceW = flipped.width / mag
            let sourceH = flipped.height / mag
            let imgSourceRect = CGRect(
                x: a.rect.midX - sourceW / 2,
                y: a.rect.midY - sourceH / 2,
                width: sourceW,
                height: sourceH
            )

            if let tiffData = image.tiffRepresentation,
               let bitmap = NSBitmapImageRep(data: tiffData),
               let cgFull = bitmap.cgImage {
                // Convert from image point coords to pixel coords (Retina 2x etc.)
                let pxScaleX = image.size.width > 0 ? CGFloat(cgFull.width) / image.size.width : 1
                let pxScaleY = image.size.height > 0 ? CGFloat(cgFull.height) / image.size.height : 1
                let clampedX = max(0, min(Int(imgSourceRect.origin.x * pxScaleX), cgFull.width - 1))
                let clampedY = max(0, min(Int(imgSourceRect.origin.y * pxScaleY), cgFull.height - 1))
                let clampedW = max(1, min(Int(imgSourceRect.width * pxScaleX), cgFull.width - clampedX))
                let clampedH = max(1, min(Int(imgSourceRect.height * pxScaleY), cgFull.height - clampedY))
                let cropCGRect = CGRect(x: clampedX, y: clampedY, width: clampedW, height: clampedH)
                if let croppedCG = cgFull.cropping(to: cropCGRect) {
                    ctx.saveGState()
                    let ellipsePath = CGPath(ellipseIn: flipped, transform: nil)
                    ctx.addPath(ellipsePath)
                    ctx.clip()
                    ctx.draw(croppedCG, in: flipped)
                    ctx.restoreGState()
                }
            }

            // White border
            let borderPath = NSBezierPath(ovalIn: flipped)
            NSColor.white.setStroke()
            borderPath.lineWidth = 3
            borderPath.stroke()

        case .ruler:
            let start = a.startPoint ?? CGPoint(x: a.rect.minX, y: a.rect.minY)
            let end = a.endPoint ?? CGPoint(x: a.rect.maxX, y: a.rect.maxY)
            let fStart = NSPoint(x: start.x, y: flipY(start.y))
            let fEnd = NSPoint(x: end.x, y: flipY(end.y))

            let dx = fEnd.x - fStart.x
            let dy = fEnd.y - fStart.y
            let angle = atan2(dy, dx)

            // Main line
            let mainPath = NSBezierPath()
            mainPath.move(to: fStart)
            mainPath.line(to: fEnd)
            c.setStroke()
            mainPath.lineWidth = a.lineWidth
            mainPath.stroke()

            // Tick marks
            let tickLen: CGFloat = 10
            let perpX = -sin(angle) * tickLen
            let perpY = cos(angle) * tickLen
            let tickPath = NSBezierPath()
            tickPath.move(to: NSPoint(x: fStart.x + perpX, y: fStart.y + perpY))
            tickPath.line(to: NSPoint(x: fStart.x - perpX, y: fStart.y - perpY))
            tickPath.move(to: NSPoint(x: fEnd.x + perpX, y: fEnd.y + perpY))
            tickPath.line(to: NSPoint(x: fEnd.x - perpX, y: fEnd.y - perpY))
            tickPath.lineWidth = a.lineWidth
            tickPath.stroke()

            // Distance label
            let origDx = end.x - start.x
            let origDy = end.y - start.y
            let dist = sqrt(origDx * origDx + origDy * origDy)
            let labelStr = "\(Int(dist))px"
            let midPoint = NSPoint(x: (fStart.x + fEnd.x) / 2, y: (fStart.y + fEnd.y) / 2)
            let labelOffset: CGFloat = 14
            let labelPos = NSPoint(x: midPoint.x - sin(angle) * labelOffset, y: midPoint.y + cos(angle) * labelOffset)

            let labelFont = NSFont.boldSystemFont(ofSize: max(10, a.lineWidth * 3))
            let labelAttrs: [NSAttributedString.Key: Any] = [
                .font: labelFont,
                .foregroundColor: c
            ]
            let labelSize = (labelStr as NSString).size(withAttributes: labelAttrs)
            let pillRect = NSRect(
                x: labelPos.x - labelSize.width / 2 - 4,
                y: labelPos.y - labelSize.height / 2 - 2,
                width: labelSize.width + 8,
                height: labelSize.height + 4
            )
            NSColor.black.withAlphaComponent(0.6).setFill()
            NSBezierPath(roundedRect: pillRect, xRadius: 4, yRadius: 4).fill()
            (labelStr as NSString).draw(
                at: NSPoint(x: pillRect.origin.x + 4, y: pillRect.origin.y + 2),
                withAttributes: labelAttrs
            )

        default:
            break
        }

        NSGraphicsContext.current?.cgContext.restoreGState()
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

    // MARK: - Save & Export

    private func saveImage() {
        autoreleasepool {
            let finalImage = renderFinalImage()

            let savePanel = NSSavePanel()
            savePanel.canCreateDirectories = true
            savePanel.showsTagField = false
            savePanel.nameFieldStringValue = "screenshot-\(Int(Date().timeIntervalSince1970)).\(exportFormat.fileExtension)"
            savePanel.level = .modalPanel

            let accessoryView = NSHostingView(rootView: ExportAccessoryView(
                format: Binding(get: { self.exportFormat }, set: { newFormat in
                    self.exportFormat = newFormat
                    savePanel.nameFieldStringValue = "screenshot-\(Int(Date().timeIntervalSince1970)).\(newFormat.fileExtension)"
                }),
                jpegQuality: Binding(get: { self.jpegQuality }, set: { self.jpegQuality = $0 })
            ))
            accessoryView.frame = NSRect(x: 0, y: 0, width: 280, height: 80)
            savePanel.accessoryView = accessoryView

            savePanel.begin { response in
                if response == .OK, let url = savePanel.url {
                    autoreleasepool {
                        guard let tiffData = finalImage.tiffRepresentation,
                              let bitmap = NSBitmapImageRep(data: tiffData) else { return }

                        let imageData: Data?
                        switch self.exportFormat {
                        case .png:
                            imageData = bitmap.representation(using: .png, properties: [:])
                        case .jpeg:
                            imageData = bitmap.representation(using: .jpeg, properties: [.compressionFactor: self.jpegQuality])
                        case .tiff:
                            imageData = bitmap.representation(using: .tiff, properties: [:])
                        }

                        guard let data = imageData else { return }
                        do {
                            try data.write(to: url)
                        } catch {
                        }
                    }
                }
            }
        }
    }

    private func shareImage() {
        let finalImage = renderFinalImage()
        guard let window = NSApp.keyWindow,
              let contentView = window.contentView else { return }

        // Write to temp file so AirDrop appears in share picker
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("clippy-share-\(Int(Date().timeIntervalSince1970)).png")
        guard let tiffData = finalImage.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData),
              let pngData = bitmap.representation(using: .png, properties: [:]) else { return }
        try? pngData.write(to: tempURL)

        let picker = NSSharingServicePicker(items: [tempURL])
        picker.show(relativeTo: .zero, of: contentView, preferredEdge: .minY)
    }

    private func saveToClippy() {
        autoreleasepool {
            let finalImage = renderFinalImage()
            clipboardMonitor.addImageToHistory(image: finalImage)
        }

        cleanupResources()

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            NSApp.keyWindow?.close()
        }
    }

    // MARK: - OCR

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
                    DispatchQueue.main.async { self.isPerformingOCR = false }
                }
            }
        }
    }

    // MARK: - Helpers

    private func findAnnotation(at point: CGPoint) -> (id: UUID, index: Int)? {
        if let index = viewModel.annotations.lastIndex(where: { $0.rect.contains(point) }) {
            return (viewModel.annotations[index].id, index)
        }
        return nil
    }

    private func startEditingText(at index: Int) {
        guard index < viewModel.annotations.count else { return }
        editingTextIndex = index
        isEditingText = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            self.isTextFieldFocused = true
        }
    }

    private func stopEditingText() {
        isEditingText = false
        editingTextIndex = nil
    }

    private func addToRecentColors(_ color: Color) {
        let newHex = color.hexString
        // Use hex comparison to avoid SwiftUI Color equality quirks
        if let existingIndex = recentColors.firstIndex(where: { $0.hexString == newHex }) {
            recentColors.remove(at: existingIndex)
        }
        recentColors.insert(color, at: 0)
        if recentColors.count > 10 {
            recentColors = Array(recentColors.prefix(10))
        }
    }

    private func pickColorFromImage(at point: CGPoint) {
        guard let tiffData = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData) else { return }

        // Convert from image point coords to bitmap pixel coords (Retina 2x etc.)
        let scaleX = image.size.width > 0 ? CGFloat(bitmap.pixelsWide) / image.size.width : 1
        let scaleY = image.size.height > 0 ? CGFloat(bitmap.pixelsHigh) / image.size.height : 1
        let x = Int(point.x * scaleX)
        let y = Int(point.y * scaleY)
        guard x >= 0, y >= 0, x < bitmap.pixelsWide, y < bitmap.pixelsHigh else { return }

        // Both SwiftUI Canvas and NSBitmapImageRep use top-left origin — no Y flip needed
        guard let nsColor = bitmap.colorAt(x: x, y: y) else { return }

        if contrastMode {
            let controller = EyedropperLoupeController.shared
            if controller.contrastForeground == nil {
                // First click: set foreground
                controller.contrastForeground = nsColor
                // Stay in eyedropper mode for background pick
                return
            } else if controller.contrastBackground == nil {
                // Second click: set background
                controller.contrastBackground = nsColor
                // Stay in eyedropper mode to show result; user can reset or switch tool
                return
            } else {
                // Already have both, start over with new foreground
                controller.contrastForeground = nsColor
                controller.contrastBackground = nil
                return
            }
        }

        selectedColor = Color(nsColor: nsColor)
        addToRecentColors(selectedColor)
        selectedTool = .select
    }

    /// Sample average background color from the edges of a rectangle in the image.
    private func sampleBackgroundColor(in rect: CGRect) -> Color {
        guard let tiffData = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData) else { return .white }

        // Convert from image point coords to pixel coords (Retina 2x etc.)
        let pxScaleX = image.size.width > 0 ? CGFloat(bitmap.pixelsWide) / image.size.width : 1
        let pxScaleY = image.size.height > 0 ? CGFloat(bitmap.pixelsHigh) / image.size.height : 1
        let w = bitmap.pixelsWide
        let h = bitmap.pixelsHigh
        var rTotal: CGFloat = 0, gTotal: CGFloat = 0, bTotal: CGFloat = 0
        var count: CGFloat = 0

        // Sample pixels along the edges of the rect (convert rect to pixel coords)
        let edgePoints: [(Int, Int)] = {
            var pts: [(Int, Int)] = []
            let minX = max(0, Int(rect.minX * pxScaleX))
            let maxX = min(w - 1, Int(rect.maxX * pxScaleX))
            let minY = max(0, Int(rect.minY * pxScaleY))
            let maxY = min(h - 1, Int(rect.maxY * pxScaleY))
            let step = max(1, (maxX - minX) / 10)
            // Top and bottom edges
            for x in stride(from: minX, to: maxX, by: step) {
                pts.append((x, minY))
                pts.append((x, maxY))
            }
            // Left and right edges
            for y in stride(from: minY, to: maxY, by: step) {
                pts.append((minX, y))
                pts.append((maxX, y))
            }
            return pts
        }()

        for (x, y) in edgePoints {
            let flippedY = h - y - 1
            guard flippedY >= 0, flippedY < h else { continue }
            if let color = bitmap.colorAt(x: x, y: flippedY)?.usingColorSpace(.sRGB) {
                rTotal += color.redComponent
                gTotal += color.greenComponent
                bTotal += color.blueComponent
                count += 1
            }
        }

        guard count > 0 else { return .white }
        return Color(red: rTotal / count, green: gTotal / count, blue: bTotal / count)
    }

    private func startImageDrag() {
        let finalImage = renderFinalImage()

        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.writeObjects([finalImage])

        // Show "Copied!" banner
        withAnimation(.easeInOut(duration: 0.3)) {
            showCopiedBanner = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation(.easeInOut(duration: 0.3)) {
                showCopiedBanner = false
            }
        }
    }

    // MARK: - Rotate

    private func rotateImage(clockwise: Bool) {
        guard let tiffData = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData),
              let cgImage = bitmap.cgImage else { return }

        let size = image.size
        let newSize = NSSize(width: size.height, height: size.width)
        let colorSpace = cgImage.colorSpace ?? CGColorSpaceCreateDeviceRGB()

        guard let ctx = CGContext(
            data: nil,
            width: Int(newSize.width),
            height: Int(newSize.height),
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return }

        ctx.translateBy(x: newSize.width / 2, y: newSize.height / 2)
        ctx.rotate(by: clockwise ? -.pi / 2 : .pi / 2)
        ctx.translateBy(x: -size.width / 2, y: -size.height / 2)
        ctx.draw(cgImage, in: CGRect(origin: .zero, size: size))

        guard let rotatedCG = ctx.makeImage() else { return }
        image = NSImage(cgImage: rotatedCG, size: newSize)
    }

    // MARK: - Flip

    private func flipImage(horizontal: Bool) {
        guard let tiffData = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData),
              let cgImage = bitmap.cgImage else { return }

        let size = image.size
        let colorSpace = cgImage.colorSpace ?? CGColorSpaceCreateDeviceRGB()

        guard let ctx = CGContext(
            data: nil,
            width: Int(size.width),
            height: Int(size.height),
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return }

        if horizontal {
            ctx.translateBy(x: size.width, y: 0)
            ctx.scaleBy(x: -1, y: 1)
        } else {
            ctx.translateBy(x: 0, y: size.height)
            ctx.scaleBy(x: 1, y: -1)
        }
        ctx.draw(cgImage, in: CGRect(origin: .zero, size: size))

        guard let flippedCG = ctx.makeImage() else { return }
        image = NSImage(cgImage: flippedCG, size: size)
    }

    // MARK: - Crop

    private func applyCrop() {
        guard let cropRect = cropRect else { return }

        let clamped = CGRect(
            x: max(0, cropRect.origin.x),
            y: max(0, cropRect.origin.y),
            width: min(cropRect.width, image.size.width - max(0, cropRect.origin.x)),
            height: min(cropRect.height, image.size.height - max(0, cropRect.origin.y))
        )

        guard clamped.width > 1, clamped.height > 1 else {
            self.cropRect = nil
            return
        }

        let flippedY = image.size.height - clamped.origin.y - clamped.height

        guard let tiffData = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData),
              let cgImage = bitmap.cgImage else {
            self.cropRect = nil
            return
        }

        // Scale from logical points to pixel coordinates for CGImage
        let scaleX = CGFloat(cgImage.width) / image.size.width
        let scaleY = CGFloat(cgImage.height) / image.size.height

        let pixelRect = CGRect(
            x: clamped.origin.x * scaleX,
            y: flippedY * scaleY,
            width: clamped.width * scaleX,
            height: clamped.height * scaleY
        )

        guard let cropped = cgImage.cropping(to: pixelRect) else {
            self.cropRect = nil
            return
        }

        let croppedImage = NSImage(cgImage: cropped, size: NSSize(width: clamped.width, height: clamped.height))
        image = croppedImage

        self.cropRect = nil
        selectedTool = .select
    }

    private func cancelCrop() {
        cropRect = nil
        selectedTool = .select
    }

    // MARK: - Fit to Window

    private func fitToWindow() {
        guard contentSize.width > 0, contentSize.height > 0 else { return }
        let fitScale = min(
            contentSize.width / image.size.width,
            contentSize.height / image.size.height
        )
        zoomScale = max(0.5, min(4.0, fitScale * 0.95))
        lastZoomScale = zoomScale
    }

    // MARK: - Expand Canvas Popover

    private var expandCanvasPopover: some View {
        VStack(spacing: 12) {
            Text("Expand Canvas")
                .font(.system(size: 13, weight: .semibold))

            // Top
            HStack {
                Spacer()
                VStack(alignment: .center, spacing: 2) {
                    Text("Top").font(.system(size: 10)).foregroundColor(.secondary)
                    TextField("0", text: $expandTop)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 60)
                        .multilineTextAlignment(.center)
                }
                Spacer()
            }

            // Left + Preview + Right
            HStack(spacing: 8) {
                VStack(alignment: .center, spacing: 2) {
                    Text("Left").font(.system(size: 10)).foregroundColor(.secondary)
                    TextField("0", text: $expandLeft)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 60)
                        .multilineTextAlignment(.center)
                }

                // Canvas preview
                ZStack {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(expandColor)
                        .frame(width: 60, height: 40)
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.gray.opacity(0.4))
                        .frame(width: 36, height: 24)
                    Text("IMG")
                        .font(.system(size: 8, weight: .medium))
                        .foregroundColor(.secondary)
                }

                VStack(alignment: .center, spacing: 2) {
                    Text("Right").font(.system(size: 10)).foregroundColor(.secondary)
                    TextField("0", text: $expandRight)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 60)
                        .multilineTextAlignment(.center)
                }
            }

            // Bottom
            HStack {
                Spacer()
                VStack(alignment: .center, spacing: 2) {
                    Text("Bottom").font(.system(size: 10)).foregroundColor(.secondary)
                    TextField("0", text: $expandBottom)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 60)
                        .multilineTextAlignment(.center)
                }
                Spacer()
            }

            // Background color
            HStack(spacing: 8) {
                Text("Fill").font(.system(size: 11))
                ColorPicker("", selection: $expandColor, supportsOpacity: true)
                    .labelsHidden()
                Button("Transparent") {
                    expandColor = .clear
                }
                .font(.system(size: 10))
                .buttonStyle(.plain)
                .foregroundColor(.accentColor)
            }

            // Preset buttons
            HStack(spacing: 6) {
                ForEach(["20", "50", "100", "200"], id: \.self) { px in
                    Button("\(px)px") {
                        expandTop = px
                        expandBottom = px
                        expandLeft = px
                        expandRight = px
                    }
                    .font(.system(size: 10))
                    .buttonStyle(.plain)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(Color.secondary.opacity(0.08))
                    .cornerRadius(4)
                }
            }

            Button("Apply") {
                let top = CGFloat(Int(expandTop) ?? 0)
                let bottom = CGFloat(Int(expandBottom) ?? 0)
                let left = CGFloat(Int(expandLeft) ?? 0)
                let right = CGFloat(Int(expandRight) ?? 0)
                guard top > 0 || bottom > 0 || left > 0 || right > 0 else { return }
                expandCanvas(top: top, bottom: bottom, left: left, right: right, fillColor: expandColor)
                showExpandCanvasPopover = false
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(16)
        .frame(width: 280)
        .onAppear {
            expandTop = "0"
            expandBottom = "0"
            expandLeft = "0"
            expandRight = "0"
        }
    }

    private func expandCanvas(top: CGFloat, bottom: CGFloat, left: CGFloat, right: CGFloat, fillColor: Color) {
        let oldSize = image.size
        let newWidth = oldSize.width + left + right
        let newHeight = oldSize.height + top + bottom

        guard newWidth >= 1, newHeight >= 1,
              newWidth <= 16384, newHeight <= 16384 else { return }

        guard let tiffData = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData),
              let cgImage = bitmap.cgImage else { return }

        let colorSpace = cgImage.colorSpace ?? CGColorSpaceCreateDeviceRGB()
        guard let ctx = CGContext(
            data: nil,
            width: Int(newWidth),
            height: Int(newHeight),
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return }

        // Fill background
        let nsColor = NSColor(fillColor)
        ctx.setFillColor(nsColor.cgColor)
        ctx.fill(CGRect(origin: .zero, size: CGSize(width: newWidth, height: newHeight)))

        // Draw original image at offset (CGContext has flipped Y: bottom is 0)
        ctx.draw(cgImage, in: CGRect(x: left, y: bottom, width: oldSize.width, height: oldSize.height))

        guard let expandedCG = ctx.makeImage() else { return }

        let oldImage = image
        let oldAnnotations = viewModel.annotations

        image = NSImage(cgImage: expandedCG, size: NSSize(width: newWidth, height: newHeight))

        // Offset all existing annotations
        for i in viewModel.annotations.indices {
            viewModel.annotations[i].rect = viewModel.annotations[i].rect.offsetBy(dx: left, dy: top)
            if let sp = viewModel.annotations[i].startPoint {
                viewModel.annotations[i].startPoint = CGPoint(x: sp.x + left, y: sp.y + top)
            }
            if let ep = viewModel.annotations[i].endPoint {
                viewModel.annotations[i].endPoint = CGPoint(x: ep.x + left, y: ep.y + top)
            }
            if let cp = viewModel.annotations[i].controlPoint {
                viewModel.annotations[i].controlPoint = CGPoint(x: cp.x + left, y: cp.y + top)
            }
            if let path = viewModel.annotations[i].path {
                viewModel.annotations[i].path = path.map { CGPoint(x: $0.x + left, y: $0.y + top) }
            }
        }

        // Register undo
        undoManager?.registerUndo(withTarget: viewModel) { [weak viewModel] vm in
            self.image = oldImage
            vm.annotations = oldAnnotations
        }
    }
}

// MARK: - Cleanup

extension ScreenshotEditorView {
    private func cleanupResources() {
        // Remove event monitors
        if let monitor = scrollWheelMonitor {
            NSEvent.removeMonitor(monitor)
            scrollWheelMonitor = nil
        }
        if let monitor = escKeyMonitor {
            NSEvent.removeMonitor(monitor)
            escKeyMonitor = nil
        }
        EyedropperLoupeController.shared.hide()

        // Clear undo history (holds strong references to old images/annotations)
        undoManager?.removeAllActions()
        viewModel.annotations.removeAll()
        viewModel.objectWillChange.send()

        // Clear UI state
        selectedAnnotationID = nil
        editingTextIndex = nil
        movingAnnotationID = nil
        isEditingText = false
        annotationClipboard = nil
        cropRect = nil

        // Release image representations
        autoreleasepool {
            for rep in image.representations {
                image.removeRepresentation(rep)
            }
            image.recache()
        }

        // Replace with minimal 1x1 image (CGContext instead of deprecated lockFocus)
        let tinyImage: NSImage = autoreleasepool {
            let tiny = NSImage(size: NSSize(width: 1, height: 1))
            tiny.cacheMode = .never
            return tiny
        }
        image = tinyImage

        zoomScale = 1.0
        lastZoomScale = 1.0
        recentColors.removeAll()
    }

    // MARK: - Layer Ordering

    private func bringToFront() {
        guard let id = selectedAnnotationID,
              let index = viewModel.annotations.firstIndex(where: { $0.id == id }),
              index < viewModel.annotations.count - 1 else { return }
        let annotation = viewModel.annotations.remove(at: index)
        viewModel.annotations.append(annotation)
    }

    private func sendToBack() {
        guard let id = selectedAnnotationID,
              let index = viewModel.annotations.firstIndex(where: { $0.id == id }),
              index > 0 else { return }
        let annotation = viewModel.annotations.remove(at: index)
        viewModel.annotations.insert(annotation, at: 0)
    }

    private func moveAnnotationUp() {
        guard let id = selectedAnnotationID,
              let index = viewModel.annotations.firstIndex(where: { $0.id == id }),
              index < viewModel.annotations.count - 1 else { return }
        viewModel.annotations.swapAt(index, index + 1)
    }

    private func moveAnnotationDown() {
        guard let id = selectedAnnotationID,
              let index = viewModel.annotations.firstIndex(where: { $0.id == id }),
              index > 0 else { return }
        viewModel.annotations.swapAt(index, index - 1)
    }
}
