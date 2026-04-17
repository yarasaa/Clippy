import SwiftUI
import Combine

// MARK: - EditorInspectorPanel
// A context-aware right side panel that mirrors creative-app inspectors
// (Figma, Sketch). Replaces the cramped top Context Bar for most settings.
//
// Contents change based on the active state:
//   • No selection  → Effects (backdrop, border, watermark)
//   • Tool active   → That tool's properties (color, width, opacity, style)
//   • Annotation    → Selected annotation details (placeholder — future work)
//
// Fully additive — does not remove functionality from the ContextBar.

struct EditorInspectorPanel: View {
    // Core
    @Binding var selectedTool: DrawingTool
    @Binding var selectedColor: Color
    @Binding var selectedLineWidth: CGFloat
    @Binding var annotationOpacity: CGFloat
    @Binding var selectedBrushStyle: BrushStyle
    @Binding var shapeFillMode: FillMode
    @Binding var dashedStroke: Bool
    @Binding var textIsBold: Bool
    @Binding var textIsItalic: Bool
    @Binding var textAlignment: TextAlignment
    @Binding var recentColors: [Color]

    // Effects
    @Binding var backdropPadding: CGFloat
    @Binding var screenshotShadowRadius: CGFloat
    @Binding var screenshotCornerRadius: CGFloat
    @Binding var backdropCornerRadius: CGFloat
    @Binding var borderConfig: ImageBorderConfig

    // Selection
    @Binding var selectedAnnotationID: UUID?
    @ObservedObject var viewModel: ScreenshotEditorViewModel

