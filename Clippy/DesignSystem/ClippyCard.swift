import SwiftUI
import Combine
import CoreData
import UniformTypeIdentifiers

// MARK: - ClippyCard
// Drop-in replacement for ClipboardRowView: same full functionality,
// restyled in the Ember design language with hover-revealed actions.

struct ClippyCard: View {
    @ObservedObject var item: ClipboardItemEntity
    let items: FetchedResults<ClipboardItemEntity>
    @Binding var comparisonData: ComparisonData?
    @ObservedObject var monitor: ClipboardMonitor
    let selectedTab: ContentView.Tab

    @EnvironmentObject var settings: SettingsManager
    @Environment(\.colorScheme) var scheme

    @State private var isHovered: Bool = false
    @State private var didPasteFlash: Bool = false
    @State private var aiTransformState: AITransformState? = nil

    private let commonLanguages = [
        "English", "Turkish", "Spanish", "French", "German",
        "Italian", "Portuguese", "Russian", "Chinese", "Japanese",
        "Korean", "Arabic", "Hindi", "Dutch", "Polish",
        "Swedish", "Norwegian", "Danish", "Finnish", "Greek",
        "Czech", "Romanian", "Hungarian", "Ukrainian", "Thai",
        "Vietnamese", "Indonesian", "Malay", "Filipino", "Hebrew"
    ]

    var isSelected: Bool {
        monitor.selectedItemIDs.contains(item.id ?? UUID())
    }

    var selectionIndex: Int? {
        guard let id = item.id,
              let idx = monitor.selectedItemIDs.firstIndex(of: id) else { return nil }
        return idx
    }

    // MARK: Body

