//
//  ClipboardDetailView.swift
//  Clippy
//
//  Created by Mehmet Akbaba on 17.09.2025.
//


import SwiftUI
import CoreData

struct ClipboardDetailView: View {
    @ObservedObject var item: ClipboardItemEntity
    @ObservedObject var monitor: ClipboardMonitor
    @EnvironmentObject var settings: SettingsManager
    @Environment(\.dismiss) var dismiss

    @State private var didCopy = false
    @State private var isScanning = false
    @State private var showAppPicker = false

    @State private var editedText: String?
    @State private var editedTitle: String?
    @State private var editedKeyword: String?
    @State private var editedAppRules: String?
    @State private var editedCategory: String?

    var body: some View {
        VStack(spacing: 0) {
            Group {
                if let content = item.content, content.count <= 50_000, item.toClipboardItem().isJSON {
                    JSONDetailView(
                        initialText: content,
                        onSave: { newText in
                            item.content = newText
                            monitor.scheduleSave()
                            dismiss()
                        }
                    )
                } else if item.contentType == "text" {
                    VStack(spacing: 0) {
                        TextField(L("Enter a title... (optional)", settings: settings), text: Binding(
                            get: { editedTitle ?? item.title ?? "" },
                            set: { editedTitle = $0 }
                        ))
                        .textFieldStyle(.plain)
                        .font(.title2.weight(.semibold))
                        .padding([.horizontal, .top])

                        Divider()

                        PlainTextEditor(text: Binding(
                            get: { editedText ?? item.content ?? "" },
                            set: { editedText = $0 }
                        ))
                        .font(.body)
                        .padding(5)
                    }
                } else if item.contentType == "image", let path = item.content {
                    if let image = monitor.loadImage(from: path) {
                        Image(nsImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .padding()
                    }
                }
            }

            HStack {
                // Color preview on the left side (only for short content that could be a color value)
                if let content = item.content, content.count <= 50, let color = item.toClipboardItem().color {
                    color
                        .frame(width: 50, height: 50)
                        .cornerRadius(8)
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.secondary.opacity(0.3), lineWidth: 1))
                        .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
                        .padding(.trailing, 8)
                }

                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Label(L("Keyword", settings: settings), systemImage: "keyboard")
                        TextField(L("e.g., ;sig", settings: settings), text: Binding(
                            get: { editedKeyword ?? item.keyword ?? "" },
                            set: { editedKeyword = $0 }
                        ))
                        .textFieldStyle(.roundedBorder)
                    }

                    // Category picker (only if category system is enabled)
                    if settings.isCategorySystemEnabled, let keyword = item.keyword, !keyword.isEmpty {
                        HStack {
                            Label(L("Category", settings: settings), systemImage: "folder")

                            Picker("", selection: Binding(
                                get: { editedCategory ?? item.category ?? "" },
                                set: { editedCategory = $0.isEmpty ? nil : $0 }
                            )) {
                                Text(L("None", settings: settings)).tag("")
                                ForEach(settings.snippetCategories) { category in
                                    Text("\(category.icon) \(L(category.name, settings: settings))").tag(category.name)
                                }
                            }
                            .frame(maxWidth: 200)
                        }
                    }

                    if let keyword = item.keyword, !keyword.isEmpty {
                        HStack(spacing: 16) {
                            HStack(spacing: 4) {
                                Image(systemName: "chart.bar.fill")
                                    .foregroundColor(.blue)
                                Text("\(L("Usage", settings: settings)): \(item.usageCount)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }

                            if let lastUsed = item.lastUsedDate {
                                HStack(spacing: 4) {
                                    Image(systemName: "clock.fill")
                                        .foregroundColor(.green)
                                    Text("\(L("Last", settings: settings)): \(lastUsed, style: .relative)")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                        .padding(.leading, 24)
                    }

                    HStack {
                        Label(L("Apps", settings: settings), systemImage: "app.dashed")

                        let identifiers = (editedAppRules ?? item.applicationRules ?? "").split(separator: ",").map { String($0).trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }

                        if identifiers.isEmpty {
                            Text(L("All Apps", settings: settings)).foregroundColor(.secondary).padding(.horizontal, 4)
                        } else {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack {
                                    ForEach(identifiers, id: \.self) { id in
                                        IconView(bundleIdentifier: id, monitor: monitor, size: 18)
                                    }
                                }
                            }
                        }

                        Button(L("Select...", settings: settings)) {
                            showAppPicker = true
                        }
                        .help(L("Set Application Rules", settings: settings))
                    }
                }

                if item.contentType == "image" && settings.enableOCR {
                    Button {
                        isScanning = true
                        Task {
                            await monitor.recognizeText(for: item)
                            dismiss()
                        }
                    } label: {
                        if isScanning {
                            ProgressView().scaleEffect(0.5)
                        } else {
                            Label(L("Scan Text", settings: settings), systemImage: "text.viewfinder")
                        }
                    }
                    .help(L("Recognize text in this image", settings: settings))
                    .disabled(isScanning)
                }

                Button {
                    monitor.copyToClipboard(item: item.toClipboardItem())
                    withAnimation { didCopy = true }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        withAnimation { didCopy = false }
                    }
                } label: {
                    if didCopy {
                        Label(L("Copied", settings: settings), systemImage: "checkmark.circle.fill")
                            .foregroundColor(.green)
                    } else {
                        Label(L("Copy", settings: settings), systemImage: "doc.on.doc")
                    }
                }
                .help(L("Copy", settings: settings))

                if editedText != nil || editedTitle != nil || editedKeyword != nil || editedAppRules != nil || editedCategory != nil {
                    Button(L("Save", settings: settings)) {
                        if let newText = editedText, newText != item.content { item.content = newText }

                        let newTitle = editedTitle?.trimmingCharacters(in: .whitespacesAndNewlines)
                        if newTitle != item.title { item.title = (newTitle?.isEmpty ?? true) ? nil : newTitle }

                        let newKeyword = editedKeyword?.trimmingCharacters(in: .whitespacesAndNewlines)
                        if newKeyword != item.keyword { item.keyword = (newKeyword?.isEmpty ?? true) ? nil : newKeyword }

                        let newRules = editedAppRules?.trimmingCharacters(in: .whitespacesAndNewlines)
                        if newRules != item.applicationRules { item.applicationRules = (newRules?.isEmpty ?? true) ? nil : newRules }

                        let newCategory = editedCategory?.trimmingCharacters(in: .whitespacesAndNewlines)
                        if newCategory != item.category { item.category = (newCategory?.isEmpty ?? true) ? nil : newCategory }

                        monitor.scheduleSave()
                        dismiss()
                    }.keyboardShortcut("s", modifiers: .command)
                }

            }
            .padding()
            .background(.bar)
        }
        .preferredColorScheme(colorScheme)
        .onAppear {
            editedTitle = item.title
            editedText = item.content
            editedKeyword = item.keyword
            editedAppRules = item.applicationRules
            editedCategory = item.category
            if item.contentType == "image" {
                Task {
                    if let imagePath = item.content, let _ = monitor.loadImage(from: imagePath) {
                    }
                }
            }
        }
        .sheet(isPresented: $showAppPicker) {
            AppPickerView(selectedIdentifiers: Binding(
                get: { Set((editedAppRules ?? "").split(separator: ",").map { String($0).trimmingCharacters(in: .whitespaces) }) },
                set: { newIdentifiers in editedAppRules = newIdentifiers.sorted().joined(separator: ",") }
            ))
            .environmentObject(settings)
        }
        .frame(minWidth: 450, idealWidth: 600, maxWidth: .infinity, minHeight: 350, idealHeight: 500, maxHeight: .infinity)
    }

