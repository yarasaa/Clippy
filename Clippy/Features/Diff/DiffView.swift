//
//  DiffView.swift
//  Clippy
//
//  Created by Mehmet Akbaba on 21.09.2025.
//

import SwiftUI

struct DiffView: View {
    let oldText: String
    let newText: String
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var settings: SettingsManager
    
    @State private var copiedSide: Side?

    struct SplitDiffLine: Identifiable {
        let id = UUID()
        let leftContent: String?
        let rightContent: String?
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

        while i > 0 || j > 0 {
            if i > 0 && j > 0 && oldLines[i-1] == newLines[j-1] {
                finalLines.insert(SplitDiffLine(leftContent: oldLines[i-1], rightContent: newLines[j-1], type: .unchanged), at: 0)
                i -= 1
                j -= 1
            } else if j > 0 && (i == 0 || matrix[i][j-1] >= matrix[i-1][j]) {
                finalLines.insert(SplitDiffLine(leftContent: nil, rightContent: newLines[j-1], type: .added), at: 0)
                j -= 1
            } else if i > 0 && (j == 0 || matrix[i][j-1] < matrix[i-1][j]) {
                finalLines.insert(SplitDiffLine(leftContent: oldLines[i-1], rightContent: nil, type: .removed), at: 0)
                i -= 1
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
        VStack {
            Text(L("Compare Differences", settings: settings))
                .font(.title2.bold())
                .padding()

            ScrollView {
                Grid(alignment: .top, horizontalSpacing: 0, verticalSpacing: 0) {
                    ForEach(diffLines) { line in
                        GridRow {
                            diffCell(content: line.leftContent, type: line.type, side: .left)
                            
                            diffCell(content: line.rightContent, type: line.type, side: .right)
                        }
                    }
                }
            }
            .overlay(alignment: .topTrailing) {
                Button {
                    handleCopy(for: newText, side: .right)
                } label: {
                    if copiedSide == .right {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                    } else {
                        Image(systemName: "doc.on.doc")
                    }
                }
                .buttonStyle(.borderless)
                .padding(8)
                .help(L("Copy New Text", settings: settings))
            }
            .overlay(alignment: .topLeading) {
                Button {
                    handleCopy(for: oldText, side: .left)
                } label: {
                    if copiedSide == .left {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                    } else {
                        Image(systemName: "doc.on.doc")
                    }
                }
                .buttonStyle(.borderless)
                .padding(8)
                .help(L("Copy Old Text", settings: settings))
            }
            .background(Color(nsColor: .textBackgroundColor))
            .cornerRadius(8)
            .padding(.horizontal)

            Button(L("Close", settings: settings)) {
                dismiss()
            }
            .padding()
            .keyboardShortcut(.escape, modifiers: [])
        }
        .frame(minWidth: 600, idealWidth: 700, minHeight: 400, idealHeight: 500)
    }

    @ViewBuilder
    private func diffCell(content: String?, type: SplitDiffLine.ChangeType, side: Side) -> some View {
        let textContent = content ?? " "
        let baseColor = backgroundColor(for: type, side: side)

        if type == .modified, let lineContent = content {
            let original = side == .left ? lineContent : (diffLines.first(where: { $0.rightContent == lineContent })?.leftContent ?? "")
            let changed = side == .right ? lineContent : (diffLines.first(where: { $0.leftContent == lineContent })?.rightContent ?? "")
            
            createHighlightedText(original: original, changed: changed, for: side)
                .padding(.vertical, 2)
                .padding(.horizontal, 8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(baseColor)
        } else {
            Text(textContent)
                .font(.system(.body, design: .monospaced))
                .padding(.vertical, 2)
                .padding(.horizontal, 8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(baseColor)
                .foregroundColor(content == nil ? .clear : .primary)
        }
    }
    
    enum Side { case left, right }

    private func backgroundColor(for type: SplitDiffLine.ChangeType, side: Side) -> Color {
        let removedColor = Color.red.opacity(0.2)
        let removedHighlight = Color.red.opacity(0.4)
        let addedColor = Color.green.opacity(0.2)
        let addedHighlight = Color.green.opacity(0.4)
        let emptyColor = Color.secondary.opacity(0.05)

        switch (type, side) {
        case (.removed, .left):
            return removedColor
        case (.removed, .right):
            return emptyColor
            
        case (.added, .left):
            return emptyColor
        case (.added, .right):
            return addedColor
            
        case (.modified, .left):
            return removedHighlight
        case (.modified, .right):
            return addedHighlight
            
        case (.unchanged, _):
            return .clear
        }
    }
    
    private func createHighlightedText(original: String, changed: String, for side: Side) -> Text {
        let textToDisplay = (side == .left) ? original : changed
        var attributedString = AttributedString(textToDisplay)
        attributedString.font = .system(.body, design: .monospaced)
        attributedString.foregroundColor = .primary

        let difference = changed.difference(from: original)
        
        let highlightColor: Color
        let changesToApply: [CollectionDifference<Character>.Change]
        
        if side == .left {
            highlightColor = Color.red.opacity(0.5)
            changesToApply = difference.removals
        } else {
            highlightColor = Color.green.opacity(0.5)
            changesToApply = difference.insertions
        }

        for change in changesToApply {
            let offset: Int
            let element: String
            
            switch change {
            case .remove(let o, let e, _):
                offset = o; element = String(e)
            case .insert(let o, let e, _):
                offset = o; element = String(e)
            }
            
            if let range = Range(NSRange(location: offset, length: element.count), in: attributedString) {
                attributedString[range].backgroundColor = highlightColor
            }
        }
        
        return Text(attributedString)
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
}
