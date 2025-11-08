//
//  AboutView.swift
//  Clippy
//
//  Created by Mehmet Akbaba on 3.10.2025.
//


import SwiftUI

struct AboutView: View {
    @EnvironmentObject var settings: SettingsManager

    var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }

    var buildNumber: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    }

    var body: some View {
        VStack(spacing: 15) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 80, height: 80)

            VStack {
                Text("Clippy")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                Text(String(format: L("Version %@ (%@)", settings: settings), appVersion, buildNumber))
                    .foregroundColor(.secondary)
            }

            Text(L("A powerful clipboard manager for macOS.", settings: settings))
                .multilineTextAlignment(.center)

            Divider()

            VStack {
                Button(action: {
                    if let url = URL(string: "https://github.com/yarasaa/Clippy") {
                        NSWorkspace.shared.open(url)
                    }
                }) {
                    Label(L("GitHub Repository", settings: settings), systemImage: "link")
                }
                .buttonStyle(.link)

                Button(action: {
                    if let url = URL(string: "https://buymeacoffee.com/12hrsofficp") {
                        NSWorkspace.shared.open(url)
                    }
                }) {
                    Label(L("Buy me a coffee", settings: settings), systemImage: "cup.and.saucer.fill")
                }
                .controlSize(.large)
                .buttonStyle(.borderedProminent)
                .tint(Color(red: 1.0, green: 0.87, blue: 0.0))
            }
        }
        .preferredColorScheme(colorScheme)
        .padding(20)
        .frame(width: 320, height: 310)
    }

    private var colorScheme: ColorScheme? {
        switch settings.appTheme {
        case "light":
            return .light
        case "dark":
            return .dark
        default:
            return nil
        }
    }
}
