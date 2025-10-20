
import SwiftUI
import UniformTypeIdentifiers
import CoreData

struct ContentView: View {
    @EnvironmentObject private var monitor: ClipboardMonitor
    @State private var selectedTab: Tab = .history
    @State private var searchText: String = ""
    
    @State private var comparisonData: ComparisonData?
    
    @FetchRequest private var items: FetchedResults<ClipboardItemEntity>
    
    init() {
        _items = FetchRequest<ClipboardItemEntity>(sortDescriptors: [
            NSSortDescriptor(keyPath: \ClipboardItemEntity.isPinned, ascending: false),
            NSSortDescriptor(keyPath: \ClipboardItemEntity.date, ascending: false)
        ], predicate: NSPredicate(value: true))
    }


    @EnvironmentObject var settings: SettingsManager

    enum Tab {
        case history, code, images, snippets, favorites
    }

    var body: some View {
        VStack {
            ClipboardListView(
                items: items,
                monitor: monitor,
                selectedTab: selectedTab,
                searchText: $searchText,
                comparisonData: $comparisonData
            )
            .safeAreaInset(edge: .top) {
                VStack(spacing: 0) {
                    HStack {
                        Picker("Tabs", selection: $selectedTab) {
                            Text(L("History", settings: settings)).tag(Tab.history)
                                if settings.showCodeTab {
                                    Text(L("Code", settings: settings)).tag(Tab.code)
                                }
                                if settings.showImagesTab {
                                    Text(L("Images", settings: settings)).tag(Tab.images)
                                }
                                if settings.showSnippetsTab {
                                    Text(L("Snippets", settings: settings)).tag(Tab.snippets)
                                }
                                if settings.showFavoritesTab {
                                    Text(L("Favorites", settings: settings)).tag(Tab.favorites)
                                }
                            }
                        .pickerStyle(.segmented)

                        Spacer()

                        // Araçlar Menüsü (Oluşturma ve Temizleme)
                        Menu {
                            Section(header: Text(L("Generate", settings: settings))) {
                                Button(L("Generate UUID", settings: settings)) { monitor.generateUUID() }
                                Button(L("Generate Lorem Ipsum", settings: settings)) { monitor.generateLoremIpsum() }
                            }
                        } label: {
                            Image(systemName: "wand.and.stars")
                        }
                        .menuStyle(.borderlessButton)
                        .help(L("Tools", settings: settings))
                        .menuIndicator(.hidden)

                        Button(role: .destructive) {
                            monitor.clear(tab: selectedTab)
                        } label: {
                            Image(systemName: "trash")
                        }
                        .help(L("Clear items in current tab", settings: settings))
                        .buttonStyle(.borderless)
                        .disabled(items.isEmpty)
                        .opacity(items.isEmpty ? 0.5 : 1)
                        
                    }
                    .padding(.horizontal)
                    .padding(.top, 10)
                    .padding(.bottom, 5)
                    .fixedSize()

                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.secondary)
                        TextField(L("Search in clipboard history...", settings: settings), text: $searchText)
                            .textFieldStyle(.plain)
                            .padding(.vertical, 4)
                        if !searchText.isEmpty {
                            Button {
                                searchText = ""
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                            }
                            .buttonStyle(.borderless)
                            .foregroundColor(.secondary)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 10)
                }
                .background(.bar)
            }
        }
        .safeAreaInset(edge: .bottom) {
            bottomBar
        }
        .id(settings.appLanguage)
        .onChange(of: selectedTab, perform: updatePredicate)
        .onChange(of: searchText, perform: updatePredicate)
        .onAppear { updatePredicate(searchText) }
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
        case .favorites:
            predicates.append(NSPredicate(format: "isFavorite == YES"))
        }

        if !searchText.isEmpty {
            predicates.append(NSPredicate(format: "content CONTAINS[c] %@", searchText))
        }

        items.nsPredicate = NSCompoundPredicate(andPredicateWithSubpredicates: predicates)
    }
    
    @ViewBuilder
    private var bottomBar: some View {
        if !monitor.selectedItemIDs.isEmpty {
            HStack {
                Text(String(format: L("%d items selected", settings: settings), monitor.selectedItemIDs.count))
                    .font(.footnote)
                    .foregroundColor(.secondary)
                Spacer()
                
                if monitor.selectedItemIDs.count > 1 {
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

struct ComparisonData: Identifiable {
    let id = UUID()
    let oldItem: ClipboardItem
    let newItem: ClipboardItem
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
            .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
            .environmentObject(SettingsManager.shared)
            .environmentObject(ClipboardMonitor())
    }
}

struct ClipboardRowView: View {
    @ObservedObject var item: ClipboardItemEntity
    let items: FetchedResults<ClipboardItemEntity>
    @Binding var comparisonData: ComparisonData?
    @ObservedObject var monitor: ClipboardMonitor
    @EnvironmentObject var settings: SettingsManager
    let selectedTab: ContentView.Tab
    var itemIndex: Int
    
    @State private var didCopy = false

    var body: some View {
        rowContent
        .onDrag {
            let provider: NSItemProvider

            let isMultiDrag = monitor.selectedItemIDs.count > 1 && monitor.selectedItemIDs.contains(item.id ?? UUID())

            if isMultiDrag {
                provider = monitor.createItemProviderForSelection()
            } else {
                provider = self.itemProvider(for: item)
            }
            
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: .closeClippyPopover, object: nil)
                if isMultiDrag {
                    monitor.clearSelection()
                }
            }

            return provider
        } preview: {
            let itemToShow = item
            
            VStack {
                if itemToShow.contentType == "text" {
                    Text(itemToShow.content ?? "")
                        .lineLimit(15)
                        .font(.body)
                } else if itemToShow.contentType == "image", let imagePath = itemToShow.content {
                    if let image = loadImage(from: imagePath) {
                        Image(nsImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(maxWidth: 200, maxHeight: 200)
                    }
                }
            }
            .padding(10)
            .background(.regularMaterial)
            .cornerRadius(8)
            .shadow(radius: 3)
        }
    }

    private var rowContent: some View {
        let isSelected = monitor.selectedItemIDs.contains(item.id ?? UUID())

        return HStack(spacing: 12) {
            favoriteButton(for: item)

            Button(action: {
                monitor.togglePin(for: item.id ?? UUID())
            }) {
                Image(systemName: item.isPinned ? "pin.fill" : "pin")
                    .foregroundColor(item.isPinned ? .accentColor : .secondary)
                    .rotationEffect(.degrees(item.isPinned ? 0 : -45))
            }
            .buttonStyle(.plain)

            contentView(for: item)

            Spacer()

            HStack(spacing: 0) {
                if item.contentType == "text" {
                    if item.toClipboardItem().isURL, let content = item.content, let url = URL(string: content) {
                        Button { NSWorkspace.shared.open(url) } label: {
                            Image(systemName: "safari")
                        }
                        .buttonStyle(.borderless)
                        .help(L("Open URL in Browser", settings: settings))
                    }
                    if item.detectedDate != nil {
                        Button { monitor.createCalendarEvent(for: item) } label: {
                            Image(systemName: "calendar.badge.plus")
                        }
                        .buttonStyle(.borderless)
                        .help(L("Add to Calendar", settings: settings))
                    }
                    transformationMenu(for: item)
                }
                pasteButton
            }
        }
        .padding(.vertical, 4)
        .id(item.id)
        .background(isSelected ? Color.accentColor.opacity(0.2) : Color.clear) 
        .cornerRadius(4)
        .contentShape(SwiftUI.Rectangle())
        .onTapGesture {
            if NSEvent.modifierFlags.contains(.command) {
                monitor.toggleSelection(for: item.id ?? UUID())
            } else {
                // Detay penceresini AppDelegate üzerinden aç
                monitor.appDelegate?.showDetailWindow(for: item)
            }
        }
        .contextMenu { contextMenuItems }
    }

    // MARK: - Subviews

    @ViewBuilder
    private var pasteButton: some View {
        Button(L("Paste", settings: settings)) {
            PasteManager.shared.pasteItem(item.toClipboardItem())
        }
        .buttonStyle(.bordered)
        .controlSize(.small)
    }
    
    
    @ViewBuilder
    private func favoriteButton(for item: ClipboardItemEntity) -> some View {
        Button(action: {
            withAnimation { monitor.toggleFavorite(for: item.id ?? UUID()) }
        }) {
            Image(systemName: item.isFavorite ? "star.fill" : "star")
                .foregroundColor(item.isFavorite ? .yellow : .secondary)
        }
        .buttonStyle(.plain)
        .overlay(alignment: .topTrailing) {
            if monitor.isPastingFromQueue, let id = item.id, let queueIndex = monitor.sequentialPasteQueueIDs.firstIndex(of: id) {
                let isNext = (queueIndex == monitor.sequentialPasteIndex % monitor.sequentialPasteQueueIDs.count)
                
                Text("\(queueIndex + 1)")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.white)
                    .padding(4)
                    .background(Circle().fill(isNext ? .green : .orange))
                    .offset(x: 8, y: -8)
                    .help(isNext ? L("Next to Paste", settings: settings) : "")
            }
            else if !monitor.selectedItemIDs.isEmpty, let id = item.id, let selectionIndex = monitor.selectedItemIDs.firstIndex(of: id) {
                Text("\(selectionIndex + 1)")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.white)
                    .padding(4)
                    .background(Circle().fill(Color.accentColor))
                    .offset(x: 8, y: -8)
            }
        }
    }
    
    private func loadImage(from path: String) -> NSImage? {
        return monitor.loadImage(from: path)
    }

    private func imageURL(from path: String) -> URL? {
        return monitor.getImagesDirectory()?.appendingPathComponent(path)
    }
    
    @ViewBuilder
    private func contentView(for item: ClipboardItemEntity) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            if let title = item.title, !title.isEmpty {
                Text(title)
                    .font(.headline)
                    .lineLimit(1)
            }
            
            if item.isEncrypted {
                HStack(spacing: 4) {
                    Image(systemName: "lock.fill").foregroundColor(.secondary)
                    Text(L("Encrypted Content", settings: settings)).foregroundColor(.secondary)
                }.font(.body)
            } else if item.contentType == "text" {
                HStack(alignment: .center) {
                    Text((item.content ?? "").trimmingCharacters(in: .whitespacesAndNewlines))
                        .lineLimit(3)
                        .font(.body)
                    
                    if let color = item.toClipboardItem().color {
                        SwiftUI.Rectangle()
                            .fill(color)
                            .frame(width: 18, height: 18)
                            .cornerRadius(4)
                            .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.secondary, lineWidth: 0.5))
                    }
                }
            } else if item.contentType == "image" {
                if let path = item.content, let image = loadImage(from: path) {
                    Image(nsImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 40, height: 40)
                        .clipped()
                        .cornerRadius(4)
                }
            }
            
            HStack(spacing: 4) {
                if let bundleId = item.sourceAppBundleIdentifier {
                    IconView(bundleIdentifier: bundleId, monitor: monitor, size: 14)
                }
                
                Text(item.date ?? Date(), style: .time)
                    .font(.caption).foregroundColor(.secondary)
            }
        }
    }

    @ViewBuilder
    private var contextMenuItems: some View {
        Button { monitor.copyToClipboard(item: item.toClipboardItem()) } label: {
            Label(L("Copy", settings: settings), systemImage: "doc.on.doc")
        }

        if let compareItems = getItemsToCompare() {
            Button {
                monitor.appDelegate?.showDiffWindow(oldText: compareItems.0.content ?? "", newText: compareItems.1.content ?? "")
                monitor.clearSelection()
            } label: {
                Label(L("Compare...", settings: settings), systemImage: "square.split.2x1")
            }
        } else if monitor.selectedItemIDs.count > 0 {
            Label(L("Compare (select 2 text items)", settings: settings), systemImage: "square.split.2x1").disabled(true)
        }

        Divider()

        Button { monitor.toggleEncryption(for: item.id ?? UUID()) } label: {
            Label(item.isEncrypted ? L("Decrypt Item", settings: settings) : L("Encrypt Item", settings: settings),
                  systemImage: item.isEncrypted ? "lock.open" : "lock")
        }

        Divider()
        Menu(L("Combine Images", settings: settings)) {
            Button {
                monitor.combineSelectedImagesAsNewItem(orientation: .vertical)
                monitor.clearSelection()
            } label: { Label(L("Combine Vertically", settings: settings), systemImage: "arrow.down.to.line.compact") }
            
            Button {
                monitor.combineSelectedImagesAsNewItem(orientation: .horizontal)
                monitor.clearSelection()
            } label: { Label(L("Combine Horizontally", settings: settings), systemImage: "arrow.right.to.line.compact") }
        }
        .disabled(!hasMultipleImagesSelected())

        Divider()

        Button(role: .destructive) {
            if monitor.selectedItemIDs.count > 1 && monitor.selectedItemIDs.contains(item.id ?? UUID()) {
                monitor.deleteSelectedItems()
            } else {
                monitor.delete(item: item)
            }
        } label: {
            let isMultiDelete = monitor.selectedItemIDs.count > 1 && monitor.selectedItemIDs.contains(item.id ?? UUID())
            let labelText = isMultiDelete ? String(format: L("Delete %d Items", settings: settings), monitor.selectedItemIDs.count) : L("Delete", settings: settings)
            Label(labelText, systemImage: "trash")
        }
    }
    
    /// Seçili öğeler arasında birden fazla resim olup olmadığını kontrol eder.
    private func hasMultipleImagesSelected() -> Bool {
        guard monitor.selectedItemIDs.count > 1 else { return false }
        
        let fetchRequest: NSFetchRequest<ClipboardItemEntity> = ClipboardItemEntity.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "id IN %@ AND contentType == 'image'", monitor.selectedItemIDs)
        
        do {
            let count = try item.managedObjectContext?.count(for: fetchRequest) ?? 0
            return count > 1
        } catch {
            return false
        }
    }

    private func transformationMenu(for item: ClipboardItemEntity) -> some View {
        let locale: Locale?
        if settings.appLanguage == "system" {
            if let langCode = Locale.preferredLanguages.first?.prefix(2) {
                locale = Locale(identifier: String(langCode))
            } else {
                locale = .current
            }
        } else {
            locale = Locale(identifier: String(settings.appLanguage.prefix(2)))
        }

        return Menu {
            if let itemID = item.id {
                Group {
                    Section(header: Text(L("Transform Text", settings: settings))) {
                        Button(L("All Uppercase", settings: settings)) { monitor.updateText(for: itemID, transformation: { $0.uppercased(with: locale) }) }
                        Button(L("All Lowercase", settings: settings)) { monitor.updateText(for: itemID, transformation: { $0.lowercased(with: locale) }) }
                        Button(L("Title Case", settings: settings)) { monitor.updateText(for: itemID, transformation: { $0.capitalized(with: locale) }) }
                        Button(L("Trim Whitespace", settings: settings)) { monitor.updateText(for: itemID, transformation: { $0.trimmingCharacters(in: .whitespacesAndNewlines) }) }
                    }

                    Section(header: Text(L("Line Operations", settings: settings))) {
                        Button(L("Remove Duplicate Lines", settings: settings)) { monitor.removeDuplicateLines(for: itemID) }
                        Button(L("Join All Lines", settings: settings)) { monitor.joinLines(for: itemID) }
                    }
                    
                    Section(header: Text(L("Coding", settings: settings))) {
                        Button(L("Base64 Encode", settings: settings)) {
                            monitor.updateText(for: itemID, transformation: { $0.data(using: .utf8)?.base64EncodedString() ?? $0 })
                        }
                        Button(L("Base64 Decode", settings: settings)) {
                            monitor.updateText(for: itemID, transformation: { Data(base64Encoded: $0).flatMap { String(data: $0, encoding: .utf8) } ?? $0 })
                        }
                        Button(L("Encode as JSON String", settings: settings)) { monitor.encodeAsJSONString(for: itemID) }
                        Button(L("Decode from JSON String", settings: settings)) { monitor.decodeFromJSONString(for: itemID) }
                    }
                    
                    if item.toClipboardItem().isJSON {
                        Section(header: Text(L("JSON", settings: settings))) {
                            Button(L("Format JSON", settings: settings)) { monitor.formatJSON(for: itemID) }
                            Button(L("Minify JSON", settings: settings)) { monitor.minifyJSON(for: itemID) }
                        }
                    }
                }
            } else {
                EmptyView()
            }

        } label: {
            Image(systemName: "wand.and.stars")
        }
        .menuStyle(.borderlessButton)
        .help(L("Transform Text", settings: settings))
        .menuIndicator(.hidden)
        .frame(width: 30)
    }

    private func itemProvider(for item: ClipboardItemEntity) -> NSItemProvider {
        if item.contentType == "text", let text = item.content {
            return NSItemProvider(object: text as NSString)
        } else if item.contentType == "image", let path = item.content {
            if let imageURL = imageURL(from: path) {
                return NSItemProvider(object: imageURL as NSURL)
            }
        }
        return NSItemProvider()
    }
    
    private func getItemsToCompare() -> (ClipboardItemEntity, ClipboardItemEntity)? {
        guard monitor.selectedItemIDs.count == 2 else { return nil }
        
        let selectedItems = monitor.selectedItemIDs.compactMap { id in
            items.first { $0.id == id && $0.contentType == "text" }
        }
        
        guard selectedItems.count == 2 else { return nil }
        
        if (selectedItems[0].date ?? .distantPast) < (selectedItems[1].date ?? .distantPast) {
            return (selectedItems[0], selectedItems[1])
        } else {
            return (selectedItems[1], selectedItems[0])
        }
    }
}
