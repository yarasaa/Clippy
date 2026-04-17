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
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header

            Divider()
                .opacity(0.25)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 14) {
                    ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                        PreviewItemView(
                            image: item.image,
                            windowID: item.id,
                            title: item.title,
                            index: index,
                            onClose: onWindowClose,
                            onMinimize: onWindowMinimize,
                            onSelect: onWindowSelect,
                            onMoveToMonitor: onMoveToMonitor
                        )
                        .id(item.id)
                        .opacity(showItems ? 1 : 0)
                        .offset(y: showItems ? 0 : 16)
                        .animation(
                            .spring(response: 0.42, dampingFraction: 0.78).delay(Double(index) * 0.04),
                            value: showItems
                        )
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 16)
            }

            if SettingsManager.shared.enableDockPreviewKeyboardShortcuts {
                Divider().opacity(0.25)
                keyboardHintsFooter
            }
        }
        .background(panelBackground)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(borderGradient, lineWidth: 0.6)
        )
        .shadow(color: .black.opacity(scheme == .dark ? 0.5 : 0.18), radius: 28, y: 14)
        .shadow(color: Ember.Palette.amber.opacity(scheme == .dark ? 0.1 : 0.04), radius: 40, y: 0)
        .fixedSize()
        .onAppear { showItems = true }
        .onDisappear { showItems = false }
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 12) {
            ZStack {
                if let appIcon = appIcon {
                    Image(nsImage: appIcon)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 30, height: 30)
                        .shadow(color: .black.opacity(0.15), radius: 3, y: 1)
                }
            }

            VStack(alignment: .leading, spacing: 1) {
                Text(appName)
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundColor(.primary)

                Text(windowCountLabel)
                    .font(.system(size: 11, design: .serif))
                    .italic()
                    .foregroundColor(.secondary)
            }

            Spacer()

            if availableScreens.count > 1 {
                monitorChip
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private var windowCountLabel: String {
        let n = items.count
        return "\(n) window\(n == 1 ? "" : "s") open"
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
        HStack(spacing: 14) {
            kbdHint(keys: "1-9", label: "open")
            kbdHint(keys: "⏎", label: "select")
            kbdHint(keys: "⌘W", label: "close")
            kbdHint(keys: "esc", label: "dismiss")
            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 7)
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

    private var panelBackground: some View {
        ZStack {
            // Use NSVisualEffectView for real vibrancy / material
            Rectangle()
                .fill(scheme == .dark
                      ? Color(red: 0.07, green: 0.09, blue: 0.16).opacity(0.72)
                      : Color.white.opacity(0.68))
                .background(.ultraThinMaterial)
        }
    }

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
struct PreviewItemView: View {
    let image: NSImage
    let windowID: CGWindowID
    let title: String?
    let index: Int
    let onClose: (CGWindowID) -> Void
    let onMinimize: (CGWindowID) -> Void
    let onSelect: (CGWindowID) -> Void
    var onMoveToMonitor: ((CGWindowID, NSScreen) -> Void)? = nil

    @State private var isHovering = false
    @State private var showMonitorMenu = false
    @Environment(\.colorScheme) private var scheme
    private let availableScreens = NSScreen.screens

    // Cache CGImage to prevent view recreation
    private let initialCGImage: CGImage?

    init(image: NSImage, windowID: CGWindowID, title: String?, index: Int = 0, onClose: @escaping (CGWindowID) -> Void, onMinimize: @escaping (CGWindowID) -> Void, onSelect: @escaping (CGWindowID) -> Void, onMoveToMonitor: ((CGWindowID, NSScreen) -> Void)? = nil) {
        self.image = image
        self.windowID = windowID
        self.title = title
        self.index = index
        self.onClose = onClose
        self.onMinimize = onMinimize
        self.onSelect = onSelect
        self.onMoveToMonitor = onMoveToMonitor
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
        VStack(spacing: 0) {
            if SettingsManager.shared.showWindowTitles {
                inlineTitleBar
            }
            previewBody
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
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(isActiveWindow() ? Ember.Palette.amber : .primary.opacity(0.85))
                .lineLimit(1)
                .truncationMode(.middle)

            Spacer(minLength: 4)

            if isHovering {
                HStack(spacing: 4) {
                    if onMoveToMonitor != nil, availableScreens.count > 1 {
                        Menu {
                            ForEach(Array(availableScreens.enumerated()), id: \.offset) { _, screen in
                                Button {
                                    onMoveToMonitor?(windowID, screen)
                                } label: {
                                    HStack {
                                        Image(systemName: "display")
                                        Text(screen.localizedName)
                                    }
                                }
                            }
                        } label: {
                            titleIconButton(systemName: "display")
                        }
                        .menuStyle(.borderlessButton)
                        .menuIndicator(.hidden)
                        .fixedSize()
                        .help("Move to another monitor")
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
        .frame(height: 26)
        .background(titleBarBackground)
    }

    private func titleIconButton(systemName: String, destructive: Bool = false) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 4)
                .fill(destructive ? Ember.Palette.rust.opacity(0.15) : Ember.Palette.smoke.opacity(0.15))
            Image(systemName: systemName)
                .font(.system(size: 8, weight: .bold))
                .foregroundColor(destructive ? Ember.Palette.rust : .secondary)
        }
        .frame(width: 18, height: 18)
    }

    private var titleBarBackground: some View {
        ZStack {
            Rectangle().fill(.ultraThinMaterial)
            Rectangle()
                .fill(
                    isActiveWindow()
                    ? Ember.Palette.amber.opacity(scheme == .dark ? 0.18 : 0.1)
                    : Color.clear
                )
        }
    }

    private var displayTitle: String {
        if let t = title, !t.isEmpty { return t }
        return "Window \(windowID)"
    }

    // MARK: - Preview Body (actual thumbnail)

    @ViewBuilder
    private var previewBody: some View {
        if SettingsManager.shared.enableAutoRefresh, let cgImage = initialCGImage {
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
        if SettingsManager.shared.enableDockPreviewKeyboardShortcuts, index < 9 {
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