    var body: some View {
        HStack(spacing: 0) {
            if item.isPinned {
                Ember.Palette.amber
                    .frame(width: 3)
                    .transition(.move(edge: .leading).combined(with: .opacity))
            }

            VStack(alignment: .leading, spacing: Ember.Space.sm) {
                metaRow
                contentBody
            }
            .padding(.horizontal, Ember.Space.md)
            .padding(.vertical, Ember.Space.md)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .emberCard(scheme, highlighted: isSelected)
        .overlay(selectionBadge, alignment: .topLeading)
        .overlay(sequentialQueueBadge, alignment: .topTrailing)
        .overlay(pasteFlashOverlay)
        // No scaleEffect on hover — it forces the whole card into a Metal layer
        // re-composite on every hover, which is the main cause of jumpy hover.
        .animation(Ember.Motion.snap, value: isSelected)
        .animation(Ember.Motion.snap, value: item.isPinned)
        .onHover { hovering in
            // Snap hover state without animation — animating background colors on
            // every move-in/out churns the GPU and feels laggy. Instant feels native.
            isHovered = hovering
        }
        .contentShape(Rectangle())
        .onTapGesture {
            if NSEvent.modifierFlags.contains(.command) {
                monitor.toggleSelection(for: item.id ?? UUID())
            } else {
                monitor.appDelegate?.showDetailWindow(for: item)
            }
        }
        .onDrag {
            let provider: NSItemProvider
            let isMultiDrag = monitor.selectedItemIDs.count > 1 && monitor.selectedItemIDs.contains(item.id ?? UUID())

            if isMultiDrag {
                provider = monitor.createItemProviderForSelection()
            } else {
                provider = self.itemProvider(for: item)
            }

            DispatchQueue.main.async {
                NotificationCenter.default.post(name: .closeClippyPopover, object: nil)
                if isMultiDrag { monitor.clearSelection() }
            }
            return provider
        } preview: {
            dragPreview
        }
        .contextMenu { cardContextMenu }
        .popover(item: $aiTransformState) { state in
            AITransformView(
                text: state.text,
                action: state.action,
                targetLanguage: state.targetLanguage,
                customPrompt: state.customPrompt,
                onResult: { result in
                    if let itemID = item.id {
                        monitor.updateText(for: itemID, transformation: { _ in result })
                    }
                    aiTransformState = nil
                },
                onDismiss: { aiTransformState = nil }
            )
            .environmentObject(settings)
        }
    }

    // MARK: Meta row

    private var metaRow: some View {
        HStack(spacing: Ember.Space.sm) {
            HStack(spacing: Ember.Space.sm) {
                if let bundleId = item.sourceAppBundleIdentifier {
                    IconView(bundleIdentifier: bundleId, monitor: monitor, size: 14)
                        .opacity(0.85)
                }

                if let appName = item.sourceAppName {
                    Text(appName)
                        .font(Ember.Font.meta)
                        .foregroundColor(Ember.secondaryText(scheme))
                        .lineLimit(1)
                        .truncationMode(.tail)
                }

                Text("·")
                    .font(Ember.Font.meta)
                    .foregroundColor(Ember.tertiaryText(scheme))

                Text(relativeTime)
                    .font(Ember.Font.meta)
                    .foregroundColor(Ember.secondaryText(scheme))
                    .fixedSize()

                if let title = item.title, !title.isEmpty {
                    Text("·")
                        .font(Ember.Font.meta)
                        .foregroundColor(Ember.tertiaryText(scheme))
                    Text(title)
                        .font(Ember.Font.meta.weight(.medium))
                        .foregroundColor(Ember.Palette.amber)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
            }
            .layoutPriority(0)

            Spacer(minLength: Ember.Space.sm)

            if isHovered {
                hoverActions
                    .fixedSize()
                    .layoutPriority(1)
                    .transition(.opacity.combined(with: .move(edge: .trailing)))
            }
        }
    }

    private var relativeTime: String {
        guard let date = item.date else { return "" }
        let diff = Date().timeIntervalSince(date)
        if diff < 60 { return "now" }
        if diff < 3600 { return "\(Int(diff / 60))m" }
        if diff < 86400 { return "\(Int(diff / 3600))h" }
        if diff < 604800 { return "\(Int(diff / 86400))d" }
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter.string(from: date)
    }

    // MARK: Hover actions

    private var hoverActions: some View {
        HStack(spacing: Ember.Space.xs) {
            // URL quick open
            if item.contentType == "text",
               let content = item.content, content.count <= 2048,
               let url = URL(string: content), let s = url.scheme,
               ["http", "https"].contains(s) {
                iconButton(systemName: "safari", help: "Open URL") {
                    NSWorkspace.shared.open(url)
                }
            }

            // Calendar quick action
            if item.contentType == "text", item.detectedDate != nil {
                iconButton(systemName: "calendar.badge.plus", help: "Add to Calendar") {
                    monitor.createCalendarEvent(for: item)
                }
            }

            // Transform menu
            if item.contentType == "text" {
                transformationMenu
            }

            // Favorite
            iconButton(
                systemName: item.isFavorite ? "star.fill" : "star",
                color: item.isFavorite ? Ember.Palette.amber : Ember.secondaryText(scheme),
                help: item.isFavorite ? "Unstar" : "Star"
            ) {
                withAnimation(Ember.Motion.snap) {
                    monitor.toggleFavorite(for: item.id ?? UUID())
                }
            }

            // Pin
            iconButton(
                systemName: item.isPinned ? "pin.fill" : "pin",
                color: item.isPinned ? Ember.Palette.amber : Ember.secondaryText(scheme),
                help: item.isPinned ? "Unpin" : "Pin"
            ) {
                withAnimation(Ember.Motion.snap) {
                    monitor.togglePin(for: item.id ?? UUID())
                }
            }

            // Paste
            Button {
                pasteWithFlash()
            } label: {
                Text("Paste")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.white)
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
                    .padding(.horizontal, Ember.Space.sm + 2)
                    .padding(.vertical, 4)
                    .background(
                        Capsule().fill(
                            LinearGradient(
                                colors: [Ember.Palette.amber, Ember.Palette.amberDark],
                                startPoint: .top, endPoint: .bottom
                            )
                        )
                    )
            }
            .buttonStyle(.plain)
            .fixedSize()
            .help("Paste to active app")
        }
    }

    private func iconButton(systemName: String, color: Color? = nil, help: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(color ?? Ember.secondaryText(scheme))
                .frame(width: 22, height: 22)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(help)
    }

    // MARK: Transform menu

    private var transformationMenu: some View {
        let locale: Locale?
        if settings.appLanguage == "system" {
            if let langCode = Locale.preferredLanguages.first?.prefix(2) {
                locale = Locale(identifier: String(langCode))
            } else {
                locale = .current
            }
        } else {
            locale = Locale(identifier: String(settings.appLanguage.prefix(2)))
        }

        return Menu {
            if let itemID = item.id {
                Section("Transform Text") {
                    Button("All Uppercase") { monitor.updateText(for: itemID, transformation: { $0.uppercased(with: locale) }) }
                    Button("All Lowercase") { monitor.updateText(for: itemID, transformation: { $0.lowercased(with: locale) }) }
                    Button("Title Case") { monitor.updateText(for: itemID, transformation: { $0.capitalized(with: locale) }) }
                    Button("Trim Whitespace") { monitor.updateText(for: itemID, transformation: { $0.trimmingCharacters(in: .whitespacesAndNewlines) }) }
                }

                Section("Line Operations") {
                    Button("Remove Duplicate Lines") { monitor.removeDuplicateLines(for: itemID) }
                    Button("Join All Lines") { monitor.joinLines(for: itemID) }
                }

                Section("Coding") {
                    Button("Base64 Encode") {
                        monitor.updateText(for: itemID, transformation: { $0.data(using: .utf8)?.base64EncodedString() ?? $0 })
                    }
                    Button("Base64 Decode") {
                        monitor.updateText(for: itemID, transformation: { Data(base64Encoded: $0).flatMap { String(data: $0, encoding: .utf8) } ?? $0 })
                    }
                    Button("Encode as JSON String") { monitor.encodeAsJSONString(for: itemID) }
                    Button("Decode from JSON String") { monitor.decodeFromJSONString(for: itemID) }
                }

                if let content = item.content, content.count <= 50_000, item.toClipboardItem().isJSON {
                    Section("JSON") {
                        Button("Format JSON") { monitor.formatJSON(for: itemID) }
                        Button("Minify JSON") { monitor.minifyJSON(for: itemID) }
                    }
                }

                if settings.enableAI, AIService.shared.isConfigured, let content = item.content, !content.isEmpty {
                    Divider()
                    Section("AI") {
                        Button("Summarize") { runAIAction(.summarize, text: content) }
                        Button("Expand") { runAIAction(.expand, text: content) }
                        Button("Fix Grammar") { runAIAction(.fixGrammar, text: content) }
                        Button("Convert to Bullet Points") { runAIAction(.bulletPoints, text: content) }
                        Button("Draft Email") { runAIAction(.draftEmail, text: content) }

                        Menu("Translate to…") {
                            ForEach(commonLanguages, id: \.self) { lang in
                                Button(lang) { runAIAction(.translate, text: content, targetLanguage: lang) }
                            }
                        }

                        if item.isCode {
                            Divider()
                            Button("Explain Code") { runAIAction(.explainCode, text: content) }
                            Button("Add Comments") { runAIAction(.addComments, text: content) }
                            Button("Find Bugs") { runAIAction(.findBugs, text: content) }
                            Button("Optimize Code") { runAIAction(.optimizeCode, text: content) }
                        }
                    }
                }
            }
        } label: {
            Image(systemName: "wand.and.stars")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(Ember.secondaryText(scheme))
                .frame(width: 22, height: 22)
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
        .help("Transform")
    }

    // MARK: Content body

    @ViewBuilder
    private var contentBody: some View {
        if item.isEncrypted {
            encryptedView
        } else if item.contentType == "image" {
            imageContent
        } else if let content = item.content {
            textContent(content)
        }
    }

    private var encryptedView: some View {
        HStack(spacing: 6) {
            Image(systemName: "lock.fill").font(.system(size: 11))
            Text("Encrypted content").font(Ember.Font.body)
        }
        .foregroundColor(Ember.secondaryText(scheme))
    }

    @ViewBuilder
    private func textContent(_ content: String) -> some View {
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
        let preview = String(trimmed.prefix(500))

        VStack(alignment: .leading, spacing: Ember.Space.sm) {
            if let color = detectColor(in: trimmed) {
                colorPreview(trimmed, color: color)
            } else if let url = detectURL(in: trimmed) {
                urlPreview(url)
            } else if item.isCode {
                codePreview(preview)
            } else if trimmed.count <= 50_000, item.toClipboardItem().isJSON {
                jsonPreview(trimmed)
            } else {
                Text(preview)
                    .font(Ember.Font.body)
                    .foregroundColor(Ember.primaryText(scheme))
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func codePreview(_ code: String) -> some View {
        VStack(alignment: .leading, spacing: Ember.Space.sm) {
            Text(code)
                .font(Ember.Font.code)
                .foregroundColor(Ember.primaryText(scheme))
                .lineLimit(4)
                .fixedSize(horizontal: false, vertical: true)
                .padding(Ember.Space.sm)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: Ember.Radius.sm)
                        .fill(Ember.Palette.ink.opacity(scheme == .dark ? 0.3 : 0.04))
                )

            if let lang = detectLanguage(code) {
                LanguageChip(language: lang)
            }
        }
    }

    private func colorPreview(_ text: String, color: Color) -> some View {
        HStack(spacing: Ember.Space.md) {
            RoundedRectangle(cornerRadius: Ember.Radius.sm)
                .fill(color)
                .frame(width: 44, height: 44)
                .overlay(
                    RoundedRectangle(cornerRadius: Ember.Radius.sm)
                        .strokeBorder(.white.opacity(0.2), lineWidth: 1)
                )
                .emberShadow(Ember.Shadow.glow(color))

            Text(text)
                .font(Ember.Font.code)
                .foregroundColor(Ember.primaryText(scheme))
        }
    }

    private func urlPreview(_ url: URL) -> some View {
        HStack(spacing: Ember.Space.sm) {
            if let host = url.host {
                Circle()
                    .fill(LinearGradient(
                        colors: [Ember.Palette.sky, Ember.Palette.amber],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ))
                    .frame(width: 18, height: 18)
                    .overlay(
                        Text(String(host.prefix(1)).uppercased())
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.white)
                    )

                VStack(alignment: .leading, spacing: 2) {
                    Text(host)
                        .font(Ember.Font.body.weight(.medium))
                        .foregroundColor(Ember.primaryText(scheme))
                    Text(url.absoluteString)
                        .font(Ember.Font.caption)
                        .foregroundColor(Ember.secondaryText(scheme))
                        .lineLimit(1)
                }
            }
        }
    }

    private func jsonPreview(_ json: String) -> some View {
        HStack(spacing: Ember.Space.sm) {
            Text("{ }")
                .font(Ember.Font.code.weight(.medium))
                .foregroundColor(Ember.Palette.amber)

            Text(collapsedJSONPreview(json))
                .font(Ember.Font.code)
                .foregroundColor(Ember.secondaryText(scheme))
                .lineLimit(2)
        }
    }

    @ViewBuilder
    private var imageContent: some View {
        if let path = item.content, let image = monitor.loadImage(from: path) {
            VStack(alignment: .leading, spacing: Ember.Space.sm) {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(maxWidth: .infinity, maxHeight: 160)
                    .clipShape(RoundedRectangle(cornerRadius: Ember.Radius.md))

                HStack(spacing: Ember.Space.xs) {
                    Text("\(Int(image.size.width)) × \(Int(image.size.height))")
                    Text("·")
                    Text("PNG")
                }
                .font(Ember.Font.caption)
                .foregroundColor(Ember.tertiaryText(scheme))
            }
        }
    }

    // MARK: Drag preview

    @ViewBuilder
    private var dragPreview: some View {
        VStack {
            if item.contentType == "text" {
                Text(String((item.content ?? "").prefix(1000)))
                    .lineLimit(15)
                    .font(.body)
            } else if item.contentType == "image", let imagePath = item.content,
                      let image = monitor.loadImage(from: imagePath) {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxWidth: 200, maxHeight: 200)
            }
        }
        .padding(10)
        .background(.regularMaterial)
        .cornerRadius(8)
        .shadow(radius: 3)
    }

    // MARK: Selection / sequential badges

    @ViewBuilder
    private var selectionBadge: some View {
        if let idx = selectionIndex {
            Text("\(idx + 1)")
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundColor(.white)
                .frame(width: 18, height: 18)
                .background(Circle().fill(Ember.Palette.amber))
                .emberShadow(Ember.Shadow.glow())
                .offset(x: -6, y: -6)
                .transition(.scale.combined(with: .opacity))
        }
    }

    @ViewBuilder
    private var sequentialQueueBadge: some View {
        if settings.enableSequentialPaste, monitor.isPastingFromQueue,
           let id = item.id,
           let queueIndex = monitor.sequentialPasteQueueIDs.firstIndex(of: id) {
            let isNext = (queueIndex == monitor.sequentialPasteIndex % monitor.sequentialPasteQueueIDs.count)
            Text("\(queueIndex + 1)")
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(.white)
                .padding(5)
                .background(Circle().fill(isNext ? Ember.Palette.moss : Ember.Palette.amber))
                .offset(x: 8, y: -8)
                .help(isNext ? "Next to paste" : "")
        }
    }

    // MARK: Paste flash

    @ViewBuilder
    private var pasteFlashOverlay: some View {
        RoundedRectangle(cornerRadius: Ember.Radius.lg, style: .continuous)
            .fill(Ember.Palette.amber.opacity(didPasteFlash ? 0.15 : 0))
            .animation(.easeOut(duration: 0.4), value: didPasteFlash)
            .allowsHitTesting(false)
    }

    private func pasteWithFlash() {
        withAnimation { didPasteFlash = true }
        PasteManager.shared.pasteItem(item.toClipboardItem())
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            didPasteFlash = false
        }
    }

