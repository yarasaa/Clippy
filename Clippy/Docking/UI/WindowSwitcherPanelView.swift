import SwiftUI

struct WindowSwitcherPanelView: View {
    @ObservedObject var panelController: WindowSwitcherPanelController
    let items: [SwitcherItem]
    let onItemSelect: (CGWindowID) -> Void

    private let columns: [GridItem] = [
        GridItem(.adaptive(minimum: 220), spacing: 20)
    ]

    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 24) {
                ForEach(items) { item in
                    WindowSwitcherItemView(item: item, isSelected: item.id == panelController.selectedItemID)
                        .onTapGesture {
                            onItemSelect(item.windowID)
                        }
                }
            }
            .padding()
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

            Image(nsImage: item.previewImage)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
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
