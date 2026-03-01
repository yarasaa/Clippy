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

            featuresSettings
                .tabItem {
                    Label(L("Features", settings: settings), systemImage: "checklist")
                }
                .tag("Features")

            aiSettings
                .tabItem {
                    Label(L("AI", settings: settings), systemImage: "brain")
                }
                .tag("AI")

            advancedSettings
                .tabItem {
                    Label(L("Advanced", settings: settings), systemImage: "sparkles")
                }
                .tag("Advanced")

            SnippetVariablesView()
                .tabItem {
                    Label(L("Variables", settings: settings), systemImage: "textformat.abc")
                }
                .tag("Variables")

            SnippetCategoriesView()
                .tabItem {
                    Label(L("Categories", settings: settings), systemImage: "folder")
                }
                .tag("Categories")
        }
        .preferredColorScheme(colorScheme)
        .frame(minWidth: 480, minHeight: 320)
        .padding()
    }

    private var generalSettings: some View {
        Form {
            Section {
                Toggle(L("Launch Clippy on login", settings: settings), isOn: $launchManager.isEnabled)
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
            Divider()
            shortcutRow(label: L("Quick Preview", settings: settings), key: $settings.quickPreviewHotkeyKey, modifiers: $settings.quickPreviewHotkeyModifiers)
            Divider()
            shortcutRow(label: L("App Switcher", settings: settings), key: $settings.switcherHotkeyKey, modifiers: $settings.switcherHotkeyModifiers)
        }
        .padding()
    }

    private var featuresSettings: some View {
        ScrollView {
            Form {
                Section(header: Text(L("Clipboard Monitoring", settings: settings))) {
                    Toggle(L("Auto Code Detection", settings: settings), isOn: $settings.enableAutoCodeDetection)
                        .help(L("Automatically detect code snippets when copying text", settings: settings))

                    Toggle(L("Content Detection", settings: settings), isOn: $settings.enableContentDetection)
                        .help(L("Detect URLs, colors, dates, and JSON in clipboard content", settings: settings))

                    Toggle(L("Duplicate Detection", settings: settings), isOn: $settings.enableDuplicateDetection)
                        .help(L("Skip saving duplicate clipboard entries", settings: settings))

                    Toggle(L("Source App Tracking", settings: settings), isOn: $settings.enableSourceAppTracking)
                        .help(L("Track which application the content was copied from", settings: settings))
                }

                Section(header: Text(L("Tools", settings: settings))) {
                    Toggle(L("Sequential Copy/Paste", settings: settings), isOn: $settings.enableSequentialPaste)
                        .help(L("Enable sequential copy and paste queue", settings: settings))

                    Toggle(L("Screenshot", settings: settings), isOn: $settings.enableScreenshot)
                        .help(L("Enable screenshot capture feature", settings: settings))

                    Toggle(L("OCR Text Recognition", settings: settings), isOn: $settings.enableOCR)
                        .help(L("Enable text recognition from images", settings: settings))

                    Toggle(L("File Converter", settings: settings), isOn: $settings.enableFileConverter)
                        .help(L("Convert files between formats (images, documents, audio, video, data)", settings: settings))

                    Toggle(L("Drag & Drop Shelf", settings: settings), isOn: $settings.enableDragDropShelf)
                        .help(L("Floating shelf for temporary drag & drop storage", settings: settings))

                    Toggle(L("Quick Preview Overlay", settings: settings), isOn: $settings.enableQuickPreview)
                        .help(L("Show a floating panel with recent clipboard items via hotkey", settings: settings))

                    if settings.enableQuickPreview {
                        Stepper(String(format: L("Quick Preview Items: %d", settings: settings), settings.quickPreviewItemCount), value: $settings.quickPreviewItemCount, in: 3...15)

                        Toggle(L("Auto-close after paste", settings: settings), isOn: $settings.quickPreviewAutoClose)
                    }
                }

                Section(header: Text(L("Performance", settings: settings))) {
                    Picker(L("Max Text Storage Length", settings: settings), selection: $settings.maxTextStorageLength) {
                        Text("50K").tag(50_000)
                        Text("100K").tag(100_000)
                        Text("500K").tag(500_000)
                        Text("1M").tag(1_000_000)
                        Text(L("Unlimited", settings: settings)).tag(Int.max)
                    }
                    .help(L("Maximum character length for storing clipboard text. Longer texts will be truncated.", settings: settings))

                    Text(L("Shorter limits improve performance with large texts", settings: settings))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding()
        }
    }

    private var advancedSettings: some View {
        ScrollView {
            Form {
                Section(header: Text(L("Keyword Expansion", settings: settings))) {
                Toggle(L("Enable Keyword Expansion", settings: settings), isOn: $settings.isKeywordExpansionEnabled)
                    .help(L("When enabled, typing a keyword (e.g., ;sig) will automatically replace it with the corresponding content.", settings: settings))

                if settings.isKeywordExpansionEnabled {
                    Stepper(String(format: L("Snippet Timeout: %.1f seconds", settings: settings), settings.snippetTimeoutDuration), value: $settings.snippetTimeoutDuration, in: 1.0...10.0, step: 0.5)
                        .disabled(!settings.isKeywordExpansionEnabled)
                }
            }

            Section(header: Text(L("Dock Preview", settings: settings))) {
                Toggle(L("Enable Dock Preview", settings: settings), isOn: $settings.enableDockPreview)
                    .help(L("Show window previews when hovering over dock icons", settings: settings))

                if settings.enableDockPreview {
                    Picker(L("Animation Style", settings: settings), selection: $settings.dockPreviewAnimationStyle) {
                        Text(L("Spring", settings: settings)).tag("spring")
                        Text(L("Ease In Out", settings: settings)).tag("easeInOut")
                        Text(L("Linear", settings: settings)).tag("linear")
                        Text(L("None", settings: settings)).tag("none")
                    }

                    Picker(L("Preview Size", settings: settings), selection: $settings.dockPreviewSize) {
                        Text(L("Small", settings: settings)).tag("small")
                        Text(L("Medium", settings: settings)).tag("medium")
                        Text(L("Large", settings: settings)).tag("large")
                        Text(L("Extra Large", settings: settings)).tag("xlarge")
                        Text(L("Extra Extra Large", settings: settings)).tag("xxlarge")
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(L("Hover Delay:", settings: settings))
                            Spacer()
                            Text(String(format: "%.1fs", settings.dockPreviewHoverDelay))
                                .foregroundColor(.secondary)
                        }
                        Slider(value: $settings.dockPreviewHoverDelay, in: 0.0...2.0, step: 0.1)
                        Text(L("Time to wait before showing preview (0s = instant)", settings: settings))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 4)

                    Toggle(L("Show Window Titles", settings: settings), isOn: $settings.showWindowTitles)

                    Toggle(L("Enable Keyboard Shortcuts", settings: settings), isOn: $settings.enableDockPreviewKeyboardShortcuts)
                        .help(L("Use 1-9, arrows, Enter, ESC to navigate window previews", settings: settings))

                    Toggle(L("Enable Trackpad Gestures", settings: settings), isOn: $settings.enableDockPreviewGestures)

                    if settings.enableDockPreviewGestures {
                        Picker(L("Swipe Up Action", settings: settings), selection: $settings.dockSwipeUpAction) {
                            Text(L("None", settings: settings)).tag("none")
                            Text(L("Close Window", settings: settings)).tag("close")
                            Text(L("Minimize Window", settings: settings)).tag("minimize")
                            Text(L("Select Window", settings: settings)).tag("select")
                        }

                        Picker(L("Swipe Down Action", settings: settings), selection: $settings.dockSwipeDownAction) {
                            Text(L("None", settings: settings)).tag("none")
                            Text(L("Close Window", settings: settings)).tag("close")
                            Text(L("Minimize Window", settings: settings)).tag("minimize")
                            Text(L("Select Window", settings: settings)).tag("select")
                        }
                    }

                    Picker(L("Middle Click Action", settings: settings), selection: $settings.middleClickAction) {
                        Text(L("None", settings: settings)).tag("none")
                        Text(L("Close Window", settings: settings)).tag("close")
                        Text(L("Minimize Window", settings: settings)).tag("minimize")
                        Text(L("Select Window", settings: settings)).tag("select")
                    }

                    Divider()

                    Toggle(L("Enable Window Caching", settings: settings), isOn: $settings.enableWindowCaching)
                        .help(L("Cache window previews for better performance", settings: settings))

                    if settings.enableWindowCaching {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(L("Performance & Memory", settings: settings))
                                .font(.headline)
                                .padding(.top, 8)

                            Picker(L("Max Cache Size", settings: settings), selection: $settings.maxCacheSizeMB) {
                                Text("50 MB").tag(50)
                                Text("100 MB").tag(100)
                                Text("200 MB").tag(200)
                                Text("500 MB").tag(500)
                                Text(L("Unlimited", settings: settings)).tag(Int.max)
                            }
                            .help(L("Maximum memory to use for caching window previews", settings: settings))

                            Toggle(L("Auto-Clear on Memory Pressure", settings: settings), isOn: $settings.enableMemoryPressureHandling)
                                .help(L("Automatically clear cache when system memory is low", settings: settings))

                            Button(L("Clear Cache Now", settings: settings)) {
                                Task { @MainActor in
                                    MemoryManager.shared.clearAllCaches()
                                }
                            }
                            .help(L("Manually clear all cached window previews", settings: settings))

                            Text(MemoryManager.shared.getFormattedStats())
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .padding(.top, 4)
                        }

                        Divider()

                        VStack(alignment: .leading, spacing: 8) {
                            Text(L("Live Preview", settings: settings))
                                .font(.headline)
                                .padding(.top, 8)

                            Toggle(L("Enable Live Preview", settings: settings), isOn: $settings.enableAutoRefresh)
                                .help(L("Show real-time live preview using ScreenCaptureKit (macOS 12.3+)", settings: settings))

                            if settings.enableAutoRefresh {
                                Text(L("Live preview uses ScreenCaptureKit to stream window content in real-time at 15 FPS. Perfect for monitoring Teams messages, videos, and dynamic content.", settings: settings))
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }
                }
            }
            }
            .padding()
        }
    }

    @State private var aiValidationState: AIValidationState = .idle
    @State private var aiValidationMessage: String = ""
    @State private var aiUseCustomModel: Bool = false

    private enum AIValidationState {
        case idle, testing, success, failure
    }

    private var modelsForProvider: [(name: String, label: String)] {
        switch settings.aiProvider {
        case "openai":
            return [
                ("gpt-4o-mini", "GPT-4o Mini (fast & cheap)"),
                ("gpt-4o", "GPT-4o (best quality)"),
                ("gpt-4.1-mini", "GPT-4.1 Mini"),
                ("gpt-4.1", "GPT-4.1"),
                ("o3-mini", "o3-mini (reasoning)"),
            ]
        case "anthropic":
            return [
                ("claude-sonnet-4-5-20250929", "Claude Sonnet 4.5"),
                ("claude-haiku-4-5-20251001", "Claude Haiku 4.5 (fast)"),
                ("claude-opus-4-6", "Claude Opus 4.6"),
            ]
        case "google":
            return [
                ("gemini-2.0-flash", "Gemini 2.0 Flash (fast)"),
                ("gemini-2.5-pro", "Gemini 2.5 Pro (best)"),
                ("gemini-2.5-flash", "Gemini 2.5 Flash"),
            ]
        default:
            return []
        }
    }

    private var isCustomModel: Bool {
        let knownModels = modelsForProvider.map { $0.name }
        return !knownModels.contains(settings.aiModel) && !settings.aiModel.isEmpty
    }

    private var aiSettings: some View {
        ScrollView {
            Form {
                Section(header: Text(L("AI Assistant", settings: settings))) {
                    Toggle(L("Enable AI Features", settings: settings), isOn: $settings.enableAI)
                        .help(L("Enable AI-powered text transformations and analysis", settings: settings))
                }

                if settings.enableAI {
                    Section(header: Text(L("Provider", settings: settings))) {
                        Picker(L("AI Provider", settings: settings), selection: $settings.aiProvider) {
                            Text("Ollama (\(L("Free, Local", settings: settings)))").tag("ollama")
                            Text("OpenAI").tag("openai")
                            Text("Anthropic").tag("anthropic")
                            Text("Google Gemini").tag("google")
                        }
                        .onChange(of: settings.aiProvider) { _ in
                            aiValidationState = .idle
                            aiValidationMessage = ""
                            aiUseCustomModel = false
                            // Set default model for new provider
                            if settings.aiProvider != "ollama" {
                                let models = modelsForProvider
                                if !models.isEmpty {
                                    settings.aiModel = models[0].name
                                }
                            }
                        }

                        if settings.aiProvider == "ollama" {
                            TextField(L("Ollama URL", settings: settings), text: $settings.ollamaURL)
                                .textFieldStyle(.roundedBorder)

                            TextField(L("Model", settings: settings), text: $settings.ollamaModel)
                                .textFieldStyle(.roundedBorder)

                            Text(L("Install Ollama from ollama.com and run: ollama pull llama3.2", settings: settings))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        } else {
                            SecureField(L("API Key", settings: settings), text: $settings.aiAPIKey)
                                .textFieldStyle(.roundedBorder)

                            // Model picker with known models + custom option
                            Picker(L("Model", settings: settings), selection: $settings.aiModel) {
                                ForEach(modelsForProvider, id: \.name) { model in
                                    Text(model.label).tag(model.name)
                                }
                                Divider()
                                if isCustomModel || aiUseCustomModel {
                                    Text(settings.aiModel).tag(settings.aiModel)
                                }
                                Text(L("Custom...", settings: settings)).tag("__custom__")
                            }
                            .onChange(of: settings.aiModel) { newValue in
                                if newValue == "__custom__" {
                                    aiUseCustomModel = true
                                    settings.aiModel = ""
                                } else {
                                    aiUseCustomModel = false
                                }
                            }

                            if aiUseCustomModel || isCustomModel {
                                TextField(L("Custom Model Name", settings: settings), text: $settings.aiModel)
                                    .textFieldStyle(.roundedBorder)
                            }
                        }

                        // Test Connection Button
                        HStack(spacing: 8) {
                            Button {
                                aiValidationState = .testing
                                aiValidationMessage = ""
                                Task {
                                    let error = await AIService.shared.validateConnection()
                                    await MainActor.run {
                                        if let error = error {
                                            aiValidationState = .failure
                                            aiValidationMessage = error
                                        } else {
                                            aiValidationState = .success
                                            aiValidationMessage = L("Connection successful!", settings: settings)
                                        }
                                    }
                                }
                            } label: {
                                HStack(spacing: 4) {
                                    if aiValidationState == .testing {
                                        ProgressView()
                                            .controlSize(.small)
                                    }
                                    Text(L("Test Connection", settings: settings))
                                }
                            }
                            .disabled(aiValidationState == .testing)

                            switch aiValidationState {
                            case .success:
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                            case .failure:
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.red)
                            default:
                                EmptyView()
                            }
                        }

                        if !aiValidationMessage.isEmpty {
                            Text(aiValidationMessage)
                                .font(.caption)
                                .foregroundColor(aiValidationState == .success ? .green : .red)
                                .textSelection(.enabled)
                        }
                    }

                    Section(header: Text(L("Available AI Actions", settings: settings))) {
                        VStack(alignment: .leading, spacing: 6) {
                            aiActionRow(icon: "text.bubble", title: L("Summarize", settings: settings))
                            aiActionRow(icon: "arrow.up.left.and.arrow.down.right", title: L("Expand", settings: settings))
                            aiActionRow(icon: "checkmark.circle", title: L("Fix Grammar", settings: settings))
                            aiActionRow(icon: "globe", title: L("Translate (any language)", settings: settings))
                            aiActionRow(icon: "list.bullet", title: L("Convert to Bullet Points", settings: settings))
                            aiActionRow(icon: "envelope", title: L("Draft Email", settings: settings))
                            aiActionRow(icon: "chevron.left.forwardslash.chevron.right", title: L("Explain Code", settings: settings))
                            aiActionRow(icon: "text.cursor", title: L("Free Prompt", settings: settings))
                        }
                        .font(.caption)
                        .foregroundColor(.secondary)
                    }
                }
            }
            .padding()
        }
    }

    private func aiActionRow(icon: String, title: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .frame(width: 16)
            Text(title)
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
            modifierToggle(label: "⌘", flag: .command)
            modifierToggle(label: "⇧", flag: .shift)
            modifierToggle(label: "⌥", flag: .option)
            modifierToggle(label: "⌃", flag: .control)

            TextField(L("Key", settings: settings), text: $hotkeyKey)
                .frame(width: 80)
                .multilineTextAlignment(.center)
                .textFieldStyle(.roundedBorder)
                .onChange(of: hotkeyKey) { newValue in
                    if newValue.count > 1 {
                        hotkeyKey = String(newValue.prefix(1))
                    }
                }
        }
    }

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
