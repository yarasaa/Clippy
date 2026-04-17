//
//  DragDropShelfView.swift
//  Clippy
//

import SwiftUI
import UniformTypeIdentifiers

// MARK: - Main View

struct DragDropShelfView: View {
    @ObservedObject var viewModel: DragDropShelfViewModel
    @State private var isTargeted = false
    @State private var showCopiedBanner = false
    @State private var showInfoPopover = false

    var body: some View {
        VStack(spacing: 0) {
            headerBar
            Divider().opacity(0.5)

            if viewModel.items.isEmpty {
                emptyState
            } else {
                itemsGrid
            }

            if !viewModel.selectedIDs.isEmpty {
                selectionBar
            }
        }
        .background(VisualEffectView(material: .hudWindow, blendingMode: .behindWindow))
        .onDrop(of: [.text, .utf8PlainText, .fileURL, .tiff, .png], isTargeted: $isTargeted) { providers in
            // Internal drag dropped on empty space — just clean up
            if viewModel.internalDragIDs != nil {
                viewModel.internalDragIDs = nil
                viewModel.dropTargetID = nil
                return true
            }
            viewModel.handleExternalDrop(providers)
            return true
        }
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(isTargeted && viewModel.internalDragIDs == nil
                        ? Ember.Palette.amber.opacity(0.6) : Color.clear, lineWidth: 2)
                .animation(.easeInOut(duration: 0.15), value: isTargeted)
        )
        .overlay(alignment: .top) {
            if showCopiedBanner {
                copiedBanner
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: showCopiedBanner)
        .animation(.easeInOut(duration: 0.2), value: viewModel.selectedIDs)
        .animation(.easeInOut(duration: 0.25), value: viewModel.items.count)
        .animation(.easeInOut(duration: 0.15), value: viewModel.dropTargetID)
    }

    // MARK: - Copied Banner

    private var copiedBanner: some View {
        HStack(spacing: 5) {
            Image(systemName: "checkmark")
                .font(.system(size: 10, weight: .bold))
            Text("Copied!")
                .font(.system(size: 11, weight: .semibold))
        }
        .foregroundColor(.white)
        .padding(.horizontal, 14)
        .padding(.vertical, 6)
        .background(
            Capsule()
                .fill(
                    LinearGradient(
                        colors: [Ember.Palette.moss, Ember.Palette.moss.opacity(0.85)],
                        startPoint: .top, endPoint: .bottom
                    )
                )
                .shadow(color: Ember.Palette.moss.opacity(0.4), radius: 8, y: 2)
        )
        .padding(.top, 48)
    }

    // MARK: - Header

