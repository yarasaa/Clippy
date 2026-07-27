//
//  TemplateSuggestionSheet.swift
//  Clippy
//
//  Review step between "we noticed you keep copying this" and an actual
//  saved snippet. The AI drafts a template from the repeated samples;
//  the user edits the wording, the fill-in fields, and the trigger
//  keyword, then saves — nothing is stored until they approve it.
//

import SwiftUI

struct TemplateSuggestionSheet: View {
    /// The repeated raw examples that triggered the suggestion.
    let samples: [String]
    /// The detector skeleton, so we can stop nagging once handled.
    let skeleton: String
    /// Close the hosting window (this view is presented as an AppDelegate
    /// child window, not a SwiftUI sheet, so it can't use `dismiss`).
    let onClose: () -> Void

    @EnvironmentObject private var monitor: ClipboardMonitor
    @Environment(\.colorScheme) private var scheme

    @State private var phase: Phase = .loading
    @State private var template: String = ""
    @State private var keyword: String = ""
    @State private var errorMessage: String?

    private enum Phase { case loading, ready, error }

    var body: some View {
        VStack(alignment: .leading, spacing: Ember.Space.md) {
            header

            switch phase {
            case .loading: loadingBody
            case .error:   errorBody
            case .ready:   editorBody
            }

            Spacer(minLength: 0)
            footer
        }
        .padding(Ember.Space.lg)
        .frame(width: 460, height: 460)
        .background(Ember.surface(scheme))
        .task { await generate() }
    }

    // MARK: Sections

    private var header: some View {
        HStack(spacing: Ember.Space.sm) {
            Image(systemName: "square.on.square.dashed")
                .foregroundColor(Ember.Palette.amber)
                .font(.system(size: 16, weight: .semibold))
            VStack(alignment: .leading, spacing: 1) {
                Text("Make a template")
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundColor(Ember.primaryText(scheme))
                Text("You copied \(samples.count) similar texts — turn them into a reusable snippet.")
                    .font(.system(size: 11))
                    .foregroundColor(Ember.secondaryText(scheme))
            }
        }
    }

    private var loadingBody: some View {
        VStack(spacing: Ember.Space.sm) {
            Spacer()
            ProgressView()
            Text("Drafting your template…")
                .font(.system(size: 12))
                .foregroundColor(Ember.secondaryText(scheme))
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    private var errorBody: some View {
        VStack(spacing: Ember.Space.sm) {
            Spacer()
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 22))
                .foregroundColor(.orange)
            Text(errorMessage ?? "Couldn't draft a template.")
                .font(.system(size: 12))
                .foregroundColor(Ember.primaryText(scheme))
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    private var editorBody: some View {
        VStack(alignment: .leading, spacing: Ember.Space.sm) {
            // Keyword
            VStack(alignment: .leading, spacing: 3) {
                Text("TRIGGER KEYWORD")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundColor(Ember.tertiaryText(scheme))
                TextField(";keyword", text: $keyword)
                    .textFieldStyle(.plain)
                    .font(.system(size: 13, design: .monospaced))
                    .padding(8)
                    .background(fieldBackground)
                Text("Type this anywhere to expand the template.")
                    .font(.system(size: 10))
                    .foregroundColor(Ember.tertiaryText(scheme))
            }

            // Template
            VStack(alignment: .leading, spacing: 3) {
                Text("TEMPLATE")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundColor(Ember.tertiaryText(scheme))
                TextEditor(text: $template)
                    .font(.system(size: 12, design: .monospaced))
                    .scrollContentBackground(.hidden)
                    .padding(6)
                    .frame(minHeight: 150)
                    .background(fieldBackground)
            }

            if !detectedFields.isEmpty {
                HStack(spacing: 6) {
                    Image(systemName: "curlybraces")
                        .font(.system(size: 10))
                        .foregroundColor(Ember.Palette.amber)
                    Text(detectedFields.joined(separator: " · "))
                        .font(.system(size: 10))
                        .foregroundColor(Ember.secondaryText(scheme))
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
            }
        }
    }

    private var footer: some View {
        HStack {
            Button("Not now") { dismissAndForget() }
                .buttonStyle(.plain)
                .foregroundColor(Ember.secondaryText(scheme))

            Spacer()

            Button {
                save()
            } label: {
                Text("Save snippet")
                    .font(.system(size: 12, weight: .semibold))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 7)
                    .background(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(canSave ? Ember.Palette.amber : Ember.Palette.amber.opacity(0.4))
                    )
                    .foregroundColor(.white)
            }
            .buttonStyle(.plain)
            .disabled(!canSave)
        }
    }

    // MARK: Derived

    private var fieldBackground: some View {
        RoundedRectangle(cornerRadius: 8, style: .continuous)
            .fill(Ember.Palette.smoke.opacity(scheme == .dark ? 0.12 : 0.06))
    }

    private var canSave: Bool {
        phase == .ready
            && keyword.trimmingCharacters(in: .whitespacesAndNewlines).count > 1
            && !template.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    /// Distinct `{{field}}` names in the current template.
    private var detectedFields: [String] {
        guard let re = try? NSRegularExpression(pattern: "\\{\\{([^}]+)\\}\\}") else { return [] }
        let range = NSRange(template.startIndex..., in: template)
        var seen: [String] = []
        for match in re.matches(in: template, range: range) {
            guard let r = Range(match.range(at: 1), in: template) else { continue }
            let name = "{{\(template[r])}}"
            if !seen.contains(name) { seen.append(name) }
        }
        return seen
    }

    // MARK: Actions

    private func generate() async {
        do {
            let draft = try await TemplateGenerator.generate(from: samples)
            template = draft.template
            keyword = draft.keyword
            phase = .ready
        } catch {
            errorMessage = (error as? TemplateGenerator.GenError)?.errorDescription
                ?? error.localizedDescription
            phase = .error
        }
    }

    private func save() {
        var kw = keyword.trimmingCharacters(in: .whitespacesAndNewlines)
        if !kw.hasPrefix(";") { kw = ";" + kw }
        let body = template.trimmingCharacters(in: .whitespacesAndNewlines)
        monitor.createTemplateSnippet(keyword: kw, content: body)
        TemplateDetector.shared.forget(skeleton: skeleton)
        onClose()
    }

    private func dismissAndForget() {
        // Explicit "not now" also silences this pattern so it doesn't
        // pop again the next time it's copied.
        TemplateDetector.shared.forget(skeleton: skeleton)
        onClose()
    }
}
