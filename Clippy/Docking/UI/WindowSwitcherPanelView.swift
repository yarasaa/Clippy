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
                        .stroke(Color.accentColor, lineWidth: isSelected ? 4 : 0)
                )
                .shadow(color: .black.opacity(0.3), radius: 5, y: 2)

            if let title = item.windowTitle, !title.isEmpty {
                Text(title)
                    .font(.caption2)
                    .lineLimit(1)
                    .foregroundColor(.secondary)
            }
        }
        .padding(10)
        .background(isHovering ? Color.primary.opacity(0.1) : Color.clear)
        .cornerRadius(12)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.1)) {
                self.isHovering = hovering
            }
        }
    }
}
