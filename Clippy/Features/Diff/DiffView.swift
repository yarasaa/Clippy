//
//  DiffView.swift
//  Clippy
//
//  Side-by-side / unified comparison of two clipboard texts.
//
//  The diff itself lives in DiffEngine (pure, no view state). This file
//  only renders it — computed once when the view appears rather than on
//  every body evaluation, which is what the old implementation did.
//
//  Closing is driven by an `onClose` closure, not `@Environment(\.dismiss)`:
//  the window is a plain AppKit NSWindow hosting this view, and in that
//  context `dismiss()` silently does nothing — which is why the Close
//  button, Save-and-close and Esc all used to appear dead.
//

import SwiftUI

struct DiffView: View {
    let oldText: String
    let newText: String
    /// Labels for the two sides (e.g. "Older · 14:02"). Optional.
    var oldLabel: String = "Old"
    var newLabel: String = "New"
    /// Closes the hosting window. See the note in the file header.
    var onClose: () -> Void = {}

    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject var settings: SettingsManager
    @EnvironmentObject var monitor: ClipboardMonitor

    @State private var result: DiffEngine.Result?
    @State private var layout: Layout = .split
    @State private var copiedSide: Side?

    private enum Layout: String, CaseIterable { case split, unified }
    private enum Side { case left, right }

    // MARK: Body

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider().opacity(0.3)

            if let result {
                if result.stats.isIdentical {
                    identicalState
                } else {
                    diffBody(result)
                }
            } else {
                ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
            }

