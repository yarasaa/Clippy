//
//  ClipboardDetailView.swift
//  Clippy
//

import SwiftUI
import CoreData

struct ClipboardDetailView: View {
    @ObservedObject var item: ClipboardItemEntity
    @ObservedObject var monitor: ClipboardMonitor
    @EnvironmentObject var settings: SettingsManager
    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) var scheme

    @State private var didCopy = false
    @State private var didPaste = false
    @State private var isScanning = false
    @State private var showAppPicker = false
    @State private var showInspector = true

    @State private var editedText: String?
    @State private var editedTitle: String?
    @State private var editedKeyword: String?
    @State private var editedAppRules: String?
    @State private var editedCategory: String?

    private var hasEdits: Bool {
        editedText != nil || editedTitle != nil || editedKeyword != nil ||
        editedAppRules != nil || editedCategory != nil
    }

    var body: some View {
        HStack(spacing: 0) {
            actionRail

            Divider().opacity(0.3)

            mainColumn
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            if showInspector {
                Divider().opacity(0.3)
                inspectorSidebar
                    .frame(width: 210)
                    .transition(.move(edge: .trailing).combined(with: .opacity))
            }
        }
        .background(Ember.surface(scheme))
        .preferredColorScheme(colorSchemeOverride)
        .onAppear {
            editedTitle = item.title
            editedText = item.content
            editedKeyword = item.keyword
            editedAppRules = item.applicationRules
            editedCategory = item.category
        }
        .sheet(isPresented: $showAppPicker) {
            AppPickerView(selectedIdentifiers: Binding(
                get: { Set((editedAppRules ?? "").split(separator: ",").map { String($0).trimmingCharacters(in: .whitespaces) }) },
                set: { newIdentifiers in editedAppRules = newIdentifiers.sorted().joined(separator: ",") }
            ))
            .environmentObject(settings)
        }
        .frame(minWidth: 620, idealWidth: 760, minHeight: 440, idealHeight: 560)
    }

    // MARK: - Action Rail (left)

    private var actionRail: some View {
        VStack(spacing: Ember.Space.xs) {
            railIcon(
                systemName: item.isFavorite ? "star.fill" : "star",
                color: item.isFavorite ? Ember.Palette.amber : nil,
                tooltip: item.isFavorite ? "Unstar" : "Star"
            ) {
                withAnimation(Ember.Motion.snap) {
                    monitor.toggleFavorite(for: item.id ?? UUID())
                }
            }

            railIcon(
                systemName: item.isPinned ? "pin.fill" : "pin",
                color: item.isPinned ? Ember.Palette.amber : nil,
                tooltip: item.isPinned ? "Unpin" : "Pin"
            ) {
                withAnimation(Ember.Motion.snap) {
                    monitor.togglePin(for: item.id ?? UUID())
                }
            }

            railIcon(
                systemName: item.isEncrypted ? "lock.fill" : "lock",
                color: item.isEncrypted ? Ember.Palette.amber : nil,
                tooltip: item.isEncrypted ? "Decrypt" : "Encrypt"
            ) {
                monitor.toggleEncryption(for: item.id ?? UUID())
            }

            Divider()
                .padding(.vertical, Ember.Space.xs)
                .opacity(0.3)

            railIcon(systemName: "square.and.arrow.up", tooltip: "Share") {
                shareItem()
            }

            if item.contentType == "image" && settings.enableOCR {
                railIcon(
                    systemName: isScanning ? "arrow.triangle.2.circlepath" : "text.viewfinder",
                    tooltip: "Recognize Text (OCR)"
                ) {
                    isScanning = true
                    Task {
                        await monitor.recognizeText(for: item)
                        dismiss()
                    }
                }
                .disabled(isScanning)
            }

            Spacer()

            Divider().opacity(0.3)

            railIcon(
                systemName: showInspector ? "sidebar.right" : "sidebar.left",
                tooltip: showInspector ? "Hide Inspector" : "Show Inspector"
            ) {
                withAnimation(Ember.Motion.smooth) { showInspector.toggle() }
            }

            railIcon(
                systemName: "trash",
                color: Ember.Palette.rust.opacity(0.8),
                tooltip: "Delete"
            ) {
                monitor.delete(item: item)
                dismiss()
            }
        }
        .padding(.horizontal, 6)
        .padding(.vertical, Ember.Space.sm)
        .frame(width: 40)
    }

    private func railIcon(systemName: String, color: Color? = nil, tooltip: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(color ?? Ember.secondaryText(scheme))
                .frame(width: 28, height: 28)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background(
            RoundedRectangle(cornerRadius: Ember.Radius.sm)
                .fill(Color.clear)
        )
        .help(tooltip)
    }

    // MARK: - Main Column (center)

    private var mainColumn: some View {
        VStack(spacing: 0) {
            heroHeader
            Divider().opacity(0.3)
            contentArea
            Divider().opacity(0.3)
            bottomActionBar
        }
    }

    // MARK: Hero Header

    private var heroHeader: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Title (editable inline, compact)
            TextField("Untitled", text: Binding(
                get: { editedTitle ?? item.title ?? "" },
                set: { editedTitle = $0 }
            ))
            .textFieldStyle(.plain)
            .font(.system(size: 18, weight: .bold, design: .rounded))
            .foregroundColor(Ember.primaryText(scheme))

            // Meta line
            HStack(spacing: Ember.Space.sm) {
                if let bundleId = item.sourceAppBundleIdentifier {
                    IconView(bundleIdentifier: bundleId, monitor: monitor, size: 14)
                        .opacity(0.85)
                }

                if let appName = item.sourceAppName {
                    Text(appName)
                        .font(Ember.Font.meta)
                        .foregroundColor(Ember.secondaryText(scheme))
                }

                dot()

                Text(item.date ?? Date(), style: .relative)
                    .font(Ember.Font.meta)
                    .foregroundColor(Ember.secondaryText(scheme))

                dot()

                typeChip

                if let content = item.content, item.isCode, let lang = detectLanguage(content) {
                    dot()
                    LanguageChip(language: lang)
                }

                Spacer()
            }
        }
        .padding(.horizontal, Ember.Space.lg)
        .padding(.top, Ember.Space.md)
        .padding(.bottom, Ember.Space.sm)
    }

    private func dot() -> some View {
        Circle()
            .fill(Ember.tertiaryText(scheme))
            .frame(width: 3, height: 3)
    }

    private var typeChip: some View {
        let label: String
        let icon: String
        switch item.contentType {
        case "image": label = "Image"; icon = "photo"
        default:
            if item.isCode { label = "Code"; icon = "chevron.left.forwardslash.chevron.right" }
            else { label = "Text"; icon = "doc.text" }
        }
        return HStack(spacing: 4) {
            Image(systemName: icon).font(.system(size: 9))
            Text(label).font(.system(size: 10, weight: .medium))
        }
        .foregroundColor(Ember.Palette.amber)
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(
            Capsule().fill(Ember.Palette.amberSoft)
        )
    }

    // MARK: Content Area

    @ViewBuilder
    private var contentArea: some View {
        if item.isEncrypted {
            encryptedContent
        } else if let contentStr = item.content, contentStr.count <= 50_000, item.toClipboardItem().isJSON {
            JSONDetailView(
                initialText: contentStr,
                onSave: { newText in
                    item.content = newText
                    monitor.scheduleSave()
                    dismiss()
                }
            )
        } else if item.contentType == "text" {
            textContentArea
        } else if item.contentType == "image", let path = item.content, let image = monitor.loadImage(from: path) {
            imageContentArea(image: image)
        }
    }

    private var encryptedContent: some View {
        VStack(spacing: Ember.Space.md) {
            Spacer()
            Image(systemName: "lock.fill")
                .font(.system(size: 44, weight: .light))
                .foregroundColor(Ember.Palette.amber)
            Text("Encrypted")
                .font(.system(size: 18, weight: .semibold, design: .rounded))
                .foregroundColor(Ember.primaryText(scheme))
            Text("Use the unlock action in the sidebar to decrypt.")
                .font(Ember.Font.caption)
                .foregroundColor(Ember.secondaryText(scheme))
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var textContentArea: some View {
        VStack(spacing: 0) {
            // Smart content preview (URL card, color card) — shown above the editable text
            if let content = item.content {
                let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
                if let url = detectURL(in: trimmed) {
                    urlCard(url)
                        .padding(Ember.Space.md)
                    Divider().opacity(0.3)
                } else if trimmed.count <= 50, let color = item.toClipboardItem().color {
                    colorCard(trimmed, color: color)
                        .padding(Ember.Space.md)
                    Divider().opacity(0.3)
                }
            }

            PlainTextEditor(text: Binding(
                get: { editedText ?? item.content ?? "" },
                set: { editedText = $0 }
            ))
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private func urlCard(_ url: URL) -> some View {
        HStack(spacing: Ember.Space.md) {
            Circle()
                .fill(LinearGradient(
                    colors: [Ember.Palette.sky, Ember.Palette.amber],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ))
                .frame(width: 40, height: 40)
                .overlay(
                    Text(String((url.host ?? "?").prefix(1)).uppercased())
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                )

            VStack(alignment: .leading, spacing: 2) {
                if let host = url.host {
                    Text(host)
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundColor(Ember.primaryText(scheme))
                }
                Text(url.absoluteString)
                    .font(Ember.Font.caption)
                    .foregroundColor(Ember.secondaryText(scheme))
                    .lineLimit(2)
            }

            Spacer()

            Button {
                NSWorkspace.shared.open(url)
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: "safari")
                    Text("Open")
                }
            }
            .buttonStyle(SecondaryActionButtonStyle())
        }
        .padding(Ember.Space.md)
        .background(
            RoundedRectangle(cornerRadius: Ember.Radius.lg)
                .fill(Ember.cardBackground(scheme))
        )
        .overlay(
            RoundedRectangle(cornerRadius: Ember.Radius.lg)
                .strokeBorder(Color.white.opacity(scheme == .dark ? 0.06 : 0.4), lineWidth: 0.5)
        )
    }

    private func colorCard(_ text: String, color: Color) -> some View {
        HStack(spacing: Ember.Space.md) {
            RoundedRectangle(cornerRadius: Ember.Radius.md)
                .fill(color)
                .frame(width: 64, height: 64)
                .overlay(
                    RoundedRectangle(cornerRadius: Ember.Radius.md)
                        .strokeBorder(.white.opacity(0.3), lineWidth: 1)
                )
                .emberShadow(Ember.Shadow.glow(color))

            VStack(alignment: .leading, spacing: 4) {
                Text(text)
                    .font(.system(size: 16, weight: .semibold, design: .monospaced))
                    .foregroundColor(Ember.primaryText(scheme))
                Text("Tap the Copy menu to convert formats (HEX, RGB, HSL…)")
                    .font(Ember.Font.caption)
                    .foregroundColor(Ember.secondaryText(scheme))
            }
            Spacer()
        }
    }

    private func imageContentArea(image: NSImage) -> some View {
        ScrollView([.horizontal, .vertical]) {
            Image(nsImage: image)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .cornerRadius(Ember.Radius.md)
                .overlay(
                    RoundedRectangle(cornerRadius: Ember.Radius.md)
                        .strokeBorder(Color.white.opacity(scheme == .dark ? 0.08 : 0.4), lineWidth: 0.5)
                )
                .padding(Ember.Space.xl)
                .frame(minWidth: 0, minHeight: 0)
        }
        .background(
            ZStack {
                // Subtle checker pattern for transparency awareness
                Ember.surface(scheme)
            }
        )
        .safeAreaInset(edge: .bottom) {
            HStack(spacing: Ember.Space.md) {
                StatItem(label: "Width",  value: Int(image.size.width))
                StatItem(label: "Height", value: Int(image.size.height))
                StatItem(label: "Ratio",  value: Int(image.size.width * 100 / max(image.size.height, 1)))
            }
            .padding(.horizontal, Ember.Space.lg)
            .padding(.vertical, Ember.Space.sm)
            .background(.ultraThinMaterial)
        }
    }

    // MARK: Bottom Action Bar

    private var bottomActionBar: some View {
        HStack(spacing: Ember.Space.sm) {
            if hasEdits {
                Button { save() } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark")
                        Text("Save")
                    }
                }
                .buttonStyle(PrimaryActionButtonStyle())
                .keyboardShortcut("s", modifiers: .command)
            }

            if let text = item.content, !text.isEmpty, item.contentType == "text" {
                Text(statsFor(text))
                    .font(.system(size: 10))
                    .foregroundColor(Ember.tertiaryText(scheme))
                    .lineLimit(1)
                    .truncationMode(.tail)
            }

            Spacer()

            Button {
                monitor.copyToClipboard(item: item.toClipboardItem())
                withAnimation(Ember.Motion.snap) { didCopy = true }
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    withAnimation { didCopy = false }
                }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: didCopy ? "checkmark" : "doc.on.doc")
                    Text(didCopy ? "Copied" : "Copy")
                }
            }
            .buttonStyle(SecondaryActionButtonStyle(success: didCopy))
            .keyboardShortcut("c", modifiers: [.command, .shift])

            Button {
                PasteManager.shared.pasteItem(item.toClipboardItem())
                withAnimation(Ember.Motion.snap) { didPaste = true }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    dismiss()
                }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: didPaste ? "checkmark" : "arrow.down.doc")
                    Text(didPaste ? "Pasted" : "Paste")
                }
            }
            .buttonStyle(PrimaryActionButtonStyle())
            .keyboardShortcut(.return, modifiers: [])
        }
        .padding(.horizontal, Ember.Space.md)
        .padding(.vertical, Ember.Space.sm)
    }

    // MARK: - Inspector Sidebar (right)

    private var inspectorSidebar: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Ember.Space.md) {
                inspectorSection(title: "Keyword", icon: "command") {
                    TextField("e.g., ;sig", text: Binding(
                        get: { editedKeyword ?? item.keyword ?? "" },
                        set: { editedKeyword = $0 }
                    ))
                    .textFieldStyle(.roundedBorder)
                    .font(Ember.Font.code)

                    Text("Type this keyword anywhere to expand instantly.")
                        .font(Ember.Font.caption)
                        .foregroundColor(Ember.tertiaryText(scheme))
                        .fixedSize(horizontal: false, vertical: true)
                }

                if settings.isCategorySystemEnabled, let keyword = item.keyword, !keyword.isEmpty {
                    inspectorSection(title: "Category", icon: "folder") {
                        Picker("", selection: Binding(
                            get: { editedCategory ?? item.category ?? "" },
                            set: { editedCategory = $0.isEmpty ? nil : $0 }
                        )) {
                            Text("None").tag("")
                            ForEach(settings.snippetCategories) { category in
                                Text("\(category.icon) \(category.name)").tag(category.name)
                            }
                        }
                        .labelsHidden()
                        .frame(maxWidth: .infinity)
                    }
                }

                inspectorSection(title: "Available In", icon: "app.dashed") {
                    let identifiers = (editedAppRules ?? item.applicationRules ?? "")
                        .split(separator: ",")
                        .map { String($0).trimmingCharacters(in: .whitespaces) }
                        .filter { !$0.isEmpty }

                    if identifiers.isEmpty {
                        HStack(spacing: 6) {
                            Image(systemName: "globe").font(.system(size: 11))
                            Text("All apps")
                                .font(Ember.Font.body)
                                .foregroundColor(Ember.secondaryText(scheme))
                        }
                    } else {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 6) {
                                ForEach(identifiers, id: \.self) { id in
                                    IconView(bundleIdentifier: id, monitor: monitor, size: 22)
                                }
                            }
                        }
                    }

                    Button("Configure…") { showAppPicker = true }
                        .buttonStyle(SecondaryActionButtonStyle())
                        .controlSize(.small)
                }

                if let keyword = item.keyword, !keyword.isEmpty {
                    inspectorSection(title: "Usage", icon: "chart.bar") {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("Times used")
                                    .font(Ember.Font.caption)
                                    .foregroundColor(Ember.secondaryText(scheme))
                                Spacer()
                                Text("\(item.usageCount)")
                                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                                    .foregroundColor(Ember.Palette.amber)
                            }

                            if let lastUsed = item.lastUsedDate {
                                HStack {
                                    Text("Last used")
                                        .font(Ember.Font.caption)
                                        .foregroundColor(Ember.secondaryText(scheme))
                                    Spacer()
                                    Text(lastUsed, style: .relative)
                                        .font(Ember.Font.caption)
                                        .foregroundColor(Ember.primaryText(scheme))
                                }
                            }
                        }
                    }
                }

                inspectorSection(title: "Details", icon: "info.circle") {
                    VStack(alignment: .leading, spacing: 4) {
                        detailLine(label: "Created", value: item.date.map { RelativeDateTimeFormatter().localizedString(for: $0, relativeTo: Date()) } ?? "—")
                        if let content = item.content, item.contentType == "text" {
                            detailLine(label: "Length", value: "\(content.count) chars")
                            detailLine(label: "Lines", value: "\(content.split(separator: "\n", omittingEmptySubsequences: false).count)")
                        }
                    }
                }
            }
            .padding(Ember.Space.md)
        }
        .background(Ember.cardBackground(scheme).opacity(0.5))
    }

    @ViewBuilder
    private func inspectorSection<Content: View>(title: String, icon: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: Ember.Space.sm) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 10))
                Text(title)
                    .font(.system(size: 10, weight: .semibold))
            }
            .foregroundColor(Ember.tertiaryText(scheme))
            .textCase(.uppercase)
            .tracking(0.8)

            content()
        }
    }

    private func detailLine(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(Ember.Font.caption)
                .foregroundColor(Ember.secondaryText(scheme))
            Spacer()
            Text(value)
                .font(Ember.Font.caption)
                .foregroundColor(Ember.primaryText(scheme))
        }
    }

    // MARK: - Helpers

    private func save() {
        if let newText = editedText, newText != item.content { item.content = newText }
        let newTitle = editedTitle?.trimmingCharacters(in: .whitespacesAndNewlines)
        if newTitle != item.title { item.title = (newTitle?.isEmpty ?? true) ? nil : newTitle }
        let newKeyword = editedKeyword?.trimmingCharacters(in: .whitespacesAndNewlines)
        if newKeyword != item.keyword { item.keyword = (newKeyword?.isEmpty ?? true) ? nil : newKeyword }
        let newRules = editedAppRules?.trimmingCharacters(in: .whitespacesAndNewlines)
        if newRules != item.applicationRules { item.applicationRules = (newRules?.isEmpty ?? true) ? nil : newRules }
        let newCategory = editedCategory?.trimmingCharacters(in: .whitespacesAndNewlines)
        if newCategory != item.category { item.category = (newCategory?.isEmpty ?? true) ? nil : newCategory }
        monitor.scheduleSave()
        dismiss()
    }

    private func shareItem() {
        var shareItems: [Any] = []
        if item.contentType == "image", let path = item.content {
            let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            let imageURL = appSupport.appendingPathComponent("Clippy").appendingPathComponent("Images").appendingPathComponent(path)
            if FileManager.default.fileExists(atPath: imageURL.path) {
                shareItems.append(imageURL)
            }
        } else if let content = item.content, !content.isEmpty {
            let tempURL = FileManager.default.temporaryDirectory
                .appendingPathComponent("clippy-share-\(Int(Date().timeIntervalSince1970)).txt")
            try? content.write(to: tempURL, atomically: true, encoding: .utf8)
            shareItems.append(tempURL)
        }
        guard !shareItems.isEmpty, let window = NSApp.keyWindow, let contentView = window.contentView else { return }
        let picker = NSSharingServicePicker(items: shareItems)
        picker.show(relativeTo: .zero, of: contentView, preferredEdge: .minY)
    }

    private func statsFor(_ text: String) -> String {
        let chars = text.count
        let words = text.split { !$0.isLetter && !$0.isNumber }.count
        let lines = text.split(separator: "\n", omittingEmptySubsequences: false).count
        return "\(chars) chars · \(words) words · \(lines) lines"
    }

    private func detectURL(in text: String) -> URL? {
        guard text.count <= 2048 else { return nil }
        guard let url = URL(string: text), let s = url.scheme, ["http", "https"].contains(s) else { return nil }
        return url
    }

    private func detectLanguage(_ code: String) -> String? {
        if code.contains("func ") && code.contains("->") { return "Swift" }
        if code.contains("def ") && code.contains(":") { return "Python" }
        if code.contains("function") || code.contains("const ") || code.contains("=>") { return "JavaScript" }
        if code.contains("interface ") || code.contains(": string") { return "TypeScript" }
        if code.contains("fn ") && code.contains("->") { return "Rust" }
        if code.contains("package ") && code.contains("func ") { return "Go" }
        if code.hasPrefix("{") || code.hasPrefix("[") { return "JSON" }
        if code.contains("<html") || code.contains("<div") { return "HTML" }
        if code.contains("{") && (code.contains("color:") || code.contains("display:")) { return "CSS" }
        return nil
    }

    private var colorSchemeOverride: ColorScheme? {
        switch settings.appTheme {
        case "light": return .light
        case "dark":  return .dark
        default:      return nil
        }
    }
}

