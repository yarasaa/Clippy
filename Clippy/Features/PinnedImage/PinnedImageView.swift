//
//  PinnedImageView.swift
//  Clippy
//
//  Contents of a pinned image panel: the image, and controls that stay out
//  of the way until the cursor is over it.
//

import SwiftUI
import AppKit

struct PinnedImageView: View {
    let image: NSImage
    let onClose: () -> Void
    let onCopy: () -> Void

    @Environment(\.colorScheme) private var scheme
    @ObservedObject private var settings = SettingsManager.shared

    @State private var isHovering = false
    /// Lowering this lets you read what's underneath without unpinning.
    /// Restored to fully opaque while the cursor is over the pin, so
    /// hovering always shows the real thing.
    @State private var opacity: Double = 1.0
    /// True while the fade slider is being dragged.
    ///
    /// Hovering normally forces the pin back to full opacity so a faded
    /// pin is always recoverable — but you have to hover to reach the
    /// slider, so that rule made the slider do nothing visible at all.
    /// While you're actually dragging it, the fade shows.
    @State private var isFading = false

    private var appColorScheme: ColorScheme? {
        switch settings.appTheme {
        case "light": return .light
        case "dark":  return .dark
        default:      return nil
        }
    }

    var body: some View {
        GeometryReader { geo in
            Image(nsImage: image)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: geo.size.width, height: geo.size.height)
                .clipped()
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .strokeBorder(Color.white.opacity(scheme == .dark ? 0.14 : 0.5), lineWidth: 0.5)
                )
                .opacity(isFading ? opacity : (isHovering ? 1.0 : opacity))
                .overlay(alignment: .top) { chrome(width: geo.size.width) }
        }
        .onHover { isHovering = $0 }
        .animation(Ember.Motion.gentle, value: isHovering)
        .preferredColorScheme(appColorScheme)
    }

    /// Hidden until hovered: a pin is something you look at, so anything
    /// permanently drawn on top of it is in the way.
    ///
    /// It also has to fit. The controls were a fixed size, so on a small pin
    /// they covered most of the picture — the thing you pinned it to see.
    /// Below each threshold the least important control is the one that goes.
    @ViewBuilder
    private func chrome(width: CGFloat) -> some View {
        if isHovering {
            // Raised with the labels. "Fade" and the spelled-out modifier
            // hint are wider than the bare icon and "⌥ click through" they
            // replaced, and a control bar that overflows its own pin is
            // worse than one that drops a row.
            let showHint = width > 430
            let showOpacity = width > 280

            HStack(spacing: 6) {
                pinButton("xmark", "Close this pin", action: onClose)
                pinButton("doc.on.doc", "Copy the image", action: onCopy)

                if showOpacity {
                    Divider().frame(height: 12).opacity(0.4)

                    // Named, not just an icon. A half-filled circle next to
                    // an unlabelled slider is a control you have to drag to
                    // find out what it does — and dragging it used to show
                    // nothing, so you couldn't find out that way either.
                    Text("Fade")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundColor(.white.opacity(0.75))

                    Slider(value: $opacity, in: 0.25...1.0) { editing in
                        isFading = editing
                    }
                    .controlSize(.mini)
                    .frame(width: 56)
                    .help("Fade the pin so you can read what's behind it")

                    // Always laid out, never inserted or removed.
                    //
                    // The first version showed this only while dragging and
                    // hid the hint at the same time. The bar is centred, so
                    // its width changing mid-press shifted every control
                    // sideways — the slider slid out from under the pointer
                    // and the value slammed to the minimum before you had
                    // moved at all. Anything that appears during a gesture
                    // has to occupy its space beforehand.
                    Text("\(Int(opacity * 100))%")
                        .font(.system(size: 9, weight: .medium))
                        .monospacedDigit()
                        .foregroundColor(.white.opacity(isFading ? 0.9 : 0.55))
                        .frame(width: 30, alignment: .leading)
                }

                if showHint {
                    Divider().frame(height: 12).opacity(0.4)
                    // A hint, not a control — so it reads as one. Sitting in
                    // the same row as the buttons in the same weight, it
                    // looked like a third button that didn't respond. It also
                    // stays put while the slider is in use; see above.
                    Text("hold ⌥ to click through")
                        .font(.system(size: 9))
                        .italic()
                        .foregroundColor(.white.opacity(0.55))
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(.ultraThinMaterial, in: Capsule())
            .overlay(Capsule().strokeBorder(Color.white.opacity(0.18), lineWidth: 0.5))
            .padding(.top, 6)
            .transition(.opacity.combined(with: .move(edge: .top)))
        }
    }

    private func pinButton(_ symbol: String, _ help: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(.white.opacity(0.9))
                .frame(width: 18, height: 18)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(help)
    }
}
