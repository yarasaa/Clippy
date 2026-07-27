//
//  AskAnswerPanel.swift
//  Clippy
//
//  The answer surface for "Ask your clipboard". Renders under the header
//  while Ask mode is on: example prompts before you ask, then a loading
//  state, an error state, or the answer — a deterministically-extracted
//  value (when the question wanted one), the model's prose, and the
//  specific history items it cited, each openable / copyable / pasteable.
//

import SwiftUI

struct AskAnswerPanel: View {
    let loading: Bool
    let result: AskResult?
    let error: String?
    /// Open a cited item's detail window.
    let onOpenItem: (ClipboardItemEntity) -> Void
    /// Put a cited item back on the clipboard.
    let onCopyItem: (ClipboardItemEntity) -> Void
    /// Paste a cited item into the frontmost app.
    let onPasteItem: (ClipboardItemEntity) -> Void
    /// Copy a raw extracted value (phone/email/…) to the clipboard.
    let onCopyText: (String) -> Void
    /// Run one of the example prompts.
    let onExample: (String) -> Void

    @Environment(\.colorScheme) private var scheme

    private let examples = [
        "Links from today",
        "My pinned items",
        "Screenshots this week",
        "The email I copied",
    ]

    var body: some View {
        Group {
            if loading {
                loadingState
            } else if let error {
                errorState(error)
            } else if let result {
                answerState(result)
            } else {
                hintState
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, Ember.Space.md)
        .padding(.vertical, Ember.Space.sm)
        .background(Ember.Palette.amber.opacity(scheme == .dark ? 0.06 : 0.04))
        .overlay(alignment: .bottom) {
            Divider().opacity(0.3)
        }
        .transition(.move(edge: .top).combined(with: .opacity))
    }

    // MARK: States

    private var hintState: some View {
        VStack(alignment: .leading, spacing: Ember.Space.sm) {
            HStack(spacing: Ember.Space.sm) {
                Image(systemName: "sparkles").foregroundColor(Ember.Palette.amber)
                Text("Ask about your clipboard, then press Return.")
                    .font(.system(size: 11))
                    .foregroundColor(Ember.secondaryText(scheme))
            }
            FlowChips(items: examples) { example in
                Button { onExample(example) } label: {
                    Text(example)
                        .font(.system(size: 11, weight: .medium))
                        .padding(.horizontal, 9)
                        .padding(.vertical, 4)
                        .background(Capsule().fill(Ember.Palette.amber.opacity(0.12)))
                        .foregroundColor(Ember.Palette.amber)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var loadingState: some View {
        HStack(spacing: Ember.Space.sm) {
            ProgressView().controlSize(.small)
            Text("Searching your history…")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(Ember.secondaryText(scheme))
        }
    }

    private func errorState(_ message: String) -> some View {
        HStack(alignment: .top, spacing: Ember.Space.sm) {
            Image(systemName: "exclamationmark.triangle.fill").foregroundColor(.orange)
            Text(message)
                .font(.system(size: 12))
                .foregroundColor(Ember.primaryText(scheme))
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func answerState(_ result: AskResult) -> some View {
        VStack(alignment: .leading, spacing: Ember.Space.sm) {
            if let value = result.extractedValue {
                extractedValueChip(value)
            }

            Text(result.answer)
                .font(.system(size: 12))
                .foregroundColor(Ember.primaryText(scheme))
                .textSelection(.enabled)
                .fixedSize(horizontal: false, vertical: true)

            let sources = citedSources(in: result)
            if !sources.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("SOURCES")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundColor(Ember.tertiaryText(scheme))
                    ForEach(sources, id: \.index) { source in
                        sourceRow(source)
                    }
                }
            }
        }
    }

    private func extractedValueChip(_ value: ExtractedValue) -> some View {
        HStack(spacing: 8) {
            Image(systemName: value.icon)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(Ember.Palette.amber)
            VStack(alignment: .leading, spacing: 0) {
                Text(value.label.uppercased())
                    .font(.system(size: 8, weight: .semibold))
                    .foregroundColor(Ember.tertiaryText(scheme))
                Text(value.value)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundColor(Ember.primaryText(scheme))
                    .textSelection(.enabled)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            Spacer(minLength: 4)
            Button { onCopyText(value.value) } label: {
                Image(systemName: "doc.on.doc")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(Ember.Palette.amber)
            }
            .buttonStyle(.plain)
            .help("Copy")
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Ember.Palette.amberSoft)
        )
    }

    private func sourceRow(_ source: CitedSource) -> some View {
        HStack(spacing: 6) {
            Text("\(source.index)")
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .foregroundColor(Ember.Palette.amber)
                .frame(width: 16, height: 16)
                .background(Circle().fill(Ember.Palette.amberSoft))

            Image(systemName: source.item.contentType == "image" ? "photo" : "doc.text")
                .font(.system(size: 10))
                .foregroundColor(Ember.tertiaryText(scheme))

            Button { onOpenItem(source.item) } label: {
                Text(sourceLabel(source.item))
                    .font(.system(size: 11))
                    .foregroundColor(Ember.secondaryText(scheme))
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)

            Button { onCopyItem(source.item) } label: {
                Image(systemName: "doc.on.doc").font(.system(size: 10))
                    .foregroundColor(Ember.tertiaryText(scheme))
            }
            .buttonStyle(.plain)
            .help("Copy")

            Button { onPasteItem(source.item) } label: {
                Image(systemName: "arrow.down.doc").font(.system(size: 10))
                    .foregroundColor(Ember.tertiaryText(scheme))
            }
            .buttonStyle(.plain)
            .help("Paste")
        }
        .padding(.vertical, 3)
        .padding(.horizontal, 6)
        .background(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(Ember.Palette.smoke.opacity(scheme == .dark ? 0.10 : 0.05))
        )
    }

    // MARK: Citation parsing

    private struct CitedSource {
        let index: Int
        let item: ClipboardItemEntity
    }

    /// Pull `[n]` references out of the answer and map them back to the
    /// candidate items, in order of first appearance. Only items the
    /// model actually cited are shown — not the whole candidate set.
    private func citedSources(in result: AskResult) -> [CitedSource] {
        let indices = referencedIndices(in: result.answer)
        var seen = Set<Int>()
        var out: [CitedSource] = []
        for n in indices where !seen.contains(n) {
            guard n >= 1, n <= result.citedItems.count else { continue }
            seen.insert(n)
            out.append(CitedSource(index: n, item: result.citedItems[n - 1]))
        }
        return out
    }

    private func referencedIndices(in answer: String) -> [Int] {
        guard let regex = try? NSRegularExpression(pattern: "\\[(\\d+)\\]") else { return [] }
        let range = NSRange(answer.startIndex..., in: answer)
        return regex.matches(in: answer, range: range).compactMap { match in
            guard let r = Range(match.range(at: 1), in: answer) else { return nil }
            return Int(answer[r])
        }
    }

    private func sourceLabel(_ item: ClipboardItemEntity) -> String {
        if let title = item.autoTitle, !title.isEmpty { return title }
        if let title = item.title, !title.isEmpty { return title }
        if item.contentType == "image" {
            return item.extractedText?.trimmingCharacters(in: .whitespacesAndNewlines).prefix(60).description
                ?? "Screenshot"
        }
        let body = (item.content ?? "").replacingOccurrences(of: "\n", with: " ")
        return String(body.prefix(60))
    }
}

/// Minimal wrapping chip row — lays items left-to-right, wrapping to new
/// lines as width runs out.
private struct FlowChips<Item: Hashable, Content: View>: View {
    let items: [Item]
    let content: (Item) -> Content

    var body: some View {
        // A simple two-per-guess wrap: SwiftUI has no native flow layout on
        // macOS 13, so a lazy grid keeps it dependency-free and tidy.
        let columns = [GridItem(.adaptive(minimum: 110), spacing: 6, alignment: .leading)]
        LazyVGrid(columns: columns, alignment: .leading, spacing: 6) {
            ForEach(items, id: \.self) { content($0) }
        }
    }
}
