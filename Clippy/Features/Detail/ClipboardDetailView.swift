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

    var body: some View {
        VStack(spacing: 0) {
            Group {
                if item.toClipboardItem().isJSON, let content = item.content {
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

                        ZStack(alignment: .bottomTrailing) {
                            TextEditor(text: Binding(
                                get: { editedText ?? item.content ?? "" },
                                set: { editedText = $0 }
                            ))
                            .font(.body)
                            .padding(5)

                            if let color = item.toClipboardItem().color {
                                color
                                    .frame(width: 80, height: 80)
                                    .cornerRadius(12)
                                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.secondary.opacity(0.5), lineWidth: 1))
                                    .shadow(radius: 5)
                                    .padding()
                            }
                        }
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
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Label(L("Keyword", settings: settings), systemImage: "keyboard")
                        TextField(L("e.g., ;sig", settings: settings), text: Binding(
                            get: { editedKeyword ?? item.keyword ?? "" },
                            set: { editedKeyword = $0 }
                        ))
                        .textFieldStyle(.roundedBorder)
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

                if item.contentType == "image" {
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

                if editedText != nil || editedTitle != nil || editedKeyword != nil || editedAppRules != nil {
                    Button(L("Save", settings: settings)) {
                        if let newText = editedText, newText != item.content { item.content = newText }

                        let newTitle = editedTitle?.trimmingCharacters(in: .whitespacesAndNewlines)
                        if newTitle != item.title { item.title = (newTitle?.isEmpty ?? true) ? nil : newTitle }

                        let newKeyword = editedKeyword?.trimmingCharacters(in: .whitespacesAndNewlines)
                        if newKeyword != item.keyword { item.keyword = (newKeyword?.isEmpty ?? true) ? nil : newKeyword }

                        let newRules = editedAppRules?.trimmingCharacters(in: .whitespacesAndNewlines)
                        if newRules != item.applicationRules { item.applicationRules = (newRules?.isEmpty ?? true) ? nil : newRules }

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
