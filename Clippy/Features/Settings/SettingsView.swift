//
//  SettingsView.swift
//  Clippy
//

import SwiftUI

// MARK: - Settings Sections

enum SettingsSection: String, CaseIterable, Identifiable {
    case general     = "General"
    case features    = "Features"
    case ai          = "AI"
    case shortcuts   = "Shortcuts"
    case snippets    = "Snippets"
    case windows     = "Windows"
    case permissions = "Privacy"
    case about       = "About"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .general:     return "gearshape"
        case .features:    return "checklist"
        case .ai:          return "sparkles"
        case .shortcuts:   return "command"
        case .snippets:    return "text.badge.star"
        case .windows:     return "macwindow"
        case .permissions: return "lock.shield"
        case .about:       return "info.circle"
        }
    }

    var title: String { rawValue }
}

// MARK: - Root

struct SettingsView: View {
    @EnvironmentObject var settings: SettingsManager
    @ObservedObject private var launchManager = LaunchAtLoginManager.shared
    @State private var selection: SettingsSection = .general

    var body: some View {
        NavigationSplitView {
            sidebar
                .navigationSplitViewColumnWidth(min: 180, ideal: 200, max: 220)
        } detail: {
            detailView
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .background(Ember.surface(.light).opacity(0.0)) // passes through
        }
        .preferredColorScheme(colorScheme)
        .frame(minWidth: 720, minHeight: 520)
    }

    private var sidebar: some View {
        List(SettingsSection.allCases, selection: $selection) { section in
            NavigationLink(value: section) {
                HStack(spacing: 10) {
                    Image(systemName: section.icon)
                        .frame(width: 18)
                        .foregroundColor(selection == section ? Ember.Palette.amber : .secondary)
                    Text(section.title)
                        .font(.system(size: 13))
                }
            }
        }
        .listStyle(.sidebar)
        .safeAreaInset(edge: .top) {
            HStack(spacing: 8) {
                ClippyMark(size: 18)
                Text("Clippy")
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
    }

    @ViewBuilder
    private var detailView: some View {
        switch selection {
        case .general:     GeneralSettingsPane()
        case .features:    FeaturesSettingsPane()
        case .ai:          AISettingsPane()
        case .shortcuts:   ShortcutsSettingsPane()
        case .snippets:    SnippetsSettingsPane()
        case .windows:     WindowsSettingsPane()
        case .permissions: PermissionsSettingsPane()
        case .about:       AboutView()
        }
    }

    private var colorScheme: ColorScheme? {
        switch settings.appTheme {
        case "light": return .light
        case "dark":  return .dark
        default:      return nil
        }
    }
}

// MARK: - Shared Pane Components

struct SettingsPane<Content: View>: View {
    let title: String
    let subtitle: String?
    @ViewBuilder let content: () -> Content
    @Environment(\.colorScheme) var scheme

    init(title: String, subtitle: String? = nil, @ViewBuilder content: @escaping () -> Content) {
        self.title = title
        self.subtitle = subtitle
        self.content = content
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Ember.Space.xl) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundColor(Ember.primaryText(scheme))
                    if let subtitle = subtitle {
                        Text(subtitle)
                            .font(Ember.Font.body)
                            .foregroundColor(Ember.secondaryText(scheme))
                    }
                }

                content()

                Spacer(minLength: Ember.Space.xl)
            }
            .padding(.horizontal, Ember.Space.xl)
            .padding(.vertical, Ember.Space.xl)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

struct SettingsGroup<Content: View>: View {
    let title: String
    let footer: String?
    @ViewBuilder let content: () -> Content
    @Environment(\.colorScheme) var scheme

    init(_ title: String, footer: String? = nil, @ViewBuilder content: @escaping () -> Content) {
        self.title = title
        self.footer = footer
        self.content = content
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Ember.Space.sm) {
            Text(title)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(Ember.secondaryText(scheme))
                .textCase(.uppercase)
                .tracking(0.8)

            VStack(alignment: .leading, spacing: 0) {
                content()
            }
            .padding(Ember.Space.md)
            .background(
                RoundedRectangle(cornerRadius: Ember.Radius.lg, style: .continuous)
                    .fill(Ember.cardBackground(scheme))
            )
            .overlay(
                RoundedRectangle(cornerRadius: Ember.Radius.lg, style: .continuous)
                    .strokeBorder(Color.white.opacity(scheme == .dark ? 0.06 : 0.5), lineWidth: 0.5)
            )

            if let footer = footer {
                Text(footer)
                    .font(Ember.Font.caption)
                    .foregroundColor(Ember.tertiaryText(scheme))
                    .padding(.horizontal, 4)
            }
        }
    }
}