    private var headerBar: some View {
        HStack(spacing: 8) {
            ClippyMark(size: 14)

            Text("Shelf")
                .font(.system(size: 13, weight: .semibold, design: .rounded))

            if !viewModel.items.isEmpty {
                Text("\(viewModel.items.count)")
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .frame(minWidth: 18, minHeight: 18)
                    .background(Circle().fill(Ember.Palette.amber))
            }

            Spacer()

            Button(action: { showInfoPopover.toggle() }) {
                Image(systemName: "info.circle")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary.opacity(0.5))
                    .frame(width: 24, height: 24)
                    .background(Color.secondary.opacity(0.06))
                    .cornerRadius(5)
            }
            .buttonStyle(.plain)
            .help("Help")
            .popover(isPresented: $showInfoPopover, arrowEdge: .bottom) {
                shelfInfoView
            }

            if !viewModel.items.isEmpty {
                Button(action: {
                    if viewModel.allSelected {
                        viewModel.deselectAll()
                    } else {
                        viewModel.selectAll()
                    }
                }) {
                    Text(viewModel.allSelected ? "Deselect" : "Select All")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(Ember.Palette.amber)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Ember.Palette.amber.opacity(0.08))
                        .cornerRadius(5)
                }
                .buttonStyle(.plain)

                Button(action: { withAnimation(.easeInOut(duration: 0.25)) { viewModel.clearAll() } }) {
                    Image(systemName: "trash")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary.opacity(0.6))
                        .frame(width: 24, height: 24)
                        .background(Color.secondary.opacity(0.06))
                        .cornerRadius(5)
                }
                .buttonStyle(.plain)
                .help("Clear All")
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 14) {
            Spacer()

            ZStack {
                Circle()
                    .fill(Ember.Palette.amber.opacity(0.12))
                    .frame(width: 100, height: 100)
                    .blur(radius: 16)

                RoundedRectangle(cornerRadius: 20)
                    .stroke(style: StrokeStyle(lineWidth: 1.5, dash: [8, 5]))
                    .foregroundColor(Ember.Palette.amber.opacity(0.5))
                    .frame(width: 88, height: 88)

                Image(systemName: "arrow.down.doc")
                    .font(.system(size: 28, weight: .light))
                    .foregroundColor(Ember.Palette.amber.opacity(0.7))
            }

            VStack(spacing: 5) {
                Text("Drop items here")
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                Text("Files, images, or text for later")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Items List

    private var itemsGrid: some View {
        ScrollView(.vertical, showsIndicators: true) {
            LazyVStack(spacing: 4) {
                ForEach(viewModel.items) { item in
                    VStack(spacing: 0) {
                        // Drop indicator for reorder
                        if viewModel.dropTargetID == item.id {
                            RoundedRectangle(cornerRadius: 1)
                                .fill(Ember.Palette.amber)
                                .frame(height: 2)
                                .padding(.horizontal, 12)
                                .transition(.opacity)
                        }

                        ShelfItemCard(
                            item: item,
                            isSelected: viewModel.selectedIDs.contains(item.id),
                            isFocused: viewModel.focusedID == item.id,
                            hasAnySelection: !viewModel.selectedIDs.isEmpty,
                            onSelect: {
                                if viewModel.selectedIDs.isEmpty {
                                    viewModel.selectOnly(item.id)
                                } else {
                                    viewModel.toggleSelection(item.id)
                                }
                            },
                            onCmdSelect: { viewModel.toggleSelection(item.id) },
                            onDoubleTap: {
                                viewModel.onPasteToApp?(item)
                            },
                            onCopy: {
                                viewModel.copyItemToClipboard(item)
                                showCopied()
                            },
                            onDelete: {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    viewModel.removeItem(item.id)
                                }
                            },
                            onDragEnded: {
                                viewModel.internalDragIDs = nil
                                viewModel.dropTargetID = nil
                            },
                            onRevealInFinder: item.contentType != .text ? {
                                viewModel.revealInFinder(item)
                            } : nil,
                            onOpenFile: item.contentType != .text ? {
                                viewModel.openFile(item)
                            } : nil,
                            onShare: { view in
                                var shareItems: [Any] = []
                                switch item.contentType {
                                case .file: shareItems = [URL(fileURLWithPath: item.content)]
                                case .image: if let img = item.image { shareItems = [img] }
                                case .text: shareItems = [item.content]
                                }
                                let picker = NSSharingServicePicker(items: shareItems)
                                picker.show(relativeTo: view.bounds, of: view, preferredEdge: .minY)
                            },
                            makeDragItems: { mousePos in viewModel.makeDragItems(for: item, mousePosition: mousePos) }
                        )
                    }
                    .onDrop(of: [UTType.item], delegate: ShelfDropDelegate(targetItem: item, viewModel: viewModel))
                    .transition(.asymmetric(
                        insertion: .scale(scale: 0.9).combined(with: .opacity),
                        removal: .scale(scale: 0.9).combined(with: .opacity)
                    ))
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
        }
    }

    // MARK: - Selection Bar

    private var selectionBar: some View {
        VStack(spacing: 0) {
            Divider().opacity(0.5)
            HStack(spacing: 10) {
                HStack(spacing: 5) {
                    Text("\(viewModel.selectedIDs.count)")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .frame(minWidth: 18, minHeight: 18)
                        .background(Circle().fill(Ember.Palette.amber))
                    Text("selected")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.secondary)
                }

                Spacer()

                Button(action: {
                    viewModel.copySelectedToClipboard()
                    showCopied()
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "doc.on.doc")
                            .font(.system(size: 10))
                        Text("Copy")
                            .font(.system(size: 11, weight: .semibold))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(
                        Capsule().fill(
                            LinearGradient(
                                colors: [Ember.Palette.amber, Ember.Palette.amberDark],
                                startPoint: .top, endPoint: .bottom
                            )
                        )
                    )
                    .shadow(color: Ember.Palette.amber.opacity(0.35), radius: 4, y: 1)
                }
                .buttonStyle(.plain)

                Button(action: {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        viewModel.removeSelected()
                    }
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "trash")
                            .font(.system(size: 10))
                        Text("Delete")
                            .font(.system(size: 11, weight: .medium))
                    }
                    .foregroundColor(Ember.Palette.rust)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Capsule().fill(Ember.Palette.rust.opacity(0.1)))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(.ultraThinMaterial)
        }
    }

    // MARK: - Helpers

    private func showCopied() {
        withAnimation { showCopiedBanner = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            withAnimation { showCopiedBanner = false }
        }
    }

    // MARK: - Info Popover

    private var shelfInfoView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                // Title
                HStack(spacing: 6) {
                    Image(systemName: "tray.2.fill")
                        .font(.system(size: 14))
                        .foregroundColor(Ember.Palette.amber)
                    Text("Shelf Guide")
                        .font(.system(size: 14, weight: .bold))
                }
                .padding(.bottom, 2)

                // Drag & Drop
                infoSection(icon: "arrow.up.doc", title: "Drag & Drop") {
                    infoBullet("Drop files, images or text onto the shelf to collect them")
                    infoBullet("Drag items from the shelf to Finder or other apps")
                    infoBullet("Multi-select and drag transfers all selected items")
                    infoBullet("Drag items within the shelf to reorder")
                }

                // Selection
                infoSection(icon: "checkmark.circle", title: "Selection") {
                    infoBullet("Click to select/deselect an item")
                    infoBullet("When items are selected, click others to add to selection")
                    infoBullet("\u{2318}+Click always toggles selection")
                }

                // Double-click
                infoSection(icon: "cursorarrow.click.2", title: "Quick Paste") {
                    infoBullet("Double-click an item to paste it into the last active app")
                }

                // Right-click
                infoSection(icon: "contextualmenu.and.cursorarrow", title: "Right-click Menu") {
                    infoBullet("Copy \u{2014} copy item to clipboard")
                    infoBullet("Open \u{2014} open file in its default app")
                    infoBullet("Reveal in Finder \u{2014} show file location")
                    infoBullet("Share \u{2014} macOS share menu")
                }

                // Keyboard
                infoSection(icon: "keyboard", title: "Keyboard Shortcuts") {
                    shortcutRow("\u{2318}A", "Select All / Deselect")
                    shortcutRow("\u{2318}C", "Copy selected to clipboard")
                    shortcutRow("\u{2318}Z", "Undo last delete")
                    shortcutRow("Delete", "Remove selected items")
                    shortcutRow("Space", "Quick Look preview")
                    shortcutRow("\u{2191} \u{2193}", "Navigate items")
                    shortcutRow("Enter", "Toggle selection on focused")
                    shortcutRow("Esc", "Clear selection & focus")
                }

                // Tips
                infoSection(icon: "lightbulb", title: "Tips") {
                    infoBullet("Drag count badge shows how many items are being moved")
                    infoBullet("Copy button in selection bar copies all selected items at once")
                    infoBullet("Undo restores deleted items (up to 20 levels)")
                }
            }
            .padding(16)
        }
        .frame(width: 280, height: 420)
    }

    private func infoSection<Content: View>(icon: String, title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(Ember.Palette.amber)
                    .frame(width: 16)
                Text(title)
                    .font(.system(size: 11, weight: .semibold))
            }
            content()
        }
    }

    private func infoBullet(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 6) {
            Text("\u{2022}")
                .font(.system(size: 9))
                .foregroundColor(.secondary.opacity(0.5))
                .padding(.top, 1)
            Text(text)
                .font(.system(size: 10))
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.leading, 21)
    }

    private func shortcutRow(_ key: String, _ desc: String) -> some View {
        HStack(spacing: 8) {
            Text(key)
                .font(.system(size: 9, weight: .medium, design: .monospaced))
                .foregroundColor(.primary)
                .padding(.horizontal, 5)
                .padding(.vertical, 2)
                .background(
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.primary.opacity(0.06))
                        .overlay(
                            RoundedRectangle(cornerRadius: 3)
                                .stroke(Color.primary.opacity(0.1), lineWidth: 0.5)
                        )
                )
            Text(desc)
                .font(.system(size: 10))
                .foregroundColor(.secondary)
        }
        .padding(.leading, 21)
    }
}

