import SwiftUI

struct WindowSwitcherPanelView: View {
    @ObservedObject var panelController: WindowSwitcherPanelController
    let items: [SwitcherItem]
    let onItemSelect: (CGWindowID) -> Void

    private let columns: [GridItem] = [
        GridItem(.adaptive(minimum: 220), spacing: 20)
    ]

    var body: some View {
        // ScrollViewReader so we can scroll the keyboard-selected item
        // into view when cycling past the last visible card on screen
        // (the original layout had the second row clipped because tab
        // never scrolled the grid).
        ScrollViewReader { proxy in
            ScrollView {
                LazyVGrid(columns: columns, spacing: 24) {
                    ForEach(items) { item in
                        WindowSwitcherItemView(item: item, isSelected: item.id == panelController.selectedItemID)
                            .id(item.id)
                            .onTapGesture {
                                onItemSelect(item.windowID)
                            }
                    }
                }
                .padding()
            }
            .onChange(of: panelController.selectedItemID) { newID in
                guard let newID else { return }
                withAnimation(.easeOut(duration: 0.18)) {
                    proxy.scrollTo(newID, anchor: .center)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
}

struct WindowSwitcherItemView: View {
    let item: SwitcherItem
    let isSelected: Bool
    @State private var isHovering = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                if let icon = item.appIcon {
                    Image(nsImage: icon)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 16, height: 16)
                }
                Text(item.appName)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .lineLimit(1)
                Spacer()
            }

            // Uniform 16:10 card container so portrait windows
            // (Simulator, Books, etc.) don't stretch the row height.
            // The image fits inside, letterboxed against a soft
            // backdrop, keeping every card the same size regardless
            // of the source window's aspect ratio.
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color.black.opacity(0.18))

                Image(nsImage: item.previewImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .padding(4)
            }
            .aspectRatio(16.0 / 10.0, contentMode: .fit)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            colors: [Ember.Palette.amber, Ember.Palette.amberDark],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        ),
                        lineWidth: isSelected ? 3 : 0
                    )
            )
            .shadow(
                color: isSelected ? Ember.Palette.amber.opacity(0.5) : .black.opacity(isHovering ? 0.45 : 0.3),
                radius: isSelected ? 14 : (isHovering ? 8 : 5),
                y: isSelected ? 6 : 2
            )
            .scaleEffect(isSelected ? 1.04 : (isHovering ? 1.02 : 1.0))

            if let title = item.windowTitle, !title.isEmpty {
                Text(title)
                    .font(.caption2)
                    .lineLimit(1)
                    .foregroundColor(.secondary)
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(isSelected
                      ? Ember.Palette.amber.opacity(0.12)
                      : (isHovering ? Color.primary.opacity(0.08) : Color.clear))
        )
        .animation(.spring(response: 0.28, dampingFraction: 0.75), value: isSelected)
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: isHovering)
        .onHover { hovering in
            self.isHovering = hovering
        }
    }
}
