//
//  QuickPreviewPanelView.swift
//  Clippy
//

import SwiftUI
import UniformTypeIdentifiers

struct QuickPreviewPanelView: View {
    let items: [ClipboardItemEntity]
    let onPaste: (ClipboardItemEntity) -> Void
    let onDismiss: () -> Void
    var onDragStarted: (() -> Void)? = nil

    @EnvironmentObject var settings: SettingsManager
    @State private var hoveredIndex: Int? = nil
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(spacing: 0) {
            headerView

            Divider()
                .opacity(0.3)

            ScrollView {
                LazyVStack(spacing: 3) {
                    ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                        QuickPreviewItemRow(
                            item: item,
                            index: index,
                            isHovered: hoveredIndex == index,
                            onPaste: { onPaste(item) }
                        )
                        .onHover { isHovered in
                            hoveredIndex = isHovered ? index : nil
                        }
                        .onDrag {
                            onDragStarted?()
                            if item.contentType == "text", let text = item.content {
                                return NSItemProvider(object: text as NSString)
                            } else if item.contentType == "image", let path = item.content,
                                      let url = imageURL(from: path) {
                                return NSItemProvider(object: url as NSURL)
                            }
                            return NSItemProvider()
                        }
                    }
                }
                .padding(.vertical, 6)
                .padding(.horizontal, 8)
            }
        }
        .frame(width: 360)
        .frame(maxHeight: 520)
        .fixedSize(horizontal: false, vertical: true)
        .background(panelBackground)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(borderGradient, lineWidth: 0.5)
        )
        .shadow(color: .black.opacity(colorScheme == .dark ? 0.5 : 0.15), radius: 20, y: 8)
        .shadow(color: .black.opacity(colorScheme == .dark ? 0.3 : 0.08), radius: 4, y: 2)
        .preferredColorScheme(appColorScheme)
    }

    // MARK: - Theme

    private var appColorScheme: ColorScheme? {
        switch settings.appTheme {
        case "light": return .light
        case "dark": return .dark
        default: return nil
        }
    }

    private var panelBackground: some View {
        ZStack {
            VisualEffectView(
                material: colorScheme == .dark ? .hudWindow : .sidebar,
                blendingMode: .behindWindow
            )
            // Solid tint overlay for better contrast in dark mode
            Color(colorScheme == .dark
                  ? NSColor(white: 0.12, alpha: 0.85)
                  : NSColor.black.withAlphaComponent(0.01))
        }
    }

    private var borderGradient: some ShapeStyle {
        LinearGradient(
            colors: colorScheme == .dark
                ? [.white.opacity(0.25), .white.opacity(0.08)]
                : [.white.opacity(0.8), .black.opacity(0.05)],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    // MARK: - Header

    private var headerView: some View {
        ZStack {
            // Drag layer covers the entire header area
            WindowDragView()

            HStack(spacing: 8) {
                Image(systemName: "list.clipboard")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.accentColor, .accentColor.opacity(0.7)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .allowsHitTesting(false)

                Text(L("Quick Preview", settings: settings))
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.primary)
                    .allowsHitTesting(false)

                Spacer()

                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 13))
                    .foregroundColor(.secondary.opacity(0.7))
                    .contentShape(SwiftUI.Rectangle().inset(by: -4))
                    .onTapGesture {
                        onDismiss()
                    }
            }
            .padding(.horizontal, 14)
        }
        .frame(height: 36)
    }

    private func imageURL(from path: String) -> URL? {
        guard let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else { return nil }
        return appSupport.appendingPathComponent("Clippy/Images").appendingPathComponent(path)
    }
}

// MARK: - Item Row

struct QuickPreviewItemRow: View {
    let item: ClipboardItemEntity
    let index: Int
    let isHovered: Bool
    let onPaste: () -> Void

