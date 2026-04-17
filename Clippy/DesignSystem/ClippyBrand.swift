import SwiftUI

// MARK: - ClippyBrand
// Logo, wordmark, icon — the visual signature of Clippy.
// The mark is a stylized paperclip that forms the letter "C".

// MARK: Logo Mark (just the icon)

struct ClippyMark: View {
    var size: CGFloat = 32
    var gradient: Bool = true

    var body: some View {
        Canvas { ctx, s in
            let w = s.width
            let h = s.height
            let lineWidth = w * 0.12

            // Paperclip-C: outer arc + inner arc forming a "C" with paperclip tail
            var path = Path()

            // Outer curve of C (left side)
            let outerRect = CGRect(x: w * 0.18, y: h * 0.12, width: w * 0.7, height: h * 0.76)
            path.addArc(
                center: CGPoint(x: outerRect.midX, y: outerRect.midY),
                radius: outerRect.width / 2,
                startAngle: .degrees(35),
                endAngle: .degrees(325),
                clockwise: false
            )

            // Inner paperclip line
            var inner = Path()
            let innerRect = CGRect(x: w * 0.32, y: h * 0.26, width: w * 0.42, height: h * 0.48)
            inner.addArc(
                center: CGPoint(x: innerRect.midX, y: innerRect.midY),
                radius: innerRect.width / 2,
                startAngle: .degrees(45),
                endAngle: .degrees(315),
                clockwise: false
            )

            let shading: GraphicsContext.Shading
            if gradient {
                shading = .linearGradient(
                    Gradient(colors: [Ember.Palette.amberGlow, Ember.Palette.amber, Ember.Palette.amberDark]),
                    startPoint: CGPoint(x: 0, y: 0),
                    endPoint: CGPoint(x: w, y: h)
                )
            } else {
                shading = .color(Ember.Palette.amber)
            }

            ctx.stroke(path, with: shading, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
            ctx.stroke(inner, with: shading, style: StrokeStyle(lineWidth: lineWidth * 0.75, lineCap: .round))
        }
        .frame(width: size, height: size)
    }
}

// MARK: Wordmark

struct ClippyWordmark: View {
    var size: CGFloat = 24
    var showMark: Bool = true

    var body: some View {
        HStack(spacing: size * 0.3) {
            if showMark {
                ClippyMark(size: size)
            }
            Text("Clippy")
                .font(.system(size: size * 0.85, weight: .bold, design: .rounded))
                .foregroundStyle(
                    LinearGradient(
                        colors: [Ember.Palette.amberDark, Ember.Palette.amber],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
        }
    }
}

// MARK: Tagline

struct ClippyTagline: View {
    @Environment(\.colorScheme) var scheme

    var body: some View {
        Text("Your clipboard has memory.")
            .font(.system(size: 14, weight: .regular, design: .serif))
            .italic()
            .foregroundColor(Ember.secondaryText(scheme))
    }
}

// MARK: Hero Logo (for About, Onboarding)

struct ClippyHeroLogo: View {
    @Environment(\.colorScheme) var scheme
    @State private var isAnimating = false

    var body: some View {
        VStack(spacing: Ember.Space.md) {
            ZStack {
                // Soft glow halo
                Circle()
                    .fill(Ember.Palette.amber.opacity(0.15))
                    .frame(width: 140, height: 140)
                    .blur(radius: 30)
                    .scaleEffect(isAnimating ? 1.1 : 1.0)
                    .animation(
                        .easeInOut(duration: 2.5).repeatForever(autoreverses: true),
                        value: isAnimating
                    )

                ClippyMark(size: 96)
                    .rotationEffect(.degrees(isAnimating ? 2 : -2))
                    .animation(
                        .easeInOut(duration: 3.0).repeatForever(autoreverses: true),
                        value: isAnimating
                    )
            }

            ClippyWordmark(size: 36, showMark: false)

            ClippyTagline()
        }
        .onAppear { isAnimating = true }
    }
}

// MARK: Menu Bar Icon (NSImage generation)

extension NSImage {
    static func clippyMenuBarIcon(size: CGFloat = 18) -> NSImage {
        let image = NSImage(size: NSSize(width: size, height: size), flipped: false) { rect in
            let ctx = NSGraphicsContext.current?.cgContext
            ctx?.setLineCap(.round)
            ctx?.setLineWidth(size * 0.14)

            // Stroke color — template so menu bar tints it
            NSColor.labelColor.setStroke()

            // Outer C arc
            let outerPath = NSBezierPath()
            let outerCenter = CGPoint(x: rect.midX, y: rect.midY)
            let outerRadius = size * 0.38

            outerPath.appendArc(
                withCenter: outerCenter,
                radius: outerRadius,
                startAngle: 35,
                endAngle: 325,
                clockwise: false
            )
            outerPath.lineWidth = size * 0.16
            outerPath.lineCapStyle = .round
            outerPath.stroke()

            // Inner paperclip arc
            let innerPath = NSBezierPath()
            innerPath.appendArc(
                withCenter: outerCenter,
                radius: size * 0.2,
                startAngle: 45,
                endAngle: 315,
                clockwise: false
            )
            innerPath.lineWidth = size * 0.12
            innerPath.lineCapStyle = .round
            innerPath.stroke()

            return true
        }
        image.isTemplate = true  // macOS menu bar tints it
        return image
    }
}

// MARK: - Previews

#if DEBUG
struct ClippyBrand_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 40) {
            ClippyMark(size: 120)
            ClippyWordmark(size: 32)
            ClippyHeroLogo()
            ClippyTagline()
        }
        .padding(50)
        .frame(width: 400, height: 600)
    }
}
#endif