    private var colorScheme: ColorScheme? {
        switch settings.appTheme {
        case "light":
            return .light
        case "dark":
            return .dark
        default:
            return nil
        }
    }

}

// Custom TextEditor that disables smart quotes and dashes
struct PlainTextEditor: NSViewRepresentable {
    @Binding var text: String

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSTextView.scrollableTextView()
        let textView = scrollView.documentView as! NSTextView

        // Disable smart quotes and smart dashes
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false

        textView.delegate = context.coordinator
        textView.isRichText = false
        textView.font = NSFont.systemFont(ofSize: NSFont.systemFontSize)
        textView.string = text

        return scrollView
    }

    func updateNSView(_ nsView: NSScrollView, context: Context) {
        let textView = nsView.documentView as! NSTextView
        if textView.string != text {
            textView.string = text
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, NSTextViewDelegate {
        var parent: PlainTextEditor

        init(_ parent: PlainTextEditor) {
            self.parent = parent
        }

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            parent.text = textView.string
        }
    }
}

struct TextStatsView: View {
    let text: String
    @EnvironmentObject var settings: SettingsManager

    private var characterCount: Int {
        text.count
    }

    private var wordCount: Int {
        text.split { !$0.isLetter && !$0.isNumber }.count
    }

    private var lineCount: Int {
        text.split(separator: "\n", omittingEmptySubsequences: false).count
    }

    var body: some View {
        HStack {
            StatItem(label: L("Characters", settings: settings), value: characterCount)
            Spacer()
            StatItem(label: L("Words", settings: settings), value: wordCount)
            Spacer()
            StatItem(label: L("Lines", settings: settings), value: lineCount)
        }
        .padding()
    }
}

struct StatItem: View {
    let label: String
    let value: Int

    var body: some View {
        VStack {
            Text("\(value)")
                .font(.title2.weight(.semibold))
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}

struct IconView: View {
    let bundleIdentifier: String
    @ObservedObject var monitor: ClipboardMonitor
    var size: CGFloat = 24
    @State private var icon: NSImage?

    var body: some View {
        Group {
            if let icon = icon {
                Image(nsImage: icon)
                    .resizable()
            } else {
                ProgressView()
                    .scaleEffect(0.5)
            }
        }
        .frame(width: size, height: size)
        .onAppear {
            monitor.loadIcon(for: bundleIdentifier) { loadedIcon in self.icon = loadedIcon }
        }
    }
}
