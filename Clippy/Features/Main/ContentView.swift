

import SwiftUI
import UniformTypeIdentifiers
import CoreData

struct ContentView: View {
    @EnvironmentObject private var monitor: ClipboardMonitor
    @State private var selectedTab: Tab = .history
    @State private var searchText: String = ""
    @State private var selectedCategory: String? = nil
    /// When set, the list shows only items captured from this app
    /// (bundle identifier). Activated via right-click → "Show only
    /// from this app" on any card; cleared via the chip in the header.
    @State private var sourceAppFilter: String? = nil
    @State private var sourceAppFilterName: String? = nil

    // MARK: Ask your clipboard
    /// When on, the search field becomes a natural-language question box
    /// (the ✨ toggle in the header). Search filtering is suspended while
    /// active — `searchText` is the question, not a filter.
    @State private var askMode: Bool = false
    @State private var askLoading: Bool = false
    @State private var askResult: AskResult?
    @State private var askError: String?
    @State private var askTask: Task<Void, Never>?

    // MARK: Template suggestions
    /// The pending "make a template" suggestion shown as a banner. The
    /// review UI itself is an AppDelegate child window (see
    /// showTemplateReviewWindow), not a sheet.
    @State private var pendingTemplate: TemplateDetector.PendingSuggestion?

    // MARK: Keyboard navigation

    /// Which region the keyboard is driving. ⇥ cycles between them.
    ///
    /// The popover deliberately opens on `.list`, not on the search field:
    /// with the field focused every plain keystroke is swallowed as text,
    /// so `1`–`9` couldn't paste and ⇥ couldn't move anywhere. Starting on
    /// the list keeps the single-keystroke actions available and makes
    /// search an explicit ⇥ away.
    enum FocusZone { case list, search, tabs }
    @State private var focusZone: FocusZone = .list

    /// The keyboard cursor — the item ↑↓ is currently on. Paste with ⏎.
    @State private var highlightedID: UUID?
    /// Local event monitor that intercepts navigation keys before the
    /// focused search field consumes them.
    @State private var keyMonitor: Any?

    @FetchRequest private var items: FetchedResults<ClipboardItemEntity>

    @EnvironmentObject var settings: SettingsManager
    @Environment(\.colorScheme) private var scheme

    enum Tab: Hashable, CaseIterable {
        case history, code, images, snippets, favorites

        var label: String {
            switch self {
            case .history:   return "All"
            case .code:      return "Code"
            case .images:    return "Images"
            case .snippets:  return "Snippets"
            case .favorites: return "Starred"
            }
        }

        var icon: String {
            switch self {
            case .history:   return "tray.full"
            case .code:      return "chevron.left.forwardslash.chevron.right"
            case .images:    return "photo"
            case .snippets:  return "text.badge.star"
            case .favorites: return "star"
            }
        }

        /// The tabs actually on screen, in display order. Single source of
        /// truth for both the header pills and ⌃Tab cycling — keeping two
        /// copies of this list would let them drift as tabs get toggled.
        static func visible(_ settings: SettingsManager) -> [Tab] {
            var tabs: [Tab] = [.history]
            if settings.showCodeTab      { tabs.append(.code) }
            if settings.showImagesTab    { tabs.append(.images) }
            if settings.showSnippetsTab  { tabs.append(.snippets) }
            if settings.showFavoritesTab { tabs.append(.favorites) }
            return tabs
        }
    }

    init() {
        let request = NSFetchRequest<ClipboardItemEntity>(entityName: "ClipboardItemEntity")
        request.sortDescriptors = [
            NSSortDescriptor(keyPath: \ClipboardItemEntity.isPinned, ascending: false),
            NSSortDescriptor(keyPath: \ClipboardItemEntity.date, ascending: false)
        ]
        request.predicate = NSPredicate(value: true)
        request.fetchBatchSize = 20
        _items = FetchRequest(fetchRequest: request)
    }