struct SettingsRow<Content: View>: View {
    let label: String
    let help: String?
    @ViewBuilder let trailing: () -> Content
    @Environment(\.colorScheme) var scheme

    init(_ label: String, help: String? = nil, @ViewBuilder trailing: @escaping () -> Content) {
        self.label = label
        self.help = help
        self.trailing = trailing
    }

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(Ember.Font.body)
                    .foregroundColor(Ember.primaryText(scheme))
                if let help = help {
                    Text(help)
                        .font(Ember.Font.caption)
                        .foregroundColor(Ember.tertiaryText(scheme))
                }
            }
            Spacer()
            trailing()
        }
        .padding(.vertical, 6)
    }
}

// MARK: - General

struct GeneralSettingsPane: View {
    @EnvironmentObject var settings: SettingsManager
    @ObservedObject private var launchManager = LaunchAtLoginManager.shared
    @StateObject private var updater = UpdaterManager.shared
    @Environment(\.colorScheme) private var scheme

    /// Footer copy tracks the chosen check frequency so the group
    /// always describes what the app is actually doing.
    private var updatesFooter: String {
        switch updater.checkFrequency {
        case .off:
            return "Background update checks are off. Use Check Now whenever you want to look for a new version."
        case .daily:
            return "Clippy checks for new versions once a day. Your Mac tells you when one is ready."
        case .every3Days:
            return "Clippy checks for new versions every 3 days. Your Mac tells you when one is ready."
        case .weekly:
            return "Clippy checks for new versions weekly. Your Mac tells you when one is ready."
        case .monthly:
            return "Clippy checks for new versions monthly. Your Mac tells you when one is ready."
        }
    }

    var body: some View {
        SettingsPane(title: "General", subtitle: "How Clippy starts, looks, and what you see.") {
            SettingsGroup("Startup") {
                SettingsRow("Launch Clippy on login", help: "Start Clippy automatically when you log in") {
                    Toggle("", isOn: $launchManager.isEnabled).labelsHidden()
                }
            }

            SettingsGroup("Updates", footer: updatesFooter) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 3) {
                        HStack(spacing: 6) {
                            Text("Version \(updater.currentVersion)")
                                .font(Ember.Font.body)
                                .foregroundColor(Ember.primaryText(scheme))
                            Text("build \(updater.build)")
                                .font(Ember.Font.caption)
                                .foregroundColor(Ember.tertiaryText(scheme))
                        }
                        if let date = updater.lastCheckDate {
                            Text("Last checked \(date, style: .relative) ago")
                                .font(Ember.Font.caption)
                                .foregroundColor(Ember.tertiaryText(scheme))
                        } else {
                            Text("Never checked yet")
                                .font(Ember.Font.caption)
                                .foregroundColor(Ember.tertiaryText(scheme))
                        }
                    }

                    Spacer()

                    Button {
                        updater.checkForUpdates()
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: "arrow.clockwise")
                            Text("Check Now")
                        }
                    }
                    .buttonStyle(PrimaryActionButtonStyle())
                    .disabled(!updater.canCheckForUpdates)
                }
                .padding(.vertical, 4)

                Divider().opacity(0.2)

                // Issue #10 — configurable background check frequency,
                // including turning scheduled checks off entirely.
                // Manual "Check Now" always works regardless.
                SettingsRow("Check for updates",
                            help: "How often Clippy looks for new versions in the background") {
                    Picker("", selection: $updater.checkFrequency) {
                        ForEach(UpdaterManager.CheckFrequency.allCases) { freq in
                            Text(freq.displayName).tag(freq)
                        }
                    }
                    .labelsHidden()
                    .frame(width: 140)
                }
            }

            SettingsGroup("Appearance") {
                SettingsRow("Theme") {
                    Picker("", selection: $settings.appTheme) {
                        Text("System").tag("system")
                        Text("Light").tag("light")
                        Text("Dark").tag("dark")
                    }
                    .labelsHidden()
                    .frame(width: 120)
                }

                Divider().opacity(0.2)

                SettingsRow("Popover width", help: "\(settings.popoverWidth) px") {
                    Stepper("", value: $settings.popoverWidth, in: 300...800, step: 20).labelsHidden()
                }

                Divider().opacity(0.2)

                SettingsRow("Popover height", help: "\(settings.popoverHeight) px") {
                    Stepper("", value: $settings.popoverHeight, in: 300...1000, step: 20).labelsHidden()
                }
            }

            SettingsGroup("Visible Tabs", footer: "Show or hide tabs in the main popover.") {
                SettingsRow("Code") {
                    Toggle("", isOn: $settings.showCodeTab).labelsHidden()
                }
                Divider().opacity(0.2)
                SettingsRow("Images") {
                    Toggle("", isOn: $settings.showImagesTab).labelsHidden()
                }
                Divider().opacity(0.2)
                SettingsRow("Snippets") {
                    Toggle("", isOn: $settings.showSnippetsTab).labelsHidden()
                }
                Divider().opacity(0.2)
                SettingsRow("Starred") {
                    Toggle("", isOn: $settings.showFavoritesTab).labelsHidden()
                }
            }

            SettingsGroup("Storage", footer: "Pinned, starred, snippets and encrypted items are never pruned.") {
                SettingsRow("Auto-prune history",
                            help: "Delete oldest history items once the limit is reached") {
                    Toggle("", isOn: $settings.enableHistoryAutoPrune).labelsHidden()
                }
                Divider().opacity(0.2)
                SettingsRow("Text history limit",
                            help: "\(settings.historyTextLimit) text items kept · oldest deleted") {
                    Picker("", selection: $settings.historyTextLimit) {
                        Text("10").tag(10)
                        Text("25").tag(25)
                        Text("50").tag(50)
                        Text("75").tag(75)
                        Text("100").tag(100)
                    }
                    .labelsHidden()
                    .frame(width: 90)
                    .disabled(!settings.enableHistoryAutoPrune)
                }
                Divider().opacity(0.2)
                SettingsRow("Image history limit",
                            help: "\(settings.historyImageLimit) image items kept · files deleted from disk too") {
                    Picker("", selection: $settings.historyImageLimit) {
                        Text("5").tag(5)
                        Text("10").tag(10)
                        Text("15").tag(15)
                        Text("20").tag(20)
                    }
                    .labelsHidden()
                    .frame(width: 90)
                    .disabled(!settings.enableHistoryAutoPrune)
                }
                Divider().opacity(0.2)
                SettingsRow("Max size of a single text item",
                            help: "Texts longer than this are truncated when captured — prevents UI freeze on huge pastes") {
                    Picker("", selection: $settings.maxTextStorageLength) {
                        Text("50K chars").tag(50_000)
                        Text("100K chars").tag(100_000)
                        Text("500K chars").tag(500_000)
                        Text("1M chars").tag(1_000_000)
                        Text("Unlimited").tag(Int.max)
                    }
                    .labelsHidden()
                    .frame(width: 140)
                }
                Divider().opacity(0.2)
                StorageStatsRow()
            }
        }
    }
}