    // MARK: Context menu

    @ViewBuilder
    private var cardContextMenu: some View {
        Button { monitor.copyToClipboard(item: item.toClipboardItem()) } label: {
            Label("Copy", systemImage: "doc.on.doc")
        }

        Button { pasteWithFlash() } label: {
            Label("Paste", systemImage: "arrow.down.doc")
        }

        Button { shareClipboardItem() } label: {
            Label("Share…", systemImage: "square.and.arrow.up")
        }

        // Color converter
        if item.contentType == "text",
           let content = item.content,
           ColorConverter.detectFormat(content) != nil,
           let color = ColorConverter.parseColor(content) {

            Menu {
                let converted = ColorConverter.convertToAllFormats(color)

                colorFormatButton("HEX", value: converted.hex)
                colorFormatButton("HEX+Alpha", value: converted.hexWithAlpha)
                Divider()
                colorFormatButton("RGB", value: converted.rgb)
                colorFormatButton("RGBA", value: converted.rgba)
                Divider()
                colorFormatButton("HSL", value: converted.hsl)
                colorFormatButton("HSLA", value: converted.hsla)
            } label: {
                Label("Convert Color", systemImage: "paintpalette")
            }

            Divider()
        }

        // Compare
        if let compareItems = getItemsToCompare() {
            Button {
                monitor.appDelegate?.showDiffWindow(oldText: compareItems.0.content ?? "", newText: compareItems.1.content ?? "")
                monitor.clearSelection()
            } label: {
                Label("Compare…", systemImage: "square.split.2x1")
            }
        } else if monitor.selectedItemIDs.count > 0 {
            Label("Compare (select 2 text items)", systemImage: "square.split.2x1").disabled(true)
        }

        Divider()

        // Snippet export
        if selectedTab == .snippets {
            if let keyword = item.keyword, !keyword.isEmpty {
                Button {
                    exportSelectedSnippet(item: item)
                } label: {
                    Label("Export Snippet", systemImage: "square.and.arrow.up")
                }
            }
            Button {
                exportAllSnippets()
            } label: {
                Label("Export All Snippets", systemImage: "square.and.arrow.up.on.square")
            }
            Divider()
        }

        // Favorite / Pin quick toggle (also in hover, but handy in menu)
        Button {
            withAnimation(Ember.Motion.snap) { monitor.toggleFavorite(for: item.id ?? UUID()) }
        } label: {
            Label(item.isFavorite ? "Unstar" : "Star", systemImage: item.isFavorite ? "star.slash" : "star")
        }

        Button {
            withAnimation(Ember.Motion.snap) { monitor.togglePin(for: item.id ?? UUID()) }
        } label: {
            Label(item.isPinned ? "Unpin" : "Pin", systemImage: item.isPinned ? "pin.slash" : "pin")
        }

        // Encryption
        Button {
            monitor.toggleEncryption(for: item.id ?? UUID())
        } label: {
            Label(item.isEncrypted ? "Decrypt" : "Encrypt",
                  systemImage: item.isEncrypted ? "lock.open" : "lock")
        }

        Divider()

        // Combine images
        Menu("Combine Images") {
            Button {
                monitor.combineSelectedImagesAsNewItem(orientation: .vertical)
                monitor.clearSelection()
            } label: { Label("Vertically", systemImage: "arrow.down.to.line.compact") }

            Button {
                monitor.combineSelectedImagesAsNewItem(orientation: .horizontal)
                monitor.clearSelection()
            } label: { Label("Horizontally", systemImage: "arrow.right.to.line.compact") }
        }
        .disabled(!hasMultipleImagesSelected())

        Divider()

        Button(role: .destructive) {
            if monitor.selectedItemIDs.count > 1 && monitor.selectedItemIDs.contains(item.id ?? UUID()) {
                monitor.deleteSelectedItems()
            } else {
                monitor.delete(item: item)
            }
        } label: {
            let isMultiDelete = monitor.selectedItemIDs.count > 1 && monitor.selectedItemIDs.contains(item.id ?? UUID())
            let labelText = isMultiDelete ? "Delete \(monitor.selectedItemIDs.count) Items" : "Delete"
            Label(labelText, systemImage: "trash")
        }
    }

