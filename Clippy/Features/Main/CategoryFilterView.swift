//
//  CategoryFilterView.swift
//  Clippy
//
//  Created by Mehmet Akbaba on 16.11.2025.
//

import SwiftUI

struct CategoryFilterView: View {
    @Binding var selectedCategory: String?
    @EnvironmentObject var settings: SettingsManager
    @State private var currentIndex: Int = 0
    @State private var cachedCategories: [CategoryItem] = []

    private var allCategories: [CategoryItem] {
        // Cache categories to avoid recomputation on every render
        if cachedCategories.isEmpty || cachedCategories.count != settings.snippetCategories.count + 1 {
            var items: [CategoryItem] = [CategoryItem(id: "all", name: "All", icon: "📁")]
            items.append(contentsOf: settings.snippetCategories.map { CategoryItem(id: $0.id.uuidString, name: $0.name, icon: $0.icon) })
            return items
        }
        return cachedCategories
    }

    var body: some View {
        HStack(spacing: 4) {
            // Left scroll button
            Button(action: {
                if currentIndex > 0 {
                    currentIndex -= 1
                }
            }) {
                Image(systemName: "chevron.left.circle.fill")
                    .font(.body)
                    .foregroundColor(currentIndex > 0 ? .accentColor : .secondary.opacity(0.3))
            }
            .buttonStyle(.plain)
            .disabled(currentIndex == 0)

            ScrollViewReader { proxy in
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        // "All" button
                        CategoryButton(
                            icon: "📁",
                            label: L("All", settings: settings),
                            isSelected: selectedCategory == nil
                        ) {
                            selectedCategory = nil
                        }
                        .id("all")

                        // Category buttons
                        ForEach(settings.snippetCategories) { category in
                            CategoryButton(
                                icon: category.icon,
                                label: L(category.name, settings: settings),
                                isSelected: selectedCategory == category.name
                            ) {
                                selectedCategory = category.name
                            }
                            .id(category.id.uuidString)
                        }
                    }
                    .padding(.horizontal, 4)
                }
                .onChange(of: currentIndex) { newIndex in
                    withAnimation {
                        proxy.scrollTo(allCategories[newIndex].id, anchor: .leading)
                    }
                }
            }

            // Right scroll button
            Button(action: {
                if currentIndex < allCategories.count - 1 {
                    currentIndex += 1
                }
            }) {
                Image(systemName: "chevron.right.circle.fill")
                    .font(.body)
                    .foregroundColor(currentIndex < allCategories.count - 1 ? .accentColor : .secondary.opacity(0.3))
            }
            .buttonStyle(.plain)
            .disabled(currentIndex >= allCategories.count - 1)
        }
        .frame(height: 36)
        .onAppear {
            updateCachedCategories()
        }
        .onChange(of: settings.snippetCategories.count) { _ in
            updateCachedCategories()
        }
    }

    private func updateCachedCategories() {
        var items: [CategoryItem] = [CategoryItem(id: "all", name: "All", icon: "📁")]
        items.append(contentsOf: settings.snippetCategories.map { CategoryItem(id: $0.id.uuidString, name: $0.name, icon: $0.icon) })
        cachedCategories = items
    }
}

struct CategoryItem {
    let id: String
    let name: String
    let icon: String
}

struct CategoryButton: View {
    let icon: String
    let label: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Text(icon)
                    .font(.system(size: 14))
                Text(label)
                    .font(.caption)
                    .fontWeight(isSelected ? .semibold : .regular)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(isSelected ? Color.accentColor : Color.secondary.opacity(0.1))
            .foregroundColor(isSelected ? .white : .primary)
            .cornerRadius(18)
        }
        .buttonStyle(.plain)
    }
}
