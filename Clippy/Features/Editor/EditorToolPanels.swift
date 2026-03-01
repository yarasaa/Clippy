//
//  EditorToolPanels.swift
//  Clippy
//

import SwiftUI

// MARK: - Shape Picker

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

// MARK: - Emoji Picker

struct EmojiPickerView: View {
    @Binding var selectedEmoji: String
    @Binding var isPresented: Bool
    @State private var selectedCategory: EmojiCategory = .symbols

    enum EmojiCategory: String, CaseIterable {
        case symbols = "Symbols"
        case smileys = "Smileys"
        case hands = "Hands"
        case arrows = "Arrows"
        case nature = "Nature"

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
            Text("Choose Emoji")
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

// MARK: - Line Width Picker

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

// MARK: - Tool Control Panel

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
