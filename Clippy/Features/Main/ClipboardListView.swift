
import SwiftUI

struct ClipboardListView: View {
    let items: FetchedResults<ClipboardItemEntity>
    @ObservedObject var monitor: ClipboardMonitor
    let selectedTab: ContentView.Tab
    @Binding var searchText: String
    @Binding var comparisonData: ComparisonData?

    @Environment(\.colorScheme) private var scheme

    var body: some View {
        // Compute partitions ONCE per body eval instead of re-filtering `items` four times.
        let pinned = items.filter { $0.isPinned }
        let unpinned = items.filter { !$0.isPinned }
        let pinnedCount = pinned.count

        return Group {
            if items.isEmpty {
                EmptyStateView(tab: selectedTab)
            } else {
                ScrollView {
                    LazyVStack(spacing: Ember.Space.sm, pinnedViews: []) {
                        if !pinned.isEmpty {
                            sectionHeader(icon: "pin.fill", label: "Pinned", trailingCount: pinnedCount, accent: Ember.Palette.amber)
                            ForEach(pinned, id: \.id) { item in
                                ClippyCard(
                                    item: item,
                                    items: items,
                                    comparisonData: $comparisonData,
                                    monitor: monitor,
                                    selectedTab: selectedTab
                                )
                            }

                            if !unpinned.isEmpty {
                                sectionHeader(icon: "clock", label: "Recent", trailingCount: nil, accent: Ember.secondaryText(scheme))
                            }
                        }

                        ForEach(unpinned, id: \.id) { item in
                            ClippyCard(
                                item: item,
                                items: items,
                                comparisonData: $comparisonData,
                                monitor: monitor,
                                selectedTab: selectedTab
                            )
                        }
                    }
                    .padding(.horizontal, Ember.Space.md)
                    .padding(.vertical, Ember.Space.sm)
                }
            }
        }
        .background(Ember.surface(scheme))
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
