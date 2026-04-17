import SwiftUI

// MARK: - Ember Design System
// "Your clipboard has memory."

enum Ember {

    // MARK: Colors

    enum Palette {
        // Primary — Amber/Copper (paperclip gold)
        static let amber        = Color(red: 232/255, green: 131/255, blue: 58/255)   // #E8833A
        static let amberDark    = Color(red: 197/255, green: 101/255, blue: 33/255)   // #C56521
        static let amberGlow    = Color(red: 255/255, green: 181/255, blue: 113/255)  // #FFB571
        static let amberSoft    = Color(red: 232/255, green: 131/255, blue: 58/255).opacity(0.12)

        // Surfaces
        static let ink          = Color(red: 15/255, green: 23/255, blue: 41/255)     // #0F1729
        static let inkSoft      = Color(red: 22/255, green: 32/255, blue: 54/255)     // dark card bg
        static let paper        = Color(red: 250/255, green: 247/255, blue: 242/255)  // #FAF7F2
        static let paperSoft    = Color(red: 253/255, green: 251/255, blue: 247/255)  // light card bg

        // Text
        static let graphite     = Color(red: 42/255, green: 46/255, blue: 55/255)     // #2A2E37
        static let smoke        = Color(red: 107/255, green: 114/255, blue: 128/255)  // #6B7280
        static let whisper      = Color(red: 156/255, green: 163/255, blue: 175/255)  // subtle

        // Semantic
        static let moss         = Color(red: 74/255, green: 157/255, blue: 127/255)   // success
        static let rust         = Color(red: 200/255, green: 75/255, blue: 49/255)    // destructive
        static let sky          = Color(red: 79/255, green: 147/255, blue: 214/255)   // info
    }

    // MARK: Adaptive Colors

    static func cardBackground(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Palette.inkSoft : Palette.paperSoft
    }

    static func surface(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Palette.ink : Palette.paper
    }

    static func primaryText(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? .white.opacity(0.92) : Palette.graphite
    }

    static func secondaryText(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? .white.opacity(0.55) : Palette.smoke
    }

    static func tertiaryText(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? .white.opacity(0.32) : Palette.whisper
    }

    // MARK: Spacing (4pt grid)

    enum Space {
        static let xs: CGFloat  = 4
        static let sm: CGFloat  = 8
        static let md: CGFloat  = 12
        static let lg: CGFloat  = 16
        static let xl: CGFloat  = 24
        static let xxl: CGFloat = 32
    }

    // MARK: Radius

    enum Radius {
        static let sm: CGFloat = 6
        static let md: CGFloat = 10
        static let lg: CGFloat = 14
        static let xl: CGFloat = 20
        static let round: CGFloat = 999
    }

    // MARK: Typography

    enum Font {
        static let display  = SwiftUI.Font.system(size: 28, weight: .bold, design: .rounded)
        static let title    = SwiftUI.Font.system(size: 17, weight: .semibold, design: .rounded)
        static let body     = SwiftUI.Font.system(size: 13, weight: .regular, design: .default)
        static let code     = SwiftUI.Font.system(size: 12, weight: .regular, design: .monospaced)
        static let caption  = SwiftUI.Font.system(size: 11, weight: .regular, design: .default)
        static let meta     = SwiftUI.Font.system(size: 11, weight: .regular, design: .serif).italic()
        static let kbd      = SwiftUI.Font.system(size: 10, weight: .medium, design: .monospaced)
    }

    // MARK: Animation

    enum Motion {
        static let snap    = Animation.spring(response: 0.25, dampingFraction: 0.75)
        static let smooth  = Animation.spring(response: 0.4, dampingFraction: 0.85)
        static let gentle  = Animation.easeOut(duration: 0.18)
        static let slow    = Animation.easeInOut(duration: 0.35)
    }

    // MARK: Shadows

    struct ShadowStyle {
        let color: Color
        let radius: CGFloat
        let x: CGFloat
        let y: CGFloat
    }

    enum Shadow {
        static func card(_ scheme: ColorScheme) -> ShadowStyle {
            ShadowStyle(
                color: .black.opacity(scheme == .dark ? 0.3 : 0.06),
                radius: 8,
                x: 0,
                y: 2
            )
        }

        static func floating(_ scheme: ColorScheme) -> ShadowStyle {
            ShadowStyle(
                color: .black.opacity(scheme == .dark ? 0.45 : 0.12),
                radius: 20,
                x: 0,
                y: 8
            )
        }

        static func glow(_ color: Color = Palette.amber) -> ShadowStyle {
            ShadowStyle(color: color.opacity(0.35), radius: 12, x: 0, y: 0)
        }
    }
}

// MARK: - View Modifiers

extension View {
    func emberShadow(_ style: Ember.ShadowStyle) -> some View {
        shadow(color: style.color, radius: style.radius, x: style.x, y: style.y)
    }

    func emberCard(_ scheme: ColorScheme, highlighted: Bool = false) -> some View {
        self
            .background(
                RoundedRectangle(cornerRadius: Ember.Radius.lg, style: .continuous)
                    .fill(Ember.cardBackground(scheme))
            )
            .overlay(
                RoundedRectangle(cornerRadius: Ember.Radius.lg, style: .continuous)
                    .strokeBorder(
                        highlighted ? Ember.Palette.amber.opacity(0.6) : Color.white.opacity(scheme == .dark ? 0.06 : 0.5),
                        lineWidth: highlighted ? 1.5 : 0.5
                    )
            )
            .emberShadow(Ember.Shadow.card(scheme))
    }
}

// MARK: - Reusable Components

struct KbdHint: View {
    let keys: String
    let label: String
    @Environment(\.colorScheme) var scheme

    var body: some View {
        HStack(spacing: 4) {
            Text(keys)
                .font(Ember.Font.kbd)
                .foregroundColor(Ember.secondaryText(scheme))
                .padding(.horizontal, 5)
                .padding(.vertical, 2)
                .background(
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Ember.Palette.smoke.opacity(scheme == .dark ? 0.15 : 0.08))
                )
            Text(label)
                .font(Ember.Font.caption)
                .foregroundColor(Ember.secondaryText(scheme))
        }
    }
}

struct LanguageChip: View {
    let language: String
    @Environment(\.colorScheme) var scheme

    var body: some View {
        HStack(spacing: 5) {
            Circle()
                .fill(languageColor)
                .frame(width: 6, height: 6)
            Text(language)
                .font(Ember.Font.caption)
                .foregroundColor(Ember.secondaryText(scheme))
        }
    }

    private var languageColor: Color {
        switch language.lowercased() {
        case "swift":       return Color(red: 1.0, green: 0.42, blue: 0.26)
        case "javascript":  return Color(red: 0.97, green: 0.87, blue: 0.26)
        case "typescript":  return Color(red: 0.19, green: 0.47, blue: 0.77)
        case "python":      return Color(red: 0.22, green: 0.49, blue: 0.72)
        case "rust":        return Color(red: 0.86, green: 0.41, blue: 0.12)
        case "go":          return Color(red: 0.0,  green: 0.68, blue: 0.84)
        case "json":        return Color(red: 0.5,  green: 0.5,  blue: 0.5)
        case "html":        return Color(red: 0.89, green: 0.33, blue: 0.18)
        case "css":         return Color(red: 0.21, green: 0.46, blue: 0.74)
        default:            return Ember.Palette.smoke
        }
    }
}