// MARK: - Secondary Button Style

struct SecondaryActionButtonStyle: ButtonStyle {
    var success: Bool = false
    @Environment(\.colorScheme) var scheme

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12, weight: .medium))
            .foregroundColor(success ? Ember.Palette.moss : Ember.primaryText(scheme))
            .lineLimit(1)
            .fixedSize(horizontal: true, vertical: false)
            .padding(.horizontal, Ember.Space.md)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: Ember.Radius.md)
                    .fill(Ember.cardBackground(scheme))
            )
            .overlay(
                RoundedRectangle(cornerRadius: Ember.Radius.md)
                    .strokeBorder(Ember.Palette.smoke.opacity(0.25), lineWidth: 0.5)
            )
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(Ember.Motion.snap, value: configuration.isPressed)
    }
}

// MARK: - Plain Text Editor

struct PlainTextEditor: NSViewRepresentable {
    @Binding var text: String

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSTextView.scrollableTextView()
        let textView = scrollView.documentView as! NSTextView
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.delegate = context.coordinator
        textView.isRichText = false
        textView.isEditable = true
        textView.isSelectable = true
        textView.allowsUndo = true
        textView.font = NSFont.systemFont(ofSize: 13)
        textView.string = text
        textView.textContainerInset = NSSize(width: 14, height: 12)
        textView.backgroundColor = .clear
        textView.drawsBackground = false
        scrollView.drawsBackground = false
        scrollView.hasVerticalScroller = true