    @EnvironmentObject var settings: SettingsManager
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(spacing: 10) {
            contentTypeIcon
                .frame(width: 28, height: 28)
                .background(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(iconBackground)
                )

            contentPreview

            Spacer(minLength: 4)

            VStack(alignment: .trailing, spacing: 2) {
                if let bundleId = item.sourceAppBundleIdentifier,
                   let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleId),
                   let icon = NSWorkspace.shared.icon(forFile: appURL.path) as NSImage? {
                    Image(nsImage: icon)
                        .resizable()
                        .frame(width: 14, height: 14)
                }

                Text(item.date ?? Date(), style: .time)
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(rowBackground)
        .contentShape(SwiftUI.Rectangle())
        .onTapGesture {
            onPaste()
        }
    }

    private var iconBackground: some ShapeStyle {
        colorScheme == .dark
            ? Color.white.opacity(0.12)
            : Color.black.opacity(0.05)
    }

    private var rowBackground: some View {
        Group {
            if isHovered {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(colorScheme == .dark
                          ? Color.white.opacity(0.14)
                          : Color.accentColor.opacity(0.08))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .strokeBorder(
                                colorScheme == .dark
                                    ? Color.white.opacity(0.18)
                                    : Color.accentColor.opacity(0.15),
                                lineWidth: 0.5
                            )
                    )
            } else {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(colorScheme == .dark
                          ? Color.white.opacity(0.05)
                          : Color.clear)
            }
        }
    }

    @ViewBuilder
    private var contentTypeIcon: some View {
        if item.isEncrypted {
            Image(systemName: "lock.fill")
                .font(.system(size: 12))
                .foregroundColor(.orange)
        } else if item.contentType == "image" {
            if let path = item.content, let image = loadImage(from: path) {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 28, height: 28)
                    .clipped()
                    .cornerRadius(6)
            } else {
                Image(systemName: "photo")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }
        } else if item.isCode {
            Image(systemName: "chevron.left.forwardslash.chevron.right")
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(colorScheme == .dark ? Color(nsColor: NSColor(red: 0.7, green: 0.5, blue: 1.0, alpha: 1.0)) : .purple)
        } else {
            Image(systemName: "doc.text")
                .font(.system(size: 12))
                .foregroundColor(colorScheme == .dark ? .primary.opacity(0.6) : .secondary)
        }
    }

    @ViewBuilder
    private var contentPreview: some View {
        if item.isEncrypted {
            Text(L("Encrypted Content", settings: settings))
                .font(.system(size: 11))
                .foregroundColor(colorScheme == .dark ? .primary.opacity(0.7) : .secondary)
                .lineLimit(2)
        } else if item.contentType == "text" {
            VStack(alignment: .leading, spacing: 2) {
                if let title = item.title, !title.isEmpty {
                    Text(title)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.accentColor)
                        .lineLimit(1)
                }
                Text(String((item.content ?? "").trimmingCharacters(in: .whitespacesAndNewlines).prefix(120)))
                    .lineLimit(2)
                    .font(.system(size: 11))
                    .foregroundColor(.primary)
            }
        } else if item.contentType == "image" {
            Text(L("Image", settings: settings))
                .font(.system(size: 11))
                .foregroundColor(.secondary)
        }
    }

    private func loadImage(from path: String) -> NSImage? {
        guard let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else { return nil }
        let imageURL = appSupport.appendingPathComponent("Clippy/Images").appendingPathComponent(path)
        return NSImage(contentsOf: imageURL)
    }
}

// MARK: - WindowDragView (enables window dragging from header)

struct WindowDragView: NSViewRepresentable {
    func makeNSView(context: Context) -> DraggableNSView {
        DraggableNSView()
    }

    func updateNSView(_ nsView: DraggableNSView, context: Context) {}
}

class DraggableNSView: NSView {
    override var mouseDownCanMoveWindow: Bool { true }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        return true
    }

    override func mouseDown(with event: NSEvent) {
        window?.performDrag(with: event)
    }
}

// MARK: - VisualEffectView

struct VisualEffectView: NSViewRepresentable {
    let material: NSVisualEffectView.Material
    let blendingMode: NSVisualEffectView.BlendingMode

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
    }
}
