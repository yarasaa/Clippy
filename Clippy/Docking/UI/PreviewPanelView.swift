import SwiftUI

struct PreviewPanelView: View {
    let appIcon: NSImage?
    let appName: String
    let items: [PreviewItem]
    let onWindowClose: (CGWindowID) -> Void
    let onWindowMinimize: (CGWindowID) -> Void
    let onWindowSelect: (CGWindowID) -> Void
    var onMoveToMonitor: ((CGWindowID, NSScreen) -> Void)? = nil

    @State private var showItems = false
    @State private var availableScreens: [NSScreen] = NSScreen.screens
    @State private var keyboardWasUsed = false
    @Environment(\.colorScheme) private var scheme

    // Reads launch-animation setting once per body eval. Stored as a
    // `let` shadow so all helpers see a stable string within one render.
    private var launchAnimation: String {
        SettingsManager.shared.dockPreviewLaunchAnimation
    }

    /// Initial offset applied to a card before the panel finishes appearing.
    /// `index` is the card's position from left; we use it to fan cards out
    /// horizontally for "fan-out", but keep them stationary for other modes.
    private func launchOffset(for index: Int) -> CGSize {
        switch launchAnimation {
        case "fan-out":
            // Cards rise from below and fan outward. Center card barely
            // moves horizontally; cards on the edges spread further out.
            let centerIndex = Double(items.count - 1) / 2.0
            let spread = (Double(index) - centerIndex) * 24
            return CGSize(width: spread, height: 60)
        case "scale-pop":
            return .zero
        case "none":
            return .zero
        default: // "fade-stagger"
            return CGSize(width: 0, height: 16)
        }
    }

    private func launchScale(for index: Int) -> CGFloat {
        switch launchAnimation {
        case "fan-out":   return 0.5
        case "scale-pop": return 0.6
        case "none":      return 1.0
        default:          return 1.0   // "fade-stagger"
        }
    }

    private func launchAnimationCurve(for index: Int) -> Animation {
        let stagger = Double(index) * 0.04
        switch launchAnimation {
        case "fan-out":
            return .spring(response: 0.55, dampingFraction: 0.72).delay(stagger)
        case "scale-pop":
            return .spring(response: 0.36, dampingFraction: 0.62).delay(stagger)
        case "none":
            return .linear(duration: 0)
        default:
            return .spring(response: 0.42, dampingFraction: 0.78).delay(stagger)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header

            Divider()
                .opacity(0.25)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 20) {  // bumped from 14 for breathing room
                    ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                        PreviewItemView(
                            image: item.image,
                            windowID: item.id,
                            title: item.title,
                            index: index,
                            onClose: onWindowClose,
                            onMinimize: onWindowMinimize,
                            onSelect: onWindowSelect,
                            onMoveToMonitor: onMoveToMonitor,
                            keyboardActive: keyboardWasUsed
                        )
                        .id(item.id)
                        .opacity(showItems ? 1 : 0)
                        .offset(showItems ? .zero : launchOffset(for: index))
                        .scaleEffect(showItems ? 1.0 : launchScale(for: index),
                                     anchor: .bottom)
                        .animation(launchAnimationCurve(for: index), value: showItems)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 16)
                // CRITICAL: tell SwiftUI the HStack should claim its
                // ideal natural width (= sum of card widths). Without
                // this, the ScrollView reports an unbounded ideal width
                // to the parent VStack, and the panel ends up sized to
                // whatever NSHostingController chose first — leaving
                // empty space on the right when the actual content is
                // narrower than that initial choice.
                .fixedSize(horizontal: true, vertical: false)
            }

