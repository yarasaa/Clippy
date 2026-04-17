//
//  CategoryFilterView.swift
//  Clippy
//

import SwiftUI

struct CategoryFilterView: View {
    @Binding var selectedCategory: String?
    @EnvironmentObject var settings: SettingsManager
    @Environment(\.colorScheme) var scheme

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                categoryPill(icon: "📁", label: "All", isSelected: selectedCategory == nil) {
                    selectedCategory = nil
                }

                ForEach(settings.snippetCategories) { category in
                    categoryPill(
                        icon: category.icon,
                        label: category.name,
                        isSelected: selectedCategory == category.name
                    ) {
                        selectedCategory = category.name
                    }
                }
            }
            .padding(.vertical, 2)
        }
    }

    private func categoryPill(icon: String, label: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Text(icon).font(.system(size: 11))
                Text(label)
                    .font(.system(size: 11, weight: .medium))
            }
            .foregroundColor(isSelected ? .white : Ember.secondaryText(scheme))
            .padding(.horizontal, Ember.Space.sm + 2)
            .padding(.vertical, 4)
            .background(
                Capsule()
                    .fill(isSelected ? AnyShapeStyle(
                        LinearGradient(
                            colors: [Ember.Palette.amber, Ember.Palette.amberDark],
                            startPoint: .top, endPoint: .bottom
                        )
                    ) : AnyShapeStyle(Color.clear))
            )
            .overlay(
                Capsule().strokeBorder(isSelected ? .clear : Ember.Palette.smoke.opacity(0.22), lineWidth: 0.5)
            )
        }
        .buttonStyle(.plain)
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
                Text(icon).font(.system(size: 14))
                Text(label)
                    .font(.caption)
                    .fontWeight(isSelected ? .semibold : .regular)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(isSelected ? Ember.Palette.amber : Color.secondary.opacity(0.1))
            .foregroundColor(isSelected ? .white : .primary)
            .cornerRadius(18)
        }
        .buttonStyle(.plain)
    }
}
