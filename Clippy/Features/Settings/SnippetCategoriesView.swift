//
//  SnippetCategoriesView.swift
//  Clippy
//

import SwiftUI

struct SnippetCategoriesView: View {
    @EnvironmentObject var settings: SettingsManager
    @Environment(\.colorScheme) var scheme

    @State private var newCategoryName = ""
    @State private var newCategoryIcon = "📁"
    @State private var editingCategory: SnippetCategory?

    fileprivate static let commonIcons = ["📧", "💼", "📝", "💻", "📋", "🎯", "🏠", "🎨", "📱", "⚙️", "🔧", "📚", "✨", "🎉", "💡"]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Ember.Space.lg) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Categories")
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundColor(Ember.primaryText(scheme))
                    Text("Group snippets into folders to find them faster.")
                        .font(Ember.Font.body)
                        .foregroundColor(Ember.secondaryText(scheme))
                }

                // Enable toggle
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Enable category system")
                            .font(Ember.Font.body)
                            .foregroundColor(Ember.primaryText(scheme))
                        Text("When off, all snippets appear together without filtering.")
                            .font(Ember.Font.caption)
                            .foregroundColor(Ember.tertiaryText(scheme))
                    }
                    Spacer()
                    Toggle("", isOn: $settings.isCategorySystemEnabled)
                        .labelsHidden()
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

                if settings.isCategorySystemEnabled {
                    addForm

                    if settings.snippetCategories.isEmpty {
                        emptyState
                    } else {
                        VStack(spacing: 6) {
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
            .padding(.horizontal, Ember.Space.xl)
            .padding(.vertical, Ember.Space.lg)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var addForm: some View {
        HStack(spacing: Ember.Space.sm) {
            Menu {
                ForEach(Self.commonIcons, id: \.self) { icon in
                    Button { newCategoryIcon = icon } label: {
                        Text(icon)
                    }
                }
            } label: {
                Text(newCategoryIcon)
                    .font(.system(size: 20))
                    .frame(width: 44, height: 36)
                    .background(
                        RoundedRectangle(cornerRadius: Ember.Radius.md)
                            .fill(Ember.cardBackground(scheme))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: Ember.Radius.md)
                            .strokeBorder(Ember.Palette.smoke.opacity(0.25), lineWidth: 0.5)
                    )
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .fixedSize()

            TextField("Category name (e.g., Work)", text: $newCategoryName)
                .textFieldStyle(.roundedBorder)

            Button {
                addCategory()
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 11, weight: .bold))
            }
            .buttonStyle(PrimaryActionButtonStyle())
            .disabled(newCategoryName.trimmingCharacters(in: .whitespaces).isEmpty)
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
            Image(systemName: "folder")
                .font(.system(size: 40, weight: .light))
                .foregroundColor(Ember.Palette.amber.opacity(0.6))
            Text("No categories yet")
                .font(Ember.Font.title)
                .foregroundColor(Ember.primaryText(scheme))
            Text("Add one above to start organizing.")
                .font(Ember.Font.caption)
                .foregroundColor(Ember.secondaryText(scheme))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Ember.Space.xxl)
    }

    private func addCategory() {
        let name = newCategoryName.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return }
        settings.addSnippetCategory(name: name, icon: newCategoryIcon)
        newCategoryName = ""
        newCategoryIcon = "📁"
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
    @Environment(\.colorScheme) var scheme

    var body: some View {
        HStack(spacing: Ember.Space.sm) {
            if isEditing {
                Menu {
                    ForEach(SnippetCategoriesView.commonIcons, id: \.self) { icon in
                        Button { editedIcon = icon } label: { Text(icon) }
                    }
                } label: {
                    Text(editedIcon)
                        .font(.system(size: 20))
                        .frame(width: 38, height: 36)
                        .background(
                            RoundedRectangle(cornerRadius: Ember.Radius.md)
                                .fill(Ember.cardBackground(scheme))
                        )
                }
                .menuStyle(.borderlessButton)
                .menuIndicator(.hidden)
                .fixedSize()

                TextField("Name", text: $editedName)
                    .textFieldStyle(.roundedBorder)

                Button("Save") {
                    onSave(editedIcon, editedName)
                }
                .buttonStyle(PrimaryActionButtonStyle())
                .disabled(editedName.trimmingCharacters(in: .whitespaces).isEmpty)

                Button("Cancel") { onCancel() }
                    .buttonStyle(SecondaryActionButtonStyle())
            } else {
                Text(category.icon)
                    .font(.system(size: 22))
                    .frame(width: 38, height: 38)
                    .background(
                        RoundedRectangle(cornerRadius: Ember.Radius.md)
                            .fill(Ember.Palette.amberSoft)
                    )

                Text(category.name)
                    .font(Ember.Font.body.weight(.medium))
                    .foregroundColor(Ember.primaryText(scheme))
                    .frame(maxWidth: .infinity, alignment: .leading)

                HStack(spacing: 2) {
                    Button {
                        editedName = category.name
                        editedIcon = category.icon
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