            Divider().opacity(0.3)
            bottomToolbar
                .padding(.horizontal, Ember.Space.lg)
                .padding(.vertical, Ember.Space.md)
        }
        .background(Ember.surface(colorScheme))
        .preferredColorScheme(preferredColorScheme)
        .frame(minWidth: 820, idealWidth: 1040, minHeight: 520, idealHeight: 700)
        .task {
            // Off the render path: the old version recomputed an O(n·m)
            // diff on every body evaluation.
            result = DiffEngine.diff(old: oldText, new: newText)
        }
        .background(EscapeKeyCatcher(action: onClose))
    }

    // MARK: Header

    private var header: some View {
        HStack(spacing: Ember.Space.md) {
            Image(systemName: "square.split.2x1")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(Ember.Palette.amber)
            Text("Compare")
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundColor(Ember.primaryText(colorScheme))

            if let stats = result?.stats, !stats.isIdentical {
                HStack(spacing: 6) {
                    if stats.added > 0 { statPill("+\(stats.added)", Ember.Palette.moss) }
                    if stats.removed > 0 { statPill("−\(stats.removed)", Ember.Palette.rust) }
                    if stats.modified > 0 { statPill("~\(stats.modified)", Ember.Palette.amber) }
                }
            }

            if result?.truncated == true {
                Label("Large input — approximate", systemImage: "exclamationmark.triangle.fill")
                    .font(Ember.Font.caption)
                    .foregroundColor(.orange)
            }

            Spacer()

            Picker("", selection: $layout) {
                Image(systemName: "rectangle.split.2x1").tag(Layout.split)
                Image(systemName: "list.bullet").tag(Layout.unified)
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .frame(width: 90)
        }
        .padding(.horizontal, Ember.Space.lg)
        .padding(.vertical, Ember.Space.md)
    }

    private func statPill(_ text: String, _ color: Color) -> some View {
        Text(text)
            .font(.system(size: 11, weight: .semibold, design: .rounded))
            .foregroundColor(color)
            .padding(.horizontal, 7)
            .padding(.vertical, 2)
            .background(Capsule().fill(color.opacity(0.15)))
    }

    // MARK: States

    private var identicalState: some View {
        VStack(spacing: Ember.Space.sm) {
            Spacer()
            Image(systemName: "equal.circle.fill")
                .font(.system(size: 34))
                .foregroundColor(Ember.Palette.moss)
            Text("These two are identical")
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundColor(Ember.primaryText(colorScheme))
            Text("No differences to show.")
                .font(Ember.Font.caption)
                .foregroundColor(Ember.secondaryText(colorScheme))
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder
    private func diffBody(_ result: DiffEngine.Result) -> some View {
        VStack(spacing: 0) {
            if layout == .split { columnHeaders }
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(result.lines) { line in
                        if layout == .split {
                            splitRow(line)
                        } else {
                            unifiedRow(line)
                        }
                    }
                }
            }
        }
    }

    private var columnHeaders: some View {
        HStack(spacing: 0) {
            columnHeader(oldLabel, Ember.Palette.rust)
            Rectangle().fill(Color.primary.opacity(0.12)).frame(width: 1)
            columnHeader(newLabel, Ember.Palette.moss)
        }
        .background(Ember.Palette.smoke.opacity(colorScheme == .dark ? 0.10 : 0.05))
        .overlay(alignment: .bottom) { Divider().opacity(0.3) }
    }

    private func columnHeader(_ text: String, _ accent: Color) -> some View {
        HStack(spacing: 5) {
            Circle().fill(accent).frame(width: 6, height: 6)
            Text(text)
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(Ember.secondaryText(colorScheme))
                .textCase(.uppercase)
                .lineLimit(1)
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 5)
        .frame(maxWidth: .infinity)
    }

    // MARK: Rows — split

    private func splitRow(_ line: DiffEngine.Line) -> some View {
        HStack(alignment: .top, spacing: 0) {
            cell(number: line.leftLineNumber,
                 text: line.leftContent,
                 segments: line.leftSegments,
                 background: background(for: line.type, side: .left),
                 changeTint: Ember.Palette.rust)

            Rectangle().fill(Color.primary.opacity(0.12)).frame(width: 1)

            cell(number: line.rightLineNumber,
                 text: line.rightContent,
                 segments: line.rightSegments,
                 background: background(for: line.type, side: .right),
                 changeTint: Ember.Palette.moss)
        }
    }

    /// One side of a split row. A nil `text` means the line doesn't exist
    /// on this side — rendered as an inert filler so the two columns stay
    /// aligned row-for-row.
    private func cell(number: Int?, text: String?, segments: [DiffEngine.Segment]?,
                      background: Color, changeTint: Color) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text(number.map(String.init) ?? "")
                .font(.system(size: 10, design: .monospaced))
                .foregroundColor(Ember.tertiaryText(colorScheme))
                .frame(width: 34, alignment: .trailing)

            Group {
                if let segments {
                    segmentedText(segments, tint: changeTint)
                } else if let text {
                    Text(text.isEmpty ? " " : text)
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundColor(Ember.primaryText(colorScheme))
                        .textSelection(.enabled)
                } else {
                    Text(" ").font(.system(size: 12, design: .monospaced))
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 3)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(background)
    }

    // MARK: Rows — unified

    @ViewBuilder
    private func unifiedRow(_ line: DiffEngine.Line) -> some View {
        switch line.type {
        case .unchanged:
            unifiedLine(" ", line.leftContent, line.leftLineNumber, nil, .clear, Ember.tertiaryText(colorScheme))
        case .removed:
            unifiedLine("−", line.leftContent, line.leftLineNumber, nil,
                        background(for: .removed, side: .left), Ember.Palette.rust)
        case .added:
            unifiedLine("+", line.rightContent, line.rightLineNumber, nil,
                        background(for: .added, side: .right), Ember.Palette.moss)
        case .modified:
            unifiedLine("−", line.leftContent, line.leftLineNumber, line.leftSegments,
                        background(for: .removed, side: .left), Ember.Palette.rust)
            unifiedLine("+", line.rightContent, line.rightLineNumber, line.rightSegments,
                        background(for: .added, side: .right), Ember.Palette.moss)
        }
    }

    private func unifiedLine(_ prefix: String, _ text: String?, _ number: Int?,
                             _ segments: [DiffEngine.Segment]?,
                             _ background: Color, _ accent: Color) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text(prefix)
                .font(.system(size: 12, weight: .bold, design: .monospaced))
                .foregroundColor(accent)
                .frame(width: 14)

            Text(number.map(String.init) ?? "")
                .font(.system(size: 10, design: .monospaced))
                .foregroundColor(Ember.tertiaryText(colorScheme))
                .frame(width: 34, alignment: .trailing)

            Group {
                if let segments {
                    segmentedText(segments, tint: accent)
                } else {
                    Text((text?.isEmpty ?? true) ? " " : text!)
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundColor(Ember.primaryText(colorScheme))
                        .textSelection(.enabled)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 3)
        .background(background)
    }

    /// Character-level highlighting. Concatenating Text keeps it one
    /// wrapping paragraph instead of an HStack that can't wrap.
    private func segmentedText(_ segments: [DiffEngine.Segment], tint: Color) -> Text {
        segments.reduce(Text("")) { acc, segment in
            acc + Text(segment.text)
                .foregroundColor(Ember.primaryText(colorScheme))
                .font(.system(size: 12, weight: segment.isChanged ? .semibold : .regular, design: .monospaced))
        }
    }

    // MARK: Colors

    private func background(for type: DiffEngine.ChangeType, side: Side) -> Color {
        let isDark = (preferredColorScheme ?? colorScheme) == .dark
        let strong = isDark ? 0.18 : 0.12

        switch type {
        case .unchanged:
            return .clear
        case .added:
            return side == .right ? Ember.Palette.moss.opacity(strong) : .clear
        case .removed:
            return side == .left ? Ember.Palette.rust.opacity(strong) : .clear
        case .modified:
            return side == .left
                ? Ember.Palette.rust.opacity(strong)
                : Ember.Palette.moss.opacity(strong)
        }
    }

    // MARK: Toolbar

    private var bottomToolbar: some View {
        HStack(spacing: Ember.Space.sm) {
            Button("Close") { onClose() }
                .buttonStyle(SecondaryActionButtonStyle())

            Spacer()

            copyButton(label: "Copy \(oldLabel)", text: oldText, side: .left)
            copyButton(label: "Copy \(newLabel)", text: newText, side: .right)

            Spacer()

            Button {
                saveAndClose()
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: "square.and.arrow.down")
                    Text("Save New to History")
                }
            }
            .buttonStyle(PrimaryActionButtonStyle())
        }
    }

    private func copyButton(label: String, text: String, side: Side) -> some View {
        Button {
            copyToClipboard(text)
            withAnimation { copiedSide = side }
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                withAnimation { if copiedSide == side { copiedSide = nil } }
            }
        } label: {
            HStack(spacing: 5) {
                Image(systemName: copiedSide == side ? "checkmark" : "doc.on.doc")
                Text(label).lineLimit(1)
            }
        }
        .buttonStyle(SecondaryActionButtonStyle(success: copiedSide == side))
    }

    // MARK: Actions

    private func saveAndClose() {
        let newItem = ClipboardItem(
            contentType: .text(newText),
            date: Date(),
            isCode: monitor.isLikelyCode(newText),
            sourceAppName: L("Clippy Diff", settings: settings)
        )
        monitor.addNewItem(newItem)
        onClose()
    }

    private func copyToClipboard(_ text: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
        pasteboard.addTypes([PasteManager.pasteFromClippyType], owner: nil)
    }

    private var preferredColorScheme: ColorScheme? {
        switch settings.appTheme {
        case "light": return .light
        case "dark":  return .dark
        default:      return nil
        }
    }
}

/// Invisible NSView that closes the window on Esc.
///
/// `.keyboardShortcut(.escape)` only binds to buttons/controls — the old
/// code attached it to a VStack, where it did nothing. A tiny AppKit
/// responder is the reliable way to get Esc in an NSWindow-hosted view.
private struct EscapeKeyCatcher: NSViewRepresentable {
    let action: () -> Void

    func makeNSView(context: Context) -> NSView {
        let view = CatcherView()
        view.action = action
        DispatchQueue.main.async { view.window?.makeFirstResponder(view) }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        (nsView as? CatcherView)?.action = action
    }

    final class CatcherView: NSView {
        var action: () -> Void = {}
        override var acceptsFirstResponder: Bool { true }
        override func cancelOperation(_ sender: Any?) { action() }
    }
}