// MARK: - Drop Delegate for Reorder

struct ShelfDropDelegate: DropDelegate {
    let targetItem: ShelfItem
    let viewModel: DragDropShelfViewModel

    func dropEntered(info: DropInfo) {
        guard let dragIDs = viewModel.internalDragIDs,
              !dragIDs.contains(targetItem.id) else { return }
        withAnimation(.easeInOut(duration: 0.15)) {
            viewModel.dropTargetID = targetItem.id
        }
    }

    func dropExited(info: DropInfo) {
        if viewModel.dropTargetID == targetItem.id {
            withAnimation(.easeInOut(duration: 0.15)) {
                viewModel.dropTargetID = nil
            }
        }
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: viewModel.internalDragIDs != nil ? .move : .copy)
    }

    func performDrop(info: DropInfo) -> Bool {
        defer { viewModel.dropTargetID = nil }

        if let dragIDs = viewModel.internalDragIDs {
            guard !dragIDs.contains(targetItem.id) else {
                viewModel.internalDragIDs = nil
                return true
            }
            withAnimation(.easeInOut(duration: 0.2)) {
                viewModel.reorderItems(moving: dragIDs, before: targetItem.id)
            }
            viewModel.internalDragIDs = nil
            return true
        }

        // External drop on a card
        let providers = info.itemProviders(for: [.text, .utf8PlainText, .fileURL, .tiff, .png])
        if !providers.isEmpty {
            viewModel.handleExternalDrop(providers)
            return true
        }
        return false
    }
}