// MARK: - Storage Stats Row
//
// Shows a live "X items, Y MB images" summary plus a Clean Now
// button that fires a manual prune. Stats refresh on appear and
// after every manual clean, so the user sees the change immediately.
private struct StorageStatsRow: View {
    @State private var stats: HistoryStats?
    @State private var isWorking = false
    @State private var lastResult: String?

    var body: some View {
        SettingsRow("Current usage", help: summary) {
            Button {
                cleanNow()
            } label: {
                if isWorking {
                    ProgressView().controlSize(.small)
                } else {
                    Text("Clean now")
                }
            }
            .disabled(isWorking)
        }
        // Utility priority: stats read hits a background CoreData
        // context, and `.task`'s default .userInitiated QoS would sit
        // waiting on that lower-QoS work — a priority inversion.
        .task(priority: .utility) { await refreshStats() }
    }

    private var summary: String {
        if let last = lastResult { return last }
        guard let s = stats else { return "Calculating…" }
        return "\(s.historyItems) history · \(s.totalItems) total · \(s.imagesFormatted) images"
    }

    private func refreshStats() async {
        let newStats = await HistoryPruner.shared.currentStats()
        await MainActor.run { self.stats = newStats }
    }

    private func cleanNow() {
        // Utility priority so this user-triggered maintenance doesn't
        // sit at user-interactive QoS waiting on the background
        // CoreData prune — that mismatch is the "Hang Risk / priority
        // inversion" Xcode flags at the count(for:) calls.
        Task(priority: .utility) {
            isWorking = true
            let result = await HistoryPruner.shared.pruneNow()
            switch result {
            case .pruned(let count, let bytes, _):
                let bytesStr = ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
                lastResult = "Removed \(count) items, freed \(bytesStr)"
            case .noWorkNeeded:
                lastResult = "Already under the limit — nothing to clean"
            case .skippedDisabled:
                lastResult = "Auto-prune is disabled"
            case .failed:
                lastResult = "Clean failed — check Console for details"
            }
            await refreshStats()
            isWorking = false
        }
    }
}

// MARK: - Features

struct FeaturesSettingsPane: View {
    @EnvironmentObject var settings: SettingsManager

