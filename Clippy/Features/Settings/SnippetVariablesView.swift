//
//  SnippetVariablesView.swift
//  Clippy
//
//  Created by Mehmet Akbaba on 15.11.2025.
//

import SwiftUI

struct SnippetVariablesView: View {
    @EnvironmentObject var settings: SettingsManager
    @State private var newVariableName = ""
    @State private var newVariableValue = ""
    @State private var editingVariable: SnippetVariable?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            VStack(alignment: .leading, spacing: 4) {
                Text(L("Snippet Variables", settings: settings))
                    .font(.title2)
                    .fontWeight(.semibold)
                Text(L("Define global variables to use across all snippets", settings: settings))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Divider()

            // Add new variable section
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    TextField(L("Variable Name (e.g., MY_NAME)", settings: settings), text: $newVariableName)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 200)

                    TextField(L("Value (can use {{DATE}}, {{UUID}}, etc.)", settings: settings), text: $newVariableValue)
                        .textFieldStyle(.roundedBorder)

                    Button(L("Add", settings: settings)) {
                        addVariable()
                    }
                    .disabled(newVariableName.trimmingCharacters(in: .whitespaces).isEmpty)
                }

                Text(L("Usage Example:", settings: settings) + " {{\(newVariableName.isEmpty ? "MY_NAME" : newVariableName)}} → \(processedPreviewValue)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.leading, 4)

                Text(L("Tip: Use {{DATE}}, {{TIME}}, {{UUID}}, {{CLIPBOARD}} in values for dynamic content", settings: settings))
                    .font(.caption2)
                    .foregroundColor(.blue)
                    .padding(.leading, 4)
            }

            Divider()

            // Variables list
            ScrollView {
                VStack(spacing: 8) {
                    if settings.snippetVariables.isEmpty {
                        HStack {
                            Spacer()
                            VStack(spacing: 8) {
                                Image(systemName: "textformat.abc")
                                    .font(.system(size: 48))
                                    .foregroundColor(.secondary)
                                Text(L("No variables defined", settings: settings))
                                    .foregroundColor(.secondary)
                            }
                            .padding(.vertical, 40)
                            Spacer()
                        }
                    } else {
                        ForEach(settings.snippetVariables) { variable in
                            VariableRow(
                                variable: variable,
                                isEditing: editingVariable?.id == variable.id,
                                onEdit: { editingVariable = variable },
                                onSave: { name, value in
                                    settings.updateSnippetVariable(id: variable.id, name: name, value: value)
                                    editingVariable = nil
                                },
                                onCancel: { editingVariable = nil },
                                onDelete: { settings.deleteSnippetVariable(id: variable.id) }
                            )
                        }
                    }
                }
            }
        }
        .preferredColorScheme(colorScheme)
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func addVariable() {
        let name = newVariableName.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return }

        settings.addSnippetVariable(name: name, value: newVariableValue)
        newVariableName = ""
        newVariableValue = ""
    }

    private var processedPreviewValue: String {
        if newVariableValue.isEmpty {
            return L("(empty)", settings: settings)
        }

        var preview = newVariableValue

        // Show preview of dynamic placeholders
        if preview.contains("{{DATE}}") {
            preview = preview.replacingOccurrences(of: "{{DATE}}", with: "[2025-11-16]")
        }
        if preview.contains("{{TIME}}") {
            preview = preview.replacingOccurrences(of: "{{TIME}}", with: "[14:30:25]")
        }
        if preview.contains("{{DATETIME}}") {
            preview = preview.replacingOccurrences(of: "{{DATETIME}}", with: "[2025-11-16 14:30]")
        }
        if preview.contains("{{UUID}}") {
            preview = preview.replacingOccurrences(of: "{{UUID}}", with: "[UUID]")
        }
        if preview.contains("{{CLIPBOARD}}") {
            preview = preview.replacingOccurrences(of: "{{CLIPBOARD}}", with: "[clipboard]")
        }

        return preview
    }

    private var colorScheme: ColorScheme? {
        switch settings.appTheme {
        case "light":
            return .light
        case "dark":
            return .dark
        default:
            return nil
        }
    }
}

struct VariableRow: View {
    let variable: SnippetVariable
    let isEditing: Bool
    let onEdit: () -> Void
    let onSave: (String, String) -> Void
    let onCancel: () -> Void
    let onDelete: () -> Void

    @State private var editedName: String = ""
    @State private var editedValue: String = ""
    @EnvironmentObject var settings: SettingsManager

    var body: some View {
        HStack(spacing: 12) {
            if isEditing {
                // Edit mode
                TextField(L("Name", settings: settings), text: $editedName)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 150)

                TextField(L("Value", settings: settings), text: $editedValue)
                    .textFieldStyle(.roundedBorder)

                Button(L("Save", settings: settings)) {
                    onSave(editedName, editedValue)
                }
                .disabled(editedName.trimmingCharacters(in: .whitespaces).isEmpty)

                Button(L("Cancel", settings: settings)) {
                    onCancel()
                }
            } else {
                // View mode
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(variable.placeholder)
                            .font(.system(.body, design: .monospaced))
                            .foregroundColor(.blue)
                            .fontWeight(.semibold)

                        Image(systemName: "arrow.right")
                            .foregroundColor(.secondary)
                            .font(.caption)
                    }

                    Text(variable.value.isEmpty ? L("(empty)", settings: settings) : variable.value)
                        .foregroundColor(variable.value.isEmpty ? .secondary : .primary)
                        .lineLimit(2)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Button(action: {
                    editedName = variable.name
                    editedValue = variable.value
                    onEdit()
                }) {
                    Image(systemName: "pencil")
                        .foregroundColor(.blue)
                }
                .buttonStyle(.plain)
                .help(L("Edit", settings: settings))

                Button(action: onDelete) {
                    Image(systemName: "trash")
                        .foregroundColor(.red)
                }
                .buttonStyle(.plain)
                .help(L("Delete", settings: settings))
            }
        }
        .padding(12)
        .background(Color.secondary.opacity(0.1))
        .cornerRadius(8)
    }
}
