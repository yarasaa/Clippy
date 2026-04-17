//
//  SnippetVariablesView.swift
//  Clippy
//

import SwiftUI

struct SnippetVariablesView: View {
    @EnvironmentObject var settings: SettingsManager
    @Environment(\.colorScheme) var scheme

    @State private var newVariableName = ""
    @State private var newVariableValue = ""
    @State private var editingVariable: SnippetVariable?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Ember.Space.lg) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Variables")
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundColor(Ember.primaryText(scheme))
                    Text("Global placeholders you can use inside any snippet.")
                        .font(Ember.Font.body)
                        .foregroundColor(Ember.secondaryText(scheme))
                }

                addForm

                if settings.snippetVariables.isEmpty {
                    emptyState
                } else {
                    VStack(spacing: 6) {
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
            .padding(.horizontal, Ember.Space.xl)
            .padding(.vertical, Ember.Space.lg)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var addForm: some View {
        VStack(alignment: .leading, spacing: Ember.Space.sm) {
            HStack(spacing: Ember.Space.sm) {
                TextField("MY_NAME", text: $newVariableName)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 180)
                    .font(Ember.Font.code)

                TextField("Value (supports {{DATE}}, {{UUID}}, {{CLIPBOARD}}…)", text: $newVariableValue)
                    .textFieldStyle(.roundedBorder)

                Button {
                    addVariable()
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 11, weight: .bold))
                }
                .buttonStyle(PrimaryActionButtonStyle())
                .disabled(newVariableName.trimmingCharacters(in: .whitespaces).isEmpty)
            }

            if !newVariableName.isEmpty || !newVariableValue.isEmpty {
                HStack(spacing: 6) {
                    Text("Preview:")
                        .font(Ember.Font.caption)
                        .foregroundColor(Ember.tertiaryText(scheme))
                    Text("{{\(newVariableName.isEmpty ? "MY_NAME" : newVariableName)}}")
                        .font(Ember.Font.code)
                        .foregroundColor(Ember.Palette.amber)
                    Image(systemName: "arrow.right")
                        .font(.system(size: 8))
                        .foregroundColor(Ember.tertiaryText(scheme))
                    Text(processedPreview)
                        .font(Ember.Font.code)
                        .foregroundColor(Ember.secondaryText(scheme))
                        .lineLimit(1)
                }
                .padding(.horizontal, 4)
            }

            Text("Tip: {{DATE}} · {{TIME}} · {{DATETIME}} · {{UUID}} · {{CLIPBOARD}}")
                .font(Ember.Font.caption)
                .foregroundColor(Ember.Palette.amber.opacity(0.8))
                .padding(.horizontal, 4)
        }
        .padding(Ember.Space.md)
        .background(
            RoundedRectangle(cornerRadius: Ember.Radius.lg)
                .fill(Ember.cardBackground(scheme))
        )
        .overlay(
            RoundedRectangle(cornerRadius: Ember.Radius.lg)
                .strokeBorder(Color.white.opacity(scheme == .dark ? 0.06 : 0.5), lineWidth: 0.5)
        )
    }

    private var emptyState: some View {
        VStack(spacing: Ember.Space.md) {
            Image(systemName: "textformat.abc")
                .font(.system(size: 40, weight: .light))
                .foregroundColor(Ember.Palette.amber.opacity(0.6))
            Text("No variables yet")
                .font(Ember.Font.title)
                .foregroundColor(Ember.primaryText(scheme))
            Text("Create one above to reuse values across snippets.")
                .font(Ember.Font.caption)
                .foregroundColor(Ember.secondaryText(scheme))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Ember.Space.xxl)
    }

    private func addVariable() {
        let name = newVariableName.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return }
        settings.addSnippetVariable(name: name, value: newVariableValue)
        newVariableName = ""
        newVariableValue = ""
    }

    private var processedPreview: String {
        if newVariableValue.isEmpty { return "(empty)" }
        var preview = newVariableValue
        preview = preview.replacingOccurrences(of: "{{DATE}}", with: "[2026-04-17]")
        preview = preview.replacingOccurrences(of: "{{TIME}}", with: "[14:30]")
        preview = preview.replacingOccurrences(of: "{{DATETIME}}", with: "[2026-04-17 14:30]")
        preview = preview.replacingOccurrences(of: "{{UUID}}", with: "[uuid]")
        preview = preview.replacingOccurrences(of: "{{CLIPBOARD}}", with: "[clipboard]")
        return preview
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
    @Environment(\.colorScheme) var scheme

    var body: some View {
        HStack(spacing: Ember.Space.sm) {
            if isEditing {
                TextField("Name", text: $editedName)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 150)
                    .font(Ember.Font.code)

                TextField("Value", text: $editedValue)
                    .textFieldStyle(.roundedBorder)

                Button("Save") {
                    onSave(editedName, editedValue)
                }
                .buttonStyle(PrimaryActionButtonStyle())
                .disabled(editedName.trimmingCharacters(in: .whitespaces).isEmpty)

                Button("Cancel") { onCancel() }
                    .buttonStyle(SecondaryActionButtonStyle())
            } else {
                VStack(alignment: .leading, spacing: 2) {
                    Text(variable.placeholder)
                        .font(Ember.Font.code.weight(.semibold))
                        .foregroundColor(Ember.Palette.amber)

                    Text(variable.value.isEmpty ? "(empty)" : variable.value)
                        .font(Ember.Font.body)
                        .foregroundColor(variable.value.isEmpty ? Ember.tertiaryText(scheme) : Ember.primaryText(scheme))
                        .lineLimit(2)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                HStack(spacing: 2) {
                    Button {
                        editedName = variable.name
                        editedValue = variable.value
                        onEdit()
                    } label: {
                        Image(systemName: "pencil")
                            .font(.system(size: 12))
                            .foregroundColor(Ember.secondaryText(scheme))
                            .frame(width: 26, height: 26)
                    }
                    .buttonStyle(.plain)

                    Button(action: onDelete) {
                        Image(systemName: "trash")
                            .font(.system(size: 12))
                            .foregroundColor(Ember.Palette.rust.opacity(0.8))
                            .frame(width: 26, height: 26)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(.horizontal, Ember.Space.md)
        .padding(.vertical, Ember.Space.sm)
        .background(
            RoundedRectangle(cornerRadius: Ember.Radius.md)
                .fill(Ember.cardBackground(scheme))
        )
        .overlay(
            RoundedRectangle(cornerRadius: Ember.Radius.md)
                .strokeBorder(Color.white.opacity(scheme == .dark ? 0.04 : 0.4), lineWidth: 0.5)
        )
    }
}
