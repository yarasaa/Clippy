//
//  EditorEffectsPanel.swift
//  Clippy
//

import SwiftUI
import UniformTypeIdentifiers

struct EffectsInspectorView: View {
    @Binding var isPresented: Bool
    @Binding var backdropPadding: CGFloat
    @Binding var shadowRadius: CGFloat
    @Binding var screenshotCornerRadius: CGFloat
    @Binding var backdropCornerRadius: CGFloat
    @Binding var backdropFill: AnyShapeStyle
    @Binding var backdropModel: BackdropFillModel
    @Binding var borderConfig: ImageBorderConfig

    @EnvironmentObject var settings: SettingsManager
    @State private var selectedTab: Int = 0
    @State private var solidColor: Color = .white
    // Linear gradient state
    @State private var gradientStartColor: Color = .blue
    @State private var gradientEndColor: Color = .cyan
    @State private var gradientStartPoint: UnitPoint = .topLeading
    // Radial gradient state
    @State private var radialCenterColor: Color = .blue
    @State private var radialEdgeColor: Color = .cyan
    @State private var radialCenterPoint: UnitPoint = .center
    @State private var radialStartRadius: CGFloat = 0
    @State private var radialEndRadius: CGFloat = 400
    // Pattern state
    @State private var patternType: PatternType = .dots
    @State private var patternColor1: Color = .blue
    @State private var patternColor2: Color = .white
    @State private var patternSpacing: CGFloat = 20
    // Image state
    @State private var backdropImageData: Data?
    @State private var imageFillMode: ImageFillMode = .fill

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

            // MARK: Backdrop Type Tabs
            Picker(L("Color Type", settings: settings), selection: $selectedTab) {
                Text(L("Solid", settings: settings)).tag(0)
                Text(L("Linear", settings: settings)).tag(1)
                Text(L("Radial", settings: settings)).tag(2)
                Text(L("Pattern", settings: settings)).tag(3)
                Text(L("Image", settings: settings)).tag(4)
            }
            .pickerStyle(.segmented)
            .labelsHidden()

            Group {
                if selectedTab == 0 {
                    solidTabContent
                } else if selectedTab == 1 {
                    linearGradientTabContent
                } else if selectedTab == 2 {
                    radialGradientTabContent
                } else if selectedTab == 3 {
                    patternTabContent
                } else {
                    imageTabContent
                }
            }
            .frame(maxHeight: .infinity)

            Divider()

