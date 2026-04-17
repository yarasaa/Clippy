import SwiftUI

struct SnippetPreviewView: View {
    let keyword: String
    let previewContent: String
    let onConfirm: () -> Void
    let onCancel: () -> Void
    @EnvironmentObject var settings: SettingsManager
    @Environment(\.colorScheme) var scheme

    var body: some View {
        VStack(spacing: Ember.Space.md) {
            HStack(spacing: Ember.Space.sm) {
                ClippyMark(size: 16)
                Text("Snippet Preview")
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                Spacer()
            }

            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 4) {
                    Image(systemName: "command")
                        .font(.system(size: 9))
                    Text("Keyword")
                        .font(.system(size: 10, weight: .semibold))
                }
                .foregroundColor(Ember.tertiaryText(scheme))
                .textCase(.uppercase)
                .tracking(0.6)

                Text(keyword)
                    .font(Ember.Font.code.weight(.semibold))
                    .foregroundColor(Ember.Palette.amber)
                    .padding(.horizontal, Ember.Space.sm + 2)
                    .padding(.vertical, 5)
                    .background(
                        Capsule().fill(Ember.Palette.amberSoft)
                    )
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 4) {
                    Image(systemName: "text.alignleft")
                        .font(.system(size: 9))
                    Text("Content")
                        .font(.system(size: 10, weight: .semibold))
                }
                .foregroundColor(Ember.tertiaryText(scheme))
                .textCase(.uppercase)
                .tracking(0.6)

                ScrollView {
                    Text(previewContent)
                        .font(Ember.Font.code)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(Ember.Space.sm + 2)
                }
                .frame(maxHeight: 200)
                .background(
                    RoundedRectangle(cornerRadius: Ember.Radius.md)
                        .fill(Ember.cardBackground(scheme))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: Ember.Radius.md)
                        .strokeBorder(Color.white.opacity(scheme == .dark ? 0.06 : 0.4), lineWidth: 0.5)
                )
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: Ember.Space.sm) {
                Button(action: onCancel) {
                    Text("Cancel").frame(maxWidth: .infinity)
                }
                .buttonStyle(SecondaryActionButtonStyle())
                .keyboardShortcut(.escape, modifiers: [])

                Button(action: onConfirm) {
                    HStack(spacing: 5) {
                        Image(systemName: "arrow.down.doc")
                        Text("Paste")
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(PrimaryActionButtonStyle())
                .keyboardShortcut(.return, modifiers: [])
            }
        }
        .padding(Ember.Space.lg)
        .frame(width: 420)
        .background(Ember.surface(scheme))
    }
}