    var body: some View {
        SettingsPane(title: "Features", subtitle: "Turn on only what you use.") {
            SettingsGroup("Clipboard Monitoring", footer: "Controls what Clippy detects and tracks when you copy.") {
                SettingsRow("Auto code detection", help: "Tag copied text that looks like code") {
                    Toggle("", isOn: $settings.enableAutoCodeDetection).labelsHidden()
                }
                Divider().opacity(0.2)
                SettingsRow("Content detection", help: "URLs, colors, dates, JSON") {
                    Toggle("", isOn: $settings.enableContentDetection).labelsHidden()
                }
                Divider().opacity(0.2)
                SettingsRow("Duplicate detection", help: "Skip saving the same thing twice") {
                    Toggle("", isOn: $settings.enableDuplicateDetection).labelsHidden()
                }
                Divider().opacity(0.2)
                SettingsRow("Source app tracking", help: "Remember which app content came from") {
                    Toggle("", isOn: $settings.enableSourceAppTracking).labelsHidden()
                }
            }

            SettingsGroup("Tools") {
                SettingsRow("Sequential paste", help: "Copy many, paste one by one") {
                    Toggle("", isOn: $settings.enableSequentialPaste).labelsHidden()
                }
                Divider().opacity(0.2)
                SettingsRow("Screenshot editor", help: "Capture + annotate + OCR") {
                    Toggle("", isOn: $settings.enableScreenshot).labelsHidden()
                }
                Divider().opacity(0.2)
                SettingsRow("Grab screen text",
                            help: "⇧⌘2 — select any screen region, its text is copied instantly. Reads QR codes too") {
                    Toggle("", isOn: $settings.enableScreenTextGrab).labelsHidden()
                }
                if settings.enableScreenTextGrab {
                    Divider().opacity(0.2)
                    SettingsRow("Show grab confirmation",
                                help: "A brief \"✓ copied\" pill near the cursor after grabbing. Errors always show.") {
                        Toggle("", isOn: $settings.showScreenGrabHUD).labelsHidden()
                    }
                }
                Divider().opacity(0.2)
                SettingsRow("OCR text recognition", help: "Extract text from copied images") {
                    Toggle("", isOn: $settings.enableOCR).labelsHidden()
                }
                if settings.enableOCR {
                    Divider().opacity(0.2)
                    SettingsRow("Auto-OCR on capture",
                                help: "Read text in every copied image in the background — makes screenshots searchable") {
                        Toggle("", isOn: $settings.enableAutoOCR).labelsHidden()
                    }
                }
                Divider().opacity(0.2)
                SettingsRow("File converter", help: "Images, docs, audio, video, data formats") {
                    Toggle("", isOn: $settings.enableFileConverter).labelsHidden()
                }
                Divider().opacity(0.2)
                SettingsRow("Drag & Drop shelf", help: "Floating tray for temporary drag sources") {
                    Toggle("", isOn: $settings.enableDragDropShelf).labelsHidden()
                }
            }

            SettingsGroup("Quick Preview", footer: "Hotkey-triggered overlay for lightning-fast paste.") {
                SettingsRow("Enable Quick Preview") {
                    Toggle("", isOn: $settings.enableQuickPreview).labelsHidden()
                }
                if settings.enableQuickPreview {
                    Divider().opacity(0.2)
                    SettingsRow("Number of items", help: "\(settings.quickPreviewItemCount) items shown") {
                        Stepper("", value: $settings.quickPreviewItemCount, in: 3...50).labelsHidden()
                    }
                    Divider().opacity(0.2)
                    SettingsRow("Auto-close after paste") {
                        Toggle("", isOn: $settings.quickPreviewAutoClose).labelsHidden()
                    }
                }
            }

            SettingsGroup("Keyword Expansion", footer: "Type a keyword like ;sig to auto-expand into text.") {
                SettingsRow("Enable keyword expansion") {
                    Toggle("", isOn: $settings.isKeywordExpansionEnabled).labelsHidden()
                }
                if settings.isKeywordExpansionEnabled {
                    Divider().opacity(0.2)
                    SettingsRow("Timeout", help: String(format: "%.1f seconds", settings.snippetTimeoutDuration)) {
                        Stepper("", value: $settings.snippetTimeoutDuration, in: 1.0...10.0, step: 0.5).labelsHidden()
                    }
                }
            }
        }
    }
}

// MARK: - AI

struct AISettingsPane: View {
    @EnvironmentObject var settings: SettingsManager
    @State private var aiValidationState: AIValidationState = .idle
    @State private var aiValidationMessage: String = ""
    @State private var aiUseCustomModel: Bool = false

    enum AIValidationState { case idle, testing, success, failure }

