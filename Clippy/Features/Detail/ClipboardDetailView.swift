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
                        // Başlık Giriş Alanı
                        TextField(L("Enter a title... (optional)", settings: settings), text: Binding(
                            get: { editedTitle ?? item.title ?? "" },
                            set: { editedTitle = $0 }
                        ))
                        .textFieldStyle(.plain)
                        .font(.title2.weight(.semibold))
                        .padding([.horizontal, .top])
                        
                        Divider()
                        
                        TextEditor(text: Binding(
                            get: { editedText ?? item.content ?? "" },
                            set: { editedText = $0 }
                        ))
                        .font(.body)
                        .padding(5)
                        
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
                    .padding()
                    .padding(.bottom, 8)
                } else if item.contentType == "image", let path = item.content {
                    if let image = monitor.loadImage(from: path) {
                        Image(nsImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .padding()
                    }
                    Spacer() // Resmin üstte kalmasını sağlar
                }
            }

            HStack {
                // "Back" butonu kaldırıldı, çünkü artık ayrı bir pencere.
                Spacer()
                
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
                if item.contentType == "image" {
                    Button {
                        showImageEditor = true
                    } label: {
                        Label(L("Edit Image", settings: settings), systemImage: "pencil.and.scribble")
                    }
                    .help("Annotate or edit this image")
                }
                
                Spacer()
                
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
                
                if editedText != nil || editedTitle != nil || editedKeyword != nil {
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
            .background(.bar)
        }
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
        .frame(minWidth: 450, idealWidth: 600, maxWidth: .infinity, minHeight: 350, idealHeight: 500, maxHeight: .infinity) // Pencerenin yeniden boyutlandırılabilir olmasını sağlar.
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
