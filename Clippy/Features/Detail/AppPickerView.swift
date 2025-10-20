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
            Text(L("Select Applications", settings: settings))
                .font(.title2)
                .padding()

            ScrollView {
                VStack(alignment: .leading) {
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
                .padding(.horizontal)
            }

            HStack {
                Button(L("Cancel", settings: settings)) {
                    // Değişiklikleri kaydetmeden kapat
                    dismiss()
                }
                Spacer()
                Button(L("Done", settings: settings)) {
                    // Seçimleri onayla ve kapat
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
            }
            .padding()
        }
        .frame(width: 350, height: 450)
        .onAppear {
            runningApps = NSWorkspace.shared.runningApplications.filter {
                $0.activationPolicy == .regular && !$0.isHidden && $0.bundleIdentifier != nil
            }.sorted { $0.localizedName ?? "" < $1.localizedName ?? "" }
        }
    }
}