    var body: some View {
        // Header is a stable sibling of the list (not a safeAreaInset of it)
        // so its @FocusState survives when the list swaps between ScrollView
        // and EmptyStateView — otherwise typing a search that returns no
        // results reconstructs the inset content and kicks the cursor out
        // of the search field.
        VStack(spacing: 0) {
            ClippyHeader(
                selectedTab: $selectedTab,
                selectedCategory: $selectedCategory,
                searchText: $searchText,
                askMode: $askMode,
                focusZone: $focusZone,
                isEmpty: items.isEmpty,
                onClear: { monitor.clear(tab: selectedTab) },
                onImportSnippets: { importSnippets() },
                onGenerateUUID: { monitor.generateUUID() },
                onGenerateLorem: { monitor.generateLoremIpsum() },
                onAskSubmit: { runAsk() }
            )

            // Answer panel for "Ask your clipboard". Sits directly under
            // the header so the answer reads as a response to the question
            // still shown in the search field.
            if askMode {
                AskAnswerPanel(
                    loading: askLoading,
                    result: askResult,
                    error: askError,
                    onOpenItem: { item in monitor.appDelegate?.showDetailWindow(for: item) },
                    onCopyItem: { item in monitor.copyToClipboard(item: item.toClipboardItem()) },
                    onPasteItem: { item in PasteManager.shared.pasteItem(item.toClipboardItem()) },
                    onCopyText: { text in
                        let pb = NSPasteboard.general
                        pb.clearContents()
                        pb.setString(text, forType: .string)
                    },
                    onExample: { example in
                        searchText = example
                        runAsk()
                    }
                )
            }

            // "You keep copying this — make a template?" suggestion.
            templateSuggestionBanner

            // Visible only when a per-app filter is active. Sits
            // between the header and list so it doesn't intrude on
            // the default empty-filter state.
            sourceAppFilterChip

            ClipboardListView(
                items: items,
                monitor: monitor,
                selectedTab: selectedTab,
                searchText: $searchText,
                highlightedID: cursorItem?.id
            )
        }
        .safeAreaInset(edge: .bottom) {
            bottomBar
        }
        .preferredColorScheme(colorScheme)
        .id(settings.appLanguage)
        .onChange(of: selectedTab, perform: updatePredicate)
        .onChange(of: searchText, perform: updatePredicate)
        .onChange(of: selectedCategory, perform: updatePredicate)
        .onChange(of: sourceAppFilter, perform: updatePredicate)
        .onChange(of: askMode) { _ in
            // Toggling Ask mode either way is a clean slate: cancel any
            // in-flight question and clear the previous answer.
            askTask?.cancel()
            askLoading = false
            askResult = nil
            askError = nil
            updatePredicate(searchText)
        }
        .onAppear {
            updatePredicate(searchText)
            refreshTemplateSuggestion()
            installKeyMonitor()
            // @State survives the popover being dismissed, so without this
            // a reopen would resume in whatever zone was last used — and
            // land the cursor mid-list. Every open starts the same way.
            focusZone = .list
            highlightedID = nil
        }
        .onDisappear { removeKeyMonitor() }
        .onReceive(NotificationCenter.default.publisher(for: .clippyFilterBySourceApp)) { note in
            // Empty userInfo or missing bundleID → clear filter.
            let bundle = note.userInfo?["bundleID"] as? String
            let name = note.userInfo?["appName"] as? String
            sourceAppFilter = (bundle?.isEmpty == false) ? bundle : nil
            sourceAppFilterName = (name?.isEmpty == false) ? name : nil
        }
        .onReceive(NotificationCenter.default.publisher(for: .clippyTemplateCandidateDetected)) { _ in
            refreshTemplateSuggestion()
        }
    }

    /// Pull the next queued template suggestion into the banner, but only
    /// when the feature is on and a local model can actually build it.
    private func refreshTemplateSuggestion() {
        guard settings.enableTemplateDetection, TemplateGenerator.isEligible else {
            pendingTemplate = nil
            return
        }
        pendingTemplate = TemplateDetector.shared.nextPending
    }

