//
//  AppPickerView.swift
//  Clippy
//
//  Created by Gemini Code Assist on 7.10.2025.
//


import SwiftUI

struct AppPickerView: View {
    @Binding var selectedIdentifiers: Set<String>
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var settings: SettingsManager

    @State private var runningApps: [NSRunningApplication] = []

    var body: some View {
        VStack {
            VStack(spacing: 4) {
                Text(L("Select Applications", settings: settings))
                    .font(.title2.bold())
                Text(L("Select the applications where this snippet will be active. If no app is selected, it will work in all apps.", settings: settings))
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding()

            List {
                    ForEach(runningApps, id: \.bundleIdentifier) { app in
                        if let bundleID = app.bundleIdentifier, let appName = app.localizedName, let icon = app.icon {
                            Toggle(isOn: Binding(
                                get: { selectedIdentifiers.contains(bundleID) },
                                set: { isSelected in
                                    if isSelected {
                                        selectedIdentifiers.insert(bundleID)
                                    } else {
                                        selectedIdentifiers.remove(bundleID)
                                    }
                                }
                            )) {
                                HStack {
                                    Image(nsImage: icon)
                                        .resizable()
                                        .aspectRatio(contentMode: .fit)
                                        .frame(width: 24, height: 24)
                                    Text(appName)
                                }
                            }
                            .toggleStyle(.checkbox)
                        }
                    }
            }

            HStack {
                Button(L("Cancel", settings: settings)) {
                    dismiss()
                }
                Spacer()
                Button(L("Done", settings: settings)) {
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
            }
            .padding()
        }
        .preferredColorScheme(colorScheme)
        .frame(width: 350, height: 450)
        .onAppear {
            runningApps = NSWorkspace.shared.runningApplications.filter {
                $0.activationPolicy == .regular && !$0.isHidden && $0.bundleIdentifier != nil
            }.sorted { $0.localizedName ?? "" < $1.localizedName ?? "" }
        }
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