    var modelsForProvider: [(name: String, label: String)] {
        switch settings.aiProvider {
        case "openai":
            return [
                ("gpt-4o-mini", "GPT-4o Mini (fast)"),
                ("gpt-4o", "GPT-4o"),
                ("gpt-4.1-mini", "GPT-4.1 Mini"),
                ("gpt-4.1", "GPT-4.1"),
                ("o3-mini", "o3-mini (reasoning)"),
            ]
        case "anthropic":
            return [
                ("claude-sonnet-4-5-20250929", "Claude Sonnet 4.5"),
                ("claude-haiku-4-5-20251001", "Claude Haiku 4.5"),
                ("claude-opus-4-6", "Claude Opus 4.6"),
            ]
        case "google":
            return [
                ("gemini-2.0-flash", "Gemini 2.0 Flash"),
                ("gemini-2.5-pro", "Gemini 2.5 Pro"),
                ("gemini-2.5-flash", "Gemini 2.5 Flash"),
            ]
        default:
            return []
        }
    }

    var isCustomModel: Bool {
        let known = modelsForProvider.map { $0.name }
        return !known.contains(settings.aiModel) && !settings.aiModel.isEmpty
    }

    var body: some View {
        SettingsPane(title: "AI", subtitle: "Transform your clipboard with summaries, translations, and more.") {
            SettingsGroup("Enable") {
                SettingsRow("AI features", help: "Unlock Summarize, Translate, Fix Grammar, and 8+ more actions") {
                    Toggle("", isOn: $settings.enableAI).labelsHidden()
                }
                if settings.enableAI {
                    Divider().opacity(0.2)
                    SettingsRow("Auto-title long items",
                                help: "Runs on-device with Apple Intelligence or Ollama. Skipped for cloud providers to avoid per-request costs") {
                        Toggle("", isOn: $settings.enableAutoTitle).labelsHidden()
                    }
                    Divider().opacity(0.2)
                    SettingsRow("Suggest templates",
                                help: "Notices text you copy repeatedly with only the details changed and offers to turn it into a reusable snippet. On-device only") {
                        Toggle("", isOn: $settings.enableTemplateDetection).labelsHidden()
                    }
                }
            }

            if settings.enableAI {
                SettingsGroup("Provider", footer: "Apple Intelligence runs entirely on-device — no setup, no API key. Cloud providers are more capable on complex tasks but require a key.") {
                    SettingsRow("Provider") {
                        // Apple Intelligence is always listed so users
                        // discover it; the Status row below explains
                        // when it isn't usable on this Mac.
                        Picker("", selection: $settings.aiProvider) {
                            Text("Apple Intelligence (on-device)").tag("apple")
                            Text("Ollama (local)").tag("ollama")
                            Text("OpenAI").tag("openai")
                            Text("Anthropic").tag("anthropic")
                            Text("Google Gemini").tag("google")
                        }
                        .labelsHidden()
                        .frame(width: 220)
                        .onChange(of: settings.aiProvider) { _ in
                            aiValidationState = .idle
                            aiValidationMessage = ""
                            aiUseCustomModel = false
                            if settings.aiProvider != "ollama" && settings.aiProvider != "apple" {
                                let models = modelsForProvider
                                if !models.isEmpty { settings.aiModel = models[0].name }
                            }
                        }
                    }

                    Divider().opacity(0.2)

                    if settings.aiProvider == "apple" {
                        // Apple Intelligence: nothing to configure.
                        // Just a status indicator so users know if
                        // the on-device model is ready.
                        SettingsRow("Status") {
                            HStack(spacing: 6) {
                                Image(systemName: AppleFoundationModelsClient.isReady
                                      ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                                    .foregroundColor(AppleFoundationModelsClient.isReady ? .green : .orange)
                                Text(AppleFoundationModelsClient.isReady
                                     ? "On-device model ready"
                                     : (AppleFoundationModelsClient.availabilityMessage() ?? "Unavailable"))
                                    .font(.caption)
                                    .multilineTextAlignment(.trailing)
                            }
                        }
                    } else if settings.aiProvider == "ollama" {
                        SettingsRow("Ollama URL") {
                            TextField("http://localhost:11434", text: $settings.ollamaURL)
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 220)
                        }
                        Divider().opacity(0.2)
                        SettingsRow("Model", help: "Run ollama pull llama3.2 in Terminal") {
                            TextField("llama3.2", text: $settings.ollamaModel)
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 180)
                        }
                    } else {
                        SettingsRow("API key") {
                            SecureField("sk-…", text: $settings.aiAPIKey)
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 220)
                        }
                        Divider().opacity(0.2)
                        SettingsRow("Model") {
                            Picker("", selection: $settings.aiModel) {
                                ForEach(modelsForProvider, id: \.name) { model in
                                    Text(model.label).tag(model.name)
                                }
                                Divider()
                                if isCustomModel || aiUseCustomModel {
                                    Text(settings.aiModel).tag(settings.aiModel)
                                }
                                Text("Custom…").tag("__custom__")
                            }
                            .labelsHidden()
                            .frame(width: 220)
                            .onChange(of: settings.aiModel) { newValue in
                                if newValue == "__custom__" {
                                    aiUseCustomModel = true
                                    settings.aiModel = ""
                                } else {
                                    aiUseCustomModel = false
                                }
                            }
                        }
                        if aiUseCustomModel || isCustomModel {
                            Divider().opacity(0.2)
                            SettingsRow("Custom model") {
                                TextField("model-id", text: $settings.aiModel)
                                    .textFieldStyle(.roundedBorder)
                                    .frame(width: 220)
                            }
                        }
                    }

                    Divider().opacity(0.2)

                    HStack {
                        Spacer()
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
                                        aiValidationMessage = "Connection successful"
                                    }
                                }
                            }
                        } label: {
                            HStack(spacing: 6) {
                                if aiValidationState == .testing {
                                    ProgressView().controlSize(.small)
                                } else if aiValidationState == .success {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(Ember.Palette.moss)
                                } else if aiValidationState == .failure {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundColor(Ember.Palette.rust)
                                }
                                Text("Test Connection")
                            }
                        }
                        .buttonStyle(PrimaryActionButtonStyle())
                        .disabled(aiValidationState == .testing)
                    }
                    .padding(.top, 4)

                    if !aiValidationMessage.isEmpty {
                        Text(aiValidationMessage)
                            .font(Ember.Font.caption)
                            .foregroundColor(aiValidationState == .success ? Ember.Palette.moss : Ember.Palette.rust)
                            .textSelection(.enabled)
                            .padding(.top, 4)
                    }
                }

                SettingsGroup("Available Actions") {
                    VStack(alignment: .leading, spacing: 10) {
                        aiActionRow("text.bubble", "Summarize")
                        aiActionRow("arrow.up.left.and.arrow.down.right", "Expand")
                        aiActionRow("checkmark.circle", "Fix Grammar")
                        aiActionRow("globe", "Translate (30+ languages)")
                        aiActionRow("list.bullet", "Convert to Bullet Points")
                        aiActionRow("envelope", "Draft Email")
                        aiActionRow("chevron.left.forwardslash.chevron.right", "Explain / Optimize / Debug Code")
                        aiActionRow("text.cursor", "Free Prompt")
                    }
                }
            }
        }
    }

    private func aiActionRow(_ icon: String, _ title: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .foregroundColor(Ember.Palette.amber)
                .frame(width: 16)
            Text(title)
                .font(Ember.Font.body)
        }
    }
}

