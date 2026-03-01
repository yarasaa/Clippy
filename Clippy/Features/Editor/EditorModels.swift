//
//  EditorModels.swift
//  Clippy
//

import SwiftUI

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
    case select, move, arrow, rectangle, ellipse, line, text, pin, pixelate, eraser, highlighter, spotlight, emoji, pen, crop, blur, eyedropper, callout, magnifier, ruler

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
        case .crop: return "crop"
        case .blur: return "aqi.medium"
        case .eyedropper: return "eyedropper.halffull"
        case .callout: return "text.bubble"
        case .magnifier: return "magnifyingglass.circle"
        case .ruler: return "ruler"
        }
    }

    var id: String {
        self.rawValue
    }

    var isShape: Bool {
        switch self {
        case .rectangle, .ellipse, .line, .callout:
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
        case .crop: return "Crop"
        case .blur: return "Blur"
        case .eyedropper: return "Eyedropper"
        case .callout: return "Callout"
        case .magnifier: return "Magnifier"
        case .ruler: return "Ruler"
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
        case .crop: key = "tool.crop"
        case .blur: key = "tool.blur"
        case .eyedropper: key = "tool.eyedropper"
        case .callout: key = "tool.callout"
        case .magnifier: key = "tool.magnifier"
        case .ruler: key = "tool.ruler"
        }

        let localized = NSLocalizedString(key, tableName: nil, bundle: .main, value: displayName, comment: "")
        return localized
    }
}

enum CropAspectRatio: String, CaseIterable, Identifiable {
    case free = "Free"
    case ratio1x1 = "1:1"
    case ratio4x3 = "4:3"
    case ratio16x9 = "16:9"
    case ratio3x2 = "3:2"

    var id: String { rawValue }

    var ratio: CGFloat? {
        switch self {
        case .free: return nil
        case .ratio1x1: return 1.0
        case .ratio4x3: return 4.0 / 3.0
        case .ratio16x9: return 16.0 / 9.0
        case .ratio3x2: return 3.0 / 2.0
        }
    }
}

enum BrushStyle: String, CaseIterable, Identifiable {
    case solid = "Solid"
    case dashed = "Dashed"
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

enum TextAlignment: String, CaseIterable {
    case left = "Left"
    case center = "Center"
    case right = "Right"

    var nsTextAlignment: NSTextAlignment {
        switch self {
        case .left: return .left
        case .center: return .center
        case .right: return .right
        }
    }

    var icon: String {
        switch self {
        case .left: return "text.alignleft"
        case .center: return "text.aligncenter"
        case .right: return "text.alignright"
        }
    }
}

enum CalloutTailDirection: String, CaseIterable {
    case bottomLeft = "Bottom Left"
    case bottomCenter = "Bottom Center"
    case bottomRight = "Bottom Right"
    case topLeft = "Top Left"
    case topCenter = "Top Center"
    case topRight = "Top Right"
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
    var blurRadius: CGFloat = 10
    var opacity: CGFloat = 1.0
    var dashedStroke: Bool = false
    var fontName: String?
    var isBold: Bool = false
    var isItalic: Bool = false
    var textAlignment: TextAlignment = .left
    var calloutTailDirection: CalloutTailDirection = .bottomLeft
    var controlPoint: CGPoint?
    var sketchStyle: Bool = false
    var magnification: CGFloat = 2.0
    var blurMode: BlurMode = .full
    // Arrow styles
    var arrowheadStyle: ArrowheadStyle = .closedTriangle
    // Line styles (replaces dashedStroke for richer options)
    var lineStyle: LineStyle = .solid
    // Gradient fill (shapes)
    var gradientFill: Bool = false
    var gradientStartColor: Color?
    var gradientEndColor: Color?
    // Per-annotation shadow
    var shadowRadius: CGFloat = 0
    var shadowColor: Color = .black
    var shadowOffset: CGSize = CGSize(width: 2, height: 2)

