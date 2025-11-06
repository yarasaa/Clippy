//
//  SettingsView.swift
//  Clippy
//
//  Created by Mehmet Akbaba on 17.09.2025.
//

import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var settings: SettingsManager
    @ObservedObject private var launchManager = LaunchAtLoginManager.shared
    @State private var selectedTab = "General"

    var body: some View {
        TabView(selection: $selectedTab) {
            generalSettings
                .tabItem {
                    Label(L("General", settings: settings), systemImage: "gear")
                }
                .tag("General")

            appearanceSettings
                .tabItem {
                    Label(L("Appearance", settings: settings), systemImage: "paintbrush")
                }
                .tag("Appearance")

            shortcutsSettings
                .tabItem {
                    Label(L("Shortcuts", settings: settings), systemImage: "keyboard")
                }
                .tag("Shortcuts")

            advancedSettings
                .tabItem {
                    Label(L("Advanced", settings: settings), systemImage: "sparkles")
                }
                .tag("Advanced")
        }
        .preferredColorScheme(colorScheme)
        .frame(minWidth: 480, minHeight: 320)
        .padding()
    }

    // MARK: - Tab Views

    private var generalSettings: some View {
        Form {
            Section {
                Toggle(L("Launch Clippy on login", settings: settings), isOn: $launchManager.isEnabled)
                Picker(L("Language", settings: settings), selection: $settings.appLanguage) {
                    Text(L("System Default", settings: settings)).tag("system")
                    Text(L("English", settings: settings)).tag("en")
                    Text(L("Turkish", settings: settings)).tag("tr")
                }
            }
            
            Section(header: Text(L("Tab Visibility", settings: settings))) {
                Toggle(L("Show Code Tab", settings: settings), isOn: $settings.showCodeTab)
                Toggle(L("Show Images Tab", settings: settings), isOn: $settings.showImagesTab)
                Toggle(L("Show Snippets Tab", settings: settings), isOn: $settings.showSnippetsTab)
                Toggle(L("Show Favorites Tab", settings: settings), isOn: $settings.showFavoritesTab)
            }

            Section(header: Text(L("Storage Limits", settings: settings))) {
                Stepper(String(format: L("History Limit: %d", settings: settings), settings.historyLimit), value: $settings.historyLimit, in: 10...100, step: 5)
                Stepper(String(format: L("Favorites Limit: %d", settings: settings), settings.favoritesLimit), value: $settings.favoritesLimit, in: 10...200, step: 10)
                Stepper(String(format: L("Image Limit: %d", settings: settings), settings.imagesLimit), value: $settings.imagesLimit, in: 5...50, step: 5)
            }
        }
        .padding()
    }

    private var appearanceSettings: some View {
        Form {
            Section {
                Picker(L("Theme", settings: settings), selection: $settings.appTheme) {
                    Text(L("System Default", settings: settings)).tag("system")
                    Text(L("Light", settings: settings)).tag("light")
                    Text(L("Dark", settings: settings)).tag("dark")
                }
                
                Stepper(String(format: L("Popover Width: %d", settings: settings), settings.popoverWidth), value: $settings.popoverWidth, in: 300...800, step: 10)
                Stepper(String(format: L("Popover Height: %d", settings: settings), settings.popoverHeight), value: $settings.popoverHeight, in: 300...1000, step: 10)
            }
        }
        .padding()
    }

    private var shortcutsSettings: some View {
        Form {
            Group {
                shortcutRow(label: L("Show/Hide App", settings: settings), key: $settings.hotkeyKey, modifiers: $settings.hotkeyModifiers)
                shortcutRow(label: L("Paste Selected", settings: settings), key: $settings.pasteAllHotkeyKey, modifiers: $settings.pasteAllHotkeyModifiers)
            }
            Divider()
            Group {
                shortcutRow(label: L("Sequential Copy", settings: settings), key: $settings.sequentialCopyHotkeyKey, modifiers: $settings.sequentialCopyHotkeyModifiers)
                shortcutRow(label: L("Sequential Paste", settings: settings), key: $settings.sequentialPasteHotkeyKey, modifiers: $settings.sequentialPasteHotkeyModifiers)
                shortcutRow(label: L("Clear Sequential Queue", settings: settings), key: $settings.clearQueueHotkeyKey, modifiers: $settings.clearQueueHotkeyModifiers)
            }
            Divider()
            shortcutRow(label: L("Take Screenshot", settings: settings), key: $settings.screenshotHotkeyKey, modifiers: $settings.screenshotHotkeyModifiers)
            shortcutRow(label: L("Scrolling Screenshot", settings: settings), key: $settings.scrollingScreenshotHotkeyKey, modifiers: $settings.scrollingScreenshotHotkeyModifiers)
        }
        .padding()
    }

    /// Gelişmiş ayarları içeren görünüm.
    private var advancedSettings: some View {
        Form {
            Section(header: Text(L("Keyword Expansion", settings: settings))) {
                Toggle(L("Enable Keyword Expansion", settings: settings), isOn: $settings.isKeywordExpansionEnabled)
                    .help(L("When enabled, typing a keyword (e.g., ;sig) will automatically replace it with the corresponding content.", settings: settings))
                
                if settings.isKeywordExpansionEnabled {
                    Stepper(String(format: L("Snippet Timeout: %.1f seconds", settings: settings), settings.snippetTimeoutDuration), value: $settings.snippetTimeoutDuration, in: 1.0...10.0, step: 0.5)
                        .disabled(!settings.isKeywordExpansionEnabled)
                }
            }
        }
        .padding()
    }

    private var colorScheme: ColorScheme? {
        switch settings.appTheme {
        case "light":
            return .light
        case "dark":
            return .dark
        default:
            return nil // Sistem varsayılanını kullan
        }
    }

    private func shortcutRow(label: String, key: Binding<String>, modifiers: Binding<UInt>) -> some View {
        LabeledContent(label) {
            HotkeySettingsView(hotkeyKey: key, hotkeyModifiers: modifiers)
        }
    }
}

struct HotkeySettingsView: View {
    @Binding var hotkeyKey: String
    @Binding var hotkeyModifiers: UInt
    @EnvironmentObject var settings: SettingsManager

    var body: some View {
        HStack {
            // Çözüm: Toggle'ların stilini .button olarak değiştirerek daha kompakt ve standart bir görünüm elde ediyoruz.
            modifierToggle(label: "⌘", flag: .command)
            modifierToggle(label: "⇧", flag: .shift)
            modifierToggle(label: "⌥", flag: .option)
            modifierToggle(label: "⌃", flag: .control)

            TextField(L("Key", settings: settings), text: $hotkeyKey)
                .frame(width: 80)
                .multilineTextAlignment(.center)
                .textFieldStyle(.roundedBorder) // Metnin görünür olmasını sağlamak için stil ekle.
                .onChange(of: hotkeyKey) { newValue in
                    // Sadece tek bir karakter girilmesini sağla
                    if newValue.count > 1 {
                        hotkeyKey = String(newValue.prefix(1))
                    }
                }
        }
    }

    /// Değiştirici tuşlar için bir Toggle oluşturan yardımcı fonksiyon.
    private func modifierToggle(label: String, flag: NSEvent.ModifierFlags) -> some View {
        Toggle(label, isOn: Binding(
            get: { hotkeyModifiers & flag.rawValue != 0 },
            set: { isOn in hotkeyModifiers = isOn ? hotkeyModifiers | flag.rawValue : hotkeyModifiers & ~flag.rawValue }
        ))
        .toggleStyle(.button)
    }
}

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView().environmentObject(SettingsManager.shared)
    }
}
