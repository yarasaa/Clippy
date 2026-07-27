import SwiftUI

// MARK: - ClippyHeader
// Unified top bar for the main popover.
// Replaces the dense row of tabs + buttons + separate search.

struct ClippyHeader: View {
    @Binding var selectedTab: ContentView.Tab
    @Binding var selectedCategory: String?
    @Binding var searchText: String
    @Binding var askMode: Bool
    @Binding var focusZone: ContentView.FocusZone
    let isEmpty: Bool

    let onClear: () -> Void
    let onImportSnippets: () -> Void
    let onGenerateUUID: () -> Void
    let onGenerateLorem: () -> Void
    /// Submit the current search text as an "ask your clipboard" question.
    let onAskSubmit: () -> Void

    /// Context-aware label for the single clear action. Reflects the
    /// tab you're looking at so it's obvious what will be cleared.
    /// (Pinned / starred / snippet / encrypted items are always kept.)
    private var clearLabel: String {
        switch selectedTab {
        case .history:   return "Clear History"
        case .code:      return "Clear Code"
        case .images:    return "Clear Images"
        case .snippets:  return "Clear Snippets"
        case .favorites: return "Clear Starred"
        }
    }

    @EnvironmentObject var settings: SettingsManager
    @Environment(\.colorScheme) var scheme
    @FocusState private var searchFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            brandRow
            tabPills
            searchBar

            if selectedTab == .snippets && settings.isCategorySystemEnabled {
                CategoryFilterView(selectedCategory: $selectedCategory)
                    .padding(.horizontal, Ember.Space.md)
                    .padding(.bottom, Ember.Space.sm)
            }

