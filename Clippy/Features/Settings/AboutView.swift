//
//  AboutView.swift
//  Clippy
//

import SwiftUI

struct AboutView: View {
    @EnvironmentObject var settings: SettingsManager
    @Environment(\.colorScheme) var scheme

    var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }

    var buildNumber: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    }

    var body: some View {
        ScrollView {
            VStack(spacing: Ember.Space.xl) {
                // Hero logo
                ClippyHeroLogo()
                    .padding(.top, Ember.Space.xxl)

                // Version
                Text("Version \(appVersion) (\(buildNumber))")
                    .font(Ember.Font.caption)
                    .foregroundColor(Ember.tertiaryText(scheme))

                // Feature grid
                featureGrid
                    .padding(.top, Ember.Space.lg)

                // Actions
                VStack(spacing: Ember.Space.md) {
                    Button {
                        if let url = URL(string: "https://github.com/yarasaa/Clippy") {
                            NSWorkspace.shared.open(url)
                        }
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "star.fill")
                            Text("Star on GitHub")
                        }
                        .frame(maxWidth: 240)
                    }
                    .buttonStyle(PrimaryActionButtonStyle())

                    Button {
                        if let url = URL(string: "https://buymeacoffee.com/12hrsofficp") {
                            NSWorkspace.shared.open(url)
                        }
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "cup.and.saucer.fill")
                            Text("Buy the developer a coffee")
                        }
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(Ember.primaryText(scheme))
                        .padding(.horizontal, Ember.Space.lg)
                        .padding(.vertical, Ember.Space.sm + 2)
                        .frame(maxWidth: 240)
                        .background(
                            RoundedRectangle(cornerRadius: Ember.Radius.md)
                                .fill(Ember.cardBackground(scheme))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: Ember.Radius.md)
                                .strokeBorder(Ember.Palette.amber.opacity(0.4), lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                }
                .padding(.top, Ember.Space.md)

                // Credits
                VStack(spacing: 4) {
                    Text("Made with ♥ in Turkey")
                        .font(Ember.Font.meta)
                        .foregroundColor(Ember.tertiaryText(scheme))
                    Text("by Mehmet Akbaba")
                        .font(Ember.Font.caption)
                        .foregroundColor(Ember.secondaryText(scheme))
                }
                .padding(.top, Ember.Space.lg)
                .padding(.bottom, Ember.Space.xl)
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, Ember.Space.xl)
        }
    }

    private var featureGrid: some View {
        LazyVGrid(
            columns: [GridItem(.flexible()), GridItem(.flexible())],
            spacing: Ember.Space.sm
        ) {
            featureCard(icon: "tray.full", title: "Smart history", subtitle: "Auto-detect code, URLs, colors, JSON")
            featureCard(icon: "sparkles", title: "AI-powered", subtitle: "Summarize, translate, fix grammar")
            featureCard(icon: "bolt", title: "Quick Preview", subtitle: "Overlay for lightning-fast paste")
            featureCard(icon: "lock.shield", title: "Private", subtitle: "100% local. No cloud. No telemetry.")
        }
        .frame(maxWidth: 480)
    }

    private func featureCard(icon: String, title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(Ember.Palette.amber)
                .frame(width: 32, height: 32)
                .background(
                    Circle().fill(Ember.Palette.amberSoft)
                )

            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(Ember.primaryText(scheme))

            Text(subtitle)
                .font(Ember.Font.caption)
                .foregroundColor(Ember.secondaryText(scheme))
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(Ember.Space.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: Ember.Radius.lg)
                .fill(Ember.cardBackground(scheme))
        )
        .overlay(
            RoundedRectangle(cornerRadius: Ember.Radius.lg)
                .strokeBorder(Color.white.opacity(scheme == .dark ? 0.06 : 0.5), lineWidth: 0.5)
        )
    }
}

#if DEBUG
struct AboutView_Previews: PreviewProvider {
    static var previews: some View {
        AboutView()
            .environmentObject(SettingsManager.shared)
            .frame(width: 640, height: 720)
    }
}
#endif
