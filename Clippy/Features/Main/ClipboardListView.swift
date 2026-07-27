
import SwiftUI

struct ClipboardListView: View {
    let items: FetchedResults<ClipboardItemEntity>
    @ObservedObject var monitor: ClipboardMonitor
    let selectedTab: ContentView.Tab
    @Binding var searchText: String
    /// The keyboard cursor. Driven by ↑↓ in ContentView; the list only
    /// renders it and keeps it scrolled into view.
    let highlightedID: UUID?

    @Environment(\.colorScheme) private var scheme

    var body: some View {
        // The fetch is sorted `isPinned` descending, so pinned rows are
        // always a prefix of `items`. That lets us split with one scan that
        // stops at the first unpinned row — a handful of objects — instead
        // of two full `filter` passes that faulted every managed object and
        // allocated two arrays.
        //
        // It matters because this body re-evaluates on every ↑↓ keypress,
        // every keystroke in search and every hover; the old version paid
        // O(all items) each time and defeated the fetch's batching.
        let splitIndex = items.firstIndex { !$0.isPinned } ?? items.endIndex
        let pinned = items[..<splitIndex]
        let unpinned = items[splitIndex...]
        let pinnedCount = pinned.count

        return Group {
            if items.isEmpty {
                EmptyStateView(tab: selectedTab)
            } else {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: Ember.Space.sm, pinnedViews: []) {
                            if !pinned.isEmpty {
                                sectionHeader(icon: "pin.fill", label: "Pinned", trailingCount: pinnedCount, accent: Ember.Palette.amber)
                                ForEach(pinned, id: \.id) { item in
                                    card(for: item)
                                }

                                if !unpinned.isEmpty {
                                    sectionHeader(icon: "clock", label: "Recent", trailingCount: nil, accent: Ember.secondaryText(scheme))
                                }
                            }

                            ForEach(unpinned, id: \.id) { item in
                                card(for: item)
                            }
                        }
                        .padding(.horizontal, Ember.Space.md)
                        .padding(.vertical, Ember.Space.sm)
                    }
                    .onChange(of: highlightedID) { id in
                        guard let id else { return }
                        withAnimation(Ember.Motion.snap) {
                            proxy.scrollTo(id, anchor: .center)
                        }
                    }
                }
            }
        }
        .background(Ember.surface(scheme))
    }

    private func card(for item: ClipboardItemEntity) -> some View {
        ClippyCard(
            item: item,
            items: items,
            monitor: monitor,
            selectedTab: selectedTab,
            isKeyboardFocused: item.id != nil && item.id == highlightedID
        )
        .id(item.id)
    }

    private func sectionHeader(icon: String, label: String, trailingCount: Int?, accent: Color) -> some View {
        HStack(spacing: Ember.Space.xs) {
            Image(systemName: icon)
                .font(.system(size: 9, weight: .semibold))
                .foregroundColor(accent)
            Text(label)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(Ember.secondaryText(scheme))
                .textCase(.uppercase)
                .tracking(0.8)
            Spacer()
            if let count = trailingCount {
                Text("\(count)")
                    .font(Ember.Font.caption)
                    .foregroundColor(Ember.tertiaryText(scheme))
            }
        }
        .padding(.horizontal, Ember.Space.xs)
        .padding(.top, label == "Pinned" ? Ember.Space.xs : Ember.Space.md)
        .padding(.bottom, 2)
    }

}