            // Footer follows the same hint-mode rules as the index badges:
            // hidden in "never" mode, fades in on-keypress, always shown
            // in "always" mode (the historical default).
            if SettingsManager.shared.enableDockPreviewKeyboardShortcuts,
               SettingsManager.shared.dockPreviewKeyboardHintMode != "never" {
                let hintMode = SettingsManager.shared.dockPreviewKeyboardHintMode
                let visible = (hintMode == "always") || (hintMode == "on-keypress" && keyboardWasUsed)

                if visible {
                    Divider().opacity(0.25)
                    keyboardHintsFooter
                        .transition(.opacity.combined(with: .move(edge: .bottom)))
                }
            }
        }
        // .fixedSize() applied IMMEDIATELY after the content VStack —
        // before any background/material/shadow modifiers. The order
        // matters: fixedSize tells SwiftUI to lock the layout to ideal
        // intrinsic size at that point in the chain. If we apply it
        // last (after .background, .overlay, .shadow), the background
        // material's sizing behavior can re-introduce flexibility and
        // the panel ends up wider than its actual content. Pin it now,
        // then decorate.
        .fixedSize()
        .modifier(PanelSurface(scheme: scheme))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(borderGradient, lineWidth: 0.6)
        )
        .shadow(color: .black.opacity(scheme == .dark ? 0.5 : 0.18), radius: 28, y: 14)
        .shadow(color: Ember.Palette.amber.opacity(scheme == .dark ? 0.1 : 0.04), radius: 40, y: 0)
        .onAppear {
            showItems = true
            // Reset the "user has used the keyboard" flag every time the
            // panel appears, so the on-keypress hint mode starts hidden.
            keyboardWasUsed = false
            installKeyboardWatcher()
        }
        .onDisappear {
            showItems = false
            removeKeyboardWatcher()
        }
    }

    // Local NSEvent monitor that flips `keyboardWasUsed` to true on the
    // first key press while the panel is showing. Used by the
    // "on-keypress" badge mode so badges stay hidden for mouse users
    // and fade in only when keyboard navigation begins.
    @State private var keyMonitor: Any?

    private func installKeyboardWatcher() {
        guard SettingsManager.shared.dockPreviewKeyboardHintMode == "on-keypress" else { return }
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .flagsChanged]) { event in
            if !keyboardWasUsed {
                withAnimation(.easeOut(duration: 0.18)) { keyboardWasUsed = true }
            }
            return event
        }
    }

    private func removeKeyboardWatcher() {
        if let monitor = keyMonitor {
            NSEvent.removeMonitor(monitor)
            keyMonitor = nil
        }
    }

    // MARK: - Header

    private var header: some View {
        // Single-line layout reads cleaner against the glass background:
        // [icon] AppName · 2 windows                    [chip]
        // The bullet separator implies an inline relationship between
        // the app name and window count without forcing a second
        // baseline that competes with the thumbnail title bars below.
        HStack(spacing: 10) {
            if let appIcon = appIcon {
                Image(nsImage: appIcon)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 22, height: 22)
                    .shadow(color: .black.opacity(0.12), radius: 2, y: 1)
            }

            HStack(spacing: 6) {
                Text(appName)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundColor(.primary)
                    .lineLimit(1)

                Text("·")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.secondary.opacity(0.4))

                Text(windowCountLabel)
                    .font(.system(size: 12, weight: .regular, design: .rounded))
                    .foregroundColor(.secondary.opacity(0.85))
                    .lineLimit(1)
            }

            Spacer()

            if availableScreens.count > 1 {
                monitorChip
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    private var windowCountLabel: String {
        let n = items.count
        return "\(n) window\(n == 1 ? "" : "s")"
    }

    private var monitorChip: some View {
        HStack(spacing: 4) {
            Image(systemName: "display")
                .font(.system(size: 10, weight: .semibold))
            Text("\(availableScreens.count)")
                .font(.system(size: 10, weight: .bold, design: .rounded))
        }
        .foregroundColor(Ember.Palette.amber)
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(Capsule().fill(Ember.Palette.amberSoft))
        .help("\(availableScreens.count) displays available. Right-click a window to move it.")
    }

    // MARK: - Keyboard Hints Footer

    private var keyboardHintsFooter: some View {
        // Compact mode for "small" preview — labels alongside the keys
        // (open / select / close / dismiss) push the footer's natural
        // width past ~310pt, which is wider than a small card section
        // (≈232pt for one card). That width then drives the panel
        // wider than its actual content, leaving empty space on the
        // right of the single thumbnail.
        // In compact mode we drop the labels and lean on hover
        // tooltips — keys still readable, footer stays narrow.
        let compact = SettingsManager.shared.dockPreviewSize == "small"

        return HStack(spacing: compact ? 10 : 14) {
            if compact {
                kbdGlyph("1-9").help("Open by number")
                kbdGlyph("⏎").help("Select highlighted")
                kbdGlyph("⌘W").help("Close window")
                kbdGlyph("esc").help("Dismiss")
            } else {
                kbdHint(keys: "1-9", label: "open")
                kbdHint(keys: "⏎", label: "select")
                kbdHint(keys: "⌘W", label: "close")
                kbdHint(keys: "esc", label: "dismiss")
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, compact ? 10 : 14)
        .padding(.vertical, compact ? 5 : 7)
    }

    /// Compact key glyph used by the small-preview footer.
    /// Same visual style as the boxed key portion of `kbdHint`, no label.
    private func kbdGlyph(_ keys: String) -> some View {
        Text(keys)
            .font(.system(size: 9, weight: .semibold, design: .monospaced))
            .foregroundColor(.secondary)
            .padding(.horizontal, 4)
            .padding(.vertical, 1)
            .background(
                RoundedRectangle(cornerRadius: 3)
                    .fill(Ember.Palette.smoke.opacity(scheme == .dark ? 0.2 : 0.08))
            )
    }

    private func kbdHint(keys: String, label: String) -> some View {
        HStack(spacing: 4) {
            Text(keys)
                .font(.system(size: 9, weight: .semibold, design: .monospaced))
                .foregroundColor(.secondary)
                .padding(.horizontal, 4)
                .padding(.vertical, 1)
                .background(
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Ember.Palette.smoke.opacity(scheme == .dark ? 0.2 : 0.08))
                )
            Text(label)
                .font(.system(size: 10))
                .foregroundColor(.secondary.opacity(0.75))
        }
    }

    // MARK: - Theme

    private var borderGradient: some ShapeStyle {
        LinearGradient(
            colors: scheme == .dark
                ? [Ember.Palette.amber.opacity(0.3), .white.opacity(0.08)]
                : [Ember.Palette.amberGlow.opacity(0.45), .black.opacity(0.06)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

}

// MARK: - VisualEffectBackground
//
// NSVisualEffectView wrapper for SwiftUI. Apple updates the system
// materials (.hudWindow, .menu, .popover, etc.) every macOS release —
// on macOS 26 these materials automatically receive the new Liquid
// Glass treatment. SwiftUI's own `.glassEffect()` is scoped for leaf
// controls (buttons, badges, capsules); for a panel-sized refractive
// surface NSVisualEffectView is the proven, system-native path.
private struct VisualEffectBackground: NSViewRepresentable {
    let material: NSVisualEffectView.Material
    let blendingMode: NSVisualEffectView.BlendingMode

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        view.isEmphasized = true
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
    }
}

// MARK: - PanelSurface
//
// Applies the panel's "background material" — Liquid Glass on macOS 26+
// when the user picks "auto", ultraThinMaterial on older systems, or an
// opaque tint when "solid". Lives as a ViewModifier so the body of
// `PreviewPanelView` can stay flat instead of branching `if`s for each
// material option.
private struct PanelSurface: ViewModifier {
    let scheme: ColorScheme

    func body(content: Content) -> some View {
        let mode = SettingsManager.shared.dockPreviewMaterial
        let shape = RoundedRectangle(cornerRadius: 18, style: .continuous)

        switch mode {
        case "solid":
            content
                .background(
                    shape.fill(scheme == .dark
                               ? Color(red: 0.10, green: 0.11, blue: 0.18)
                               : Color(red: 0.97, green: 0.97, blue: 0.97))
                )
                .clipShape(shape)

        case "auto":
            // `.hudWindow` is Apple's "floating panel HUD" material. On
            // macOS 26 this material is rendered with Liquid Glass —
            // refractive, tinted by the wallpaper, with the new specular
            // highlights. On older macOS it's a strong frosted look.
            // Either way it's clearly distinct from the standard
            // ultraThin used by "translucent" mode.
            content
                .background(
                    VisualEffectBackground(material: .hudWindow,
                                           blendingMode: .behindWindow)
                        .clipShape(shape)
                )
                .clipShape(shape)

        default:  // "translucent"
            content
                .background(
                    shape.fill(scheme == .dark
                               ? Color(red: 0.07, green: 0.09, blue: 0.16).opacity(0.72)
                               : Color.white.opacity(0.68))
                        .background(.ultraThinMaterial, in: shape)
                )
                .clipShape(shape)
        }
    }
}

struct PreviewItemView: View {
    let image: NSImage
    let windowID: CGWindowID
    let title: String?
    let index: Int
    let onClose: (CGWindowID) -> Void
    let onMinimize: (CGWindowID) -> Void
    let onSelect: (CGWindowID) -> Void
    var onMoveToMonitor: ((CGWindowID, NSScreen) -> Void)? = nil
    /// True when the user has pressed any key during this panel session.
    /// Used by the "on-keypress" keyboard-hint mode to fade index badges in.
    var keyboardActive: Bool = false

    @State private var isHovering = false
    @State private var showMonitorMenu = false
    @Environment(\.colorScheme) private var scheme
    private let availableScreens = NSScreen.screens

    // Cache CGImage to prevent view recreation
    private let initialCGImage: CGImage?

    init(image: NSImage, windowID: CGWindowID, title: String?, index: Int = 0, onClose: @escaping (CGWindowID) -> Void, onMinimize: @escaping (CGWindowID) -> Void, onSelect: @escaping (CGWindowID) -> Void, onMoveToMonitor: ((CGWindowID, NSScreen) -> Void)? = nil, keyboardActive: Bool = false) {
        self.image = image
        self.windowID = windowID
        self.title = title
        self.index = index
        self.onClose = onClose
        self.onMinimize = onMinimize
        self.onSelect = onSelect
        self.onMoveToMonitor = onMoveToMonitor
        self.keyboardActive = keyboardActive
        self.initialCGImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil)
    }


    private var previewSize: (maxWidth: CGFloat, maxHeight: CGFloat) {
        let sizeStyle = SettingsManager.shared.dockPreviewSize
        switch sizeStyle {
        case "small":
            return (200, 133)
        case "large":
            return (400, 267)
        case "xlarge":
            return (500, 333)
        case "xxlarge":
            return (600, 400)
        default:
            return (300, 200)
        }
    }

    var body: some View {
        // The title bar lives as an `.overlay` on the preview thumbnail
        // (NOT a ZStack sibling) for one important reason: the overlay
        // is sized by its host's frame, so any `.frame(maxWidth: .infinity)`
        // inside the title bar resolves to the thumbnail's actual width.
        // In a ZStack that infinity would have leaked outward and caused
        // the surrounding panel to widen — visible as empty space on the
        // right when only a single window was previewed.
        previewBody
            .overlay(alignment: .top) {
                if SettingsManager.shared.showWindowTitles {
                    inlineTitleBar
                }
            }
            .frame(maxWidth: previewSize.maxWidth)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(cardBorder)
            .overlay(alignment: .topTrailing) { notificationBadgeOverlay }
            .overlay(alignment: .bottomLeading) { indexBadge }
        .scaleEffect(isHovering ? 1.025 : 1.0)
        .shadow(
            color: isActiveWindow() ? Ember.Palette.amber.opacity(0.5) : .black.opacity(isHovering ? 0.5 : 0.35),
            radius: isActiveWindow() ? 16 : (isHovering ? 14 : 8),
            y: isActiveWindow() ? 6 : (isHovering ? 6 : 4)
        )
        .contentShape(Rectangle())
        .onTapGesture { onSelect(windowID) }
        .help("Click to bring this window to front")
        .contextMenu {
            QuickActionsMenu(
                windowID: windowID,
                onSelect: onSelect,
                onMinimize: onMinimize,
                onClose: onClose,
                onMoveToMonitor: onMoveToMonitor
            )
        }
        .background(
            Group {
                if SettingsManager.shared.enableDockPreviewGestures {
                    MiddleClickHandler(
                        onMiddleClick: {
                            let action = SettingsManager.shared.middleClickAction
                            guard action != "none" else { return }
                            handleGestureAction(action)
                        }
                    )
                }
            }
        )
        .onHover { hovering in
            withAnimation(.spring(response: 0.32, dampingFraction: 0.78)) { isHovering = hovering }
        }
        .onDrag {
            let itemProvider = NSItemProvider()
            itemProvider.registerDataRepresentation(forTypeIdentifier: "public.utf8-plain-text", visibility: .all) { completion in
                let data = "WindowID:\(self.windowID)".data(using: .utf8)
                completion(data, nil)
                return nil
            }
            return itemProvider
        }
    }

    // MARK: - Inline Title Bar (Windows 11 style)

    private var inlineTitleBar: some View {
        HStack(spacing: 8) {
            Text(displayTitle)
                .font(.system(size: 11, weight: .semibold))
                // White-on-gradient: title floats over the thumbnail now,
                // so we always use a high-contrast color and let the
                // gradient backdrop carry the legibility. Active windows
                // get an amber tint that still reads against any wallpaper.
                .foregroundColor(isActiveWindow() ? Ember.Palette.amber : .white)
                .shadow(color: .black.opacity(0.4), radius: 1.5, y: 0.5)
                .lineLimit(1)
                .truncationMode(.middle)

            Spacer(minLength: 4)

            if isHovering {
                HStack(spacing: 4) {
                    if let onMoveToMonitor = onMoveToMonitor, availableScreens.count > 1 {
                        if availableScreens.count == 2 {
                            // One-click: send to the other display immediately.
                            // The user wanted this behavior — no dropdown, no
                            // extra confirmation, just move. With 2 displays
                            // "the other one" is unambiguous.
                            Button {
                                if let target = nextScreenForCurrentWindow() {
                                    onMoveToMonitor(windowID, target)
                                }
                            } label: {
                                titleIconButton(systemName: "rectangle.on.rectangle.angled")
                            }
                            .buttonStyle(.plain)
                            .help("Send to other display")
                        } else {
                            // 3+ displays: keep the picker menu. Add a "Next"
                            // entry at the top so a single click still works
                            // when the user just wants "wherever".
                            Menu {
                                Button("Next display") {
                                    if let target = nextScreenForCurrentWindow() {
                                        onMoveToMonitor(windowID, target)
                                    }
                                }
                                Divider()
                                ForEach(Array(availableScreens.enumerated()), id: \.offset) { _, screen in
                                    Button {
                                        onMoveToMonitor(windowID, screen)
                                    } label: {
                                        HStack {
                                            Image(systemName: "display")
                                            Text(screen.localizedName)
                                        }
                                    }
                                }
                            } label: {
                                titleIconButton(systemName: "rectangle.on.rectangle.angled")
                            }
                            .menuStyle(.borderlessButton)
                            .menuIndicator(.hidden)
                            .fixedSize()
                            .help("Move to another display")
                        }
                    }

                    Button { onMinimize(windowID) } label: {
                        titleIconButton(systemName: "minus")
                    }
                    .buttonStyle(.plain)
                    .help("Minimize")

                    Button { onClose(windowID) } label: {
                        titleIconButton(systemName: "xmark", destructive: true)
                    }
                    .buttonStyle(.plain)
                    .help("Close window")
                }
                .transition(.opacity)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        // Stretch to the overlay's full width (== previewBody's width)
        // so the gradient backdrop spans edge-to-edge of the card. The
        // overlay parent provides the bound, so this `infinity` doesn't
        // leak outward.
        .frame(maxWidth: .infinity, alignment: .leading)
        // Background extends a bit BELOW the text into the thumbnail so
        // the gradient fade looks natural (text on solid → fade to clear).
        .background(
            titleBarBackground
                .frame(height: 36)
                .frame(maxHeight: .infinity, alignment: .top),
            alignment: .top
        )
    }

    private func titleIconButton(systemName: String, destructive: Bool = false) -> some View {
        ZStack {
            // Slightly stronger backdrop now that the title bar lives over
            // the thumbnail (no more material strip behind to soften).
            RoundedRectangle(cornerRadius: 4)
                .fill(destructive
                      ? Ember.Palette.rust.opacity(0.85)
                      : Color.white.opacity(0.22))
            Image(systemName: systemName)
                .font(.system(size: 8, weight: .bold))
                .foregroundColor(destructive ? .white : .white.opacity(0.95))
        }
        .frame(width: 18, height: 18)
        .shadow(color: .black.opacity(0.25), radius: 1, y: 0.5)
    }

    private var titleBarBackground: some View {
        // Gradient backdrop — black at the top fading to clear at the
        // bottom of the strip. Gives white text legibility over any
        // thumbnail content without the heavy frosted look that
        // ultraThinMaterial produces (which also competes with the panel's
        // Liquid Glass background and creates a "double frost" effect).
        LinearGradient(
            colors: [
                Color.black.opacity(0.55),
                Color.black.opacity(0.0)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .overlay(
            isActiveWindow()
            ? LinearGradient(
                colors: [
                    Ember.Palette.amber.opacity(0.18),
                    Color.clear
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            : nil
        )
    }

    private var displayTitle: String {
        if let t = title, !t.isEmpty { return t }
        return "Window \(windowID)"
    }

    /// Find the "next" screen relative to the one the window currently
    /// lives on. Used by the one-click display-toggle button.
    /// Falls back to the second screen (index 1) if we can't locate
    /// the current one.
    private func nextScreenForCurrentWindow() -> NSScreen? {
        let screens = NSScreen.screens
        guard screens.count > 1 else { return nil }

        // Locate the screen containing the window's center.
        let currentScreen: NSScreen? = {
            guard let info = CGWindowListCopyWindowInfo([.optionIncludingWindow], windowID) as? [[String: Any]],
                  let first = info.first,
                  let boundsDict = first[kCGWindowBounds as String] as? [String: Any],
                  let bounds = CGRect(dictionaryRepresentation: boundsDict as CFDictionary),
                  let primary = screens.first else {
                return nil
            }
            // CG bounds use top-left anchored to primary; convert to Cocoa.
            let cocoaCenter = CGPoint(x: bounds.midX,
                                      y: primary.frame.maxY - bounds.midY)
            return screens.first(where: { $0.frame.contains(cocoaCenter) })
        }()

        guard let cur = currentScreen, let idx = screens.firstIndex(of: cur) else {
            return screens.dropFirst().first
        }
        return screens[(idx + 1) % screens.count]
    }

    // MARK: - Preview Body (actual thumbnail)

    @ViewBuilder
    private var previewBody: some View {
        // Only the window the cursor is actually over streams live; every
        // other thumbnail stays a static capture. This turns the live-
        // preview cost from O(N) SCStreams (one per window — 6 windows = 6
        // concurrent ScreenCaptureKit pipelines) into O(1): at most one
        // stream at a time, for the thumbnail the user is looking at.
        // The rest of the grid still shows the crisp static capture taken
        // when the panel opened. When hover ends, `LivePreviewView`'s
        // `.onDisappear` tears its stream down, so we never accumulate.
        if SettingsManager.shared.enableAutoRefresh, isHovering, let cgImage = initialCGImage {
            LivePreviewView(
                windowID: windowID,
                initialImage: cgImage,
                maxWidth: previewSize.maxWidth,
                maxHeight: previewSize.maxHeight
            )
            .id("live-preview-\(windowID)")
        } else {
            Image(nsImage: image)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(maxWidth: previewSize.maxWidth, maxHeight: previewSize.maxHeight)
        }
    }

    // MARK: - Borders & Badges

    @ViewBuilder
    private var cardBorder: some View {
        if isActiveWindow() {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(
                    LinearGradient(
                        colors: [Ember.Palette.amber, Ember.Palette.amberDark],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 2
                )
        } else if isHovering {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(Ember.Palette.amber.opacity(0.55), lineWidth: 2)
        } else {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(Color.white.opacity(scheme == .dark ? 0.06 : 0.3), lineWidth: 0.5)
        }
    }

    @ViewBuilder
    private var notificationBadgeOverlay: some View {
        if let badgeCount = getNotificationBadge(), badgeCount > 0 {
            NotificationBadge(count: badgeCount)
                .offset(x: 8, y: -8)
        }
    }

    @ViewBuilder
    private var indexBadge: some View {
        // The badge is gated by both the master keyboard-shortcut switch
        // (must be enabled for the hotkeys to do anything) and the visual
        // hint mode (`always` / `on-keypress` / `never`). The `on-keypress`
        // mode keeps the badge hidden until the user actually presses a key,
        // which avoids a noisy permanent overlay for mouse-only users.
        if SettingsManager.shared.enableDockPreviewKeyboardShortcuts,
           SettingsManager.shared.dockPreviewKeyboardHintMode != "never",
           index < 9 {
            let hintMode = SettingsManager.shared.dockPreviewKeyboardHintMode
            let visible = (hintMode == "always") || (hintMode == "on-keypress" && keyboardActive)

            Text("\(index + 1)")
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .foregroundColor(.white)
                .frame(width: 20, height: 20)
                .background(
                    Circle()
                        .fill(
                            isActiveWindow()
                            ? AnyShapeStyle(
                                LinearGradient(
                                    colors: [Ember.Palette.amber, Ember.Palette.amberDark],
                                    startPoint: .top, endPoint: .bottom
                                )
                            )
                            : AnyShapeStyle(Color.black.opacity(0.7))
                        )
                )
                .overlay(
                    Circle().strokeBorder(.white.opacity(0.2), lineWidth: 0.5)
                )
                .shadow(color: .black.opacity(0.35), radius: 3, y: 1)
                .padding(8)
                .opacity(visible ? 1 : 0)
                .scaleEffect(visible ? 1 : 0.7)
                .animation(.easeOut(duration: 0.18), value: visible)
        }
    }

    private func handleGestureAction(_ action: String) {
        switch action {
        case "close": onClose(windowID)
        case "minimize": onMinimize(windowID)
        case "select": onSelect(windowID)
        default: break
        }
    }

    private func getNotificationBadge() -> Int? {
        // Get badge count from NSRunningApplication
        guard let windowInfo = CGWindowListCopyWindowInfo([.optionOnScreenOnly], windowID) as? [[String: Any]],
              let ownerPID = windowInfo.first?[kCGWindowOwnerPID as String] as? pid_t,
              let app = NSRunningApplication(processIdentifier: ownerPID) else {
            return nil
        }

        // Try to get badge label from Dock
        if app.bundleURL != nil {
            let dockTile = NSApplication.shared.dockTile
            // Note: This gets the main app's badge, not per-window
            // For per-window badges, we'd need accessibility API
            return Int(dockTile.badgeLabel ?? "0")
        }

        return nil
    }

    private func isActiveWindow() -> Bool {
        // Check if this window belongs to the active application
        guard let windowInfo = CGWindowListCopyWindowInfo([.optionOnScreenOnly], windowID) as? [[String: Any]],
              let ownerPID = windowInfo.first?[kCGWindowOwnerPID as String] as? pid_t else {
            return false
        }

        // Check if the app is active
        if let activeApp = NSWorkspace.shared.frontmostApplication,
           activeApp.processIdentifier == ownerPID {
            // Additionally check if this is the main window (layer 0)
            if let layer = windowInfo.first?[kCGWindowLayer as String] as? Int {
                return layer == 0
            }
            return true
        }

        return false
    }
}

struct MacButton: View {
    enum ButtonType {
        case close
        case minimize
    }

    let type: ButtonType
    let action: () -> Void

    @State private var isHoveringOnButton = false

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(type == .close ? Color(red: 255/255, green: 95/255, blue: 86/255) : Color(red: 255/255, green: 189/255, blue: 46/255))

                if isHoveringOnButton {
                    Image(systemName: type == .close ? "xmark" : "minus")
                        .font(.system(size: 6, weight: .black))
                        .foregroundColor(.black.opacity(0.6))
                }
            }
            .frame(width: 12, height: 12)
        }
        .buttonStyle(.plain)
        .onHover { hovering in isHoveringOnButton = hovering }
    }
}

// MARK: - Middle Click Handler

struct MiddleClickHandler: NSViewRepresentable {
    let onMiddleClick: () -> Void

    func makeNSView(context: Context) -> MiddleClickNSView {
        let view = MiddleClickNSView()
        view.onMiddleClick = onMiddleClick
        return view
    }

    func updateNSView(_ nsView: MiddleClickNSView, context: Context) {
        nsView.onMiddleClick = onMiddleClick
    }
}

class MiddleClickNSView: NSView {
    var onMiddleClick: (() -> Void)?
    private var localMonitor: Any?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        self.wantsLayer = true
        self.layer?.backgroundColor = NSColor.clear.cgColor

        localMonitor = NSEvent.addLocalMonitorForEvents(matching: [.otherMouseDown]) { [weak self] event in
            guard let self = self else { return event }

            if self.window != nil {
                let locationInWindow = event.locationInWindow
                let locationInView = self.convert(locationInWindow, from: nil)

                if self.bounds.contains(locationInView) && event.buttonNumber == 2 {
                    self.onMiddleClick?()
                }
            }
            return event
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        if let monitor = localMonitor {
            NSEvent.removeMonitor(monitor)
        }
    }
}

// MARK: - Notification Badge

struct NotificationBadge: View {
    let count: Int

    var body: some View {
        Text("\(count)")
            .font(.system(size: 10, weight: .bold))
            .foregroundColor(.white)
            .padding(.horizontal, count > 9 ? 6 : 5)
            .padding(.vertical, 3)
            .background(
                Capsule()
                    .fill(Color.red)
                    .shadow(color: .black.opacity(0.3), radius: 2, y: 1)
            )
            .overlay(
                Capsule()
                    .strokeBorder(Color.white.opacity(0.3), lineWidth: 1)
            )
    }
}

// MARK: - Quick Actions Menu

struct QuickActionsMenu: View {
    let windowID: CGWindowID
    let onSelect: (CGWindowID) -> Void
    let onMinimize: (CGWindowID) -> Void
    let onClose: (CGWindowID) -> Void
    var onMoveToMonitor: ((CGWindowID, NSScreen) -> Void)?

    private let availableScreens = NSScreen.screens

    var body: some View {
        Group {
            Button(action: { onSelect(windowID) }) {
                Label("Bring to Front", systemImage: "arrow.up.forward.app")
            }

            Divider()

            Button(action: { onMinimize(windowID) }) {
                Label("Minimize", systemImage: "minus.circle")
            }

            Button(action: { onClose(windowID) }) {
                Label("Close Window", systemImage: "xmark.circle")
            }

            if availableScreens.count > 1, let onMoveToMonitor = onMoveToMonitor {
                Divider()

                Menu {
                    ForEach(Array(availableScreens.enumerated()), id: \.offset) { index, screen in
                        Button(action: {
                            onMoveToMonitor(windowID, screen)
                        }) {
                            Label(screen.localizedName, systemImage: "display")
                        }
                    }
                } label: {
                    Label("Move to Monitor", systemImage: "rectangle.on.rectangle.angled")
                }
            }
        }
    }
}
