import SwiftUI

struct SnippetPreviewView: View {
    let keyword: String
    let previewContent: String
    let onConfirm: () -> Void
    let onCancel: () -> Void
    @EnvironmentObject var settings: SettingsManager

    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Snippet Önizleme")
                    .font(.headline)
                Spacer()
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Anahtar Kelime:")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text(keyword)
                    .font(.system(.body, design: .monospaced))
                    .padding(8)
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(4)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("İçerik:")
                    .font(.caption)
                    .foregroundColor(.secondary)
                ScrollView {
                    Text(previewContent)
                        .font(.system(.body, design: .monospaced))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(8)
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(4)
                }
                .frame(maxHeight: 200)
            }

            HStack(spacing: 12) {
                Button(action: onCancel) {
                    Text("İptal")
                        .frame(maxWidth: .infinity)
                }
                .keyboardShortcut(.escape, modifiers: [])

                Button(action: onConfirm) {
                    Text("Yapıştır")
                        .frame(maxWidth: .infinity)
                }
                .keyboardShortcut(.return, modifiers: [])
                .buttonStyle(.borderedProminent)
            }
        }
        .padding()
        .frame(width: 400)
    }
}
