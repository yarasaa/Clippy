//
//  JSONDetailView.swift
//  Clippy
//

import SwiftUI

struct JSONDetailView: View {
    @State private var editedText: String
    let onSave: (String) -> Void
    @EnvironmentObject var settings: SettingsManager
    @Environment(\.colorScheme) var scheme

    @State private var parsedValue: JSONValue?
    @State private var parseError: String?
    @State private var showRawText = false

    init(initialText: String, onSave: @escaping (String) -> Void) {
        _editedText = State(initialValue: initialText)
        self.onSave = onSave
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            headerView

            Divider().opacity(0.3)

            if showRawText {
                PlainTextEditor(text: $editedText)
            } else if let parsedValue = parsedValue {
                ScrollView {
                    JSONTreeView(key: nil, value: parsedValue, currentPath: "")
                        .padding(Ember.Space.md)
                }
            } else {
                PlainTextEditor(text: $editedText)
            }
        }
        .background(Ember.surface(scheme))
        .onAppear(perform: parseJSON)
        .onChange(of: editedText, perform: { _ in parseJSON() })
    }

    @ViewBuilder
    private var headerView: some View {
        HStack(spacing: Ember.Space.sm) {
            HStack(spacing: 5) {
                Image(systemName: parseError == nil ? "checkmark.circle.fill" : "xmark.octagon.fill")
                    .font(.system(size: 12))
                    .foregroundColor(parseError == nil ? Ember.Palette.moss : Ember.Palette.rust)

                Text(parseError == nil ? "Valid JSON" : "Invalid JSON")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(Ember.primaryText(scheme))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(
                Capsule()
                    .fill(parseError == nil
                          ? Ember.Palette.moss.opacity(0.12)
                          : Ember.Palette.rust.opacity(0.12))
            )
            .help(parseError ?? "")

            Spacer()

            Button {
                showRawText.toggle()
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: showRawText ? "list.bullet.indent" : "pencil.and.scribble")
                    Text(showRawText ? "Tree" : "Raw")
                }
            }
            .buttonStyle(SecondaryActionButtonStyle())

            Button {
                onSave(editedText)
            } label: {
                Text("Save")
            }
            .buttonStyle(PrimaryActionButtonStyle())
            .disabled(parseError != nil)
        }
        .padding(.horizontal, Ember.Space.md)
        .padding(.vertical, Ember.Space.sm)
    }

    private func parseJSON() {
        guard !editedText.isEmpty else {
            self.parseError = nil
            self.parsedValue = nil
            return
        }

        guard let data = editedText.data(using: .utf8) else {
            self.parseError = "Could not encode text to UTF-8."
            self.parsedValue = nil
            return
        }

        do {
            let jsonObject = try JSONSerialization.jsonObject(with: data, options: .allowFragments)
            self.parsedValue = JSONValue(from: jsonObject)
            self.parseError = nil
        } catch {
            self.parseError = error.localizedDescription
            self.parsedValue = nil
        }
    }
}
