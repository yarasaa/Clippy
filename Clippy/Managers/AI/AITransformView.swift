//
//  AITransformView.swift
//  Clippy
//

import SwiftUI

struct AITransformView: View {
    let text: String
    let action: AIAction
    var targetLanguage: String? = nil
    var customPrompt: String? = nil
    let onResult: (String) -> Void
    let onDismiss: () -> Void

    @State private var result: String = ""
    @State private var isLoading = true
    @State private var error: String? = nil

    @EnvironmentObject var settings: SettingsManager

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                if isLoading {
                    ProgressView()
                        .controlSize(.small)
                    Text(L("Processing with AI...", settings: settings))
                        .font(.headline)
                } else if error != nil {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                    Text(L("AI Error", settings: settings))
                        .font(.headline)
                } else {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text(L("AI Result", settings: settings))
                        .font(.headline)
                }
                Spacer()
                Button { onDismiss() } label: {
                    Image(systemName: "xmark.circle")
                }
                .buttonStyle(.borderless)
            }

            if let error = error {
                Text(error)
                    .font(.caption)
                    .foregroundColor(.red)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else if !result.isEmpty {
                ScrollView {
                    Text(result)
                        .font(.system(size: 12))
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(maxHeight: 200)

                HStack {
                    Button(L("Copy Result", settings: settings)) {
                        let pb = NSPasteboard.general
                        pb.clearContents()
                        pb.setString(result, forType: .string)
                    }
                    .buttonStyle(.bordered)

                    Button(L("Replace Original", settings: settings)) {
                        onResult(result)
                    }
                    .buttonStyle(.borderedProminent)

                    Spacer()
                }
            }
        }
        .padding()
        .frame(width: 400)
        .task {
            do {
                result = try await AIService.shared.process(
                    text: text,
                    action: action,
                    targetLanguage: targetLanguage,
                    customPrompt: customPrompt
                )
                isLoading = false
            } catch {
                self.error = error.localizedDescription
                isLoading = false
            }
        }
    }
}