    /// "You keep copying this — make a template?" banner. Appears when
    /// TemplateDetector has queued a repeated structure and a local model
    /// is available to draft it. Collapses when there's nothing pending.
    @ViewBuilder
    private var templateSuggestionBanner: some View {
        if let suggestion = pendingTemplate {
            HStack(spacing: Ember.Space.sm) {
                Image(systemName: "square.on.square.dashed")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(Ember.Palette.amber)

                VStack(alignment: .leading, spacing: 1) {
                    Text("Make this a template?")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(Ember.primaryText(scheme))
                    Text("You've copied \(suggestion.samples.count) similar texts.")
                        .font(.system(size: 10))
                        .foregroundColor(Ember.secondaryText(scheme))
                        .lineLimit(1)
                }

                Spacer(minLength: 4)

                Button {
                    monitor.appDelegate?.showTemplateReviewWindow(
                        samples: suggestion.samples,
                        skeleton: suggestion.skeleton
                    )
                    // Drop it from the persisted queue so the banner
                    // doesn't return on the next popover open regardless
                    // of how the review window is closed.
                    TemplateDetector.shared.dismissPending(skeleton: suggestion.skeleton)
                    pendingTemplate = nil
                } label: {
                    Text("Create")
                        .font(.system(size: 11, weight: .semibold))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Capsule().fill(Ember.Palette.amber))
                        .foregroundColor(.white)
                }
                .buttonStyle(.plain)

                Button {
                    // Snooze this pattern for a cooldown instead of asking
                    // again on the next open.
                    TemplateDetector.shared.snooze(skeleton: suggestion.skeleton)
                    refreshTemplateSuggestion()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 12))
                        .foregroundColor(Ember.tertiaryText(scheme))
                }
                .buttonStyle(.plain)
                .help("Dismiss for now")
            }
            .padding(.horizontal, Ember.Space.md)
            .padding(.vertical, 7)
            .background(Ember.Palette.amber.opacity(0.08))
            .overlay(alignment: .bottom) { Divider().opacity(0.2) }
            .transition(.move(edge: .top).combined(with: .opacity))
        }
    }

    /// Always-on shortcut legend. The keyboard flow (↑↓ / ⏎ / ⌃Tab / ⌘1-9)
    /// is the fastest way to use Clippy, but it was completely invisible —
    /// an undiscoverable shortcut may as well not exist. Mirrors the hint
    /// footer the Quick Preview panel already had.
    private var keyboardHintBar: some View {
        HStack(spacing: Ember.Space.md) {
            if askMode {
                // Return submits the question in Ask mode, so advertising
                // "⏎ paste" here would be a lie.
                //
                // The `Spacer()` is load-bearing, exactly as in the branches
                // below: it stretches the HStack to the full width, and
                // `.background(.bar)` paints whatever the HStack occupies.
                // Without it the bar shrank to hug these two labels and the
                // list showed through on either side — a half-drawn strip
                // instead of a footer.
                KbdHint(keys: "⏎", label: "ask")
                Spacer()
                KbdHint(keys: "esc", label: "back to search")
            } else {
                switch focusZone {
                case .tabs:
                    KbdHint(keys: "←→", label: "switch tab")
                    KbdHint(keys: "⏎", label: "done")
                    Spacer()
                    KbdHint(keys: "⇥", label: "list")
                case .search:
                    KbdHint(keys: "↑↓", label: "navigate")
                    KbdHint(keys: "⏎", label: "paste")
                    Spacer()
                    KbdHint(keys: "esc", label: "clear")
                case .list:
                    KbdHint(keys: "↑↓", label: "navigate")
                    KbdHint(keys: "⏎", label: "paste")
                    KbdHint(keys: "1-9", label: "quick paste")
                    Spacer()
                    KbdHint(keys: "⇥", label: "search")
                }
            }
        }
        .padding(.horizontal, Ember.Space.md)
        .padding(.vertical, 6)
        .background(.bar)
    }

    /// Small dismissible chip shown when a source-app filter is active.
    /// Uses Ember.Palette.amber to match the rest of the brand. The
    /// whole view collapses when no filter is set.
    @ViewBuilder
    private var sourceAppFilterChip: some View {
        if let bundle = sourceAppFilter, !bundle.isEmpty {
            HStack(spacing: 6) {
                Image(systemName: "app.badge.checkmark")
                    .font(.system(size: 10, weight: .semibold))
                Text("Only from")
                    .font(.system(size: 11, weight: .medium))
                Text(sourceAppFilterName ?? bundle)
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                Spacer(minLength: 4)
                Button {
                    sourceAppFilter = nil
                    sourceAppFilterName = nil
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 12))
                        .foregroundColor(Ember.Palette.amber.opacity(0.7))
                }
                .buttonStyle(.plain)
                .help("Clear filter")
            }
            .foregroundColor(Ember.Palette.amber)
            .padding(.horizontal, Ember.Space.md)
            .padding(.vertical, 6)
            .background(Ember.Palette.amber.opacity(0.08))
        }
    }

    private func updatePredicate(_: Any) {
        var predicates: [NSPredicate] = []

        switch selectedTab {
        case .history:
            predicates.append(NSPredicate(format: "(keyword == nil OR keyword == '')"))
            predicates.append(NSPredicate(format: "isFavorite == NO"))
            predicates.append(NSPredicate(format: "contentType == 'text'"))
            if settings.showCodeTab {
                predicates.append(NSPredicate(format: "isCode == NO"))
            }
        case .images:
            predicates.append(NSPredicate(format: "(keyword == nil OR keyword == '')"))
            predicates.append(NSPredicate(format: "isFavorite == NO"))
            predicates.append(NSPredicate(format: "contentType == 'image'"))
        case .code:
            predicates.append(NSPredicate(format: "(keyword == nil OR keyword == '')"))
            predicates.append(NSPredicate(format: "isFavorite == NO"))
            predicates.append(NSPredicate(format: "isCode == YES"))
        case .snippets:
            predicates.append(NSPredicate(format: "keyword != nil AND keyword != ''"))

            // Category filter for snippets (only if category system is enabled)
            if settings.isCategorySystemEnabled, let category = selectedCategory {
                predicates.append(NSPredicate(format: "category == %@", category))
            }
        case .favorites:
            predicates.append(NSPredicate(format: "isFavorite == YES"))
        }

        // In Ask mode the field holds a question, not a filter — leave
        // the full list visible behind the answer panel.
        if !searchText.isEmpty && !askMode {
            // Match the literal content, the OCR text from images, and
            // both title fields (user-set and AI-generated) — so items
            // are findable by whatever name the list displays for them.
            predicates.append(NSPredicate(
                format: "content CONTAINS[c] %@ OR extractedText CONTAINS[c] %@ OR title CONTAINS[c] %@ OR autoTitle CONTAINS[c] %@",
                searchText, searchText, searchText, searchText
            ))
        }

        // Source-app filter (set via right-click → "Show only from this app").
        if let bundle = sourceAppFilter, !bundle.isEmpty {
            predicates.append(NSPredicate(format: "sourceAppBundleIdentifier == %@", bundle))
        }

        items.nsPredicate = NSCompoundPredicate(andPredicateWithSubpredicates: predicates)
    }

    // MARK: - Keyboard navigation

    /// Items in visual order. The fetch is already sorted pinned-first,
    /// date-descending, which is exactly how the list renders them.
    private var orderedItems: [ClipboardItemEntity] { Array(items) }

    /// The cursor resolved against the *current* filter. If the previously
    /// highlighted item was filtered away (user typed a search, switched
    /// tab), the cursor falls back to the first row — so ⏎ always pastes
    /// the top match without any state-syncing gymnastics.
    private var cursorIndex: Int {
        if let id = highlightedID,
           let idx = orderedItems.firstIndex(where: { $0.id == id }) {
            return idx
        }
        return 0
    }

    private var cursorItem: ClipboardItemEntity? {
        orderedItems.indices.contains(cursorIndex) ? orderedItems[cursorIndex] : nil
    }

    private func installKeyMonitor() {
        guard keyMonitor == nil else { return }
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            handleKey(event) ? nil : event
        }
    }

    private func removeKeyMonitor() {
        if let keyMonitor { NSEvent.removeMonitor(keyMonitor) }
        keyMonitor = nil
    }

    /// Returns true when the event was consumed (so it never reaches the
    /// focused search field).
    private func handleKey(_ event: NSEvent) -> Bool {
        // Only ever act while the popover is actually on screen. Without
        // this, a monitor that outlives an onDisappear would swallow
        // arrows/Esc in the Settings, Detail or Editor windows.
        guard monitor.appDelegate?.statusBarController?.popover.isShown == true else {
            return false
        }
        // Never steal keys from a text field in another window (e.g. the
        // detail editor) that happens to be key while the popover is up.
        if let keyWindow = NSApp.keyWindow,
           keyWindow !== monitor.appDelegate?.statusBarController?.popover.contentViewController?.view.window {
            return false
        }

        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        let hasCommand = flags.contains(.command)

        // ⌃Tab / ⌃⇧Tab — jump straight between tabs from any zone.
        // Control+Tab rather than the ⌘1–5 the Mac normally uses for tabs,
        // because ⌘1–9 is already the clipboard-manager convention for
        // "paste item N" here. It's also layout-independent: Safari's
        // ⌘⇧[ / ⌘⇧] would be unreachable on a Turkish keyboard, where
        // [ and ] sit behind AltGr.
        if flags.contains(.control), event.keyCode == 48 {
            cycleTab(by: flags.contains(.shift) ? -1 : 1)
            return true
        }

        // ⇥ / ⇧⇥ — move between list, search and tabs.
        if event.keyCode == 48 {
            cycleFocusZone(by: flags.contains(.shift) ? -1 : 1)
            return true
        }

        // ⌘1–9 — paste the Nth visible item, from any zone.
        if hasCommand,
           let digit = event.charactersIgnoringModifiers?.first?.wholeNumberValue,
           digit >= 1, digit <= 9 {
            return pasteByIndex(digit - 1)
        }

        // Bare 1–9 — same thing without the modifier. Only outside the
        // search field, where those keystrokes are text the user is typing.
        if focusZone != .search, flags.isEmpty,
           let digit = event.charactersIgnoringModifiers?.first?.wholeNumberValue,
           digit >= 1, digit <= 9 {
            return pasteByIndex(digit - 1)
        }

        // ←→ steer the tabs while the tab row holds focus.
        if focusZone == .tabs, event.keyCode == 123 || event.keyCode == 124 {
            cycleTab(by: event.keyCode == 124 ? 1 : -1)
            return true
        }

        switch event.keyCode {
        case 125: // ↓
            moveCursor(by: 1)
            return true

        case 126: // ↑
            moveCursor(by: -1)
            return true

        case 36, 76: // ⏎ / numpad enter
            // In Ask mode Return submits the question — leave it alone.
            if askMode { return false }
            // From the tab row, Return just commits the choice and hands
            // the keyboard back to the list.
            if focusZone == .tabs {
                focusZone = .list
                return true
            }
            guard let item = cursorItem else { return true }
            paste(item)
            return true

        case 53: // esc — unwind one step at a time, close only at the end
            if !searchText.isEmpty {
                searchText = ""
                return true
            }
            if askMode {
                askMode = false
                return true
            }
            if focusZone != .list {
                focusZone = .list
                return true
            }
            NotificationCenter.default.post(name: .closeClippyPopover, object: nil)
            return true

        default:
            return false
        }
    }

    /// ⇥ order: list → search → tabs → list. Search comes first because
    /// it's the more common detour; the tab row is rarely the destination.
    private func cycleFocusZone(by delta: Int) {
        let zones: [FocusZone] = Tab.visible(settings).count > 1
            ? [.list, .search, .tabs]
            : [.list, .search]          // no point focusing a single tab
        let current = zones.firstIndex(of: focusZone) ?? 0
        let next = (current + delta + zones.count) % zones.count
        withAnimation(Ember.Motion.gentle) {
            focusZone = zones[next]
        }
    }

    /// Pastes the item at `index` in the visible list. Always consumes the
    /// key, so an out-of-range digit is a no-op rather than leaking into
    /// whatever is behind the popover.
    private func pasteByIndex(_ index: Int) -> Bool {
        guard orderedItems.indices.contains(index) else { return true }
        paste(orderedItems[index])
        return true
    }

    /// Moves to the next/previous *visible* tab, wrapping around. Hidden
    /// tabs are skipped because they aren't reachable by clicking either.
    private func cycleTab(by delta: Int) {
        let tabs = Tab.visible(settings)
        guard tabs.count > 1 else { return }
        let current = tabs.firstIndex(of: selectedTab) ?? 0
        let next = (current + delta + tabs.count) % tabs.count
        withAnimation(Ember.Motion.gentle) {
            selectedTab = tabs[next]
        }
        // Start the cursor at the top of the newly shown list.
        highlightedID = nil
    }

    private func moveCursor(by delta: Int) {
        guard !orderedItems.isEmpty else { return }
        let next = (cursorIndex + delta + orderedItems.count) % orderedItems.count
        highlightedID = orderedItems[next].id
    }

    private func paste(_ item: ClipboardItemEntity) {
        PasteManager.shared.pasteItem(item.toClipboardItem())
        NotificationCenter.default.post(name: .closeClippyPopover, object: nil)
    }

    /// Submit the current search text as an "ask your clipboard" question
    /// and stream the result into the answer panel.
    private func runAsk() {
        let question = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !question.isEmpty else { return }

        askTask?.cancel()
        askError = nil
        askResult = nil
        askLoading = true

        askTask = Task {
            do {
                let result = try await AskClipboardEngine.ask(question)
                if Task.isCancelled { return }
                askResult = result
                askLoading = false
            } catch {
                if Task.isCancelled { return }
                askError = (error as? AskClipboardEngine.AskError)?.errorDescription
                    ?? error.localizedDescription
                askLoading = false
            }
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

    private func importSnippets() {

        // Use DispatchQueue to avoid blocking UI
        DispatchQueue.main.async {
            let panel = NSOpenPanel()
            panel.allowedContentTypes = [.json]
            panel.allowsMultipleSelection = false
            panel.canChooseDirectories = false
            panel.canChooseFiles = true
            panel.message = L("Select snippets JSON file to import", settings: self.settings)

            panel.begin { response in
                if response == .OK, let url = panel.url {
                    do {
                        let count = try SnippetExportManager.shared.importSnippets(from: url)

                        DispatchQueue.main.async {
                            let alert = NSAlert()
                            alert.messageText = L("Import Successful", settings: self.settings)
                            let messageKey = count == 1 ? "1 snippet was imported successfully." : "%d snippets were imported successfully."
                            alert.informativeText = String(format: L(messageKey, settings: self.settings), count)
                            alert.alertStyle = .informational
                            alert.addButton(withTitle: L("Ok", settings: self.settings))
                            alert.runModal()
                        }
                    } catch {

                        DispatchQueue.main.async {
                            let alert = NSAlert()
                            alert.messageText = L("Import Failed", settings: self.settings)
                            alert.informativeText = String(format: L("Failed to import snippets: %@", settings: self.settings), error.localizedDescription)
                            alert.alertStyle = .critical
                            alert.addButton(withTitle: L("Ok", settings: self.settings))
                            alert.runModal()
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var bottomBar: some View {
        if monitor.selectedItemIDs.isEmpty {
            keyboardHintBar
        } else {
            HStack {
                Text(String(format: L("%d items selected", settings: settings), monitor.selectedItemIDs.count))
                    .font(.footnote)
                    .foregroundColor(.secondary)
                Spacer()

                // Compare belongs here — this bar is the one place the app
                // already knows a multi-selection exists. It used to live
                // only in the 39-item card context menu, where it was
                // effectively undiscoverable.
                if let pair = monitor.comparablePair() {
                    Button {
                        monitor.appDelegate?.showDiffWindow(
                            oldText: pair.0.content ?? "",
                            newText: pair.1.content ?? "",
                            oldLabel: ClipboardMonitor.diffLabel(for: pair.0),
                            newLabel: ClipboardMonitor.diffLabel(for: pair.1)
                        )
                        monitor.clearSelection()
                    } label: {
                        Label(L("Compare", settings: settings), systemImage: "square.split.2x1")
                    }
                } else if monitor.selectedItemIDs.count == 2 {
                    // Two things are selected but they aren't both text —
                    // say why instead of silently hiding the action.
                    Text(L("Select 2 text items to compare", settings: settings))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                if settings.enableSequentialPaste && monitor.selectedItemIDs.count > 1 {
                    Button {
                        monitor.addSelectionToSequentialQueue()
                    } label: {
                        Label(L("Add to Sequential Queue", settings: settings), systemImage: "text.badge.plus")
                    }
                }

                Button {
                    monitor.clearSelection()
                } label: {
                    Label(L("Clear Selection", settings: settings), systemImage: "xmark.circle")
                }

                Button {
                    monitor.copySelectionToClipboard()
                    PasteManager.shared.performPaste(completion: monitor.clearSelection)
                } label: {
                    Label(L("Paste All", settings: settings), systemImage: "list.clipboard.fill")
                }
                .buttonStyle(.borderedProminent)

            }
            .padding()
            .background(.bar)
            .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }

}

struct AITransformState: Identifiable {
    let id = UUID()
    let text: String
    let action: AIAction
    var targetLanguage: String?
    var customPrompt: String?
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
            .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
            .environmentObject(SettingsManager.shared)
            .environmentObject(ClipboardMonitor())
    }
}
