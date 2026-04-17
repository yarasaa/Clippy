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
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        VStack(spacing: 0) {
            headerView

            Divider()
                .opacity(0.3)

            if items.isEmpty {
                emptyView
            } else {
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

            footerHints
        }
        .frame(width: 380)
        .frame(maxHeight: 560)
        .fixedSize(horizontal: false, vertical: true)
        .background(panelBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(borderGradient, lineWidth: 0.5)
        )
        .shadow(color: .black.opacity(scheme == .dark ? 0.5 : 0.15), radius: 24, y: 10)
        .shadow(color: Ember.Palette.amber.opacity(scheme == .dark ? 0.2 : 0.1), radius: 30, y: 0)
        .preferredColorScheme(appColorScheme)
    }

    // MARK: - Theme

    private var appColorScheme: ColorScheme? {
        switch settings.appTheme {
        case "light": return .light
        case "dark":  return .dark
        default:      return nil
        }
    }

    private var panelBackground: some View {
        ZStack {
            VisualEffectView(
                material: scheme == .dark ? .hudWindow : .sidebar,
                blendingMode: .behindWindow
            )
            Color(scheme == .dark
                  ? NSColor(red: 0.07, green: 0.09, blue: 0.16, alpha: 0.85)
                  : NSColor.white.withAlphaComponent(0.15))
        }
    }

    private var borderGradient: some ShapeStyle {
        LinearGradient(
            colors: scheme == .dark
                ? [Ember.Palette.amber.opacity(0.35), Color.white.opacity(0.08)]
                : [Ember.Palette.amberGlow.opacity(0.5), .black.opacity(0.05)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    // MARK: - Header

    private var headerView: some View {
        ZStack {
            WindowDragView()

            HStack(spacing: Ember.Space.sm) {
                ClippyMark(size: 16)
                    .allowsHitTesting(false)

                Text("Quick Preview")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundColor(Ember.primaryText(scheme))
                    .allowsHitTesting(false)

                Spacer()

                Button {
                    onDismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(Ember.secondaryText(scheme))
                        .frame(width: 18, height: 18)
                        .background(Circle().fill(Ember.Palette.smoke.opacity(0.2)))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 14)
        }
        .frame(height: 38)
    }

    private var emptyView: some View {
        VStack(spacing: Ember.Space.md) {
            Image(systemName: "tray")
                .font(.system(size: 36, weight: .light))
                .foregroundColor(Ember.Palette.amber.opacity(0.6))
            Text("Nothing yet")
                .font(Ember.Font.body.weight(.medium))
                .foregroundColor(Ember.primaryText(scheme))
            Text("Copy something to see it here.")
                .font(Ember.Font.caption)
                .foregroundColor(Ember.secondaryText(scheme))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 50)
    }

    private var footerHints: some View {
        HStack(spacing: Ember.Space.md) {
            hintPair(keys: "1-9", label: "paste")
            hintPair(keys: "↑↓", label: "navigate")
            hintPair(keys: "esc", label: "close")
            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(
            Rectangle()
                .fill(Ember.Palette.smoke.opacity(scheme == .dark ? 0.12 : 0.05))
        )
    }

    private func hintPair(keys: String, label: String) -> some View {
        HStack(spacing: 4) {
            Text(keys)
                .font(.system(size: 9, weight: .semibold, design: .monospaced))
                .foregroundColor(Ember.secondaryText(scheme))
                .padding(.horizontal, 4)
                .padding(.vertical, 1)
                .background(
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Ember.Palette.smoke.opacity(0.2))
                )
            Text(label)
                .font(.system(size: 10))
                .foregroundColor(Ember.tertiaryText(scheme))
        }
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
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        HStack(spacing: 10) {
            // Number badge — now prominent
            numberBadge

            contentTypeIcon
                .frame(width: 26, height: 26)
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
                        .opacity(0.85)
                }

                Text(item.date ?? Date(), style: .time)
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundColor(Ember.tertiaryText(scheme))
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(rowBackground)
        .contentShape(Rectangle())
        .onTapGesture { onPaste() }
    }

    private var numberBadge: some View {
        Text("\(index + 1)")
            .font(.system(size: 10, weight: .bold, design: .rounded))
            .foregroundColor(isHovered ? .white : Ember.secondaryText(scheme))
            .frame(width: 18, height: 18)
            .background(
                Circle()
                    .fill(
                        isHovered
                        ? AnyShapeStyle(
                            LinearGradient(
                                colors: [Ember.Palette.amber, Ember.Palette.amberDark],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        : AnyShapeStyle(Ember.Palette.smoke.opacity(0.2))
                    )
            )
            .animation(Ember.Motion.snap, value: isHovered)
    }

    private var iconBackground: some ShapeStyle {
        scheme == .dark
            ? Color.white.opacity(0.1)
            : Color.black.opacity(0.04)
    }

    private var rowBackground: some View {
        Group {
            if isHovered {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Ember.Palette.amber.opacity(scheme == .dark ? 0.15 : 0.09),
                                Ember.Palette.amberDark.opacity(scheme == .dark ? 0.08 : 0.04)
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .strokeBorder(Ember.Palette.amber.opacity(0.3), lineWidth: 0.5)
                    )
            } else {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color.clear)
            }
        }
    }

    @ViewBuilder
    private var contentTypeIcon: some View {
        if item.isEncrypted {
            Image(systemName: "lock.fill")
                .font(.system(size: 11))
                .foregroundColor(Ember.Palette.amber)
        } else if item.contentType == "image" {
            if let path = item.content, let image = loadImage(from: path) {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 26, height: 26)
                    .clipped()
                    .cornerRadius(6)
            } else {
                Image(systemName: "photo")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
        } else if item.isCode {
            Image(systemName: "chevron.left.forwardslash.chevron.right")
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(Ember.Palette.amber)
        } else {
            Image(systemName: "doc.text")
                .font(.system(size: 11))
                .foregroundColor(Ember.secondaryText(scheme))
        }
    }

    @ViewBuilder
    private var contentPreview: some View {
        if item.isEncrypted {
            Text("Encrypted")
                .font(.system(size: 11))
                .foregroundColor(Ember.secondaryText(scheme))
                .lineLimit(2)
        } else if item.contentType == "text" {
            VStack(alignment: .leading, spacing: 2) {
                if let title = item.title, !title.isEmpty {
                    Text(title)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(Ember.Palette.amber)
                        .lineLimit(1)
                }
                Text(String((item.content ?? "").trimmingCharacters(in: .whitespacesAndNewlines).prefix(120)))
                    .lineLimit(2)
                    .font(.system(size: 11))
                    .foregroundColor(Ember.primaryText(scheme))
            }
        } else if item.contentType == "image" {
            Text("Image")
                .font(.system(size: 11))
                .foregroundColor(Ember.secondaryText(scheme))
        }
    }

    private func loadImage(from path: String) -> NSImage? {
        guard let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else { return nil }
        let imageURL = appSupport.appendingPathComponent("Clippy/Images").appendingPathComponent(path)
        return NSImage(contentsOf: imageURL)
    }
}

// MARK: - WindowDragView

struct WindowDragView: NSViewRepresentable {
    func makeNSView(context: Context) -> DraggableNSView { DraggableNSView() }
    func updateNSView(_ nsView: DraggableNSView, context: Context) {}
}

class DraggableNSView: NSView {
    override var mouseDownCanMoveWindow: Bool { true }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
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