    private func colorFormatButton(_ label: String, value: String) -> some View {
        Button {
            copyToPasteboard(value)
        } label: {
            HStack {
                Text(label)
                Spacer()
                Text(value)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundColor(.secondary)
            }
        }
    }

    // MARK: Helpers

    private func runAIAction(_ action: AIAction, text: String, targetLanguage: String? = nil, customPrompt: String? = nil) {
        aiTransformState = AITransformState(text: text, action: action, targetLanguage: targetLanguage, customPrompt: customPrompt)
    }

    private func detectURL(in text: String) -> URL? {
        guard text.count <= 2048 else { return nil }
        guard let url = URL(string: text),
              let scheme = url.scheme,
              ["http", "https"].contains(scheme) else { return nil }
        return url
    }

    private func detectColor(in text: String) -> Color? {
        guard text.count <= 50 else { return nil }
        return item.toClipboardItem().color
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

    private func collapsedJSONPreview(_ json: String) -> String {
        let compacted = json
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "  ", with: " ")
        return String(compacted.prefix(120))
    }

    private func copyToPasteboard(_ text: String) {
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(text, forType: .string)
    }

    private func itemProvider(for item: ClipboardItemEntity) -> NSItemProvider {
        if item.contentType == "text", let text = item.content {
            return NSItemProvider(object: text as NSString)
        } else if item.contentType == "image", let path = item.content {
            if let imageURL = monitor.getImagesDirectory()?.appendingPathComponent(path) {
                return NSItemProvider(object: imageURL as NSURL)
            }
        }
        return NSItemProvider()
    }

