//
//  AppPickerView.swift
//  Clippy
//

import SwiftUI

struct AppPickerView: View {
    @Binding var selectedIdentifiers: Set<String>
    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) var scheme
    @EnvironmentObject var settings: SettingsManager

    @State private var runningApps: [NSRunningApplication] = []
    @State private var searchText: String = ""

    var filteredApps: [NSRunningApplication] {
        if searchText.isEmpty { return runningApps }
        return runningApps.filter {
            ($0.localizedName ?? "").localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: Ember.Space.xs) {
                HStack(spacing: Ember.Space.sm) {
                    ClippyMark(size: 16)
                    Text("Select Applications")
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                }
                Text("Limit this snippet to specific apps. None selected = available everywhere.")
                    .font(Ember.Font.caption)
                    .foregroundColor(Ember.secondaryText(scheme))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, Ember.Space.lg)
            .padding(.vertical, Ember.Space.md)

            HStack(spacing: Ember.Space.sm) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 11))
                    .foregroundColor(Ember.secondaryText(scheme))
                TextField("Search apps…", text: $searchText)
                    .textFieldStyle(.plain)
                    .font(Ember.Font.body)
            }
            .padding(.horizontal, Ember.Space.md)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: Ember.Radius.md)
                    .fill(Ember.Palette.smoke.opacity(scheme == .dark ? 0.12 : 0.06))
            )
            .padding(.horizontal, Ember.Space.lg)
            .padding(.bottom, Ember.Space.sm)

            Divider().opacity(0.3)

            List {
                ForEach(filteredApps, id: \.bundleIdentifier) { app in
                    if let bundleID = app.bundleIdentifier, let appName = app.localizedName, let icon = app.icon {
                        Toggle(isOn: Binding(
                            get: { selectedIdentifiers.contains(bundleID) },
                            set: { isSelected in
                                if isSelected { selectedIdentifiers.insert(bundleID) }
                                else { selectedIdentifiers.remove(bundleID) }
                            }
                        )) {
                            HStack {
                                Image(nsImage: icon)
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(width: 22, height: 22)
                                Text(appName)
                                    .font(Ember.Font.body)
                            }
                        }
                        .toggleStyle(.checkbox)
                    }
                }
            }
            .listStyle(.inset)

            Divider().opacity(0.3)

            HStack {
                Text(selectedIdentifiers.isEmpty ? "All apps" : "\(selectedIdentifiers.count) selected")
                    .font(Ember.Font.caption)
                    .foregroundColor(Ember.tertiaryText(scheme))

                Spacer()

                Button("Cancel") { dismiss() }
                    .buttonStyle(SecondaryActionButtonStyle())

                Button("Done") { dismiss() }
                    .buttonStyle(PrimaryActionButtonStyle())
            }
            .padding(Ember.Space.md)
        }
        .background(Ember.surface(scheme))
        .preferredColorScheme(colorSchemeOverride)
        .frame(width: 380, height: 500)
        .onAppear {
            runningApps = NSWorkspace.shared.runningApplications.filter {
                $0.activationPolicy == .regular && !$0.isHidden && $0.bundleIdentifier != nil
            }.sorted { $0.localizedName ?? "" < $1.localizedName ?? "" }
        }
    }

    private var colorSchemeOverride: ColorScheme? {
        switch settings.appTheme {
        case "light": return .light
        case "dark":  return .dark
        default:      return nil
        }
    }
}