// MARK: - Item Card

struct ShelfItemCard: View {
    let item: ShelfItem
    let isSelected: Bool
    let isFocused: Bool
    let hasAnySelection: Bool
    let onSelect: () -> Void
    let onCmdSelect: () -> Void
    let onDoubleTap: () -> Void
    let onCopy: () -> Void
    let onDelete: () -> Void
    let onDragEnded: () -> Void
    let onRevealInFinder: (() -> Void)?
    let onOpenFile: (() -> Void)?
    let onShare: ((NSView) -> Void)?
    let makeDragItems: (NSPoint) -> [NSDraggingItem]

    @State private var isHovering = false

    var body: some View {
        HStack(spacing: 0) {
            // Selection checkmark
            if hasAnySelection || isHovering {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 15))
                    .foregroundColor(isSelected ? Ember.Palette.amber : .secondary.opacity(0.25))
                    .frame(width: 28)
            }

            HStack(spacing: 10) {
                itemThumbnail

                VStack(alignment: .leading, spacing: 3) {
                    Text(item.displayText)
                        .font(.system(size: 12, weight: .medium))
                        .lineLimit(2)
                        .foregroundColor(.primary)

                    HStack(spacing: 5) {
                        typeBadge
                        Circle()
                            .fill(Color.secondary.opacity(0.3))
                            .frame(width: 3, height: 3)
                        Text(item.timeAgo)
                            .font(.system(size: 10))
                            .foregroundColor(.secondary.opacity(0.5))
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                // Reserve trailing space so layout doesn't shift when hover actions appear.
                // Actual buttons live in an overlay above the drag layer (below).
                Color.clear
                    .frame(width: (isHovering && !hasAnySelection) ? 55 : 0, height: 28)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .contentShape(Rectangle())
        .overlay(
            DragSourceOverlay(
                onTap: onSelect,
                onCmdTap: onCmdSelect,
                onDoubleTap: onDoubleTap,
                onHoverChanged: { hovering in
                    isHovering = hovering
                },
                onCopy: onCopy,
                onDelete: onDelete,
                onDragEnded: onDragEnded,
                contentType: item.contentType,
                onRevealInFinder: onRevealInFinder,
                onOpenFile: onOpenFile,
                onShare: onShare,
                makeDragItems: makeDragItems
            )
        )
        .overlay(alignment: .trailing) {
            // Hover actions layered ABOVE the drag overlay so they are clickable.
            if isHovering && !hasAnySelection {
                hoverActions
                    .padding(.trailing, 12)
                    .allowsHitTesting(true)
            }
        }
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Ember.Palette.amber.opacity(isFocused && !isSelected ? 0.5 : 0), lineWidth: 1.5)
        )
        .animation(.easeInOut(duration: 0.15), value: hasAnySelection)
        .animation(.easeInOut(duration: 0.15), value: isFocused)
    }