// MARK: - Shortcuts

struct ShortcutsSettingsPane: View {
    @EnvironmentObject var settings: SettingsManager

    var body: some View {
        SettingsPane(title: "Shortcuts", subtitle: "Summon Clippy from anywhere. Customize everything.") {
            SettingsGroup("Main") {
                shortcutRow("Show / Hide", $settings.hotkeyKey, $settings.hotkeyModifiers)
                Divider().opacity(0.2)
                shortcutRow("Paste Selected", $settings.pasteAllHotkeyKey, $settings.pasteAllHotkeyModifiers)
                Divider().opacity(0.2)
                shortcutRow("Quick Preview", $settings.quickPreviewHotkeyKey, $settings.quickPreviewHotkeyModifiers)
            }

            SettingsGroup("Sequential Paste") {
                shortcutRow("Sequential Copy", $settings.sequentialCopyHotkeyKey, $settings.sequentialCopyHotkeyModifiers)
                Divider().opacity(0.2)
                shortcutRow("Sequential Paste", $settings.sequentialPasteHotkeyKey, $settings.sequentialPasteHotkeyModifiers)
                Divider().opacity(0.2)
                shortcutRow("Clear Queue", $settings.clearQueueHotkeyKey, $settings.clearQueueHotkeyModifiers)
            }

            SettingsGroup("Tools") {
                shortcutRow("Screenshot", $settings.screenshotHotkeyKey, $settings.screenshotHotkeyModifiers)
                Divider().opacity(0.2)
                shortcutRow("Grab Screen Text", $settings.screenTextGrabHotkeyKey, $settings.screenTextGrabHotkeyModifiers)
                Divider().opacity(0.2)
                shortcutRow("App Switcher", $settings.switcherHotkeyKey, $settings.switcherHotkeyModifiers)
            }
        }
    }

