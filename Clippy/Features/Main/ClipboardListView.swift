import SwiftUI

struct ClipboardListView: View {
    let items: FetchedResults<ClipboardItemEntity>
    @ObservedObject var monitor: ClipboardMonitor
    let selectedTab: ContentView.Tab
    @Binding var searchText: String
    @Binding var comparisonData: ComparisonData?

    var body: some View {
        List {
            ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                ClipboardRowView(
                    item: item,
                    items: items,
                    comparisonData: $comparisonData,
                    monitor: monitor,
                    selectedTab: selectedTab,
                    itemIndex: index
                )
            }
        }
        .listStyle(.inset(alternatesRowBackgrounds: true))
        .searchable(text: $searchText, prompt: "Pano geçmişinde ara...")
    }
}