    func duplicating(offset: CGSize = CGSize(width: 10, height: 10)) -> Annotation {
        var dup = Annotation(
            rect: rect.offsetBy(dx: offset.width, dy: offset.height),
            color: color,
            lineWidth: lineWidth,
            tool: tool,
            text: text
        )
        dup.number = number
        dup.numberShape = numberShape
        dup.startPoint = startPoint.map { CGPoint(x: $0.x + offset.width, y: $0.y + offset.height) }
        dup.endPoint = endPoint.map { CGPoint(x: $0.x + offset.width, y: $0.y + offset.height) }
        dup.cornerRadius = cornerRadius
        dup.fillMode = fillMode
        dup.spotlightShape = spotlightShape
        dup.emoji = emoji
        dup.path = path?.map { CGPoint(x: $0.x + offset.width, y: $0.y + offset.height) }
        dup.brushStyle = brushStyle
        dup.backgroundColor = backgroundColor
        dup.blurRadius = blurRadius
        dup.opacity = opacity
        dup.dashedStroke = dashedStroke
        dup.lineStyle = lineStyle
        dup.fontName = fontName
        dup.isBold = isBold
        dup.isItalic = isItalic
        dup.textAlignment = textAlignment
        dup.calloutTailDirection = calloutTailDirection
        dup.controlPoint = controlPoint.map { CGPoint(x: $0.x + offset.width, y: $0.y + offset.height) }
        dup.sketchStyle = sketchStyle
        dup.magnification = magnification
        dup.blurMode = blurMode
        dup.arrowheadStyle = arrowheadStyle
        dup.gradientFill = gradientFill
        dup.gradientStartColor = gradientStartColor
        dup.gradientEndColor = gradientEndColor
        dup.shadowRadius = shadowRadius
        dup.shadowColor = shadowColor
        dup.shadowOffset = shadowOffset
        return dup
    }
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

// MARK: - Arrow Styles

enum ArrowheadStyle: String, CaseIterable, Identifiable {
    case closedTriangle = "Closed Triangle"
    case openTriangle = "Open Triangle"
    case diamond = "Diamond"
    case circle = "Circle"
    case none = "None"
    var id: String { rawValue }
}

// MARK: - Line Styles

enum LineStyle: String, CaseIterable, Identifiable {
    case solid = "Solid"
    case dashed = "Dashed"
    case dotted = "Dotted"
    case dashDot = "Dash-Dot"
    case dashDotDot = "Dash-Dot-Dot"
    var id: String { rawValue }

    var dashPattern: [CGFloat]? {
        switch self {
        case .solid: return nil
        case .dashed: return [8, 4]
        case .dotted: return [2, 4]
        case .dashDot: return [8, 4, 2, 4]
        case .dashDotDot: return [8, 4, 2, 4, 2, 4]
        }
    }
}

// MARK: - Backdrop Models

enum ImageFillMode: String, CaseIterable, Identifiable {
    case stretch = "Stretch"
    case fit = "Fit"
    case fill = "Fill"
    case tile = "Tile"
    var id: String { rawValue }
}

enum PatternType: String, CaseIterable, Identifiable {
    case dots = "Dots"
    case grid = "Grid"
    case stripes = "Stripes"
    case checkerboard = "Checkerboard"
    var id: String { rawValue }
}

enum BackdropFillModel: Equatable {
    case solid(Color)
    case linearGradient(start: Color, end: Color, startPoint: UnitPoint, endPoint: UnitPoint)
    case radialGradient(center: Color, edge: Color, centerPoint: UnitPoint, startRadius: CGFloat, endRadius: CGFloat)
    case pattern(PatternType, Color, Color, CGFloat)
    case image(Data, ImageFillMode)
}

// MARK: - Border

enum BorderStyle: String, CaseIterable, Identifiable {
    case none = "None"
    case solid = "Solid"
    case dashed = "Dashed"
    case double = "Double"
    var id: String { rawValue }
}

struct ImageBorderConfig: Equatable {
    var style: BorderStyle = .none
    var color: Color = .black
    var width: CGFloat = 2
}

// MARK: - Watermark

enum WatermarkPosition: String, CaseIterable, Identifiable {
    case center = "Center"
    case topLeft = "Top Left"
    case topRight = "Top Right"
    case bottomLeft = "Bottom Left"
    case bottomRight = "Bottom Right"
    case tiled = "Tiled"
    case diagonal = "Diagonal"
    var id: String { rawValue }
}

struct WatermarkConfig {
    var text: String = ""
    var fontSize: CGFloat = 24
    var color: Color = .white
    var opacity: CGFloat = 0.3
    var position: WatermarkPosition = .bottomRight
    var rotation: CGFloat = 0
}

// MARK: - Grid Overlay

struct NamedUnitPoint: Identifiable, Hashable {
    let id = UUID()
    let name: String
    let point: UnitPoint
}


enum BlurMode: String, CaseIterable, Identifiable {
    case full = "Full"
    case textOnly = "Text Only"
    case erase = "Erase"
    case textErase = "Text Erase"

    var id: String { rawValue }
}

enum ExportFormat: String, CaseIterable, Identifiable {
    case png = "PNG"
    case jpeg = "JPEG"
    case tiff = "TIFF"

    var id: String { rawValue }

    var fileExtension: String {
        switch self {
        case .png: return "png"
        case .jpeg: return "jpg"
        case .tiff: return "tiff"
        }
    }
}