        // Ensure first-responder behavior: clicking anywhere inside the scroll view
        // should focus the text view and place the caret.
        DispatchQueue.main.async {
            scrollView.window?.makeFirstResponder(textView)
        }
        return scrollView
    }

    func updateNSView(_ nsView: NSScrollView, context: Context) {
        let textView = nsView.documentView as! NSTextView
        if textView.string != text { textView.string = text }
    }

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    class Coordinator: NSObject, NSTextViewDelegate {
        var parent: PlainTextEditor
        init(_ parent: PlainTextEditor) { self.parent = parent }
        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            parent.text = textView.string
        }
    }
}

// MARK: - Text Stats

struct TextStatsView: View {
    let text: String
    @Environment(\.colorScheme) var scheme

    var body: some View {
        HStack(spacing: Ember.Space.xl) {
            StatItem(label: "Characters", value: text.count)
            StatItem(label: "Words", value: text.split { !$0.isLetter && !$0.isNumber }.count)
            StatItem(label: "Lines", value: text.split(separator: "\n", omittingEmptySubsequences: false).count)
        }
        .padding(Ember.Space.md)
    }
}

struct StatItem: View {
    let label: String
    let value: Int
    @Environment(\.colorScheme) var scheme

    var body: some View {
        VStack(spacing: 2) {
            Text("\(value)")
                .font(.system(size: 16, weight: .semibold, design: .rounded))
                .foregroundColor(Ember.primaryText(scheme))
            Text(label)
                .font(Ember.Font.caption)
                .foregroundColor(Ember.secondaryText(scheme))
                .textCase(.uppercase)
                .tracking(0.6)
        }
    }
}

// MARK: - Icon View

struct IconView: View {
    let bundleIdentifier: String
    @ObservedObject var monitor: ClipboardMonitor
    var size: CGFloat = 24
    @State private var icon: NSImage?

    var body: some View {
        Group {
            if let icon = icon {
                Image(nsImage: icon).resizable()
            } else {
                ProgressView().scaleEffect(0.5)
            }
        }
        .frame(width: size, height: size)
        .onAppear {
            monitor.loadIcon(for: bundleIdentifier) { loadedIcon in self.icon = loadedIcon }
        }
    }
}
