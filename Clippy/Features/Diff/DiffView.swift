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
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject var settings: SettingsManager
    @EnvironmentObject var monitor: ClipboardMonitor

    @State private var copiedSide: Side?
    @State private var cachedDiffLines: [SplitDiffLine] = []
    @State private var lastOldText: String = ""
    @State private var lastNewText: String = ""
    @State private var scrollOffset: CGFloat = 0

    struct SplitDiffLine: Identifiable {
        let id = UUID()
        let leftContent: String?
        let rightContent: String?
        let leftLineNumber: Int?
        let rightLineNumber: Int?
        enum ChangeType { case added, removed, unchanged, modified }
        var type: ChangeType
        var charDiffs: [CharDiff]?
    }

    struct CharDiff {
        let text: String
        let isChanged: Bool
    }

    private var diffLines: [SplitDiffLine] {
        // Cache expensive diff calculation
        if cachedDiffLines.isEmpty || oldText != lastOldText || newText != lastNewText {
            let lines = computeDiffLines()
            // Note: Cannot update @State in computed property, would need onChange modifier
            return lines
        }
        return cachedDiffLines
    }

    private func computeDiffLines() -> [SplitDiffLine] {
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
                finalLines.insert(SplitDiffLine(leftContent: oldLines[i-1], rightContent: newLines[j-1], leftLineNumber: leftLineNum, rightLineNumber: rightLineNum, type: .unchanged, charDiffs: nil), at: 0)
                i -= 1
                j -= 1
                leftLineNum -= 1
                rightLineNum -= 1
            } else if j > 0 && (i == 0 || matrix[i][j-1] >= matrix[i-1][j]) {
                finalLines.insert(SplitDiffLine(leftContent: nil, rightContent: newLines[j-1], leftLineNumber: nil, rightLineNumber: rightLineNum, type: .added, charDiffs: nil), at: 0)
                j -= 1
                rightLineNum -= 1
            } else if i > 0 && (j == 0 || matrix[i][j-1] < matrix[i-1][j]) {
                finalLines.insert(SplitDiffLine(leftContent: oldLines[i-1], rightContent: nil, leftLineNumber: leftLineNum, rightLineNumber: nil, type: .removed, charDiffs: nil), at: 0)
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
               finalLines[index+1].type == .added,
               let oldLine = finalLines[index].leftContent,
               let newLine = finalLines[index+1].rightContent {

                let charDiffs = computeCharDiffs(old: oldLine, new: newLine)
                processedLines.append(SplitDiffLine(
                    leftContent: oldLine,
                    rightContent: newLine,
                    leftLineNumber: finalLines[index].leftLineNumber,
                    rightLineNumber: finalLines[index+1].rightLineNumber,
                    type: .modified,
                    charDiffs: charDiffs
                ))
                index += 2
            } else {
                processedLines.append(finalLines[index])
                index += 1
            }
        }

        return processedLines
    }

    private func computeCharDiffs(old: String, new: String) -> [CharDiff] {
        // Simple approach: highlight entire new string if different
        // This gives consistent visual feedback
        if old == new {
            return [CharDiff(text: new, isChanged: false)]
        }

        let oldChars = Array(old)
        let newChars = Array(new)

        // Find common prefix
        var commonPrefix = 0
        while commonPrefix < min(oldChars.count, newChars.count) &&
              oldChars[commonPrefix] == newChars[commonPrefix] {
            commonPrefix += 1
        }

        // Find common suffix
        var commonSuffix = 0
        while commonSuffix < min(oldChars.count - commonPrefix, newChars.count - commonPrefix) &&
              oldChars[oldChars.count - 1 - commonSuffix] == newChars[newChars.count - 1 - commonSuffix] {
            commonSuffix += 1
        }

        var result: [CharDiff] = []

        // Add common prefix
        if commonPrefix > 0 {
            let prefixStr = String(newChars[0..<commonPrefix])
            result.append(CharDiff(text: prefixStr, isChanged: false))
        }

        // Add changed middle part
        let changedStart = commonPrefix
        let changedEnd = newChars.count - commonSuffix
        if changedStart < changedEnd {
            let changedStr = String(newChars[changedStart..<changedEnd])
            result.append(CharDiff(text: changedStr, isChanged: true))
        }

        // Add common suffix
        if commonSuffix > 0 {
            let suffixStart = newChars.count - commonSuffix
            let suffixStr = String(newChars[suffixStart..<newChars.count])
            result.append(CharDiff(text: suffixStr, isChanged: false))
        }

        return result
    }

    private func updateDiffCache() {
        cachedDiffLines = computeDiffLines()
        lastOldText = oldText
        lastNewText = newText
    }

    var body: some View {
        VStack(spacing: 0) {
            Text(L("Compare Differences", settings: settings))
                .font(.title2.bold())
                .padding()

            // Unified diff view
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(diffLines) { line in
                        unifiedDiffLineView(for: line)
                    }
                }
            }

            bottomToolbar
                .padding()
                .background(.bar)
        }
        .preferredColorScheme(preferredColorScheme)
        .frame(minWidth: 800, idealWidth: 1000, minHeight: 500, idealHeight: 700)
        .keyboardShortcut(.escape, modifiers: [])
        .onAppear {
            updateDiffCache()
        }
        .onChange(of: oldText) { _ in
            updateDiffCache()
        }
        .onChange(of: newText) { _ in
            updateDiffCache()
        }
    }

    @ViewBuilder
    private func unifiedDiffLineView(for line: SplitDiffLine) -> some View {
        switch line.type {
        case .unchanged:
            // Show unchanged line once
            if let content = line.leftContent {
                unifiedLineContent(
                    prefix: " ",
                    content: content,
                    lineNumber: line.leftLineNumber,
                    backgroundColor: .clear
                )
            }

        case .removed:
            // Show removed line with "-" prefix
            if let content = line.leftContent {
                unifiedLineContent(
                    prefix: "-",
                    content: content,
                    lineNumber: line.leftLineNumber,
                    backgroundColor: diffBackgroundColor(for: .removed)
                )
            }

        case .added:
            // Show added line with "+" prefix
            if let content = line.rightContent {
                unifiedLineContent(
                    prefix: "+",
                    content: content,
                    lineNumber: line.rightLineNumber,
                    backgroundColor: diffBackgroundColor(for: .added)
                )
            }

        case .modified:
            // Show both old and new versions
            if let oldContent = line.leftContent {
                unifiedLineContent(
                    prefix: "-",
                    content: oldContent,
                    lineNumber: line.leftLineNumber,
                    backgroundColor: diffBackgroundColor(for: .removed)
                )
            }
            if let newContent = line.rightContent, let charDiffs = line.charDiffs {
                unifiedModifiedLineContent(
                    prefix: "+",
                    charDiffs: charDiffs,
                    lineNumber: line.rightLineNumber,
                    backgroundColor: diffBackgroundColor(for: .added)
                )
            }
        }
    }

    @ViewBuilder
    private func unifiedLineContent(prefix: String, content: String, lineNumber: Int?, backgroundColor: Color) -> some View {
        HStack(alignment: .top, spacing: 8) {
            // Prefix (-, +, or space)
            Text(prefix)
                .font(.system(.body, design: .monospaced))
                .foregroundColor(prefix == "-" ? .red : (prefix == "+" ? .green : .secondary))
                .frame(width: 20, alignment: .center)

            // Line number
            Text(lineNumber.map { String($0) } ?? "")
                .font(.system(.caption, design: .monospaced))
                .foregroundColor(.secondary)
                .frame(width: 40, alignment: .trailing)

            // Content
            Text(content)
                .font(.system(.body, design: .monospaced))
                .frame(maxWidth: .infinity, alignment: .leading)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 4)
        .background(backgroundColor)
    }

    @ViewBuilder
    private func unifiedModifiedLineContent(prefix: String, charDiffs: [CharDiff], lineNumber: Int?, backgroundColor: Color) -> some View {
        HStack(alignment: .top, spacing: 8) {
            // Prefix
            Text(prefix)
                .font(.system(.body, design: .monospaced))
                .foregroundColor(.green)
                .frame(width: 20, alignment: .center)

            // Line number
            Text(lineNumber.map { String($0) } ?? "")
                .font(.system(.caption, design: .monospaced))
                .foregroundColor(.secondary)
                .frame(width: 40, alignment: .trailing)

            // Content with character-level highlighting
            HStack(spacing: 0) {
                ForEach(Array(charDiffs.enumerated()), id: \.offset) { _, charDiff in
                    Text(charDiff.text)
                        .background(charDiff.isChanged ? Color.green.opacity(0.3) : Color.clear)
                }
            }
            .font(.system(.body, design: .monospaced))
            .frame(maxWidth: .infinity, alignment: .leading)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 4)
        .background(backgroundColor)
    }

    private func diffBackgroundColor(for type: SplitDiffLine.ChangeType) -> Color {
        let isDark = (preferredColorScheme ?? colorScheme) == .dark

        switch type {
        case .added:
            return isDark ? Color.green.opacity(0.2) : Color.green.opacity(0.15)
        case .removed:
            return isDark ? Color.red.opacity(0.2) : Color.red.opacity(0.15)
        case .modified:
            return isDark ? Color.orange.opacity(0.2) : Color.orange.opacity(0.15)
        case .unchanged:
            return Color.clear
        }
    }

    private var bottomToolbar: some View {
        HStack {
            Button(L("Close", settings: settings)) {
                dismiss()
            }

            Spacer()

            Button {
                copyToClipboard(oldText)
                withAnimation {
                    copiedSide = .left
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    withAnimation {
                        copiedSide = nil
                    }
                }
            } label: {
                Label(L("Copy Old", settings: settings), systemImage: copiedSide == .left ? "checkmark.circle.fill" : "doc.on.doc")
            }

            Button {
                copyToClipboard(newText)
                withAnimation {
                    copiedSide = .right
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    withAnimation {
                        copiedSide = nil
                    }
                }
            } label: {
                Label(L("Copy New", settings: settings), systemImage: copiedSide == .right ? "checkmark.circle.fill" : "doc.on.doc")
            }

            Spacer()

            Button {
                saveAndClose()
            } label: {
                Label(L("Save New", settings: settings), systemImage: "square.and.arrow.down")
            }
            .buttonStyle(.borderedProminent)
            .help(L("Save new version to clipboard history", settings: settings))
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

    private var preferredColorScheme: ColorScheme? {
        switch settings.appTheme {
        case "light":
            return .light
        case "dark":
            return .dark
        default:
            return nil
        }
    }

    enum Side { case left, right }
}
