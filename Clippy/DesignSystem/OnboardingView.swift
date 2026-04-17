import SwiftUI

// MARK: - OnboardingView
// First-run experience. 3 screens. Warm, fast, no pressure.

struct OnboardingView: View {
    var onComplete: () -> Void
    @State private var page: Int = 0
    @Environment(\.colorScheme) var scheme

    private let totalPages = 3

    var body: some View {
        ZStack {
            Ember.surface(scheme).ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                TabView(selection: $page) {
                    welcomeSlide.tag(0)
                    hotkeysSlide.tag(1)
                    privacySlide.tag(2)
                }
                .tabViewStyle(.automatic)
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                Spacer()

                footer
            }
        }
        .frame(width: 520, height: 500)
    }

    // MARK: Slides

    private var welcomeSlide: some View {
        VStack(spacing: Ember.Space.xl) {
            ClippyHeroLogo()

            VStack(spacing: Ember.Space.sm) {
                Text("Welcome to Clippy")
                    .font(Ember.Font.display)
                    .foregroundColor(Ember.primaryText(scheme))

                Text("A clipboard that remembers everything you copy,\nand helps you find it again.")
                    .font(Ember.Font.body)
                    .foregroundColor(Ember.secondaryText(scheme))
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
            }
        }
    }

    private var hotkeysSlide: some View {
        VStack(spacing: Ember.Space.xl) {
            Image(systemName: "command.circle.fill")
                .font(.system(size: 72, weight: .light))
                .foregroundStyle(
                    LinearGradient(
                        colors: [Ember.Palette.amber, Ember.Palette.amberDark],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            VStack(spacing: Ember.Space.sm) {
                Text("Fast by default")
                    .font(Ember.Font.display)
                    .foregroundColor(Ember.primaryText(scheme))

                Text("Summon Clippy from anywhere with a hotkey.")
                    .font(Ember.Font.body)
                    .foregroundColor(Ember.secondaryText(scheme))
            }

            VStack(alignment: .leading, spacing: Ember.Space.md) {
                hotkeyRow(keys: ["⌘", "⇧", "V"], label: "Open the full history")
                hotkeyRow(keys: ["⌘", "⌥", "V"], label: "Quick paste overlay")
                hotkeyRow(keys: ["⌘", "⇧", "S"], label: "Screenshot with editor")
            }
            .padding(.top, Ember.Space.md)
        }
    }

    private var privacySlide: some View {
        VStack(spacing: Ember.Space.xl) {
            Image(systemName: "lock.shield.fill")
                .font(.system(size: 72, weight: .light))
                .foregroundStyle(
                    LinearGradient(
                        colors: [Ember.Palette.moss, Ember.Palette.sky],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            VStack(spacing: Ember.Space.sm) {
                Text("Yours alone")
                    .font(Ember.Font.display)
                    .foregroundColor(Ember.primaryText(scheme))

                Text("Everything stays on your Mac.\nNo accounts. No telemetry. No cloud.")
                    .font(Ember.Font.body)
                    .foregroundColor(Ember.secondaryText(scheme))
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
            }

            VStack(alignment: .leading, spacing: Ember.Space.sm) {
                privacyPoint("Local-first storage in Core Data")
                privacyPoint("Optional on-device AI via Ollama")
                privacyPoint("Encrypt any item with one click")
            }
            .padding(.top, Ember.Space.md)
        }
    }

    private func hotkeyRow(keys: [String], label: String) -> some View {
        HStack(spacing: Ember.Space.md) {
            HStack(spacing: 3) {
                ForEach(keys, id: \.self) { key in
                    Text(key)
                        .font(Ember.Font.kbd)
                        .foregroundColor(Ember.primaryText(scheme))
                        .frame(minWidth: 22, minHeight: 22)
                        .padding(.horizontal, 4)
                        .background(
                            RoundedRectangle(cornerRadius: 5)
                                .fill(Ember.cardBackground(scheme))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 5)
                                        .strokeBorder(Ember.Palette.smoke.opacity(0.3), lineWidth: 0.5)
                                )
                        )
                }
            }
            .frame(width: 120, alignment: .leading)

            Text(label)
                .font(Ember.Font.body)
                .foregroundColor(Ember.secondaryText(scheme))
        }
    }

    private func privacyPoint(_ text: String) -> some View {
        HStack(spacing: Ember.Space.sm) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 14))
                .foregroundColor(Ember.Palette.moss)
            Text(text)
                .font(Ember.Font.body)
                .foregroundColor(Ember.secondaryText(scheme))
        }
    }

    // MARK: Footer

    private var footer: some View {
        VStack(spacing: Ember.Space.md) {
            // Page dots
            HStack(spacing: 8) {
                ForEach(0..<totalPages, id: \.self) { i in
                    Circle()
                        .fill(i == page ? Ember.Palette.amber : Ember.Palette.smoke.opacity(0.3))
                        .frame(width: 7, height: 7)
                        .animation(Ember.Motion.snap, value: page)
                }
            }

            HStack {
                if page > 0 {
                    Button("Back") {
                        withAnimation(Ember.Motion.smooth) { page -= 1 }
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(Ember.secondaryText(scheme))
                }

                Spacer()

                if page < totalPages - 1 {
                    Button {
                        withAnimation(Ember.Motion.smooth) { page += 1 }
                    } label: {
                        HStack(spacing: 4) {
                            Text("Continue")
                            Image(systemName: "arrow.right")
                        }
                    }
                    .buttonStyle(PrimaryActionButtonStyle())
                } else {
                    Button {
                        finish()
                    } label: {
                        Text("Start using Clippy")
                    }
                    .buttonStyle(PrimaryActionButtonStyle())
                }
            }
            .padding(.horizontal, Ember.Space.xl)
        }
        .padding(.bottom, Ember.Space.xl)
    }

    private func finish() {
        UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")
        DispatchQueue.main.async {
            onComplete()
        }
    }
}

// MARK: - Button Style

struct PrimaryActionButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .semibold))
            .foregroundColor(.white)
            .lineLimit(1)
            .fixedSize(horizontal: true, vertical: false)
            .padding(.horizontal, Ember.Space.lg)
            .padding(.vertical, Ember.Space.sm + 2)
            .background(
                RoundedRectangle(cornerRadius: Ember.Radius.md)
                    .fill(
                        LinearGradient(
                            colors: [Ember.Palette.amber, Ember.Palette.amberDark],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
            )
            .shadow(color: Ember.Palette.amber.opacity(0.4), radius: 8, y: 3)
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(Ember.Motion.snap, value: configuration.isPressed)
    }
}

#if DEBUG
struct OnboardingView_Previews: PreviewProvider {
    static var previews: some View {
        OnboardingView(onComplete: {})
    }
}
#endif