    // MARK: - Card Background

    private var cardBackground: some View {
        Group {
            if isSelected {
                RoundedRectangle(cornerRadius: 10)
                    .fill(
                        LinearGradient(
                            colors: [
                                Ember.Palette.amber.opacity(0.12),
                                Ember.Palette.amberDark.opacity(0.05)
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Ember.Palette.amber.opacity(0.35), lineWidth: 1)
                    )
                    .shadow(color: Ember.Palette.amber.opacity(0.12), radius: 6, y: 2)
            } else if isFocused {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Ember.Palette.amber.opacity(0.04))
            } else if isHovering {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.primary.opacity(0.05))
            } else {
                Color.clear
            }
        }
    }

    // MARK: - Hover Actions

    private var hoverActions: some View {
        HStack(spacing: 3) {
            Button(action: onCopy) {
                Image(systemName: "doc.on.doc")
                    .font(.system(size: 10))
                    .foregroundColor(Ember.Palette.amber)
                    .frame(width: 24, height: 24)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Ember.Palette.amber.opacity(0.12))
                    )
            }
            .buttonStyle(.plain)
            .help("Copy")

            Button(action: onDelete) {
                Image(systemName: "xmark")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(Ember.Palette.rust.opacity(0.85))
                    .frame(width: 24, height: 24)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Ember.Palette.rust.opacity(0.1))
                    )
            }
            .buttonStyle(.plain)
            .help("Remove")
        }
    }

    // MARK: - Thumbnail

    @ViewBuilder
    private var itemThumbnail: some View {
        switch item.contentType {
        case .image:
            if let img = item.image {
                Image(nsImage: img)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 44, height: 44)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .strokeBorder(Color.white.opacity(0.12), lineWidth: 0.5)
                    )
                    .shadow(color: .black.opacity(0.12), radius: 3, y: 1)
            } else {
                thumbnailPlaceholder(icon: "photo.fill", color: Color(red: 0.28, green: 0.55, blue: 0.92))
            }
        case .file:
            if let icon = item.thumbnail {
                Image(nsImage: icon)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 32, height: 32)
                    .frame(width: 44, height: 44)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Ember.Palette.amber.opacity(0.08))
                    )
            } else {
                thumbnailPlaceholder(icon: "doc.fill", color: Ember.Palette.amber)
            }
        case .text:
            thumbnailPlaceholder(icon: "text.alignleft", color: Ember.Palette.moss)
        }
    }

    private func thumbnailPlaceholder(icon: String, color: Color) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8)
                .fill(color.opacity(0.12))
            Image(systemName: icon)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(color)
        }
        .frame(width: 44, height: 44)
    }

    // MARK: - Type Badge

    private var typeBadge: some View {
        let (label, color): (String, Color) = {
            switch item.contentType {
            case .text:
                return ("\(item.content.count) chars", Ember.Palette.moss)
            case .image:
                if let img = item.image {
                    return ("\(Int(img.size.width))×\(Int(img.size.height))", Color(red: 0.28, green: 0.55, blue: 0.92))
                }
                return ("Image", Color(red: 0.28, green: 0.55, blue: 0.92))
            case .file:
                let ext = (item.content as NSString).pathExtension.uppercased()
                return (ext.isEmpty ? "File" : ext, Ember.Palette.amber)
            }
        }()

        return Text(label)
            .font(.system(size: 9, weight: .bold, design: .rounded))
            .foregroundColor(color)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Capsule().fill(color.opacity(0.12)))
    }
}

