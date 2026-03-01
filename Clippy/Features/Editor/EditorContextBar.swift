//
//  EditorContextBar.swift
//  Clippy
//

import SwiftUI

struct EditorContextBar: View {
    @ObservedObject var viewModel: ScreenshotEditorViewModel
    @EnvironmentObject var settings: SettingsManager

    @Binding var selectedTool: DrawingTool
    @Binding var selectedColor: Color
    @Binding var selectedLineWidth: CGFloat
    @Binding var selectedAnnotationID: UUID?

    @Binding var numberSize: CGFloat
    @Binding var numberShape: NumberShape
    @Binding var shapeCornerRadius: CGFloat
    @Binding var shapeFillMode: FillMode
    @Binding var spotlightShape: SpotlightShape
    @Binding var selectedEmoji: String
    @Binding var emojiSize: CGFloat
    @Binding var selectedBrushStyle: BrushStyle

    @Binding var showEffectsPanel: Bool
    @Binding var showColorCopied: Bool
    @Binding var showLineWidthPicker: Bool

    @Binding var backdropPadding: CGFloat
    @Binding var screenshotShadowRadius: CGFloat
    @Binding var screenshotCornerRadius: CGFloat
    @Binding var backdropCornerRadius: CGFloat
    @Binding var backdropFill: AnyShapeStyle
    @Binding var backdropModel: BackdropFillModel

    @Binding var cropAspectRatio: CropAspectRatio
    @Binding var blurRadius: CGFloat
    @Binding var annotationOpacity: CGFloat
    @Binding var dashedStroke: Bool
    @Binding var textIsBold: Bool
    @Binding var textIsItalic: Bool
    @Binding var textAlignment: TextAlignment
    @Binding var calloutTailDirection: CalloutTailDirection
    @Binding var recentColors: [Color]
    @Binding var contrastMode: Bool
    @Binding var blurMode: BlurMode
    @Binding var borderConfig: ImageBorderConfig

    var imageSize: CGSize
    var isPerformingOCR: Bool
    var ocrButtonIcon: String
    var showImagesTab: Bool
    var annotationsEmpty: Bool
    var undoManager: UndoManager?
    var isCropping: Bool

    var onUndo: () -> Void
    var onRedo: () -> Void
    var onApply: () -> Void
    var onClearAll: () -> Void
    var onSave: () -> Void
    var onSaveToClippy: () -> Void
    var onPerformOCR: () -> Void
    var onCopyImage: () -> Void
    var onClose: () -> Void
    var onApplyCrop: () -> Void
    var onCancelCrop: () -> Void

    var onShare: () -> Void
    var onBringToFront: () -> Void
    var onSendToBack: () -> Void
    var onMoveUp: () -> Void
    var onMoveDown: () -> Void

    var currentAnnotation: Annotation? {
        guard let id = selectedAnnotationID else { return nil }
        return viewModel.annotations.first(where: { $0.id == id })
    }

