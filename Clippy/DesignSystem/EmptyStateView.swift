import SwiftUI

// MARK: - EmptyStateView
// Shown when a tab has no items. Warm, inviting, never scolding.

struct EmptyStateView: View {
    let tab: ContentView.Tab
    @Environment(\.colorScheme) var scheme
    @State private var bounce = false

    var body: some View {
        VStack(spacing: Ember.Space.lg) {
            Spacer()

            ZStack {
                Circle()
                    .fill(Ember.Palette.amber.opacity(0.08))
                    .frame(width: 120, height: 120)
                    .blur(radius: 20)
                    .scaleEffect(bounce ? 1.1 : 0.95)
                    .animation(
                        .easeInOut(duration: 2.5).repeatForever(autoreverses: true),
                        value: bounce
                    )

                Image(systemName: icon)
                    .font(.system(size: 44, weight: .light))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Ember.Palette.amber, Ember.Palette.amberDark],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .rotationEffect(.degrees(bounce ? 3 : -3))
                    .animation(
                        .easeInOut(duration: 3.0).repeatForever(autoreverses: true),
                        value: bounce
                    )
            }

            VStack(spacing: Ember.Space.sm) {
                Text(title)
                    .font(Ember.Font.title)
                    .foregroundColor(Ember.primaryText(scheme))

                Text(subtitle)
                    .font(Ember.Font.body)
                    .foregroundColor(Ember.secondaryText(scheme))
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 280)
            }

            if let hint = keyboardHint {
                HStack(spacing: Ember.Space.xs) {
                    ForEach(hint.keys, id: \.self) { key in
                        Text(key)
                            .font(Ember.Font.kbd)
                            .foregroundColor(Ember.secondaryText(scheme))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(Ember.Palette.smoke.opacity(scheme == .dark ? 0.18 : 0.1))
                            )
                    }
                    Text(hint.label)
                        .font(Ember.Font.caption)
                        .foregroundColor(Ember.tertiaryText(scheme))
                        .padding(.leading, 4)
                }
                .padding(.top, Ember.Space.sm)
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear { bounce = true }
    }

    private var icon: String {
        switch tab {
        case .history:   return "tray"
        case .code:      return "chevron.left.forwardslash.chevron.right"
        case .images:    return "photo.on.rectangle.angled"
        case .snippets:  return "text.badge.star"
        case .favorites: return "star"
        }
    }

    private var title: String {
        switch tab {
        case .history:   return "Nothing yet"
        case .code:      return "No code snippets"
        case .images:    return "No images"
        case .snippets:  return "No snippets saved"
        case .favorites: return "Nothing starred"
        }
    }

    private var subtitle: String {
        switch tab {
        case .history:   return "Copy anything — text, images, code. Clippy will remember."
        case .code:      return "Code you copy shows up here automatically."
        case .images:    return "Screenshots and images land here."
        case .snippets:  return "Save reusable text with a keyword to summon it anytime."
        case .favorites: return "Star the items you want to keep forever."
        }
    }

    private var keyboardHint: (keys: [String], label: String)? {
        switch tab {
        case .history:   return (["⌘", "C"], "to copy something")
        case .snippets:  return (["⌘", "N"], "to create one")
        default:         return nil
        }
    }
}

#if DEBUG
struct EmptyStateView_Previews: PreviewProvider {
    static var previews: some View {
        EmptyStateView(tab: .history)
            .frame(width: 420, height: 500)
    }
}
#endif
