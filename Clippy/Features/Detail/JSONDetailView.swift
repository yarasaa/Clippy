//
//  JSONDetailView.swift
//  Clippy
//
//  Created by Mehmet Akbaba on 25.09.2025.
//

import SwiftUI

struct JSONDetailView: View {
    @State private var editedText: String
    let onSave: (String) -> Void
    @EnvironmentObject var settings: SettingsManager
    
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
                .padding(.horizontal)
                .padding(.top, 8)
                .padding(.bottom, 4)

            Divider()

            if showRawText {
                TextEditor(text: $editedText)
                    .font(.system(.body, design: .monospaced))
                    .padding(5)
            } else {
                if let parsedValue = parsedValue {
                    ScrollView {
                        JSONTreeView(key: nil, value: parsedValue, currentPath: "")
                            .padding()
                    }
                } else {
                    TextEditor(text: $editedText)
                        .font(.system(.body, design: .monospaced))
                        .padding(5)
                }
            }
        }
        .onAppear(perform: parseJSON)
        .onChange(of: editedText, perform: { _ in parseJSON() })
    }
    
    @ViewBuilder
    private var headerView: some View {
        HStack {
            if let error = parseError {
                Label(L("Invalid JSON", settings: settings), systemImage: "xmark.octagon.fill")
                    .foregroundColor(.red)
                    .help(error)
            } else {
                Label(L("Valid JSON", settings: settings), systemImage: "checkmark.circle.fill")
                    .foregroundColor(.green)
            }
            
            Spacer()
            
            Button {
                showRawText.toggle()
            } label: {
                Image(systemName: showRawText ? "list.bullet.indent" : "pencil.and.scribble")
            }
            .buttonStyle(.borderless)
            .help(showRawText ? L("Show Tree View", settings: settings) : L("Edit Raw Text", settings: settings))
            
            Button(L("Save", settings: settings)) {
                onSave(editedText)
            }
            .buttonStyle(.borderedProminent)
            .disabled(parseError != nil)
        }
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