    private func shareClipboardItem() {
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

    private func exportSelectedSnippet(item: ClipboardItemEntity) {
        guard let keyword = item.keyword, !keyword.isEmpty else { return }

        let panel = NSSavePanel()
        panel.allowedContentTypes = [.json]
        panel.nameFieldStringValue = "\(keyword)_snippet.json"
        panel.message = "Export snippet to JSON file"

        panel.begin { response in
            if response == .OK, let url = panel.url {
                do {
                    try SnippetExportManager.shared.exportSnippet(item: item, to: url)
                    showAlert(title: "Export Successful", message: "1 snippet was exported.", style: .informational)
                } catch {
                    showAlert(title: "Export Failed", message: error.localizedDescription, style: .critical)
                }
            }
        }
    }

    private func exportAllSnippets() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.json]
        panel.nameFieldStringValue = "snippets_export.json"
        panel.message = "Export all snippets to JSON"

        panel.begin { response in
            if response == .OK, let url = panel.url {
                do {
                    try SnippetExportManager.shared.exportSnippets(to: url)
                    let fetchRequest: NSFetchRequest<ClipboardItemEntity> = ClipboardItemEntity.fetchRequest()
                    fetchRequest.predicate = NSPredicate(format: "keyword != nil AND keyword != ''")
                    let count = (try? item.managedObjectContext?.count(for: fetchRequest)) ?? 0
                    showAlert(title: "Export Successful", message: "\(count) snippet\(count == 1 ? "" : "s") exported.", style: .informational)
                } catch {
                    showAlert(title: "Export Failed", message: error.localizedDescription, style: .critical)
                }
            }
        }
    }

    private func showAlert(title: String, message: String, style: NSAlert.Style) {
        DispatchQueue.main.async {
            let alert = NSAlert()
            alert.messageText = title
            alert.informativeText = message
            alert.alertStyle = style
            alert.addButton(withTitle: "OK")
            alert.runModal()
        }
    }

    private func hasMultipleImagesSelected() -> Bool {
        guard monitor.selectedItemIDs.count > 1 else { return false }

        let fetchRequest: NSFetchRequest<ClipboardItemEntity> = ClipboardItemEntity.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "id IN %@ AND contentType == 'image'", monitor.selectedItemIDs)

        do {
            let count = try item.managedObjectContext?.count(for: fetchRequest) ?? 0
            return count > 1
        } catch {
            return false
        }
    }

    private func getItemsToCompare() -> (ClipboardItemEntity, ClipboardItemEntity)? {
        guard monitor.selectedItemIDs.count == 2 else { return nil }

        let selectedItems = monitor.selectedItemIDs.compactMap { id in
            items.first { $0.id == id && $0.contentType == "text" }
        }

        guard selectedItems.count == 2 else { return nil }

        if (selectedItems[0].date ?? .distantPast) < (selectedItems[1].date ?? .distantPast) {
            return (selectedItems[0], selectedItems[1])
        } else {
            return (selectedItems[1], selectedItems[0])
        }
    }
}
