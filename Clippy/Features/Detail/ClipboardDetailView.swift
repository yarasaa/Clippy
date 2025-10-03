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
    @State private var showImageEditor = false

    @State private var editedText: String?
    @State private var editedTitle: String?
    @State private var editedKeyword: String?
    
    var body: some View {
        VStack {
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
                    VStack {
                        // Başlık Giriş Alanı
                        TextField(L("Enter a title... (optional)", settings: settings), text: Binding(
                            get: { editedTitle ?? item.title ?? "" },
                            set: { editedTitle = $0 }
                        ))
                        .textFieldStyle(.plain)
                        .font(.title2.weight(.semibold))
                        .padding()
                        
                        Divider()
                        
                        TextEditor(text: Binding(
                            get: { editedText ?? item.content ?? "" },
                            set: { editedText = $0 }
                        ))
                        .font(.body)
                        
                        TextStatsView(text: editedText ?? item.content ?? "")
                    }
                    
                    // Anahtar Kelime Giriş Alanı
                    HStack {
                        Text(L("Keyword:", settings: settings))
                            .font(.headline)
                        TextField(L("e.g., ;imza", settings: settings), text: Binding(
                            get: { editedKeyword ?? item.keyword ?? "" },
                            set: { editedKeyword = $0 }
                        ))
                        .textFieldStyle(.roundedBorder)
                        .help(L("Type this keyword in any app to paste the content.", settings: settings))
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 8)
                } else if item.contentType == "image", let path = item.content {
                    ScrollView {
                        if let image = monitor.loadImage(from: path) {
                            Image(nsImage: image)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .padding()
                        }
                    }
                }
            }

            Spacer()
            
            HStack {
                Button { dismiss() } label: {
                    Label(L("Back", settings: settings), systemImage: "arrow.left")
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
                            Label("Scan Text", systemImage: "text.viewfinder")
                        }
                    }
                    .help("Recognize text in this image")
                    .disabled(isScanning)
                }
                if item.contentType == "image" {
                    Button {
                        showImageEditor = true
                    } label: {
                        Label("Edit Image", systemImage: "pencil.and.scribble")
                    }
                    .help("Annotate or edit this image")
                }
                
                Spacer()
                
                Button {
                    if let newText = editedText {
                        item.content = newText
                        monitor.scheduleSave()
                        editedText = nil
                        monitor.copyToClipboard(item: item.toClipboardItem())
                    } else {
                        monitor.copyToClipboard(item: item.toClipboardItem())
                    }
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
                
                if editedText != nil {
                    Button(L("Save", settings: settings)) {
                        if let newText = editedText {
                            item.content = newText
                            monitor.scheduleSave()
                        }
                        if let newTitle = editedTitle {
                            item.title = newTitle.isEmpty ? nil : newTitle
                            monitor.scheduleSave()
                        }
                        if let newKeyword = editedKeyword {
                            item.keyword = newKeyword.isEmpty ? nil : newKeyword
                            monitor.scheduleSave()
                        }
                        dismiss()
                    }.keyboardShortcut("s", modifiers: .command)
                }

            }
            .padding()
        }
        .navigationTitle(L("Detail", settings: settings))
        .onAppear {
            if item.contentType == "text" {
                if editedTitle == nil { editedTitle = item.title }
                if editedText == nil { editedText = item.content }
                if editedKeyword == nil {
                    editedKeyword = item.keyword?.trimmingCharacters(in: .whitespaces) ?? ""
                }
            }
        }
        .sheet(isPresented: $showImageEditor) {
            if let imagePath = item.content, let image = monitor.loadImage(from: imagePath) {
                ImageEditorView(image: image) { editedImage in
                    monitor.saveEditedImage(editedImage, from: item)
                    dismiss()
                }
                .environmentObject(settings)
            }
        }
    }
    
}

// MARK: - Statistics Subviews

/// Metin istatistiklerini (karakter, kelime, satır) gösteren görünüm.
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

/// Tek bir istatistik öğesini (değer ve etiket) gösteren küçük görünüm.
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