// MARK: - Drag Source Overlay (AppKit)

struct DragSourceOverlay: NSViewRepresentable {
    let onTap: () -> Void
    let onCmdTap: () -> Void
    let onDoubleTap: () -> Void
    let onHoverChanged: (Bool) -> Void
    let onCopy: () -> Void
    let onDelete: () -> Void
    let onDragEnded: () -> Void
    let contentType: ShelfContentType
    let onRevealInFinder: (() -> Void)?
    let onOpenFile: (() -> Void)?
    let onShare: ((NSView) -> Void)?
    let makeDragItems: (NSPoint) -> [NSDraggingItem]

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeNSView(context: Context) -> DragSourceNSView {
        let view = DragSourceNSView()
        view.coordinator = context.coordinator
        updateCoordinator(context.coordinator)
        return view
    }

    func updateNSView(_ nsView: DragSourceNSView, context: Context) {
        updateCoordinator(context.coordinator)
    }

    private func updateCoordinator(_ c: Coordinator) {
        c.onTap = onTap
        c.onCmdTap = onCmdTap
        c.onDoubleTap = onDoubleTap
        c.onHoverChanged = onHoverChanged
        c.onCopy = onCopy
        c.onDelete = onDelete
        c.onDragEnded = onDragEnded
        c.contentType = contentType
        c.onRevealInFinder = onRevealInFinder
        c.onOpenFile = onOpenFile
        c.onShare = onShare
        c.makeDragItems = makeDragItems
    }

    class Coordinator {
        var onTap: (() -> Void)?
        var onCmdTap: (() -> Void)?
        var onDoubleTap: (() -> Void)?
        var onHoverChanged: ((Bool) -> Void)?
        var onCopy: (() -> Void)?
        var onDelete: (() -> Void)?
        var onDragEnded: (() -> Void)?
        var contentType: ShelfContentType = .text
        var onRevealInFinder: (() -> Void)?
        var onOpenFile: (() -> Void)?
        var onShare: ((NSView) -> Void)?
        var makeDragItems: ((NSPoint) -> [NSDraggingItem])?
    }
}

class DragSourceNSView: NSView, NSDraggingSource {
    weak var coordinator: DragSourceOverlay.Coordinator?

    private var mouseDownPoint: NSPoint?
    private var mouseDownEvent: NSEvent?
    private var didStartDrag = false
    private var currentTrackingArea: NSTrackingArea?

    override var isOpaque: Bool { false }
    override var isFlipped: Bool { true }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    func draggingSession(_ session: NSDraggingSession, sourceOperationMaskFor context: NSDraggingContext) -> NSDragOperation {
        context == .outsideApplication ? [.copy, .generic] : [.copy, .move, .generic]
    }