    var body: some View {
        HStack(spacing: 8) {
            // MARK: Undo/Redo
            HStack(spacing: 2) {
                Button(action: onUndo) {
                    Image(systemName: "arrow.uturn.backward")
                        .font(.system(size: 13))
                }
                .disabled(!(undoManager?.canUndo ?? false))

                Button(action: onRedo) {
                    Image(systemName: "arrow.uturn.forward")
                        .font(.system(size: 13))
                }
                .disabled(!(undoManager?.canRedo ?? false))
            }
            .buttonStyle(.plain)

            thinDivider

            // MARK: Color
            ColorPicker("", selection: $selectedColor, supportsOpacity: false)
                .labelsHidden()
                .frame(width: 24, height: 24)

            Menu {
                let converted = ColorConverter.convertToAllFormats(NSColor(selectedColor))
                colorFormatButton("HEX", value: converted.hex)
                colorFormatButton("RGB", value: converted.rgb)
                colorFormatButton("HSL", value: converted.hsl)
                colorFormatButton("HSB", value: converted.hsb)
                Divider()
                colorFormatButton("RGBA", value: converted.rgba)
                colorFormatButton("HSLA", value: converted.hsla)
                colorFormatButton("HEX+Alpha", value: converted.hexWithAlpha)
                Divider()
                colorFormatButton("SwiftUI", value: converted.swiftUI)
                colorFormatButton("NSColor", value: converted.nsColor)
            } label: {
                Text(showColorCopied ? L("Copied!", settings: settings) : selectedColor.hexString)
                    .font(.system(.caption2, design: .monospaced))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(Color.secondary.opacity(0.08))
                    .cornerRadius(4)
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .fixedSize()

            // MARK: Line Width
            Button(action: { showLineWidthPicker.toggle() }) {
                HStack(spacing: 3) {
                    Circle()
                        .fill(Color.secondary)
                        .frame(width: max(3, selectedLineWidth / 2.5), height: max(3, selectedLineWidth / 2.5))
                    Text(selectedLineWidth <= 4 ? "S" : selectedLineWidth <= 8 ? "M" : "L")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.secondary)
                }
                .frame(width: 40, height: 24)
                .background(Color.secondary.opacity(0.08))
                .cornerRadius(4)
            }
            .buttonStyle(.plain)
            .help(L("Line Width", settings: settings))
            .popover(isPresented: $showLineWidthPicker, arrowEdge: .bottom) {
                LineWidthPickerView(selectedLineWidth: $selectedLineWidth, isPresented: $showLineWidthPicker)
            }

            // MARK: Opacity
            opacityControl

            // MARK: Dashed Stroke
            dashedStrokeToggle

            // MARK: Sketch Style
            sketchStyleToggle

            thinDivider

            // MARK: Recent Colors
            recentColorsView

            thinDivider

            // MARK: Tool-specific controls (inline)
            toolSpecificControls

            Spacer()

            // MARK: Layer Ordering (when annotation selected)
            if selectedAnnotationID != nil {
                HStack(spacing: 1) {
                    Button(action: onBringToFront) {
                        Image(systemName: "square.3.layers.3d.top.filled")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                    .help(L("Bring to Front", settings: settings))

                    Button(action: onMoveUp) {
                        Image(systemName: "square.2.layers.3d.top.filled")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                    .help(L("Move Up", settings: settings))

                    Button(action: onMoveDown) {
                        Image(systemName: "square.2.layers.3d.bottom.filled")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                    .help(L("Move Down", settings: settings))

                    Button(action: onSendToBack) {
                        Image(systemName: "square.3.layers.3d.bottom.filled")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                    .help(L("Send to Back", settings: settings))
                }

                thinDivider
            }

            // MARK: Effects
            Button(action: { showEffectsPanel.toggle() }) {
                Image(systemName: "wand.and.rays")
                    .font(.system(size: 13))
                    .foregroundColor(showEffectsPanel ? .accentColor : .secondary)
            }
            .buttonStyle(.plain)
            .help(L("Effects", settings: settings))
            .popover(isPresented: $showEffectsPanel, arrowEdge: .bottom) {
                EffectsInspectorView(isPresented: $showEffectsPanel,
                                     backdropPadding: $backdropPadding,
                                     shadowRadius: $screenshotShadowRadius,
                                     screenshotCornerRadius: $screenshotCornerRadius,
                                     backdropCornerRadius: $backdropCornerRadius,
                                     backdropFill: $backdropFill,
                                     backdropModel: $backdropModel,
                                     borderConfig: $borderConfig)
            }

            // MARK: OCR
            Button(action: onPerformOCR) {
                Image(systemName: ocrButtonIcon)
                    .font(.system(size: 13))
            }
            .buttonStyle(.plain)
            .help(L("Copy Text from Image (OCR)", settings: settings))
            .disabled(isPerformingOCR)

            // MARK: Copy
            Button(action: onCopyImage) {
                Image(systemName: "doc.on.doc")
                    .font(.system(size: 13))
            }
            .buttonStyle(.plain)
            .help(L("Copy to Clipboard", settings: settings))

            // MARK: Share
            Button(action: onShare) {
                Image(systemName: "square.and.arrow.up")
                    .font(.system(size: 13))
            }
            .buttonStyle(.plain)
            .help(L("Share", settings: settings))

            if showImagesTab {
                Button(action: onSaveToClippy) {
                    Image(systemName: "internaldrive")
                        .font(.system(size: 13))
                }
                .buttonStyle(.plain)
                .help(L("Save to Clippy History", settings: settings))
            }

            thinDivider

            // MARK: Actions
            Button(action: onApply) {
                HStack(spacing: 3) {
                    Image(systemName: "checkmark")
                        .font(.system(size: 10, weight: .semibold))
                    Text(L("Apply", settings: settings))
                        .font(.system(size: 11, weight: .medium))
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.accentColor.opacity(annotationsEmpty ? 0.1 : 0.15))
                .cornerRadius(5)
            }
            .buttonStyle(.plain)
            .disabled(annotationsEmpty)
            .keyboardShortcut("a", modifiers: .command)

            Button(action: onClearAll) {
                Image(systemName: "trash")
                    .font(.system(size: 12))
                    .foregroundColor(annotationsEmpty ? .secondary.opacity(0.5) : .secondary)
            }
            .buttonStyle(.plain)
            .disabled(annotationsEmpty)
            .help(L("Clear All", settings: settings))
            .keyboardShortcut("k", modifiers: [.command, .shift])

            Button(action: onSave) {
                HStack(spacing: 3) {
                    Image(systemName: "square.and.arrow.down")
                        .font(.system(size: 10, weight: .semibold))
                    Text("Save")
                        .font(.system(size: 11, weight: .medium))
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .foregroundColor(.white)
                .background(Color.accentColor)
                .cornerRadius(5)
            }
            .buttonStyle(.plain)
            .keyboardShortcut("s", modifiers: .command)

            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
            .help(L("Close Editor (⌘Q)", settings: settings))
            .keyboardShortcut("q", modifiers: .command)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .frame(height: 40)
        .background(.bar)
    }

    private func colorFormatButton(_ label: String, value: String) -> some View {
        Button {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(value, forType: .string)
            showColorCopied = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                showColorCopied = false
            }
        } label: {
            HStack {
                Text(label)
                    .frame(width: 70, alignment: .leading)
                Spacer()
                Text(value)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundColor(.secondary)
            }
        }
    }

    private var thinDivider: some View {
        Divider().frame(height: 20)
    }

    // MARK: - Tool Specific Controls

    @ViewBuilder
    private var toolSpecificControls: some View {
        let activeTool = currentAnnotation?.tool ?? selectedTool

        switch activeTool {
        case .rectangle:
            rectangleControls
        case .ellipse:
            fillModeButtons
        case .arrow:
            HStack(spacing: 8) {
                lineWidthSlider
                Divider().frame(height: 16)
                curveToggle
            }
        case .line:
            lineWidthSlider
        case .text:
            textControls
        case .pin:
            pinControls
        case .spotlight:
            spotlightControls
        case .emoji:
            emojiSizeSlider
        case .pen:
            penControls
        case .highlighter:
            lineWidthSlider
        case .crop:
            cropControls
        case .blur:
            blurControls
        case .callout:
            calloutControls
        case .magnifier:
            magnifierControls
        case .ruler:
            Text("Drag to measure distance")
                .font(.system(size: 10))
                .foregroundColor(.secondary)
        case .eyedropper:
            eyedropperControls
        default:
            EmptyView()
        }
    }

    // MARK: - Fill Mode

    @ViewBuilder
    private var fillModeButtons: some View {
        HStack(spacing: 2) {
            ForEach(FillMode.allCases, id: \.self) { mode in
                Button(action: {
                    shapeFillMode = mode
                    if let id = selectedAnnotationID,
                       let index = viewModel.annotations.firstIndex(where: { $0.id == id }) {
                        viewModel.annotations[index].fillMode = mode
                    }
                }) {
                    Image(systemName: mode.icon)
                        .font(.system(size: 12))
                        .foregroundColor((currentAnnotation?.fillMode ?? shapeFillMode) == mode ? .accentColor : .secondary)
                        .frame(width: 24, height: 24)
                        .background(
                            RoundedRectangle(cornerRadius: 4)
                                .fill((currentAnnotation?.fillMode ?? shapeFillMode) == mode ? Color.accentColor.opacity(0.15) : Color.clear)
                        )
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Rectangle

    @ViewBuilder
    private var rectangleControls: some View {
        fillModeButtons

        HStack(spacing: 4) {
            Image(systemName: "rectangle.roundedtop")
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
            .frame(width: 70)
            Text("\(Int(currentAnnotation?.cornerRadius ?? shapeCornerRadius))")
                .font(.system(size: 10))
                .foregroundColor(.secondary)
                .frame(width: 18)
        }
    }

    // MARK: - Line Width Slider

    @ViewBuilder
    private var lineWidthSlider: some View {
        HStack(spacing: 4) {
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
            .frame(width: 80)
            Text("\(Int(currentAnnotation?.lineWidth ?? selectedLineWidth))")
                .font(.system(size: 10))
                .foregroundColor(.secondary)
                .frame(width: 18)
        }
    }

    private var curveToggle: some View {
        Button(action: {
            guard let id = selectedAnnotationID,
                  let index = viewModel.annotations.firstIndex(where: { $0.id == id }),
                  viewModel.annotations[index].tool == .arrow else { return }
            if viewModel.annotations[index].controlPoint != nil {
                viewModel.annotations[index].controlPoint = nil
            } else {
                let start = viewModel.annotations[index].startPoint ?? viewModel.annotations[index].rect.origin
                let end = viewModel.annotations[index].endPoint ?? CGPoint(x: viewModel.annotations[index].rect.maxX, y: viewModel.annotations[index].rect.maxY)
                viewModel.annotations[index].controlPoint = CGPoint(
                    x: (start.x + end.x) / 2 + (end.y - start.y) * 0.3,
                    y: (start.y + end.y) / 2 - (end.x - start.x) * 0.3
                )
            }
        }) {
            let isCurved = currentAnnotation?.controlPoint != nil
            Image(systemName: "point.topleft.down.to.point.bottomright.curvepath")
                .font(.system(size: 11))
                .foregroundColor(isCurved ? .accentColor : .secondary)
                .frame(width: 24, height: 24)
                .background(isCurved ? Color.accentColor.opacity(0.15) : Color.clear)
                .cornerRadius(4)
        }
        .buttonStyle(.plain)
        .help("Toggle Curve")
    }

    // MARK: - Text

    @ViewBuilder
    private var textControls: some View {
        HStack(spacing: 6) {
            // Bold
            Button(action: {
                textIsBold.toggle()
                if let id = selectedAnnotationID,
                   let index = viewModel.annotations.firstIndex(where: { $0.id == id }) {
                    viewModel.annotations[index].isBold = textIsBold
                }
            }) {
                Image(systemName: "bold")
                    .font(.system(size: 12))
                    .foregroundColor((currentAnnotation?.isBold ?? textIsBold) ? .accentColor : .secondary)
                    .frame(width: 24, height: 24)
                    .background(RoundedRectangle(cornerRadius: 4).fill((currentAnnotation?.isBold ?? textIsBold) ? Color.accentColor.opacity(0.15) : Color.secondary.opacity(0.08)))
            }
            .buttonStyle(.plain)
            .help("Bold")

            // Italic
            Button(action: {
                textIsItalic.toggle()
                if let id = selectedAnnotationID,
                   let index = viewModel.annotations.firstIndex(where: { $0.id == id }) {
                    viewModel.annotations[index].isItalic = textIsItalic
                }
            }) {
                Image(systemName: "italic")
                    .font(.system(size: 12))
                    .foregroundColor((currentAnnotation?.isItalic ?? textIsItalic) ? .accentColor : .secondary)
                    .frame(width: 24, height: 24)
                    .background(RoundedRectangle(cornerRadius: 4).fill((currentAnnotation?.isItalic ?? textIsItalic) ? Color.accentColor.opacity(0.15) : Color.secondary.opacity(0.08)))
            }
            .buttonStyle(.plain)
            .help("Italic")

            // Text alignment
            HStack(spacing: 1) {
                ForEach(TextAlignment.allCases, id: \.self) { alignment in
                    Button(action: {
                        textAlignment = alignment
                        if let id = selectedAnnotationID,
                           let index = viewModel.annotations.firstIndex(where: { $0.id == id }) {
                            viewModel.annotations[index].textAlignment = alignment
                        }
                    }) {
                        Image(systemName: alignment.icon)
                            .font(.system(size: 10))
                            .foregroundColor((currentAnnotation?.textAlignment ?? textAlignment) == alignment ? .accentColor : .secondary)
                            .frame(width: 20, height: 24)
                    }
                    .buttonStyle(.plain)
                }
            }
            .background(RoundedRectangle(cornerRadius: 4).fill(Color.secondary.opacity(0.08)))

            Divider().frame(height: 16)

            // Background toggle
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
                Image(systemName: currentAnnotation?.backgroundColor == nil ? "rectangle.dashed" : "rectangle.fill")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                    .frame(width: 24, height: 24)
                    .background(RoundedRectangle(cornerRadius: 4).fill(Color.secondary.opacity(0.08)))
            }
            .buttonStyle(.plain)
            .help("Toggle Background")

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
                .frame(width: 24, height: 24)
            }

            Divider().frame(height: 16)

            Image(systemName: "textformat.size")
                .font(.system(size: 10))
                .foregroundColor(.secondary)

            Slider(value: Binding(
                get: { currentAnnotation?.lineWidth ?? selectedLineWidth },
                set: { newSize in
                    selectedLineWidth = newSize
                    if let id = selectedAnnotationID,
                       let index = viewModel.annotations.firstIndex(where: { $0.id == id }) {
                        viewModel.annotations[index].lineWidth = newSize
                    }
                }
            ), in: 3...12, step: 1)
            .frame(width: 80)
        }
    }

    // MARK: - Pin

    @ViewBuilder
    private var pinControls: some View {
        HStack(spacing: 6) {
            Text("\(viewModel.currentNumber)")
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundColor(.accentColor)

            Button(action: { viewModel.currentNumber = 1 }) {
                Image(systemName: "arrow.counterclockwise")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
            .help(L("Reset numbering", settings: settings))

            Divider().frame(height: 16)

            Slider(value: Binding(
                get: { currentAnnotation?.rect.width ?? numberSize },
                set: { newSize in
                    numberSize = newSize
                    if let id = selectedAnnotationID,
                       let index = viewModel.annotations.firstIndex(where: { $0.id == id }) {
                        let center = viewModel.annotations[index].rect.center
                        viewModel.annotations[index].rect = CGRect(
                            x: center.x - newSize / 2,
                            y: center.y - newSize / 2,
                            width: newSize,
                            height: newSize
                        )
                    }
                }
            ), in: 20...120, step: 5)
            .frame(width: 80)

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
                Image(systemName: "shape")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .frame(width: 24, height: 24)
                    .background(RoundedRectangle(cornerRadius: 4).fill(Color.secondary.opacity(0.08)))
            }
            .menuStyle(.borderlessButton)
            .frame(width: 30)
        }
    }

    // MARK: - Spotlight

    @ViewBuilder
    private var spotlightControls: some View {
        HStack(spacing: 2) {
            ForEach(SpotlightShape.allCases, id: \.self) { shape in
                Button(action: {
                    spotlightShape = shape
                    if let id = selectedAnnotationID,
                       let index = viewModel.annotations.firstIndex(where: { $0.id == id }) {
                        viewModel.annotations[index].spotlightShape = shape
                    }
                }) {
                    Image(systemName: shape == .ellipse ? "circle" : "square")
                        .font(.system(size: 12))
                        .foregroundColor((currentAnnotation?.spotlightShape ?? spotlightShape) == shape ? .accentColor : .secondary)
                        .frame(width: 24, height: 24)
                        .background(
                            RoundedRectangle(cornerRadius: 4)
                                .fill((currentAnnotation?.spotlightShape ?? spotlightShape) == shape ? Color.accentColor.opacity(0.15) : Color.clear)
                        )
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Emoji Size

    @ViewBuilder
    private var emojiSizeSlider: some View {
        HStack(spacing: 4) {
            Text("Size")
                .font(.system(size: 10))
                .foregroundColor(.secondary)
            Slider(value: Binding(
                get: { currentAnnotation?.rect.width ?? emojiSize },
                set: { newSize in
                    emojiSize = newSize
                    if let id = selectedAnnotationID,
                       let index = viewModel.annotations.firstIndex(where: { $0.id == id }) {
                        let center = viewModel.annotations[index].rect.center
                        viewModel.annotations[index].rect = CGRect(
                            x: center.x - newSize / 2,
                            y: center.y - newSize / 2,
                            width: newSize,
                            height: newSize
                        )
                    }
                }
            ), in: 24...120, step: 4)
            .frame(width: 80)
        }
    }

    // MARK: - Pen

    @ViewBuilder
    private var penControls: some View {
        lineWidthSlider

        Divider().frame(height: 16)

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
            HStack(spacing: 3) {
                Image(systemName: "paintbrush.fill")
                    .font(.system(size: 10))
                Text((currentAnnotation?.brushStyle ?? selectedBrushStyle).localizedName)
                    .font(.system(size: 10))
            }
            .foregroundColor(.secondary)
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(RoundedRectangle(cornerRadius: 4).fill(Color.secondary.opacity(0.08)))
        }
        .menuStyle(.borderlessButton)
        .frame(width: 90)
    }

    // MARK: - Crop

    @ViewBuilder
    private var cropControls: some View {
        HStack(spacing: 6) {
            ForEach(CropAspectRatio.allCases) { ratio in
                Button(action: { cropAspectRatio = ratio }) {
                    Text(ratio.rawValue)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(cropAspectRatio == ratio ? .accentColor : .secondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(
                            RoundedRectangle(cornerRadius: 4)
                                .fill(cropAspectRatio == ratio ? Color.accentColor.opacity(0.15) : Color.secondary.opacity(0.08))
                        )
                }
                .buttonStyle(.plain)
            }

            if isCropping {
                Divider().frame(height: 16)

                Button(action: onApplyCrop) {
                    HStack(spacing: 3) {
                        Image(systemName: "checkmark")
                            .font(.system(size: 10, weight: .semibold))
                        Text("Crop")
                            .font(.system(size: 11, weight: .medium))
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .foregroundColor(.white)
                    .background(Color.accentColor)
                    .cornerRadius(5)
                }
                .buttonStyle(.plain)
                .keyboardShortcut(.return, modifiers: [])

                Button(action: onCancelCrop) {
                    Text("Cancel")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .keyboardShortcut(.escape, modifiers: [])
            }
        }
    }

    // MARK: - Blur

    @ViewBuilder
    private var magnifierControls: some View {
        HStack(spacing: 4) {
            Image(systemName: "magnifyingglass.circle")
                .font(.system(size: 10))
                .foregroundColor(.secondary)
            Text("Zoom")
                .font(.system(size: 10))
                .foregroundColor(.secondary)
            Slider(value: Binding(
                get: { currentAnnotation?.magnification ?? 2.0 },
                set: { newValue in
                    if let id = selectedAnnotationID,
                       let index = viewModel.annotations.firstIndex(where: { $0.id == id }) {
                        viewModel.annotations[index].magnification = newValue
                    }
                }
            ), in: 1.5...5.0, step: 0.5)
            .frame(width: 100)
            Text("\(String(format: "%.1f", currentAnnotation?.magnification ?? 2.0))x")
                .font(.system(size: 10, design: .monospaced))
                .foregroundColor(.secondary)
                .frame(width: 28)
        }
    }

    private var blurControls: some View {
        HStack(spacing: 8) {
            HStack(spacing: 4) {
                Image(systemName: "aqi.medium")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
                Text("Radius")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
                Slider(value: Binding(
                    get: { currentAnnotation?.blurRadius ?? blurRadius },
                    set: { newValue in
                        blurRadius = newValue
                        if let id = selectedAnnotationID,
                           let index = viewModel.annotations.firstIndex(where: { $0.id == id }) {
                            viewModel.annotations[index].blurRadius = newValue
                        }
                    }
                ), in: 1...30, step: 1)
                .frame(width: 100)
                Text("\(Int(currentAnnotation?.blurRadius ?? blurRadius))")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(.secondary)
                    .frame(width: 20)
            }

            Divider().frame(height: 16)

            blurModePicker
        }
    }

    private var blurModePicker: some View {
        HStack(spacing: 2) {
            ForEach(BlurMode.allCases) { mode in
                Button(action: {
                    blurMode = mode
                    if let id = selectedAnnotationID,
                       let index = viewModel.annotations.firstIndex(where: { $0.id == id }) {
                        viewModel.annotations[index].blurMode = mode
                    }
                }) {
                    Text(mode.rawValue)
                        .font(.system(size: 9, weight: .medium))
                        .foregroundColor((currentAnnotation?.blurMode ?? blurMode) == mode ? .accentColor : .secondary)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 3)
                        .background(
                            RoundedRectangle(cornerRadius: 4)
                                .fill((currentAnnotation?.blurMode ?? blurMode) == mode ? Color.accentColor.opacity(0.15) : Color.secondary.opacity(0.08))
                        )
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Callout

    @ViewBuilder
    private var calloutControls: some View {
        HStack(spacing: 6) {
            fillModeButtons

            Divider().frame(height: 16)

            HStack(spacing: 4) {
                Image(systemName: "rectangle.roundedtop")
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
                .frame(width: 60)
            }

            Divider().frame(height: 16)

            Menu {
                ForEach(CalloutTailDirection.allCases, id: \.self) { direction in
                    Button(action: {
                        calloutTailDirection = direction
                        if let id = selectedAnnotationID,
                           let index = viewModel.annotations.firstIndex(where: { $0.id == id }) {
                            viewModel.annotations[index].calloutTailDirection = direction
                        }
                    }) {
                        HStack {
                            Text(direction.rawValue)
                            if (currentAnnotation?.calloutTailDirection ?? calloutTailDirection) == direction {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            } label: {
                HStack(spacing: 3) {
                    Image(systemName: "arrowtriangle.down.fill")
                        .font(.system(size: 8))
                    Text("Tail")
                        .font(.system(size: 10))
                }
                .foregroundColor(.secondary)
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(RoundedRectangle(cornerRadius: 4).fill(Color.secondary.opacity(0.08)))
            }
            .menuStyle(.borderlessButton)
            .frame(width: 70)
        }
    }

    // MARK: - Opacity Control

    @ViewBuilder
    private var opacityControl: some View {
        let activeTool = currentAnnotation?.tool ?? selectedTool
        let showOpacity: [DrawingTool] = [.rectangle, .ellipse, .line, .arrow, .text, .pin, .spotlight, .emoji, .pen, .highlighter, .callout]

        if showOpacity.contains(activeTool) {
            HStack(spacing: 3) {
                Image(systemName: "circle.lefthalf.filled")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
                Slider(value: Binding(
                    get: { currentAnnotation?.opacity ?? annotationOpacity },
                    set: { newValue in
                        annotationOpacity = newValue
                        if let id = selectedAnnotationID,
                           let index = viewModel.annotations.firstIndex(where: { $0.id == id }) {
                            viewModel.annotations[index].opacity = newValue
                        }
                    }
                ), in: 0.1...1.0, step: 0.1)
                .frame(width: 60)
                Text("\(Int((currentAnnotation?.opacity ?? annotationOpacity) * 100))%")
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundColor(.secondary)
                    .frame(width: 28)
            }
        }
    }

    // MARK: - Dashed Stroke Toggle

    @ViewBuilder
    private var dashedStrokeToggle: some View {
        let activeTool = currentAnnotation?.tool ?? selectedTool
        let showDashed: [DrawingTool] = [.rectangle, .ellipse, .line, .arrow, .callout]

        if showDashed.contains(activeTool) {
            Button(action: {
                dashedStroke.toggle()
                if let id = selectedAnnotationID,
                   let index = viewModel.annotations.firstIndex(where: { $0.id == id }) {
                    viewModel.annotations[index].dashedStroke = dashedStroke
                }
            }) {
                Image(systemName: (currentAnnotation?.dashedStroke ?? dashedStroke) ? "line.3.horizontal" : "minus")
                    .font(.system(size: 12))
                    .foregroundColor((currentAnnotation?.dashedStroke ?? dashedStroke) ? .accentColor : .secondary)
                    .frame(width: 24, height: 24)
                    .background(RoundedRectangle(cornerRadius: 4).fill((currentAnnotation?.dashedStroke ?? dashedStroke) ? Color.accentColor.opacity(0.15) : Color.secondary.opacity(0.08)))
            }
            .buttonStyle(.plain)
            .help("Dashed Stroke")
        }
    }

    // MARK: - Sketch Style Toggle

    @ViewBuilder
    private var sketchStyleToggle: some View {
        let activeTool = currentAnnotation?.tool ?? selectedTool
        let showSketch: [DrawingTool] = [.rectangle, .ellipse, .line, .arrow]

        if showSketch.contains(activeTool) {
            Button(action: {
                if let id = selectedAnnotationID,
                   let index = viewModel.annotations.firstIndex(where: { $0.id == id }) {
                    viewModel.annotations[index].sketchStyle.toggle()
                }
            }) {
                let isSketch = currentAnnotation?.sketchStyle ?? false
                Image(systemName: "hand.draw")
                    .font(.system(size: 11))
                    .foregroundColor(isSketch ? .accentColor : .secondary)
                    .frame(width: 24, height: 24)
                    .background(RoundedRectangle(cornerRadius: 4).fill(isSketch ? Color.accentColor.opacity(0.15) : Color.secondary.opacity(0.08)))
            }
            .buttonStyle(.plain)
            .help("Sketch Style")
        }
    }

    // MARK: - Eyedropper

    @ViewBuilder
    private var eyedropperControls: some View {
        HStack(spacing: 8) {
            Text(contrastMode ? "Contrast Mode: click FG then BG" : "Click to pick a color")
                .font(.system(size: 10))
                .foregroundColor(.secondary)

            Divider().frame(height: 16)

            Button(action: {
                contrastMode.toggle()
                let controller = EyedropperLoupeController.shared
                controller.contrastMode = contrastMode
                if !contrastMode {
                    controller.clearContrast()
                }
            }) {
                HStack(spacing: 3) {
                    Image(systemName: "circle.lefthalf.filled.inverse")
                        .font(.system(size: 11))
                    Text("Contrast")
                        .font(.system(size: 10, weight: .medium))
                }
                .foregroundColor(contrastMode ? .accentColor : .secondary)
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(RoundedRectangle(cornerRadius: 4).fill(contrastMode ? Color.accentColor.opacity(0.15) : Color.secondary.opacity(0.08)))
            }
            .buttonStyle(.plain)
            .help("WCAG Contrast Checker")

            if contrastMode {
                Button(action: {
                    EyedropperLoupeController.shared.clearContrast()
                }) {
                    Image(systemName: "arrow.counterclockwise")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .help("Reset contrast colors")
            }
        }
    }

    // MARK: - Recent Colors

    @ViewBuilder
    private var recentColorsView: some View {
        if !recentColors.isEmpty {
            HStack(spacing: 2) {
                ForEach(Array(recentColors.prefix(8).enumerated()), id: \.offset) { _, color in
                    Button(action: { selectedColor = color }) {
                        Circle()
                            .fill(color)
                            .frame(width: 14, height: 14)
                            .overlay(
                                Circle()
                                    .stroke(selectedColor == color ? Color.accentColor : Color.clear, lineWidth: 2)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}