    @Environment(\.colorScheme) private var scheme
    @State private var effectsExpanded: Bool = true

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Ember.Space.md) {
                headerChip

                if selectedAnnotationID != nil {
                    selectedAnnotationSection
                } else if hasToolProps {
                    toolPropsSection
                }

                Divider().opacity(0.25)

                effectsSection
            }
            .padding(Ember.Space.md)
        }
        .frame(width: 260)
        .background(Ember.cardBackground(scheme).opacity(0.6))
    }

    // MARK: Header chip

    private var headerChip: some View {
        HStack(spacing: Ember.Space.sm) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Ember.Palette.amber, Ember.Palette.amberDark],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 28, height: 28)
                Image(systemName: selectedTool.icon)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.white)
            }

            VStack(alignment: .leading, spacing: 1) {
                Text(selectedTool.displayName)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundColor(Ember.primaryText(scheme))
                Text(selectedAnnotationID != nil ? "Selected" : toolSubtitle)
                    .font(.system(size: 10, design: .serif)).italic()
                    .foregroundColor(Ember.secondaryText(scheme))
            }

            Spacer()
        }
    }

    private var toolSubtitle: String {
        switch selectedTool {
        case .select: return "Click an annotation"
        case .move:   return "Drag to reposition"
        case .pen:    return "Freehand drawing"
        case .text:   return "Click to type"
        case .crop:   return "Drag to select area"
        default:      return "Drag to draw"
        }
    }

    // MARK: Tool prop gate

    private var hasToolProps: Bool {
        switch selectedTool {
        case .select, .move, .eyedropper, .magnifier, .ruler: return false
        default: return true
        }
    }

    // MARK: Tool properties

    private var toolPropsSection: some View {
        VStack(alignment: .leading, spacing: Ember.Space.md) {
            // COLOR
            if selectedTool != .emoji {
                sectionLabel("COLOR")
                colorRow
            }

            // WIDTH (applies to strokes + pen + text)
            if toolUsesLineWidth {
                sectionLabel(selectedTool == .text ? "SIZE" : "WIDTH")
                lineWidthRow
            }

            // OPACITY
            if toolUsesOpacity {
                sectionLabel("OPACITY")
                opacityRow
            }

            // FILL MODE (shapes)
            if selectedTool == .rectangle || selectedTool == .ellipse {
                sectionLabel("FILL")
                fillModePicker
            }

            // PEN brush style
            if selectedTool == .pen {
                sectionLabel("BRUSH")
                brushStylePicker
            }

            // DASHED toggle (strokes)
            if toolSupportsDashed {
                sectionLabel("STROKE")
                HStack {
                    Text("Dashed")
                        .font(.system(size: 12))
                        .foregroundColor(Ember.primaryText(scheme))
                    Spacer()
                    Toggle("", isOn: $dashedStroke).labelsHidden()
                }
            }

            // TEXT formatting
            if selectedTool == .text {
                sectionLabel("FORMAT")
                textFormatRow
            }
        }
    }

    private var toolUsesLineWidth: Bool {
        switch selectedTool {
        case .arrow, .rectangle, .ellipse, .line, .callout, .pen,
             .highlighter, .text, .pin, .ruler:
            return true
        default:
            return false
        }
    }

    private var toolUsesOpacity: Bool {
        switch selectedTool {
        case .arrow, .rectangle, .ellipse, .line, .callout, .pen,
             .highlighter, .text:
            return true
        default:
            return false
        }
    }

    private var toolSupportsDashed: Bool {
        switch selectedTool {
        case .arrow, .rectangle, .ellipse, .line:
            return true
        default:
            return false
        }
    }

    // MARK: Color row

    private var colorRow: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                ColorPicker("", selection: $selectedColor)
                    .labelsHidden()
                    .frame(width: 34, height: 28)

                Text(colorHex)
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundColor(Ember.secondaryText(scheme))

                Spacer()
            }

            if !recentColors.isEmpty {
                HStack(spacing: 4) {
                    ForEach(Array(recentColors.prefix(8).enumerated()), id: \.offset) { _, c in
                        Button {
                            selectedColor = c
                        } label: {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(c)
                                .frame(width: 18, height: 18)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 4)
                                        .strokeBorder(Color.white.opacity(0.15), lineWidth: 0.5)
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private var colorHex: String {
        let ns = NSColor(selectedColor).usingColorSpace(.sRGB) ?? NSColor(selectedColor)
        let r = Int((ns.redComponent * 255).rounded())
        let g = Int((ns.greenComponent * 255).rounded())
        let b = Int((ns.blueComponent * 255).rounded())
        return String(format: "#%02X%02X%02X", r, g, b)
    }

    // MARK: Line width

    private var lineWidthRow: some View {
        HStack(spacing: Ember.Space.sm) {
            // Visual preview dot
            Circle()
                .fill(selectedColor)
                .frame(width: max(4, min(selectedLineWidth * 2, 22)),
                       height: max(4, min(selectedLineWidth * 2, 22)))
                .frame(width: 24, height: 24)

            Slider(value: $selectedLineWidth, in: 1...20, step: 1)

            Text("\(Int(selectedLineWidth))")
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundColor(Ember.secondaryText(scheme))
                .frame(width: 24, alignment: .trailing)
        }
    }

    // MARK: Opacity

    private var opacityRow: some View {
        HStack(spacing: Ember.Space.sm) {
            Image(systemName: "circle.lefthalf.filled")
                .font(.system(size: 12))
                .foregroundColor(Ember.secondaryText(scheme))
                .frame(width: 24)

            Slider(value: $annotationOpacity, in: 0.1...1.0)

            Text("\(Int(annotationOpacity * 100))%")
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundColor(Ember.secondaryText(scheme))
                .frame(width: 36, alignment: .trailing)
        }
    }

    // MARK: Fill mode

    private var fillModePicker: some View {
        HStack(spacing: 4) {
            ForEach(FillMode.allCases, id: \.self) { mode in
                Button {
                    shapeFillMode = mode
                } label: {
                    Image(systemName: mode.icon)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(shapeFillMode == mode ? .white : Ember.secondaryText(scheme))
                        .frame(maxWidth: .infinity, minHeight: 28)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(shapeFillMode == mode
                                      ? AnyShapeStyle(
                                          LinearGradient(colors: [Ember.Palette.amber, Ember.Palette.amberDark],
                                                         startPoint: .top, endPoint: .bottom)
                                        )
                                      : AnyShapeStyle(Ember.Palette.smoke.opacity(0.12))
                                )
                        )
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: Brush style

    private var brushStylePicker: some View {
        HStack(spacing: 4) {
            ForEach(BrushStyle.allCases) { style in
                Button {
                    selectedBrushStyle = style
                } label: {
                    Text(style.displayName)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(selectedBrushStyle == style ? .white : Ember.secondaryText(scheme))
                        .frame(maxWidth: .infinity, minHeight: 26)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(selectedBrushStyle == style
                                      ? AnyShapeStyle(
                                          LinearGradient(colors: [Ember.Palette.amber, Ember.Palette.amberDark],
                                                         startPoint: .top, endPoint: .bottom)
                                        )
                                      : AnyShapeStyle(Ember.Palette.smoke.opacity(0.12))
                                )
                        )
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: Text format

    private var textFormatRow: some View {
        HStack(spacing: 4) {
            textFormatButton(systemName: "bold", isOn: textIsBold) {
                textIsBold.toggle()
            }
            textFormatButton(systemName: "italic", isOn: textIsItalic) {
                textIsItalic.toggle()
            }

            Divider().frame(height: 18).padding(.horizontal, 2)

            ForEach(TextAlignment.allCases, id: \.self) { align in
                textFormatButton(
                    systemName: alignIcon(align),
                    isOn: textAlignment == align
                ) {
                    textAlignment = align
                }
            }
        }
    }

    private func textFormatButton(systemName: String, isOn: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(isOn ? .white : Ember.secondaryText(scheme))
                .frame(maxWidth: .infinity, minHeight: 26)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(isOn
                              ? AnyShapeStyle(Ember.Palette.amber)
                              : AnyShapeStyle(Ember.Palette.smoke.opacity(0.12)))
                )
        }
        .buttonStyle(.plain)
    }

    private func alignIcon(_ a: TextAlignment) -> String {
        switch a {
        case .left:   return "text.alignleft"
        case .center: return "text.aligncenter"
        case .right:  return "text.alignright"
        }
    }

    // MARK: Effects (always shown at bottom)

    private var effectsSection: some View {
        VStack(alignment: .leading, spacing: Ember.Space.sm) {
            Button {
                withAnimation(.easeInOut(duration: 0.15)) { effectsExpanded.toggle() }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: effectsExpanded ? "chevron.down" : "chevron.right")
                        .font(.system(size: 9, weight: .bold))
                    Text("EFFECTS")
                        .font(.system(size: 10, weight: .semibold))
                        .tracking(0.8)
                    Spacer()
                }
                .foregroundColor(Ember.tertiaryText(scheme))
            }
            .buttonStyle(.plain)

            if effectsExpanded {
                effectsSlider(label: "Padding", value: $backdropPadding, range: 0...150, suffix: "px")
                effectsSlider(label: "Shadow",  value: $screenshotShadowRadius, range: 0...100, suffix: "")
                effectsSlider(label: "Image corners", value: $screenshotCornerRadius, range: 0...60, suffix: "px")
                effectsSlider(label: "Backdrop corners", value: $backdropCornerRadius, range: 0...60, suffix: "px")

                Divider().opacity(0.15)

                HStack {
                    Text("Border")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(Ember.primaryText(scheme))
                    Spacer()
                    Picker("", selection: $borderConfig.style) {
                        Text("None").tag(BorderStyle.none)
                        Text("Solid").tag(BorderStyle.solid)
                        Text("Dashed").tag(BorderStyle.dashed)
                        Text("Double").tag(BorderStyle.double)
                    }
                    .labelsHidden()
                    .frame(width: 110)
                }

                if borderConfig.style != .none {
                    HStack(spacing: Ember.Space.sm) {
                        ColorPicker("", selection: $borderConfig.color)
                            .labelsHidden()
                            .frame(width: 34, height: 22)
                        Slider(value: $borderConfig.width, in: 1...40)
                        Stepper("", value: $borderConfig.width, in: 1...40, step: 1)
                            .labelsHidden()
                            .controlSize(.small)
                        Text("\(Int(borderConfig.width))")
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundColor(Ember.secondaryText(scheme))
                            .frame(width: 22, alignment: .trailing)
                    }
                }
            }
        }
    }

    private func effectsSlider(label: String, value: Binding<CGFloat>, range: ClosedRange<CGFloat>, suffix: String) -> some View {
        HStack(spacing: Ember.Space.sm) {
            Text(label)
                .font(.system(size: 11))
                .foregroundColor(Ember.primaryText(scheme))
                .frame(width: 80, alignment: .leading)

            Slider(value: value, in: range)

            Text("\(Int(value.wrappedValue))\(suffix)")
                .font(.system(size: 10, design: .monospaced))
                .foregroundColor(Ember.secondaryText(scheme))
                .frame(width: 36, alignment: .trailing)
        }
    }

    // MARK: Selected annotation section — LIVE EDITABLE properties

    @ViewBuilder
    private var selectedAnnotationSection: some View {
        if let id = selectedAnnotationID,
           viewModel.annotations.contains(where: { $0.id == id }) {
            let b = annotationBinding(for: id)
            let tool = b.wrappedValue.tool

            VStack(alignment: .leading, spacing: Ember.Space.md) {
                // COLOR — always editable (except for pure-utility tools)
                if tool != .emoji && tool != .pixelate && tool != .blur {
                    sectionLabel("COLOR")
                    HStack(spacing: 8) {
                        ColorPicker("", selection: Binding(
                            get: { b.wrappedValue.color },
                            set: { newValue in mutateAnnotation(id: id) { $0.color = newValue } }
                        ))
                        .labelsHidden()
                        .frame(width: 34, height: 28)
                        Text(hexString(for: b.wrappedValue.color))
                            .font(.system(size: 11, weight: .medium, design: .monospaced))
                            .foregroundColor(Ember.secondaryText(scheme))
                        Spacer()
                    }
                }

                // WIDTH — most tools
                if annotationUsesLineWidth(tool) {
                    sectionLabel(tool == .text ? "SIZE" : "WIDTH")
                    HStack(spacing: Ember.Space.sm) {
                        Circle()
                            .fill(b.wrappedValue.color)
                            .frame(width: max(4, min(b.wrappedValue.lineWidth * 2, 22)),
                                   height: max(4, min(b.wrappedValue.lineWidth * 2, 22)))
                            .frame(width: 24, height: 24)

                        Slider(value: floatBinding(id: id,
                                                   get: { b.wrappedValue.lineWidth },
                                                   set: { $0.lineWidth = $1 }),
                               in: 1...(tool == .text ? 40 : 20), step: 1)

                        Text("\(Int(b.wrappedValue.lineWidth))")
                            .font(.system(size: 11, weight: .medium, design: .monospaced))
                            .foregroundColor(Ember.secondaryText(scheme))
                            .frame(width: 24, alignment: .trailing)
                    }
                }

                // OPACITY
                if annotationUsesOpacity(tool) {
                    sectionLabel("OPACITY")
                    HStack(spacing: Ember.Space.sm) {
                        Image(systemName: "circle.lefthalf.filled")
                            .font(.system(size: 12))
                            .foregroundColor(Ember.secondaryText(scheme))
                            .frame(width: 24)

                        Slider(value: floatBinding(id: id,
                                                   get: { b.wrappedValue.opacity },
                                                   set: { $0.opacity = $1 }),
                               in: 0.1...1.0)

                        Text("\(Int(b.wrappedValue.opacity * 100))%")
                            .font(.system(size: 11, weight: .medium, design: .monospaced))
                            .foregroundColor(Ember.secondaryText(scheme))
                            .frame(width: 36, alignment: .trailing)
                    }
                }

                // TOOL-SPECIFIC SECTIONS ==========================

                // TEXT — Format + box + optional background
                if tool == .text {
                    textFormatSection(binding: b)
                    textBoxSection(binding: b)
                    textBackgroundSection(binding: b)
                }

                // ARROW — arrowhead + line style + sketch
                if tool == .arrow {
                    arrowheadSection(binding: b)
                    lineStyleSection(binding: b)
                    sketchToggle(binding: b)
                }

                // LINE / RULER — line style only
                if tool == .line || tool == .ruler {
                    lineStyleSection(binding: b)
                }

                // RECTANGLE — corner radius + fill + gradient + sketch
                if tool == .rectangle {
                    fillModeSection(binding: b)
                    cornerRadiusSection(binding: b)
                    lineStyleSection(binding: b)
                    sketchToggle(binding: b)
                }

                // ELLIPSE — fill + gradient + sketch
                if tool == .ellipse {
                    fillModeSection(binding: b)
                    lineStyleSection(binding: b)
                    sketchToggle(binding: b)
                }

                // CALLOUT — tail direction + corner radius + fill
                if tool == .callout {
                    fillModeSection(binding: b)
                    cornerRadiusSection(binding: b)
                    calloutTailSection(binding: b)
                }

                // PEN — brush style
                if tool == .pen {
                    penBrushSection(binding: b)
                }

                // PIN — number shape
                if tool == .pin {
                    pinShapeSection(binding: b)
                }

                // SPOTLIGHT — shape
                if tool == .spotlight {
                    spotlightShapeSection(binding: b)
                }

                // BLUR — mode + radius
                if tool == .blur {
                    blurSection(binding: b)
                }

                // PIXELATE — pixel size (uses blurRadius field)
                if tool == .pixelate {
                    pixelateSection(binding: b)
                }

                // SHADOW (most visual tools)
                if tool == .rectangle || tool == .ellipse || tool == .callout ||
                   tool == .arrow || tool == .line || tool == .text || tool == .pin {
                    shadowSection(binding: b)
                }

                // POSITION (informational read-only)
                sectionLabel("POSITION")
                HStack(spacing: Ember.Space.sm) {
                    numberField(label: "X", value: b.wrappedValue.rect.origin.x)
                    numberField(label: "Y", value: b.wrappedValue.rect.origin.y)
                }
                HStack(spacing: Ember.Space.sm) {
                    numberField(label: "W", value: b.wrappedValue.rect.size.width)
                    numberField(label: "H", value: b.wrappedValue.rect.size.height)
                }

                Divider().opacity(0.2)

                smallChipButton(systemName: "trash", text: "Delete Annotation", destructive: true) {
                    viewModel.removeAnnotation(with: id, undoManager: nil)
                    selectedAnnotationID = nil
                }
            }
        }
    }

    // MARK: - Tool-specific sub-sections

    // TEXT: Font family (default / rounded / serif / mono)
    private func textFontFamilySection(binding b: Binding<Annotation>) -> some View {
        let id = b.wrappedValue.id
        let current = b.wrappedValue.fontName

        return VStack(alignment: .leading, spacing: 6) {
            sectionLabel("FONT")
            HStack(spacing: 4) {
                fontFamilyChip(name: "Default", key: nil, current: current, id: id, design: .default, weight: .semibold)
                fontFamilyChip(name: "Round",   key: "rounded", current: current, id: id, design: .rounded, weight: .semibold)
                fontFamilyChip(name: "Serif",   key: "serif", current: current, id: id, design: .serif, weight: .regular)
                fontFamilyChip(name: "Mono",    key: "mono", current: current, id: id, design: .monospaced, weight: .regular)
            }
        }
    }

    private func fontFamilyChip(name: String, key: String?, current: String?, id: UUID, design: Font.Design, weight: Font.Weight) -> some View {
        let active = (current ?? "") == (key ?? "")
        return Button {
            // Direct mutation — bypass any Binding chain to guarantee the
            // @Published array publishes the change and the canvas redraws.
            mutateAnnotation(id: id) { $0.fontName = key }
        } label: {
            Text(name)
                .font(.system(size: 11, weight: weight, design: design))
                .foregroundColor(active ? .white : Ember.primaryText(scheme))
                .frame(maxWidth: .infinity, minHeight: 28)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(active
                              ? AnyShapeStyle(
                                  LinearGradient(colors: [Ember.Palette.amber, Ember.Palette.amberDark],
                                                 startPoint: .top, endPoint: .bottom)
                                )
                              : AnyShapeStyle(Ember.Palette.smoke.opacity(0.12)))
                )
        }
        .buttonStyle(.plain)
    }

    /// Mutate a specific annotation's struct fields via a closure, then
    /// publish the change by assigning the whole array back so @Published
    /// is guaranteed to fire and Canvas redraws.
    private func mutateAnnotation(id: UUID, _ mutate: (inout Annotation) -> Void) {
        guard let idx = viewModel.annotations.firstIndex(where: { $0.id == id }) else { return }
        // Explicit pre-notify so SwiftUI-observing views (Canvas, sibling views) always see the change,
        // even if @Published's automatic publish is coalesced.
        viewModel.objectWillChange.send()
        var annotation = viewModel.annotations[idx]
        mutate(&annotation)
        viewModel.annotations[idx] = annotation
    }

    // TEXT: Bold/Italic/Alignment
    private func textFormatSection(binding b: Binding<Annotation>) -> some View {
        let id = b.wrappedValue.id
        let isBold = b.wrappedValue.isBold
        let isItalic = b.wrappedValue.isItalic
        let alignment = b.wrappedValue.textAlignment

        return VStack(alignment: .leading, spacing: 6) {
            sectionLabel("FORMAT")
            HStack(spacing: 4) {
                textFormatButton(systemName: "bold", isOn: isBold) {
                    mutateAnnotation(id: id) { $0.isBold.toggle() }
                }
                textFormatButton(systemName: "italic", isOn: isItalic) {
                    mutateAnnotation(id: id) { $0.isItalic.toggle() }
                }

                Divider().frame(height: 18).padding(.horizontal, 2)

                ForEach(TextAlignment.allCases, id: \.self) { align in
                    textFormatButton(
                        systemName: alignIcon(align),
                        isOn: alignment == align
                    ) {
                        mutateAnnotation(id: id) { $0.textAlignment = align }
                    }
                }
            }
        }
    }

    // TEXT: letter spacing, line height, padding
    private func textTypographySection(binding b: Binding<Annotation>) -> some View {
        let id = b.wrappedValue.id
        let letterSpacing = b.wrappedValue.textLetterSpacing
        let lineHeight = b.wrappedValue.textLineHeight
        let padding = b.wrappedValue.textPadding

        return VStack(alignment: .leading, spacing: 6) {
            sectionLabel("TYPOGRAPHY")

            // Letter spacing (tracking)
            HStack(spacing: Ember.Space.sm) {
                HStack(spacing: 3) {
                    Image(systemName: "character")
                        .font(.system(size: 10))
                    Text("AV")
                        .font(.system(size: 10, design: .serif)).italic()
                }
                .foregroundColor(Ember.secondaryText(scheme))
                .frame(width: 32, alignment: .leading)

                Slider(value: floatBinding(id: id, get: { letterSpacing },
                                           set: { $0.textLetterSpacing = $1 }),
                       in: -2...10)

                Text(String(format: "%.1f", letterSpacing))
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(Ember.secondaryText(scheme))
                    .frame(width: 32, alignment: .trailing)
            }

            // Line height
            HStack(spacing: Ember.Space.sm) {
                Image(systemName: "arrow.up.and.down.text.horizontal")
                    .font(.system(size: 10))
                    .foregroundColor(Ember.secondaryText(scheme))
                    .frame(width: 32, alignment: .leading)

                Slider(value: floatBinding(id: id, get: { lineHeight },
                                           set: { $0.textLineHeight = $1 }),
                       in: 0.8...2.5, step: 0.05)

                Text(String(format: "%.2f", lineHeight))
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(Ember.secondaryText(scheme))
                    .frame(width: 32, alignment: .trailing)
            }

            // Padding
            HStack(spacing: Ember.Space.sm) {
                Image(systemName: "rectangle.inset.filled")
                    .font(.system(size: 10))
                    .foregroundColor(Ember.secondaryText(scheme))
                    .frame(width: 32, alignment: .leading)

                Slider(value: floatBinding(id: id, get: { padding },
                                           set: { $0.textPadding = $1 }),
                       in: 0...32, step: 1)

                Text("\(Int(padding))")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(Ember.secondaryText(scheme))
                    .frame(width: 32, alignment: .trailing)
            }
        }
    }

    /// A CGFloat Binding that routes through mutateAnnotation for guaranteed publishing.
    private func floatBinding(id: UUID, get: @escaping () -> CGFloat, set: @escaping (inout Annotation, CGFloat) -> Void) -> Binding<CGFloat> {
        Binding(
            get: { get() },
            set: { newValue in
                mutateAnnotation(id: id) { set(&$0, newValue) }
            }
        )
    }

    // TEXT: manual box sizing (width/height) and quick "fit-to-width" actions.
    // Useful when users want to pre-size the text area or stretch it for wrapping.
    private func textBoxSection(binding b: Binding<Annotation>) -> some View {
        let id = b.wrappedValue.id
        let currentWidth = b.wrappedValue.rect.size.width
        let currentHeight = b.wrappedValue.rect.size.height

        return VStack(alignment: .leading, spacing: 6) {
            sectionLabel("BOX")

            // Width
            HStack(spacing: Ember.Space.sm) {
                Image(systemName: "arrow.left.and.right")
                    .font(.system(size: 10))
                    .foregroundColor(Ember.secondaryText(scheme))
                    .frame(width: 22, alignment: .leading)

                Slider(value: Binding(
                    get: { currentWidth },
                    set: { newValue in
                        mutateAnnotation(id: id) { $0.rect.size.width = max(40, newValue) }
                    }
                ), in: 40...1200, step: 1)

                Text("\(Int(currentWidth))")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(Ember.secondaryText(scheme))
                    .frame(width: 36, alignment: .trailing)
            }

            // Height
            HStack(spacing: Ember.Space.sm) {
                Image(systemName: "arrow.up.and.down")
                    .font(.system(size: 10))
                    .foregroundColor(Ember.secondaryText(scheme))
                    .frame(width: 22, alignment: .leading)

                Slider(value: Binding(
                    get: { currentHeight },
                    set: { newValue in
                        mutateAnnotation(id: id) { $0.rect.size.height = max(20, newValue) }
                    }
                ), in: 20...800, step: 1)

                Text("\(Int(currentHeight))")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(Ember.secondaryText(scheme))
                    .frame(width: 36, alignment: .trailing)
            }

            // Quick actions
            HStack(spacing: 4) {
                quickBoxChip(label: "S", help: "Small (200×60)") {
                    mutateAnnotation(id: id) {
                        $0.rect.size = CGSize(width: 200, height: 60)
                    }
                }
                quickBoxChip(label: "M", help: "Medium (360×100)") {
                    mutateAnnotation(id: id) {
                        $0.rect.size = CGSize(width: 360, height: 100)
                    }
                }
                quickBoxChip(label: "L", help: "Large (640×160)") {
                    mutateAnnotation(id: id) {
                        $0.rect.size = CGSize(width: 640, height: 160)
                    }
                }
                quickBoxChip(label: "XL", help: "Extra Large (900×220)") {
                    mutateAnnotation(id: id) {
                        $0.rect.size = CGSize(width: 900, height: 220)
                    }
                }
            }
        }
    }

    private func quickBoxChip(label: String, help: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 10, weight: .semibold, design: .rounded))
                .foregroundColor(Ember.primaryText(scheme))
                .frame(maxWidth: .infinity, minHeight: 24)
                .background(
                    RoundedRectangle(cornerRadius: 5)
                        .fill(Ember.Palette.smoke.opacity(0.12))
                )
        }
        .buttonStyle(.plain)
        .help(help)
    }

    // TEXT: background color + toggle
    private func textBackgroundSection(binding b: Binding<Annotation>) -> some View {
        let id = b.wrappedValue.id
        let currentBG = b.wrappedValue.backgroundColor
        let textColor = b.wrappedValue.color

        return VStack(alignment: .leading, spacing: 6) {
            sectionLabel("BACKGROUND")
            HStack(spacing: 8) {
                Toggle("", isOn: Binding(
                    get: { currentBG != nil },
                    set: { isOn in
                        mutateAnnotation(id: id) { anno in
                            if isOn {
                                // Default background: readable contrast against the current text color.
                                // If text is dark-ish, use a light background; else a dark background.
                                anno.backgroundColor = anno.backgroundColor ?? defaultContrastBackground(for: textColor)
                            } else {
                                anno.backgroundColor = nil
                            }
                        }
                    }
                ))
                .labelsHidden()
                .controlSize(.small)

                if let bg = currentBG {
                    ColorPicker("", selection: Binding(
                        get: { bg },
                        set: { newValue in
                            mutateAnnotation(id: id) { $0.backgroundColor = newValue }
                        }
                    ))
                    .labelsHidden()
                    .frame(width: 34, height: 28)

                    Text(hexString(for: bg))
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundColor(Ember.secondaryText(scheme))
                } else {
                    Text("No background")
                        .font(.system(size: 11))
                        .foregroundColor(Ember.tertiaryText(scheme))
                }

                Spacer()
            }

            // Quick background preset chips
            if currentBG != nil {
                HStack(spacing: 4) {
                    ForEach(textBackgroundPresets, id: \.hex) { preset in
                        Button {
                            mutateAnnotation(id: id) { $0.backgroundColor = preset.color }
                        } label: {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(preset.color)
                                .frame(height: 18)
                                .frame(maxWidth: .infinity)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 4)
                                        .strokeBorder(.white.opacity(0.2), lineWidth: 0.5)
                                )
                        }
                        .buttonStyle(.plain)
                        .help(preset.hex)
                    }
                }
            }
        }
    }

    /// Picks a sensible default background for text: light background for dark text,
    /// dark background for light text. Prevents red-on-red / white-on-white.
    private func defaultContrastBackground(for textColor: Color) -> Color {
        let ns = NSColor(textColor).usingColorSpace(.sRGB) ?? NSColor(textColor)
        let luminance = 0.299 * ns.redComponent + 0.587 * ns.greenComponent + 0.114 * ns.blueComponent
        return luminance > 0.5 ? .black.opacity(0.72) : .white.opacity(0.92)
    }

    private var textBackgroundPresets: [(color: Color, hex: String)] {
        [
            (.black.opacity(0.7), "Dark"),
            (.white.opacity(0.9), "Light"),
            (Ember.Palette.amber, "Amber"),
            (Ember.Palette.moss, "Moss"),
            (Ember.Palette.sky, "Sky"),
            (Ember.Palette.rust, "Rust")
        ]
    }

    // ARROW: arrowhead style picker
    private func arrowheadSection(binding b: Binding<Annotation>) -> some View {
        let id = b.wrappedValue.id
        let current = b.wrappedValue.arrowheadStyle
        return VStack(alignment: .leading, spacing: 6) {
            sectionLabel("ARROWHEAD")
            HStack(spacing: 4) {
                ForEach(ArrowheadStyle.allCases) { style in
                    Button {
                        mutateAnnotation(id: id) { $0.arrowheadStyle = style }
                    } label: {
                        Text(arrowheadSymbol(style))
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(current == style ? .white : Ember.secondaryText(scheme))
                            .frame(maxWidth: .infinity, minHeight: 26)
                            .background(
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(current == style
                                          ? AnyShapeStyle(
                                              LinearGradient(colors: [Ember.Palette.amber, Ember.Palette.amberDark],
                                                             startPoint: .top, endPoint: .bottom)
                                            )
                                          : AnyShapeStyle(Ember.Palette.smoke.opacity(0.12)))
                            )
                    }
                    .buttonStyle(.plain)
                    .help(style.rawValue)
                }
            }
        }
    }

    private func arrowheadSymbol(_ s: ArrowheadStyle) -> String {
        switch s {
        case .closedTriangle: return "▶"
        case .openTriangle:   return "▷"
        case .diamond:        return "◆"
        case .circle:         return "●"
        case .none:           return "─"
        }
    }

    // LINE STYLE picker (for arrow, line, rect, ellipse, ruler)
    private func lineStyleSection(binding b: Binding<Annotation>) -> some View {
        let id = b.wrappedValue.id
        let current = b.wrappedValue.lineStyle
        let color = b.wrappedValue.color
        return VStack(alignment: .leading, spacing: 6) {
            sectionLabel("STROKE STYLE")
            HStack(spacing: 4) {
                ForEach(LineStyle.allCases) { style in
                    Button {
                        mutateAnnotation(id: id) { $0.lineStyle = style }
                    } label: {
                        lineStylePreview(style: style, color: color, selected: current == style)
                    }
                    .buttonStyle(.plain)
                    .help(style.rawValue)
                }
            }
        }
    }

    private func lineStylePreview(style: LineStyle, color: Color, selected: Bool) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 6)
                .fill(selected
                      ? AnyShapeStyle(
                          LinearGradient(colors: [Ember.Palette.amber, Ember.Palette.amberDark],
                                         startPoint: .top, endPoint: .bottom)
                        )
                      : AnyShapeStyle(Ember.Palette.smoke.opacity(0.12))
                )

            // Line preview — mirrors the actual canvas renderer (butt cap, scaled pattern)
            // so the picker faithfully shows how the stroke will look.
            GeometryReader { geo in
                Path { path in
                    path.move(to: CGPoint(x: 6, y: geo.size.height / 2))
                    path.addLine(to: CGPoint(x: geo.size.width - 6, y: geo.size.height / 2))
                }
                .stroke(selected ? Color.white : color,
                        style: StrokeStyle(lineWidth: 2,
                                           lineCap: .butt,
                                           dash: style.dashPattern ?? []))
            }
        }
        .frame(maxWidth: .infinity, minHeight: 26)
    }

    // RECTANGLE: corner radius
    private func cornerRadiusSection(binding b: Binding<Annotation>) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            sectionLabel("CORNERS")
            HStack(spacing: Ember.Space.sm) {
                Image(systemName: "rectangle.portrait")
                    .font(.system(size: 12))
                    .foregroundColor(Ember.secondaryText(scheme))
                    .frame(width: 24)

                Slider(value: b.cornerRadius, in: 0...40)

                Text("\(Int(b.wrappedValue.cornerRadius))")
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundColor(Ember.secondaryText(scheme))
                    .frame(width: 24, alignment: .trailing)
            }
        }
    }

    // FILL MODE
    private func fillModeSection(binding b: Binding<Annotation>) -> some View {
        let id = b.wrappedValue.id
        let current = b.wrappedValue.fillMode
        return VStack(alignment: .leading, spacing: 6) {
            sectionLabel("FILL")
            HStack(spacing: 4) {
                ForEach(FillMode.allCases, id: \.self) { mode in
                    Button {
                        mutateAnnotation(id: id) { $0.fillMode = mode }
                    } label: {
                        Image(systemName: mode.icon)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(current == mode ? .white : Ember.secondaryText(scheme))
                            .frame(maxWidth: .infinity, minHeight: 28)
                            .background(
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(current == mode
                                          ? AnyShapeStyle(
                                              LinearGradient(colors: [Ember.Palette.amber, Ember.Palette.amberDark],
                                                             startPoint: .top, endPoint: .bottom)
                                            )
                                          : AnyShapeStyle(Ember.Palette.smoke.opacity(0.12)))
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // SKETCH toggle
    private func sketchToggle(binding b: Binding<Annotation>) -> some View {
        let id = b.wrappedValue.id
        let isOn = b.wrappedValue.sketchStyle
        return HStack {
            Text("Sketch mode")
                .font(.system(size: 12))
                .foregroundColor(Ember.primaryText(scheme))
            Spacer()
            Toggle("", isOn: Binding(
                get: { isOn },
                set: { newValue in
                    mutateAnnotation(id: id) { $0.sketchStyle = newValue }
                }
            ))
            .labelsHidden()
            .controlSize(.small)
        }
    }

    // PEN brush style
    private func penBrushSection(binding b: Binding<Annotation>) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            sectionLabel("BRUSH")
            HStack(spacing: 4) {
                ForEach(BrushStyle.allCases) { style in
                    Button {
                        b.brushStyle.wrappedValue = style
                    } label: {
                        Text(style.displayName)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor((b.wrappedValue.brushStyle ?? .solid) == style ? .white : Ember.secondaryText(scheme))
                            .frame(maxWidth: .infinity, minHeight: 26)
                            .background(
                                RoundedRectangle(cornerRadius: 6)
                                    .fill((b.wrappedValue.brushStyle ?? .solid) == style
                                          ? AnyShapeStyle(
                                              LinearGradient(colors: [Ember.Palette.amber, Ember.Palette.amberDark],
                                                             startPoint: .top, endPoint: .bottom)
                                            )
                                          : AnyShapeStyle(Ember.Palette.smoke.opacity(0.12)))
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // CALLOUT tail direction picker (2x3 grid)
    private func calloutTailSection(binding b: Binding<Annotation>) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            sectionLabel("TAIL DIRECTION")
            VStack(spacing: 4) {
                HStack(spacing: 4) {
                    tailButton(.topLeft, binding: b)
                    tailButton(.topCenter, binding: b)
                    tailButton(.topRight, binding: b)
                }
                HStack(spacing: 4) {
                    tailButton(.bottomLeft, binding: b)
                    tailButton(.bottomCenter, binding: b)
                    tailButton(.bottomRight, binding: b)
                }
            }
        }
    }

    private func tailButton(_ dir: CalloutTailDirection, binding b: Binding<Annotation>) -> some View {
        let active = b.wrappedValue.calloutTailDirection == dir
        return Button {
            b.calloutTailDirection.wrappedValue = dir
        } label: {
            Image(systemName: tailIcon(dir))
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(active ? .white : Ember.secondaryText(scheme))
                .frame(maxWidth: .infinity, minHeight: 24)
                .background(
                    RoundedRectangle(cornerRadius: 5)
                        .fill(active
                              ? AnyShapeStyle(
                                  LinearGradient(colors: [Ember.Palette.amber, Ember.Palette.amberDark],
                                                 startPoint: .top, endPoint: .bottom)
                                )
                              : AnyShapeStyle(Ember.Palette.smoke.opacity(0.12)))
                )
        }
        .buttonStyle(.plain)
    }

    private func tailIcon(_ dir: CalloutTailDirection) -> String {
        switch dir {
        case .topLeft:      return "arrow.up.left"
        case .topCenter:    return "arrow.up"
        case .topRight:     return "arrow.up.right"
        case .bottomLeft:   return "arrow.down.left"
        case .bottomCenter: return "arrow.down"
        case .bottomRight:  return "arrow.down.right"
        }
    }

    // PIN shape picker
    private func pinShapeSection(binding b: Binding<Annotation>) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            sectionLabel("PIN SHAPE")
            HStack(spacing: 4) {
                ForEach(NumberShape.allCases, id: \.self) { shape in
                    Button {
                        b.numberShape.wrappedValue = shape
                    } label: {
                        Image(systemName: pinShapeIcon(shape))
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor((b.wrappedValue.numberShape ?? .circle) == shape ? .white : Ember.secondaryText(scheme))
                            .frame(maxWidth: .infinity, minHeight: 28)
                            .background(
                                RoundedRectangle(cornerRadius: 6)
                                    .fill((b.wrappedValue.numberShape ?? .circle) == shape
                                          ? AnyShapeStyle(
                                              LinearGradient(colors: [Ember.Palette.amber, Ember.Palette.amberDark],
                                                             startPoint: .top, endPoint: .bottom)
                                            )
                                          : AnyShapeStyle(Ember.Palette.smoke.opacity(0.12)))
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func pinShapeIcon(_ s: NumberShape) -> String {
        switch s {
        case .circle:        return "circle.fill"
        case .square:        return "square.fill"
        case .roundedSquare: return "square.inset.filled"
        }
    }

    // SPOTLIGHT shape
    private func spotlightShapeSection(binding b: Binding<Annotation>) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            sectionLabel("SPOTLIGHT SHAPE")
            HStack(spacing: 4) {
                ForEach(SpotlightShape.allCases, id: \.self) { shape in
                    Button {
                        b.spotlightShape.wrappedValue = shape
                    } label: {
                        Image(systemName: shape == .ellipse ? "circle" : "square")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor((b.wrappedValue.spotlightShape ?? .ellipse) == shape ? .white : Ember.secondaryText(scheme))
                            .frame(maxWidth: .infinity, minHeight: 28)
                            .background(
                                RoundedRectangle(cornerRadius: 6)
                                    .fill((b.wrappedValue.spotlightShape ?? .ellipse) == shape
                                          ? AnyShapeStyle(
                                              LinearGradient(colors: [Ember.Palette.amber, Ember.Palette.amberDark],
                                                             startPoint: .top, endPoint: .bottom)
                                            )
                                          : AnyShapeStyle(Ember.Palette.smoke.opacity(0.12)))
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // BLUR mode + radius
    private func blurSection(binding b: Binding<Annotation>) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            sectionLabel("MODE")
            Picker("", selection: b.blurMode) {
                ForEach(BlurMode.allCases) { mode in
                    Text(mode.rawValue).tag(mode)
                }
            }
            .labelsHidden()

            sectionLabel("STRENGTH")
            HStack(spacing: Ember.Space.sm) {
                Image(systemName: "aqi.medium")
                    .font(.system(size: 12))
                    .foregroundColor(Ember.secondaryText(scheme))
                    .frame(width: 24)
                Slider(value: b.blurRadius, in: 1...60)
                Text("\(Int(b.wrappedValue.blurRadius))")
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundColor(Ember.secondaryText(scheme))
                    .frame(width: 24, alignment: .trailing)
            }
        }
    }

    // PIXELATE size (uses blurRadius as pixel size)
    private func pixelateSection(binding b: Binding<Annotation>) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            sectionLabel("PIXEL SIZE")
            HStack(spacing: Ember.Space.sm) {
                Image(systemName: "square.grid.3x3.fill")
                    .font(.system(size: 12))
                    .foregroundColor(Ember.secondaryText(scheme))
                    .frame(width: 24)
                Slider(value: b.blurRadius, in: 5...40)
                Text("\(Int(b.wrappedValue.blurRadius))")
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundColor(Ember.secondaryText(scheme))
                    .frame(width: 24, alignment: .trailing)
            }
        }
    }

    // SHADOW
    private func shadowSection(binding b: Binding<Annotation>) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("SHADOW")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(Ember.tertiaryText(scheme))
                    .tracking(0.8)
                Spacer()
                Toggle("", isOn: Binding(
                    get: { b.wrappedValue.shadowRadius > 0 },
                    set: { on in b.shadowRadius.wrappedValue = on ? 6 : 0 }
                ))
                .labelsHidden()
                .controlSize(.small)
            }

            if b.wrappedValue.shadowRadius > 0 {
                HStack(spacing: Ember.Space.sm) {
                    ColorPicker("", selection: b.shadowColor)
                        .labelsHidden()
                        .frame(width: 34, height: 22)
                    Slider(value: b.shadowRadius, in: 0...30)
                    Text("\(Int(b.wrappedValue.shadowRadius))")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundColor(Ember.secondaryText(scheme))
                        .frame(width: 24, alignment: .trailing)
                }
            }
        }
    }

    // Binding into the live annotation so controls mutate it in place.
    // Assigns the whole array back so @Published fires reliably and Canvas redraws.
    private func annotationBinding(for id: UUID) -> Binding<Annotation> {
        Binding(
            get: {
                self.viewModel.annotations.first(where: { $0.id == id })
                    ?? Annotation(rect: .zero, color: .clear, tool: .select)
            },
            set: { newValue in
                guard let idx = self.viewModel.annotations.firstIndex(where: { $0.id == id }) else { return }
                var updated = self.viewModel.annotations
                updated[idx] = newValue
                self.viewModel.annotations = updated
            }
        )
    }

    private func annotationUsesLineWidth(_ tool: DrawingTool) -> Bool {
        switch tool {
        case .arrow, .rectangle, .ellipse, .line, .callout, .pen,
             .highlighter, .text, .pin, .ruler:
            return true
        default:
            return false
        }
    }

    private func annotationUsesOpacity(_ tool: DrawingTool) -> Bool {
        switch tool {
        case .arrow, .rectangle, .ellipse, .line, .callout, .pen,
             .highlighter, .text:
            return true
        default:
            return false
        }
    }

    private func hexString(for color: Color) -> String {
        let ns = NSColor(color).usingColorSpace(.sRGB) ?? NSColor(color)
        let r = Int((ns.redComponent * 255).rounded())
        let g = Int((ns.greenComponent * 255).rounded())
        let b = Int((ns.blueComponent * 255).rounded())
        return String(format: "#%02X%02X%02X", r, g, b)
    }

    private func numberField(label: String, value: CGFloat) -> some View {
        HStack(spacing: 4) {
            Text(label)
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(Ember.tertiaryText(scheme))
                .frame(width: 14, alignment: .leading)
            Text("\(Int(value))")
                .font(.system(size: 11, design: .monospaced))
                .foregroundColor(Ember.primaryText(scheme))
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(
            RoundedRectangle(cornerRadius: 5)
                .fill(Ember.Palette.smoke.opacity(0.1))
        )
    }

    private func smallChipButton(systemName: String, text: String, destructive: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: systemName)
                    .font(.system(size: 10, weight: .medium))
                Text(text)
                    .font(.system(size: 11, weight: .medium))
            }
            .foregroundColor(destructive ? Ember.Palette.rust : Ember.primaryText(scheme))
            .frame(maxWidth: .infinity, minHeight: 26)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill((destructive ? Ember.Palette.rust : Ember.Palette.smoke).opacity(0.12))
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: Helpers

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 10, weight: .semibold))
            .foregroundColor(Ember.tertiaryText(scheme))
            .tracking(0.8)
            .padding(.top, 2)
    }
}
