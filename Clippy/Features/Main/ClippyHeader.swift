import SwiftUI

// MARK: - ClippyHeader
// Unified top bar for the main popover.
// Replaces the dense row of tabs + buttons + separate search.

struct ClippyHeader: View {
    @Binding var selectedTab: ContentView.Tab
    @Binding var selectedCategory: String?
    @Binding var searchText: String
    let isEmpty: Bool

    let onClear: () -> Void
    let onImportSnippets: () -> Void
    let onGenerateUUID: () -> Void
    let onGenerateLorem: () -> Void

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

            Button(role: .destructive) {
                onClear()
            } label: {
                Label("Clear Current Tab", systemImage: "trash")
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
                tabPill(.history, label: "All", icon: "tray.full")

                if settings.showCodeTab {
                    tabPill(.code, label: "Code", icon: "chevron.left.forwardslash.chevron.right")
                }
                if settings.showImagesTab {
                    tabPill(.images, label: "Images", icon: "photo")
                }
                if settings.showSnippetsTab {
                    tabPill(.snippets, label: "Snippets", icon: "text.badge.star")
                }
                if settings.showFavoritesTab {
                    tabPill(.favorites, label: "Starred", icon: "star")
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
        }
        .buttonStyle(.plain)
    }

    // MARK: Search bar

    private var searchBar: some View {
        HStack(spacing: Ember.Space.sm) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(searchFocused ? Ember.Palette.amber : Ember.secondaryText(scheme))

            TextField(searchPlaceholder, text: $searchText)
                .textFieldStyle(.plain)
                .font(Ember.Font.body)
                .focused($searchFocused)

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
                    searchFocused ? Ember.Palette.amber.opacity(0.6) : Color.clear,
                    lineWidth: 1.5
                )
        )
        .animation(Ember.Motion.gentle, value: searchFocused)
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
