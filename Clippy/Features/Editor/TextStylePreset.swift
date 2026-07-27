//
//  TextStylePreset.swift
//  Clippy
//
//  Named, reusable text styles.
//
//  The editor already remembers the last style you used within a session,
//  which covers "annotate five things the same way". What it couldn't do
//  is carry a look across sessions — the "my callout style" that Snagit
//  users reach for constantly. A preset is just the styling half of an
//  annotation, saved under a name.
//

import SwiftUI
// Explicit: MemberImportVisibility means SwiftUI's re-export isn't enough
// for @Published / ObservableObject in this project.
import Combine

struct TextStylePreset: Codable, Identifiable, Equatable {
    var id: UUID = UUID()
    var name: String

    // SwiftUI's Color isn't Codable, so colours are stored as sRGB
    // components. Alpha is kept because a translucent plate is a
    // legitimate style choice.
    var colorComponents: [Double]
    var strokeColorComponents: [Double]
    var backgroundComponents: [Double]?

    var fontName: String?
    var lineWidth: CGFloat
    var isBold: Bool
    var isItalic: Bool
    var textAlignment: String
    var verticalAlignment: String
    var strokeWidth: CGFloat
    var letterSpacing: CGFloat
    var lineHeight: CGFloat
    var shadowRadius: CGFloat

    // MARK: Conversion

    init(name: String, from annotation: Annotation) {
        self.name = name
        self.colorComponents = Self.components(annotation.color)
        self.strokeColorComponents = Self.components(annotation.textStrokeColor)
        self.backgroundComponents = annotation.backgroundColor.map(Self.components)
        self.fontName = annotation.fontName
        self.lineWidth = annotation.lineWidth
        self.isBold = annotation.isBold
        self.isItalic = annotation.isItalic
        self.textAlignment = annotation.textAlignment.rawValue
        self.verticalAlignment = annotation.textVerticalAlignment.rawValue
        self.strokeWidth = annotation.textStrokeWidth
        self.letterSpacing = annotation.textLetterSpacing
        self.lineHeight = annotation.textLineHeight
        self.shadowRadius = annotation.shadowRadius
    }

    /// Applies the styling to an annotation, leaving its content and
    /// geometry (text, rect, id) untouched.
    func apply(to annotation: inout Annotation) {
        annotation.color = Self.color(from: colorComponents)
        annotation.textStrokeColor = Self.color(from: strokeColorComponents)
        annotation.backgroundColor = backgroundComponents.map(Self.color)
        annotation.fontName = fontName
        annotation.lineWidth = lineWidth
        annotation.isBold = isBold
        annotation.isItalic = isItalic
        annotation.textAlignment = TextAlignment(rawValue: textAlignment) ?? .left
        annotation.textVerticalAlignment = VerticalTextAlignment(rawValue: verticalAlignment) ?? .top
        annotation.textStrokeWidth = strokeWidth
        annotation.textLetterSpacing = letterSpacing
        annotation.textLineHeight = lineHeight
        annotation.shadowRadius = shadowRadius
    }

    private static func components(_ color: Color) -> [Double] {
        guard let srgb = NSColor(color).usingColorSpace(.sRGB) else { return [1, 1, 1, 1] }
        return [Double(srgb.redComponent), Double(srgb.greenComponent),
                Double(srgb.blueComponent), Double(srgb.alphaComponent)]
    }

    private static func color(from components: [Double]) -> Color {
        guard components.count == 4 else { return .white }
        return Color(.sRGB, red: components[0], green: components[1],
                     blue: components[2], opacity: components[3])
    }
}

/// Persists the user's saved text styles.
@MainActor
final class TextStylePresetStore: ObservableObject {
    static let shared = TextStylePresetStore()

    @Published private(set) var presets: [TextStylePreset] = []

    private let storageKey = "editorTextStylePresets.v1"
    /// A generous cap — this is a personal style shelf, not a library.
    private let maxPresets = 12

    private init() { load() }

    func save(_ annotation: Annotation, named name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let finalName = trimmed.isEmpty ? "Style \(presets.count + 1)" : trimmed

        var preset = TextStylePreset(name: finalName, from: annotation)
        // Re-saving under an existing name replaces it rather than
        // stacking near-identical entries.
        if let existing = presets.firstIndex(where: { $0.name.caseInsensitiveCompare(finalName) == .orderedSame }) {
            preset.id = presets[existing].id
            presets[existing] = preset
        } else {
            presets.append(preset)
            if presets.count > maxPresets { presets.removeFirst() }
        }
        persist()
    }

    func delete(_ preset: TextStylePreset) {
        presets.removeAll { $0.id == preset.id }
        persist()
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let decoded = try? JSONDecoder().decode([TextStylePreset].self, from: data) else { return }
        presets = decoded
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(presets) else { return }
        UserDefaults.standard.set(data, forKey: storageKey)
    }
}