            Divider()
                .opacity(0.3)
        }
        .background(.ultraThinMaterial)
        // Keep the AppKit first responder and our focus model in step, in
        // both directions: ⇥ moves the zone, and clicking straight into the
        // field must move the zone too or the two would disagree.
        .onChange(of: focusZone) { zone in
            searchFocused = (zone == .search)
        }
        .onChange(of: searchFocused) { isFocused in
            if isFocused { focusZone = .search }
            else if focusZone == .search { focusZone = .list }
        }
    }

    // MARK: Brand row

    private var brandRow: some View {
        HStack(spacing: Ember.Space.sm) {
            ClippyMark(size: 18)

            Text("Clippy")
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundColor(Ember.primaryText(scheme))

            Spacer()

            headerMenu
        }
        .padding(.horizontal, Ember.Space.md)
        .padding(.top, Ember.Space.sm + 2)
        .padding(.bottom, Ember.Space.xs)
    }

    private var headerMenu: some View {
        Menu {
            Section("Generate") {
                Button {
                    onGenerateUUID()
                } label: {
                    Label("UUID", systemImage: "number")
                }
                Button {
                    onGenerateLorem()
                } label: {
                    Label("Lorem Ipsum", systemImage: "text.alignleft")
                }
            }

            if selectedTab == .snippets {
                Divider()
                Button {
                    onImportSnippets()
                } label: {
                    Label("Import Snippets…", systemImage: "square.and.arrow.down")
                }
            }

            Divider()

            // Single context-aware clear: label reflects the active
            // tab, and it always preserves deliberately-saved items
            // (pinned, starred, snippets, encrypted) — see issue #9.
            Button(role: .destructive) {
                onClear()
            } label: {
                Label(clearLabel, systemImage: "trash")
            }
            .disabled(isEmpty)
        } label: {
            Image(systemName: "ellipsis.circle")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(Ember.secondaryText(scheme))
                .frame(width: 22, height: 22)
                .contentShape(Rectangle())
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
    }

    // MARK: Tab pills

    private var tabPills: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 4) {
                ForEach(ContentView.Tab.visible(settings), id: \.self) { tab in
                    tabPill(tab, label: tab.label, icon: tab.icon)
                }
            }
            .padding(.horizontal, Ember.Space.md)
        }
        .padding(.bottom, Ember.Space.xs)
    }

    private func tabPill(_ tab: ContentView.Tab, label: String, icon: String) -> some View {
        let isActive = selectedTab == tab

        return Button {
            withAnimation(Ember.Motion.snap) { selectedTab = tab }
        } label: {
            HStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.system(size: 10, weight: .semibold))
                Text(label)
                    .font(.system(size: 12, weight: .medium))
            }
            .foregroundColor(isActive ? .white : Ember.secondaryText(scheme))
            .padding(.horizontal, Ember.Space.md)
            .padding(.vertical, 5)
            .background(
                Capsule()
                    .fill(isActive ? AnyShapeStyle(
                        LinearGradient(
                            colors: [Ember.Palette.amber, Ember.Palette.amberDark],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    ) : AnyShapeStyle(Color.clear))
            )
            .overlay(
                Capsule()
                    .strokeBorder(
                        isActive ? Color.clear : Ember.Palette.smoke.opacity(0.25),
                        lineWidth: 0.5
                    )
            )
            .shadow(
                color: isActive ? Ember.Palette.amber.opacity(0.4) : .clear,
                radius: 4,
                y: 2
            )
            // Focus ring while ⇥ has the tabs row: without it there's no
            // way to tell that ←→ is currently steering the tabs.
            .overlay(
                Capsule()
                    .strokeBorder(Ember.Palette.amber, lineWidth: 2)
                    .padding(-2)
                    .opacity(focusZone == .tabs && isActive ? 1 : 0)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: Search bar

    /// Whether AI-powered "Ask your clipboard" mode is available.
    private var askAvailable: Bool {
        settings.enableAI && AIService.shared.isConfigured
    }

    private var searchBar: some View {
        HStack(spacing: Ember.Space.sm) {
            Image(systemName: askMode ? "sparkles" : "magnifyingglass")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(askMode || searchFocused ? Ember.Palette.amber : Ember.secondaryText(scheme))

            TextField(askMode ? "Ask your clipboard…" : searchPlaceholder, text: $searchText)
                .textFieldStyle(.plain)
                .font(Ember.Font.body)
                .focused($searchFocused)
                .onSubmit {
                    if askMode { onAskSubmit() }
                }

            if !searchText.isEmpty {
                Button {
                    searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 12))
                        .foregroundColor(Ember.tertiaryText(scheme))
                }
                .buttonStyle(.plain)
                .transition(.opacity)
            }

            // Ask-mode toggle. Only shown when a provider is configured
            // — no point advertising AI Q&A the app can't run.
            if askAvailable {
                Button {
                    withAnimation(Ember.Motion.gentle) {
                        askMode.toggle()
                        searchText = ""
                    }
                    searchFocused = true
                } label: {
                    Image(systemName: "sparkles")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(askMode ? Ember.Palette.amber : Ember.tertiaryText(scheme))
                        .padding(4)
                        .background(
                            Circle().fill(askMode ? Ember.Palette.amberSoft : Color.clear)
                        )
                }
                .buttonStyle(.plain)
                .help(askMode ? "Back to search" : "Ask your clipboard")
            }
        }
        .padding(.horizontal, Ember.Space.md)
        .padding(.vertical, 7)
        .background(
            RoundedRectangle(cornerRadius: Ember.Radius.md, style: .continuous)
                .fill(Ember.Palette.smoke.opacity(scheme == .dark ? 0.12 : 0.06))
        )
        .overlay(
            RoundedRectangle(cornerRadius: Ember.Radius.md, style: .continuous)
                .strokeBorder(
                    askMode ? Ember.Palette.amber.opacity(0.6)
                            : (searchFocused ? Ember.Palette.amber.opacity(0.6) : Color.clear),
                    lineWidth: 1.5
                )
        )
        .animation(Ember.Motion.gentle, value: searchFocused)
        .animation(Ember.Motion.gentle, value: askMode)
        .padding(.horizontal, Ember.Space.md)
        .padding(.bottom, Ember.Space.sm)
    }

    private var searchPlaceholder: String {
        switch selectedTab {
        case .history:   return "Search clipboard…"
        case .code:      return "Search code snippets…"
        case .images:    return "Search images…"
        case .snippets:  return "Search snippets by keyword or content…"
        case .favorites: return "Search starred items…"
        }
    }
}
