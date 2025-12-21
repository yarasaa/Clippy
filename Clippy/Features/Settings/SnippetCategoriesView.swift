//
//  SnippetCategoriesView.swift
//  Clippy
//
//  Created by Mehmet Akbaba on 16.11.2025.
//

import SwiftUI

struct SnippetCategoriesView: View {
    @EnvironmentObject var settings: SettingsManager
    @State private var newCategoryName = ""
    @State private var newCategoryIcon = "📁"
    @State private var editingCategory: SnippetCategory?

    // Common emoji icons for quick selection - shared static to avoid duplication
    fileprivate static let commonIcons = ["📧", "💼", "📝", "💻", "📋", "🎯", "🏠", "🎨", "📱", "⚙️", "🔧", "📚", "✨", "🎉", "💡"]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            VStack(alignment: .leading, spacing: 4) {
                Text(L("Snippet Categories", settings: settings))
                    .font(.title2)
                    .fontWeight(.semibold)
                Text(L("Organize your snippets with custom categories", settings: settings))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Divider()

            // Enable/Disable toggle
            Toggle(L("Enable Category System", settings: settings), isOn: $settings.isCategorySystemEnabled)
                .help(L("When disabled, all snippets will be shown without category filtering", settings: settings))

            if settings.isCategorySystemEnabled {
                Divider()

                // Add new category section
                VStack(alignment: .leading, spacing: 8) {
                HStack {
                    // Icon picker
                    Menu {
                        ForEach(Self.commonIcons, id: \.self) { icon in
                            Button(action: {
                                newCategoryIcon = icon
                            }) {
                                Text(icon)
                            }
                        }
                    } label: {
                        Text(newCategoryIcon)
                            .font(.title2)
                            .frame(width: 50, height: 40)
                            .background(Color.secondary.opacity(0.1))
                            .cornerRadius(6)
                    }

                    TextField(L("Category Name (e.g., Work)", settings: settings), text: $newCategoryName)
                        .textFieldStyle(.roundedBorder)

                    Button(L("Add", settings: settings)) {
                        addCategory()
                    }
                    .disabled(newCategoryName.trimmingCharacters(in: .whitespaces).isEmpty)
                }

                Text(L("Tip: Click the icon to choose from common emojis", settings: settings))
                    .font(.caption2)
                    .foregroundColor(.blue)
                    .padding(.leading, 4)
                }

                Divider()

                // Categories list
                ScrollView {
                VStack(spacing: 8) {
                    if settings.snippetCategories.isEmpty {
                        HStack {
                            Spacer()
                            VStack(spacing: 8) {
                                Image(systemName: "folder")
                                    .font(.system(size: 48))
                                    .foregroundColor(.secondary)
                                Text(L("No categories defined", settings: settings))
                                    .foregroundColor(.secondary)
                            }
                            .padding(.vertical, 40)
                            Spacer()
                        }
                    } else {
                        ForEach(settings.snippetCategories) { category in
                            CategoryRow(
                                category: category,
                                isEditing: editingCategory?.id == category.id,
                                onEdit: { editingCategory = category },
                                onSave: { icon, name in
                                    settings.updateSnippetCategory(id: category.id, name: name, icon: icon)
                                    editingCategory = nil
                                },
                                onCancel: { editingCategory = nil },
                                onDelete: { settings.deleteSnippetCategory(id: category.id) }
                            )
                        }
                    }
                }
                }
            }
        }
        .preferredColorScheme(colorScheme)
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func addCategory() {
        let name = newCategoryName.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return }

        settings.addSnippetCategory(name: name, icon: newCategoryIcon)
        newCategoryName = ""
        newCategoryIcon = "📁"
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

struct CategoryRow: View {
    let category: SnippetCategory
    let isEditing: Bool
    let onEdit: () -> Void
    let onSave: (String, String) -> Void
    let onCancel: () -> Void
    let onDelete: () -> Void

    @State private var editedName: String = ""
    @State private var editedIcon: String = ""
    @EnvironmentObject var settings: SettingsManager

    var body: some View {
        HStack(spacing: 12) {
            if isEditing {
                // Edit mode
                Menu {
                    ForEach(SnippetCategoriesView.commonIcons, id: \.self) { icon in
                        Button(action: {
                            editedIcon = icon
                        }) {
                            Text(icon)
                        }
                    }
                } label: {
                    Text(editedIcon)
                        .font(.title2)
                        .frame(width: 40, height: 40)
                        .background(Color.secondary.opacity(0.1))
                        .cornerRadius(6)
                }

                TextField(L("Name", settings: settings), text: $editedName)
                    .textFieldStyle(.roundedBorder)

                Button(L("Save", settings: settings)) {
                    onSave(editedIcon, editedName)
                }
                .disabled(editedName.trimmingCharacters(in: .whitespaces).isEmpty)

                Button(L("Cancel", settings: settings)) {
                    onCancel()
                }
            } else {
                // View mode
                Text(category.icon)
                    .font(.title2)
                    .frame(width: 40, height: 40)
                    .background(Color.secondary.opacity(0.1))
                    .cornerRadius(6)

                VStack(alignment: .leading, spacing: 4) {
                    Text(category.name)
                        .font(.body)
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Button(action: {
                    editedName = category.name
                    editedIcon = category.icon
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
