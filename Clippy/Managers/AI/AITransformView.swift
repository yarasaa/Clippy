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
    @State private var copied = false

    @EnvironmentObject var settings: SettingsManager
    @Environment(\.colorScheme) var scheme

    var body: some View {
        VStack(spacing: 0) {
            header

            Divider().opacity(0.3)

            if let error = error {
                errorView(error)
            } else if isLoading {
                loadingView
            } else {
                resultView
            }
        }
        .frame(width: 440)
        .frame(minHeight: 200, maxHeight: 440)
        .background(Ember.cardBackground(scheme))
        .clipShape(RoundedRectangle(cornerRadius: Ember.Radius.lg))
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

    // MARK: Header

    private var header: some View {
        HStack(spacing: Ember.Space.sm) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Ember.Palette.amber, Ember.Palette.amberDark],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 28, height: 28)

                Image(systemName: actionIcon)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.white)
            }

            VStack(alignment: .leading, spacing: 0) {
                Text(actionTitle)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundColor(Ember.primaryText(scheme))

                Text(statusText)
                    .font(Ember.Font.meta)
                    .foregroundColor(Ember.secondaryText(scheme))
            }

            Spacer()

            Button { onDismiss() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(Ember.secondaryText(scheme))
                    .frame(width: 20, height: 20)
                    .background(Circle().fill(Ember.Palette.smoke.opacity(0.15)))
            }
            .buttonStyle(.plain)
        }
        .padding(Ember.Space.md)
    }

    // MARK: Loading

    private var loadingView: some View {
        VStack(spacing: Ember.Space.md) {
            ZStack {
                Circle()
                    .stroke(Ember.Palette.amber.opacity(0.2), lineWidth: 3)
                    .frame(width: 36, height: 36)

                Circle()
                    .trim(from: 0, to: 0.7)
                    .stroke(
                        LinearGradient(
                            colors: [Ember.Palette.amber, Ember.Palette.amberDark],
                            startPoint: .top,
                            endPoint: .bottom
                        ),
                        style: StrokeStyle(lineWidth: 3, lineCap: .round)
                    )
                    .frame(width: 36, height: 36)
                    .rotationEffect(.degrees(isLoading ? 360 : 0))
                    .animation(
                        .linear(duration: 1.0).repeatForever(autoreverses: false),
                        value: isLoading
                    )
            }

            Text("Thinking…")
                .font(Ember.Font.body)
                .foregroundColor(Ember.secondaryText(scheme))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(Ember.Space.xl)
    }

    // MARK: Error

    private func errorView(_ message: String) -> some View {
        VStack(spacing: Ember.Space.md) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 28))
                .foregroundColor(Ember.Palette.rust)

            Text("Something went wrong")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(Ember.primaryText(scheme))

            Text(message)
                .font(Ember.Font.caption)
                .foregroundColor(Ember.secondaryText(scheme))
                .multilineTextAlignment(.center)
                .textSelection(.enabled)
                .padding(.horizontal, Ember.Space.md)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(Ember.Space.xl)
    }

    // MARK: Result

    private var resultView: some View {
        VStack(spacing: 0) {
            ScrollView {
                Text(result)
                    .font(Ember.Font.body)
                    .foregroundColor(Ember.primaryText(scheme))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(Ember.Space.md)
            }

            Divider().opacity(0.3)

            HStack(spacing: Ember.Space.sm) {
                Button {
                    let pb = NSPasteboard.general
                    pb.clearContents()
                    pb.setString(result, forType: .string)
                    withAnimation(Ember.Motion.snap) { copied = true }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        withAnimation { copied = false }
                    }
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: copied ? "checkmark" : "doc.on.doc")
                        Text(copied ? "Copied" : "Copy")
                    }
                }
                .buttonStyle(SecondaryActionButtonStyle(success: copied))

                Spacer()

                Button { onResult(result) } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "arrow.triangle.2.circlepath")
                        Text("Replace Original")
                    }
                }
                .buttonStyle(PrimaryActionButtonStyle())
            }
            .padding(Ember.Space.md)
        }
    }

    // MARK: Action metadata

    private var actionIcon: String {
        switch action {
        case .summarize:    return "text.bubble"
        case .expand:       return "arrow.up.left.and.arrow.down.right"
        case .fixGrammar:   return "checkmark.circle"
        case .translate:    return "globe"
        case .bulletPoints: return "list.bullet"
        case .draftEmail:   return "envelope"
        case .explainCode:  return "chevron.left.forwardslash.chevron.right"
        case .addComments:  return "text.quote"
        case .findBugs:     return "ladybug"
        case .optimizeCode: return "wand.and.stars"
        case .freePrompt:   return "text.cursor"
        }
    }

    private var actionTitle: String {
        if action == .translate, let lang = targetLanguage {
            return "Translate to \(lang)"
        }
        switch action {
        case .summarize:    return "Summarize"
        case .expand:       return "Expand"
        case .fixGrammar:   return "Fix Grammar"
        case .translate:    return "Translate"
        case .bulletPoints: return "Convert to Bullet Points"
        case .draftEmail:   return "Draft Email"
        case .explainCode:  return "Explain Code"
        case .addComments:  return "Add Comments"
        case .findBugs:     return "Find Bugs"
        case .optimizeCode: return "Optimize Code"
        case .freePrompt:   return "AI"
        }
    }

    private var statusText: String {
        if isLoading { return "Processing…" }
        if error != nil { return "Failed" }
        return "Powered by \(providerName)"
    }

    private var providerName: String {
        switch settings.aiProvider {
        case "ollama":    return "Ollama"
        case "openai":    return "OpenAI"
        case "anthropic": return "Anthropic"
        case "google":    return "Gemini"
        default:          return "AI"
        }
    }
}
