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

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                if let appIcon = appIcon {
                    Image(nsImage: appIcon)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 24, height: 24)
                }
                Text(appName)
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)

                Spacer()

                if availableScreens.count > 1 {
                    HStack(spacing: 4) {
                        Image(systemName: "display")
                            .font(.system(size: 10))
                        Text("\(availableScreens.count)")
                            .font(.caption2)
                    }
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.blue.opacity(0.2))
                    .cornerRadius(4)
                }
            }
            .padding([.top, .horizontal])

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                        PreviewItemView(
                            image: item.image,
                            windowID: item.id,
                            title: item.title,
                            onClose: onWindowClose,
                            onMinimize: onWindowMinimize,
                            onSelect: onWindowSelect,
                            onMoveToMonitor: onMoveToMonitor
                        )
                        .id(item.id) // Stable identity based on windowID
                        .opacity(showItems ? 1 : 0)
                        .offset(y: showItems ? 0 : 20)
                        .animation(
                            .spring(response: 0.4, dampingFraction: 0.6).delay(Double(index) * 0.05),
                            value: showItems
                        )
                    }
                }
                .padding(.horizontal)
                .padding(.bottom)
            }
        }
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .fixedSize()
        .onAppear {
            showItems = true
        }
        .onDisappear {
            showItems = false
        }
    }
}
struct PreviewItemView: View {
    let image: NSImage
    let windowID: CGWindowID
    let title: String?
    let onClose: (CGWindowID) -> Void
    let onMinimize: (CGWindowID) -> Void
    let onSelect: (CGWindowID) -> Void
    var onMoveToMonitor: ((CGWindowID, NSScreen) -> Void)? = nil

    @State private var isHovering = false
    @State private var showMonitorMenu = false
    private let availableScreens = NSScreen.screens

    // Cache CGImage to prevent view recreation
    private let initialCGImage: CGImage?

    init(image: NSImage, windowID: CGWindowID, title: String?, onClose: @escaping (CGWindowID) -> Void, onMinimize: @escaping (CGWindowID) -> Void, onSelect: @escaping (CGWindowID) -> Void, onMoveToMonitor: ((CGWindowID, NSScreen) -> Void)? = nil) {
        self.image = image
        self.windowID = windowID
        self.title = title
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
        VStack(spacing: 6) {
            ZStack(alignment: .topTrailing) {
                // Notification badge overlay
                if let badgeCount = getNotificationBadge(), badgeCount > 0 {
                    NotificationBadge(count: badgeCount)
                        .offset(x: 10, y: -10)
                        .zIndex(10)
                }

                ZStack {
                    // Base preview content - isolated from hover state
                    if SettingsManager.shared.enableAutoRefresh, let cgImage = initialCGImage {
                        // Use live preview with ScreenCaptureKit
                        LivePreviewView(
                            windowID: windowID,
                            initialImage: cgImage,
                            maxWidth: previewSize.maxWidth,
                            maxHeight: previewSize.maxHeight
                        )
                        .id("live-preview-\(windowID)") // Stable identity to prevent view recreation
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    } else {
                        // Static image (fallback when live preview disabled)
                        Image(nsImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(maxWidth: previewSize.maxWidth, maxHeight: previewSize.maxHeight)
                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    }

                    // Overlays that depend on state - separate layer
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.accentColor.opacity(isHovering ? 0.8 : 0.0), lineWidth: 3)

                    if isActiveWindow() {
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(
                                LinearGradient(
                                    colors: [.blue.opacity(0.6), .cyan.opacity(0.4)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 2
                            )
                    }
                }
                .shadow(color: isActiveWindow() ? .blue.opacity(0.6) : .black.opacity(0.4), radius: isActiveWindow() ? 12 : 8, y: 4)
                .contentShape(Rectangle())
                .onTapGesture {
                    onSelect(windowID)
                }
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

                if isHovering {
                    HStack(spacing: 6) {
                        if onMoveToMonitor != nil {
                            Menu {
                                ForEach(Array(availableScreens.enumerated()), id: \.offset) { index, screen in
                                    Button(action: {
                                        onMoveToMonitor?(windowID, screen)
                                    }) {
                                        HStack {
                                            Image(systemName: "display")
                                            Text(screen.localizedName)
                                        }
                                    }
                                }
                            } label: {
                                ZStack {
                                    Circle()
                                        .fill(Color(red: 100/255, green: 200/255, blue: 255/255))
                                    Image(systemName: "display")
                                        .font(.system(size: 6, weight: .black))
                                        .foregroundColor(.white)
                                }
                                .frame(width: 12, height: 12)
                            }
                            .menuStyle(.borderlessButton)
                            .help("Move to another monitor")
                        }

                        MacButton(type: .minimize, action: { onMinimize(windowID) })
                        MacButton(type: .close, action: { onClose(windowID) })
                    }
                    .padding(5)
                    .transition(.opacity.animation(.easeInOut(duration: 0.2)))
                }
            }

            if SettingsManager.shared.showWindowTitles, let title = title, !title.isEmpty {
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                    .frame(maxWidth: previewSize.maxWidth - 20)
            }
        }
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.2)) { isHovering = hovering }
        }
        .onDrag {
            // Create drag item with window information
            let itemProvider = NSItemProvider()

            // Encode window ID as string
            itemProvider.registerDataRepresentation(forTypeIdentifier: "public.utf8-plain-text", visibility: .all) { completion in
                let data = "WindowID:\(self.windowID)".data(using: .utf8)
                completion(data, nil)
                return nil
            }

            return itemProvider
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