            // MARK: Border Config
            borderSection

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
                    borderConfig = ImageBorderConfig()
                }
                Spacer()
                Button(L("Ok", settings: settings)) { isPresented = false }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding()
        }
        .frame(width: 300, height: 600)
        .onAppear(perform: setupInitialStateFromFill)
    }

    // MARK: - Tab Contents

    private var solidTabContent: some View {
        VStack(alignment: .leading, spacing: 8) {
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
        }
    }

    private var linearGradientTabContent: some View {
        VStack(alignment: .leading) {
            Text(L("Presets", settings: settings)).font(.caption)
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 24), spacing: 8)], spacing: 8) {
                ForEach(presetGradients, id: \.self) { colors in
                    Button {
                        gradientStartColor = colors.first ?? .white
                        gradientEndColor = colors.count > 1 ? colors[1] : .black
                        updateLinearGradient()
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
                .onChange(of: gradientStartColor) { _ in updateLinearGradient() }
                .onChange(of: gradientEndColor) { _ in updateLinearGradient() }
                .onChange(of: gradientStartPoint) { _ in updateLinearGradient() }
        }
    }

    private var radialGradientTabContent: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                ColorPicker(L("Center", settings: settings), selection: $radialCenterColor)
                ColorPicker(L("Edge", settings: settings), selection: $radialEdgeColor)
                Spacer()
            }

            Text(L("Center Point", settings: settings)).font(.caption)
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 3), spacing: 4) {
                ForEach(gradientDirections) { dir in
                    Button {
                        radialCenterPoint = dir.point
                        updateRadialGradient()
                    } label: {
                        Text(L(dir.name, settings: settings))
                            .font(.system(size: 9))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 4)
                            .background(radialCenterPoint == dir.point ? Color.accentColor.opacity(0.3) : Color.secondary.opacity(0.1))
                            .cornerRadius(4)
                    }
                    .buttonStyle(.plain)
                }
            }

            HStack { Text(L("End Radius", settings: settings)).font(.caption); Spacer(); Text("\(Int(radialEndRadius))").font(.caption2) }
            Slider(value: $radialEndRadius, in: 50...800)
                .onChange(of: radialEndRadius) { _ in updateRadialGradient() }

            // Preview
            RoundedRectangle(cornerRadius: 6)
                .fill(RadialGradient(gradient: Gradient(colors: [radialCenterColor, radialEdgeColor]),
                                     center: radialCenterPoint,
                                     startRadius: radialStartRadius,
                                     endRadius: radialEndRadius / 4))
                .frame(height: 40)
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.primary.opacity(0.2)))
                .onChange(of: radialCenterColor) { _ in updateRadialGradient() }
                .onChange(of: radialEdgeColor) { _ in updateRadialGradient() }
                .onChange(of: radialCenterPoint) { _ in updateRadialGradient() }
        }
    }

    private var patternTabContent: some View {
        VStack(alignment: .leading, spacing: 8) {
            Picker(L("Pattern", settings: settings), selection: $patternType) {
                ForEach(PatternType.allCases) { type in
                    Text(type.rawValue).tag(type)
                }
            }
            .pickerStyle(.segmented)

            HStack {
                ColorPicker(L("Color 1", settings: settings), selection: $patternColor1)
                ColorPicker(L("Color 2", settings: settings), selection: $patternColor2)
                Spacer()
            }

            HStack { Text(L("Spacing", settings: settings)).font(.caption); Spacer(); Text("\(Int(patternSpacing))").font(.caption2) }
            Slider(value: $patternSpacing, in: 5...50)

            // Preview
            RoundedRectangle(cornerRadius: 6)
                .fill(Color.clear)
                .frame(height: 40)
                .overlay(
                    patternPreview
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                )
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.primary.opacity(0.2)))
                .onChange(of: patternType) { _ in updatePattern() }
                .onChange(of: patternColor1) { _ in updatePattern() }
                .onChange(of: patternColor2) { _ in updatePattern() }
                .onChange(of: patternSpacing) { _ in updatePattern() }
        }
    }

    @ViewBuilder
    private var patternPreview: some View {
        Canvas { context, size in
            let bg = patternColor2
            context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(bg))
            let fg = patternColor1
            let sp = patternSpacing

            switch patternType {
            case .dots:
                var y: CGFloat = sp / 2
                while y < size.height {
                    var x: CGFloat = sp / 2
                    while x < size.width {
                        let rect = CGRect(x: x - 2, y: y - 2, width: 4, height: 4)
                        context.fill(Path(ellipseIn: rect), with: .color(fg))
                        x += sp
                    }
                    y += sp
                }
            case .grid:
                var x: CGFloat = 0
                while x <= size.width {
                    context.stroke(Path { p in p.move(to: CGPoint(x: x, y: 0)); p.addLine(to: CGPoint(x: x, y: size.height)) }, with: .color(fg), lineWidth: 0.5)
                    x += sp
                }
                var y2: CGFloat = 0
                while y2 <= size.height {
                    context.stroke(Path { p in p.move(to: CGPoint(x: 0, y: y2)); p.addLine(to: CGPoint(x: size.width, y: y2)) }, with: .color(fg), lineWidth: 0.5)
                    y2 += sp
                }
            case .stripes:
                var x2: CGFloat = 0
                while x2 <= size.width + size.height {
                    context.stroke(Path { p in p.move(to: CGPoint(x: x2, y: 0)); p.addLine(to: CGPoint(x: x2 - size.height, y: size.height)) }, with: .color(fg), lineWidth: sp / 3)
                    x2 += sp
                }
            case .checkerboard:
                var row = 0
                var y3: CGFloat = 0
                while y3 < size.height {
                    var col = 0
                    var x3: CGFloat = 0
                    while x3 < size.width {
                        if (row + col).isMultiple(of: 2) {
                            context.fill(Path(CGRect(x: x3, y: y3, width: sp, height: sp)), with: .color(fg))
                        }
                        x3 += sp
                        col += 1
                    }
                    y3 += sp
                    row += 1
                }
            }
        }
    }

    private var imageTabContent: some View {
        VStack(spacing: 8) {
            if let data = backdropImageData, let nsImg = NSImage(data: data) {
                Image(nsImage: nsImg)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxHeight: 80)
                    .cornerRadius(6)
                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.primary.opacity(0.2)))
            } else {
                Image(systemName: "photo.on.rectangle.angled")
                    .font(.largeTitle).foregroundColor(.secondary)
                Text(L("Select an image for the backdrop", settings: settings)).font(.caption).foregroundColor(.secondary)
            }

            Picker(L("Fill Mode", settings: settings), selection: $imageFillMode) {
                ForEach(ImageFillMode.allCases) { mode in
                    Text(mode.rawValue).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .onChange(of: imageFillMode) { _ in updateImageBackdrop() }

            Button(L("Browse...", settings: settings)) {
                let panel = NSOpenPanel()
                panel.allowedContentTypes = [.image]
                panel.allowsMultipleSelection = false
                panel.canChooseDirectories = false
                if panel.runModal() == .OK, let url = panel.url {
                    if let data = try? Data(contentsOf: url) {
                        backdropImageData = data
                        updateImageBackdrop()
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, minHeight: 100)
    }

    // MARK: - Border Section

    private var borderSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(L("Border", settings: settings)).font(.caption).fontWeight(.medium)

            Picker(L("Style", settings: settings), selection: $borderConfig.style) {
                ForEach(BorderStyle.allCases) { style in
                    Text(style.rawValue).tag(style)
                }
            }
            .pickerStyle(.segmented)

            if borderConfig.style != .none {
                HStack {
                    ColorPicker(L("Color", settings: settings), selection: $borderConfig.color)
                    Spacer()
                    Text("\(Int(borderConfig.width))px").font(.caption2)
                }
                Slider(value: $borderConfig.width, in: 1...20)
            }
        }
    }

    // MARK: - Update Methods

    private func updateLinearGradient() {
        let gradient = LinearGradient(gradient: Gradient(colors: [gradientStartColor, gradientEndColor]), startPoint: gradientStartPoint, endPoint: gradientEndPoint)
        backdropFill = AnyShapeStyle(gradient)
        backdropModel = .linearGradient(start: gradientStartColor, end: gradientEndColor, startPoint: gradientStartPoint, endPoint: gradientEndPoint)
    }

    private func updateRadialGradient() {
        let gradient = RadialGradient(gradient: Gradient(colors: [radialCenterColor, radialEdgeColor]),
                                      center: radialCenterPoint,
                                      startRadius: radialStartRadius,
                                      endRadius: radialEndRadius)
        backdropFill = AnyShapeStyle(gradient)
        backdropModel = .radialGradient(center: radialCenterColor, edge: radialEdgeColor, centerPoint: radialCenterPoint, startRadius: radialStartRadius, endRadius: radialEndRadius)
    }

    private func updatePattern() {
        backdropModel = .pattern(patternType, patternColor1, patternColor2, patternSpacing)
        let tileImage = createPatternTileImage(type: patternType, color1: patternColor1, color2: patternColor2, spacing: patternSpacing)
        backdropFill = AnyShapeStyle(ImagePaint(image: Image(nsImage: tileImage)))
    }

    private func updateImageBackdrop() {
        guard let data = backdropImageData else { return }
        backdropModel = .image(data, imageFillMode)
        if let nsImage = NSImage(data: data) {
            backdropFill = AnyShapeStyle(ImagePaint(image: Image(nsImage: nsImage)))
        } else {
            backdropFill = AnyShapeStyle(Color.gray.opacity(0.3))
        }
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
        case .radialGradient(let center, let edge, let centerPoint, let startR, let endR):
            radialCenterColor = center
            radialEdgeColor = edge
            radialCenterPoint = centerPoint
            radialStartRadius = startR
            radialEndRadius = endR
            selectedTab = 2
        case .pattern(let type, let c1, let c2, let spacing):
            patternType = type
            patternColor1 = c1
            patternColor2 = c2
            patternSpacing = spacing
            selectedTab = 3
        case .image(let data, let mode):
            backdropImageData = data
            imageFillMode = mode
            selectedTab = 4
        }
    }
}

