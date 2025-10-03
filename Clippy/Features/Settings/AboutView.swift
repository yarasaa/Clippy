//
//  AboutView.swift
//  Clippy
//
//  Created by Gemini Code Assist on 3.10.2025.
//

import SwiftUI

struct AboutView: View {
    @EnvironmentObject var settings: SettingsManager

    // Uygulamanın versiyon ve build numarasını Bundle'dan al.
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
                    Label("GitHub Repository", systemImage: "link")
                }
                .buttonStyle(.link)
                
                Button(action: {
                    if let url = URL(string: "https://www.buymeacoffee.com/yarasaa") {
                        NSWorkspace.shared.open(url)
                    }
                }) {
                    Label(L("Buy me a coffee", settings: settings), systemImage: "cup.and.saucer.fill")
                }
                .controlSize(.large)
                .buttonStyle(.borderedProminent)
                .tint(Color(red: 1.0, green: 0.87, blue: 0.0)) // BuyMeACoffee sarısı
            }
        }
        .padding(20)
        .frame(width: 320, height: 280)
    }
}