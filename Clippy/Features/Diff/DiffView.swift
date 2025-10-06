//
//  DiffView.swift
//  Clippy
//
//  Created by Mehmet Akbaba on 21.09.2025.
//

import SwiftUI

struct DiffView: View {
    @State var oldText: String
    @State var newText: String
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var settings: SettingsManager
    @EnvironmentObject var monitor: ClipboardMonitor
    
    @State private var copiedSide: Side?

    struct SplitDiffLine: Identifiable {
        let id = UUID()
        let leftContent: String?
        let rightContent: String?
        let leftLineNumber: Int?
        let rightLineNumber: Int?
        enum ChangeType { case added, removed, unchanged, modified }
        var type: ChangeType
    }

    private var diffLines: [SplitDiffLine] {
        let oldLines = oldText.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        let newLines = newText.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)

        var matrix = Array(repeating: Array(repeating: 0, count: newLines.count + 1), count: oldLines.count + 1)

        for i in 1...oldLines.count {
            for j in 1...newLines.count {
                if oldLines[i-1] == newLines[j-1] {
                    matrix[i][j] = matrix[i-1][j-1] + 1
                } else {
                    matrix[i][j] = max(matrix[i-1][j], matrix[i][j-1])
                }
            }
        }

        var i = oldLines.count
        var j = newLines.count
        var finalLines: [SplitDiffLine] = []
        var leftLineNum = oldLines.count
        var rightLineNum = newLines.count

        while i > 0 || j > 0 {
            if i > 0 && j > 0 && oldLines[i-1] == newLines[j-1] {
                finalLines.insert(SplitDiffLine(leftContent: oldLines[i-1], rightContent: newLines[j-1], leftLineNumber: leftLineNum, rightLineNumber: rightLineNum, type: .unchanged), at: 0)
                i -= 1
                j -= 1
                leftLineNum -= 1
                rightLineNum -= 1
            } else if j > 0 && (i == 0 || matrix[i][j-1] >= matrix[i-1][j]) {
                finalLines.insert(SplitDiffLine(leftContent: nil, rightContent: newLines[j-1], leftLineNumber: nil, rightLineNumber: rightLineNum, type: .added), at: 0)
                j -= 1
                rightLineNum -= 1
            } else if i > 0 && (j == 0 || matrix[i][j-1] < matrix[i-1][j]) {
                finalLines.insert(SplitDiffLine(leftContent: oldLines[i-1], rightContent: nil, leftLineNumber: leftLineNum, rightLineNumber: nil, type: .removed), at: 0)
                i -= 1
                leftLineNum -= 1
            } else {
                break
            }
        }

        var processedLines: [SplitDiffLine] = []
        var index = 0
        while index < finalLines.count {
            if index + 1 < finalLines.count,
               finalLines[index].type == .removed,
               finalLines[index+1].type == .added {
                processedLines.append(SplitDiffLine(
                    leftContent: finalLines[index].leftContent,
                    rightContent: finalLines[index+1].rightContent,
                    leftLineNumber: finalLines[index].leftLineNumber,
                    rightLineNumber: finalLines[index+1].rightLineNumber,
                    type: .modified
                ))
                index += 2
            } else {
                processedLines.append(finalLines[index])
                index += 1
            }
        }

        return processedLines
    }

    var body: some View {
        VStack(spacing: 0) {
            Text(L("Compare Differences", settings: settings))
                .font(.title2.bold())
                .padding()

            HStack(spacing: 0) {
                editorPane(for: .left, text: $oldText)
                editorPane(for: .right, text: $newText)
            }

            bottomToolbar
                .padding()
                .background(.bar)
        }
        .frame(minWidth: 800, idealWidth: 1000, minHeight: 500, idealHeight: 700)
        .keyboardShortcut(.escape, modifiers: [])
    }

    @ViewBuilder
    private func editorPane(for side: Side, text: Binding<String>) -> some View {
        VStack(spacing: 0) {
            HStack {
                Text(side == .left ? L("Old Text", settings: settings) : L("New Text", settings: settings))
                    .font(.headline)
                Spacer()
                Button {
                    handleCopy(for: text.wrappedValue, side: side)
                } label: {
                    if copiedSide == side {
                        Image(systemName: "checkmark.circle.fill").foregroundColor(.green)
                    } else {
                        Image(systemName: "doc.on.doc")
                    }
                }
                .buttonStyle(.borderless)
                .help(side == .left ? L("Copy Old Text", settings: settings) : L("Copy New Text", settings: settings))
            }
            .padding(8)
            .background(Color.secondary.opacity(0.1))

            TextEditor(text: text)
                .font(.system(.body, design: .monospaced))
        }
    }

    private var bottomToolbar: some View {
        HStack {
            Button(L("Close", settings: settings)) {
                dismiss()
            }

            Spacer()

            Button {
                newText = oldText
            } label: {
                Label(L("Merge All", settings: settings), systemImage: "arrow.right.to.line")
            }
            .help(L("Merge all content from old to new", settings: settings))

            Spacer()

            Button {
                saveAndClose()
            } label: {
                Label(L("Save & Close", settings: settings), systemImage: "square.and.arrow.down")
            }
            .buttonStyle(.borderedProminent)
        }
    }

    private func saveAndClose() {
        let newItem = ClipboardItem(contentType: .text(newText), date: Date(), isCode: monitor.isLikelyCode(newText), sourceAppName: L("Clippy Diff", settings: settings))
        monitor.addNewItem(newItem)
        dismiss()
    }

    private func copyToClipboard(_ text: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
        pasteboard.addTypes([PasteManager.pasteFromClippyType], owner: nil)
    }
    
    private func handleCopy(for text: String, side: Side) {
        copyToClipboard(text)
        withAnimation {
            copiedSide = side
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation {
                copiedSide = nil
            }
        }
    }
    
    enum Side { case left, right }
}
