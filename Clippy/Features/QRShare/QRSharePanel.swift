//
//  QRSharePanel.swift
//  Clippy
//
//  Small floating panel that shows a QR code for a clipboard item so
//  the user can scan it with their phone camera. "Send to Phone"
//  without any account, server, or sync — the QR carries the payload.
//

import AppKit
import SwiftUI

/// Borderless panels refuse key status by default, and this one needs it:
/// dropping the titlebar also dropped ⌘W, so Esc takes over as the keyboard
/// way out. The card's ✕ still works for the mouse.
private final class QRPanel: NSPanel {
    var onCancel: (() -> Void)?
    override var canBecomeKey: Bool { true }
    override func cancelOperation(_ sender: Any?) { onCancel?() }
}

@MainActor
final class QRSharePanelController {
    static let shared = QRSharePanelController()

    private var panel: NSPanel?
    private init() {}

    /// Present a QR for a URL. The card layer only offers this for
    /// links (plain text is pointed at AirDrop / Universal Clipboard
    /// instead), so the copy here is URL-specific.
    func show(text: String, near anchorWindow: NSWindow?) {
        close()

        guard let qr = QRCodeGenerator.image(for: text) else { return }

        let view = QRShareView(
            qrImage: qr,
            caption: "Scan to open on your phone",
            subcaption: text,
            onClose: { [weak self] in self?.close() }
        )

        let host = NSHostingController(rootView: view)
        let newPanel = QRPanel(contentViewController: host)
        newPanel.onCancel = { [weak self] in self?.close() }
        // Borderless, like every other floating panel in the app.
        //
        // This used to be `[.titled, .closable, .fullSizeContentView]` with a
        // hidden title and transparent titlebar, which still drew the three
        // window buttons — and since the card is inset inside a clear window,
        // they ended up hovering in empty space above it rather than sitting
        // on any chrome. The card already carries its own ✕, so the buttons
        // were a second, worse-looking way to do the same thing.
        newPanel.styleMask = [.borderless, .nonactivatingPanel]
        newPanel.isMovableByWindowBackground = true
        newPanel.level = .floating
        newPanel.backgroundColor = .clear
        newPanel.isOpaque = false
        newPanel.hasShadow = true

        if let anchor = anchorWindow {
            anchor.addChildWindowSafely(newPanel, ordered: .above)
        }
        newPanel.center()
        newPanel.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        self.panel = newPanel
    }

    func close() {
        // Detach before ordering out: `orderOut` alone leaves the panel
        // attached to its anchor, so the parent keeps it alive as a child
        // and every reopen grows the graph by one more stale edge.
        panel?.detachFromParentWindow()
        panel?.orderOut(nil)
        panel = nil
    }
}

private struct QRShareView: View {
    let qrImage: NSImage
    let caption: String
    let subcaption: String
    let onClose: () -> Void

    @ObservedObject private var settings = SettingsManager.shared
    @Environment(\.colorScheme) private var scheme

    /// Clippy's own theme setting, not the system's.
    ///
    /// Every other panel already does this; this view was the one that
    /// didn't, so with the app set to dark on a light Mac the QR card came
    /// up cream while the rest of Clippy stayed navy.
    private var appColorScheme: ColorScheme? {
        switch settings.appTheme {
        case "light": return .light
        case "dark":  return .dark
        default:      return nil
        }
    }

    var body: some View {
        VStack(spacing: Ember.Space.md) {
            HStack {
                Image(systemName: "qrcode")
                    .foregroundColor(Ember.Palette.amber)
                Text("Send to Phone")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                Spacer()
                Button(action: onClose) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(Ember.tertiaryText(scheme))
                }
                .buttonStyle(.plain)
            }

            // QR always on a white plate — scanners want maximum
            // contrast regardless of the app's light/dark theme.
            Image(nsImage: qrImage)
                .interpolation(.none)
                .resizable()
                .frame(width: 240, height: 240)
                .padding(16)
                .background(RoundedRectangle(cornerRadius: 14).fill(.white))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .strokeBorder(Color.black.opacity(0.06), lineWidth: 1)
                )

            VStack(spacing: 3) {
                Text(caption)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(Ember.primaryText(scheme))
                Text(subcaption)
                    .font(.system(size: 11))
                    .foregroundColor(Ember.tertiaryText(scheme))
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
        }
        .padding(Ember.Space.lg)
        .frame(width: 300)
        .background(Ember.surface(scheme))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(Color.white.opacity(scheme == .dark ? 0.08 : 0.4), lineWidth: 0.5)
        )
        .preferredColorScheme(appColorScheme)
    }
}