    func draggingSession(_ session: NSDraggingSession, endedAt screenPoint: NSPoint, operation: NSDragOperation) {
        coordinator?.onDragEnded?()
    }

    // MARK: - Mouse Events

    override func mouseDown(with event: NSEvent) {
        window?.makeKey()
        mouseDownPoint = convert(event.locationInWindow, from: nil)
        mouseDownEvent = event
        didStartDrag = false
    }

    override func mouseDragged(with event: NSEvent) {
        guard let start = mouseDownPoint, !didStartDrag else { return }
        let current = convert(event.locationInWindow, from: nil)
        let distance = hypot(current.x - start.x, current.y - start.y)

        guard distance > 5 else { return }
        didStartDrag = true

        guard let items = coordinator?.makeDragItems?(start), !items.isEmpty else { return }
        beginDraggingSession(with: items, event: mouseDownEvent ?? event, source: self)
    }

    override func mouseUp(with event: NSEvent) {
        if !didStartDrag {
            if event.clickCount == 2 {
                coordinator?.onDoubleTap?()
            } else if event.modifierFlags.contains(.command) {
                coordinator?.onCmdTap?()
            } else {
                coordinator?.onTap?()
            }
        }
        mouseDownPoint = nil
        mouseDownEvent = nil
        didStartDrag = false
    }

    // MARK: - Tracking Areas (Hover)

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let existing = currentTrackingArea { removeTrackingArea(existing) }
        let area = NSTrackingArea(
            rect: bounds,
            options: [.mouseEnteredAndExited, .activeInActiveApp],
            owner: self
        )
        addTrackingArea(area)
        currentTrackingArea = area
    }

    override func mouseEntered(with event: NSEvent) {
        coordinator?.onHoverChanged?(true)
    }

    override func mouseExited(with event: NSEvent) {
        coordinator?.onHoverChanged?(false)
    }

    // MARK: - Context Menu

    override func menu(for event: NSEvent) -> NSMenu? {
        let menu = NSMenu()

        let copyItem = NSMenuItem(title: "Copy", action: #selector(handleCopy), keyEquivalent: "c")
        copyItem.target = self
        menu.addItem(copyItem)

        if coordinator?.contentType != .text {
            menu.addItem(NSMenuItem.separator())

            let openItem = NSMenuItem(title: "Open", action: #selector(handleOpen), keyEquivalent: "")
            openItem.target = self
            menu.addItem(openItem)

            let revealItem = NSMenuItem(title: "Reveal in Finder", action: #selector(handleReveal), keyEquivalent: "")
            revealItem.target = self
            menu.addItem(revealItem)
        }

        menu.addItem(NSMenuItem.separator())
        let shareItem = NSMenuItem(title: "Share\u{2026}", action: #selector(handleShare), keyEquivalent: "")
        shareItem.target = self
        menu.addItem(shareItem)

        menu.addItem(NSMenuItem.separator())
        let removeItem = NSMenuItem(title: "Remove", action: #selector(handleDelete), keyEquivalent: "")
        removeItem.target = self
        menu.addItem(removeItem)

        return menu
    }

    @objc private func handleCopy() { coordinator?.onCopy?() }
    @objc private func handleDelete() { coordinator?.onDelete?() }
    @objc private func handleOpen() { coordinator?.onOpenFile?() }
    @objc private func handleReveal() { coordinator?.onRevealInFinder?() }
    @objc private func handleShare() { coordinator?.onShare?(self) }
}

// MARK: - ShelfItem Extension

extension ShelfItem {
    var timeAgo: String {
        let interval = Date().timeIntervalSince(dateAdded)
        if interval < 60 { return "Just now" }
        if interval < 3600 { return "\(Int(interval / 60))m ago" }
        if interval < 86400 { return "\(Int(interval / 3600))h ago" }
        return "\(Int(interval / 86400))d ago"
    }
}

// VisualEffectView is defined in QuickPreviewPanelView.swift and shared across the app