    private func shortcutRow(_ label: String, _ key: Binding<String>, _ modifiers: Binding<UInt>) -> some View {
        SettingsRow(label) {
            HotkeySettingsView(hotkeyKey: key, hotkeyModifiers: modifiers)
        }
    }
}

// MARK: - Snippets

struct SnippetsSettingsPane: View {
    @EnvironmentObject var settings: SettingsManager
    @State private var subSection: SnippetSection = .variables

    enum SnippetSection: String, CaseIterable {
        case variables, categories

        var title: String {
            switch self {
            case .variables:  return "Variables"
            case .categories: return "Categories"
            }
        }

        var icon: String {
            switch self {
            case .variables:  return "textformat.abc"
            case .categories: return "folder"
            }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 4) {
                ForEach(SnippetSection.allCases, id: \.self) { s in
                    snippetPill(s)
                }
                Spacer()
            }
            .padding(.horizontal, Ember.Space.xl)
            .padding(.top, Ember.Space.xl)
            .padding(.bottom, Ember.Space.md)

            Group {
                switch subSection {
                case .variables:  SnippetVariablesView()
                case .categories: SnippetCategoriesView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private func snippetPill(_ s: SnippetSection) -> some View {
        let active = subSection == s
        return Button {
            withAnimation(Ember.Motion.snap) { subSection = s }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: s.icon).font(.system(size: 11, weight: .semibold))
                Text(s.title).font(.system(size: 12, weight: .medium))
            }
            .foregroundColor(active ? .white : .secondary)
            .padding(.horizontal, 12)
            .padding(.vertical, 5)
            .background(
                Capsule()
                    .fill(active ? AnyShapeStyle(
                        LinearGradient(
                            colors: [Ember.Palette.amber, Ember.Palette.amberDark],
                            startPoint: .top, endPoint: .bottom
                        )
                    ) : AnyShapeStyle(Color.clear))
            )
            .overlay(
                Capsule().strokeBorder(active ? .clear : Ember.Palette.smoke.opacity(0.25), lineWidth: 0.5)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Windows (Dock Preview)

struct WindowsSettingsPane: View {
    @EnvironmentObject var settings: SettingsManager

    var body: some View {
        SettingsPane(title: "Windows", subtitle: "Hover over the Dock to see live previews. Switch windows faster.") {
            SettingsGroup("Dock Preview") {
                SettingsRow("Enable Dock Preview") {
                    Toggle("", isOn: $settings.enableDockPreview).labelsHidden()
                }
            }

            if settings.enableDockPreview {
                SettingsGroup("Appearance") {
                    SettingsRow("Animation style") {
                        Picker("", selection: $settings.dockPreviewAnimationStyle) {
                            Text("Spring").tag("spring")
                            Text("Ease").tag("easeInOut")
                            Text("Linear").tag("linear")
                            Text("None").tag("none")
                        }.labelsHidden().frame(width: 130)
                    }
                    Divider().opacity(0.2)
                    SettingsRow("Preview size") {
                        Picker("", selection: $settings.dockPreviewSize) {
                            Text("Small").tag("small")
                            Text("Medium").tag("medium")
                            Text("Large").tag("large")
                            Text("X-Large").tag("xlarge")
                            Text("XX-Large").tag("xxlarge")
                        }.labelsHidden().frame(width: 130)
                    }
                    Divider().opacity(0.2)
                    SettingsRow("Hover delay", help: String(format: "%.1fs — 0s means instant", settings.dockPreviewHoverDelay)) {
                        Slider(value: $settings.dockPreviewHoverDelay, in: 0.0...2.0, step: 0.1)
                            .frame(width: 140)
                    }
                    Divider().opacity(0.2)
                    SettingsRow("Show window titles") {
                        Toggle("", isOn: $settings.showWindowTitles).labelsHidden()
                    }
                    Divider().opacity(0.2)
                    SettingsRow("Launch animation",
                                help: "How the panel animates in when you hover the Dock") {
                        Picker("", selection: $settings.dockPreviewLaunchAnimation) {
                            Text("Fade stagger").tag("fade-stagger")
                            Text("Fan-out").tag("fan-out")
                            Text("Scale pop").tag("scale-pop")
                            Text("None").tag("none")
                        }.labelsHidden().frame(width: 130)
                    }
                    Divider().opacity(0.2)
                    SettingsRow("Material",
                                help: "Auto uses Liquid Glass on macOS 26+, translucent everywhere else") {
                        Picker("", selection: $settings.dockPreviewMaterial) {
                            Text("Auto").tag("auto")
                            Text("Translucent").tag("translucent")
                            Text("Solid").tag("solid")
                        }.labelsHidden().frame(width: 130)
                    }
                }

                SettingsGroup("Interaction") {
                    SettingsRow("Keyboard shortcuts", help: "1-9, arrows, Enter, ESC") {
                        Toggle("", isOn: $settings.enableDockPreviewKeyboardShortcuts).labelsHidden()
                    }
                    if settings.enableDockPreviewKeyboardShortcuts {
                        Divider().opacity(0.2)
                        SettingsRow("Show key hints",
                                    help: "When to show the 1-9 numeric badges and footer") {
                            Picker("", selection: $settings.dockPreviewKeyboardHintMode) {
                                Text("Always").tag("always")
                                Text("On keypress").tag("on-keypress")
                                Text("Never").tag("never")
                            }.labelsHidden().frame(width: 130)
                        }
                    }
                    Divider().opacity(0.2)
                    SettingsRow("Trackpad gestures") {
                        Toggle("", isOn: $settings.enableDockPreviewGestures).labelsHidden()
                    }
                    if settings.enableDockPreviewGestures {
                        Divider().opacity(0.2)
                        SettingsRow("Swipe up") {
                            actionPicker($settings.dockSwipeUpAction)
                        }
                        Divider().opacity(0.2)
                        SettingsRow("Swipe down") {
                            actionPicker($settings.dockSwipeDownAction)
                        }
                    }
                    Divider().opacity(0.2)
                    SettingsRow("Middle click") {
                        actionPicker($settings.middleClickAction)
                    }
                }

                SettingsGroup("Performance") {
                    SettingsRow("Window caching") {
                        Toggle("", isOn: $settings.enableWindowCaching).labelsHidden()
                    }
                    if settings.enableWindowCaching {
                        Divider().opacity(0.2)
                        SettingsRow("Max cache size") {
                            Picker("", selection: $settings.maxCacheSizeMB) {
                                Text("50 MB").tag(50)
                                Text("100 MB").tag(100)
                                Text("200 MB").tag(200)
                                Text("500 MB").tag(500)
                                Text("Unlimited").tag(Int.max)
                            }.labelsHidden().frame(width: 130)
                        }
                        Divider().opacity(0.2)
                        SettingsRow("Auto-clear on memory pressure") {
                            Toggle("", isOn: $settings.enableMemoryPressureHandling).labelsHidden()
                        }
                        Divider().opacity(0.2)
                        HStack {
                            Text(MemoryManager.shared.getFormattedStats())
                                .font(Ember.Font.caption)
                                .foregroundColor(.secondary)
                            Spacer()
                            Button("Clear Now") {
                                Task { @MainActor in
                                    MemoryManager.shared.clearAllCaches()
                                }
                            }
                            .controlSize(.small)
                        }
                        .padding(.vertical, 4)
                    }
                }

                SettingsGroup("Live Preview", footer: "Uses ScreenCaptureKit to stream 15 FPS live window content.") {
                    SettingsRow("Enable live preview") {
                        Toggle("", isOn: $settings.enableAutoRefresh).labelsHidden()
                    }
                }
            }
        }
    }

    private func actionPicker(_ binding: Binding<String>) -> some View {
        Picker("", selection: binding) {
            Text("None").tag("none")
            Text("Close").tag("close")
            Text("Minimize").tag("minimize")
            Text("Select").tag("select")
        }.labelsHidden().frame(width: 110)
    }
}

// MARK: - Hotkey field (preserved)

struct HotkeySettingsView: View {
    @Binding var hotkeyKey: String
    @Binding var hotkeyModifiers: UInt

    var body: some View {
        HStack(spacing: 3) {
            modifierToggle("⌘", flag: .command)
            modifierToggle("⇧", flag: .shift)
            modifierToggle("⌥", flag: .option)
            modifierToggle("⌃", flag: .control)

            TextField("", text: $hotkeyKey)
                .frame(width: 38)
                .multilineTextAlignment(.center)
                .textFieldStyle(.roundedBorder)
                .onChange(of: hotkeyKey) { newValue in
                    if newValue.count > 1 { hotkeyKey = String(newValue.prefix(1)) }
                }
        }
    }

    private func modifierToggle(_ label: String, flag: NSEvent.ModifierFlags) -> some View {
        Toggle(label, isOn: Binding(
            get: { hotkeyModifiers & flag.rawValue != 0 },
            set: { isOn in hotkeyModifiers = isOn ? hotkeyModifiers | flag.rawValue : hotkeyModifiers & ~flag.rawValue }
        ))
        .toggleStyle(.button)
        .controlSize(.small)
    }
}
