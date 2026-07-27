//
//  ScreenTextGrabber.swift
//  Clippy
//
//  ⇧⌘2 → native crosshair region select → Vision OCR → text lands
//  straight on the pasteboard, ready for ⌘V. No editor, no preview
//  window — the whole point is: hotkey, drag, paste.
//
//  Bonus: if the selected region contains a QR / barcode, its payload
//  is copied instead (WiFi passwords, links, ticket codes off any
//  screen — video frames, Zoom calls, locked PDFs included).
//
//  The grabbed text is also inserted into history (source "Screen
//  Text") so it's searchable later. We tag the pasteboard write with
//  `PasteManager.pasteFromClippyType` so ClipboardMonitor's polling
//  skips it — otherwise the item would appear twice, attributed to
//  whatever app happened to be frontmost.
//

import AppKit
import SwiftUI

@MainActor
final class ScreenTextGrabber {
    static let shared = ScreenTextGrabber()

    /// Set once at startup by AppDelegate so grabbed text can be
    /// inserted into history with proper attribution.
    weak var clipboardMonitor: ClipboardMonitor?

    /// Guards against a second hotkey press while the system
    /// crosshair from the first one is still up.
    private var isCapturing = false

    private init() {}

    func grab() {
        guard SettingsManager.shared.enableScreenTextGrab else { return }
        guard !isCapturing else { return }
        isCapturing = true

        ScreenshotManager.shared.captureArea(mode: .interactive) { [weak self] image in
            Task { @MainActor in
                guard let self else { return }
                self.isCapturing = false
                self.process(image)
            }
        }

        // `screencapture -i` gives no callback when the user cancels
        // with esc (terminationHandler fires but with no image, and our
        // completion is never called). Re-arm after a generous window
        // so a cancelled capture doesn't lock the feature until
        // relaunch.
        Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(60))
            self?.isCapturing = false
        }
    }

    private func process(_ image: NSImage) {
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            GrabHUD.show("Capture failed")
            return
        }

        let appLanguage = SettingsManager.shared.appLanguage

        Task.detached(priority: .userInitiated) {
            // QR / barcode wins over OCR: when someone deliberately
            // frames a QR code, they want the payload, not the
            // pixel-art squares transliterated.
            if let payload = VisionOCR.detectBarcodePayload(in: cgImage) {
                await MainActor.run {
                    ScreenTextGrabber.shared.deliver(payload, kind: .qrCode)
                }
                return
            }

            let text = VisionOCR.recognizeText(in: cgImage, primaryHint: appLanguage)
            await MainActor.run {
                if text.isEmpty {
                    GrabHUD.show("No text found")
                } else {
                    ScreenTextGrabber.shared.deliver(text, kind: .text)
                }
            }
        }
    }

    private enum GrabKind { case text, qrCode }

    private func deliver(_ text: String, kind: GrabKind) {
        // 1. Pasteboard — ready for immediate ⌘V. The Clippy marker
        //    type stops ClipboardMonitor from re-capturing this write.
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(text, forType: .string)
        pb.addTypes([PasteManager.pasteFromClippyType], owner: nil)

        // 2. History — searchable later, correctly attributed.
        if let monitor = clipboardMonitor {
            let item = ClipboardItem(
                contentType: .text(text),
                date: Date(),
                isCode: monitor.isLikelyCode(text),
                sourceAppName: "Screen Text",
                sourceAppBundleIdentifier: "com.yarasa.Clippy.ScreenGrab"
            )
            monitor.addNewItem(item)
        }

        // 3. Feedback — success confirmation is opt-out; errors below
        //    always show (see `process`), so a failed grab is never silent.
        guard SettingsManager.shared.showScreenGrabHUD else { return }
        switch kind {
        case .qrCode:
            GrabHUD.show("✓ QR code copied")
        case .text:
            GrabHUD.show("✓ \(text.count) characters copied")
        }
    }
}

// MARK: - GrabHUD
//
// Tiny non-activating pill near the cursor: confirms the grab without
// stealing focus from wherever the user is about to paste. Fades out
// on its own.

@MainActor
private enum GrabHUD {
    private static var panel: NSPanel?
    private static var dismissTask: Task<Void, Never>?

    // Fixed geometry, measured from the string — no dependence on
    // NSHostingController.fittingSize, which returned a too-small value
    // before layout and collapsed the pill into a black dot.
    private static let font = NSFont.systemFont(ofSize: 12, weight: .semibold)
    private static let hPad: CGFloat = 14   // capsule horizontal padding
    private static let vPad: CGFloat = 7    // capsule vertical padding
    private static let margin: CGFloat = 12 // outer room for the shadow

    static func show(_ message: String) {
        dismissTask?.cancel()
        panel?.orderOut(nil)

        // Measure the exact text extent, then derive capsule + panel size.
        let textSize = (message as NSString).size(withAttributes: [.font: font])
        let capsuleW = ceil(textSize.width) + hPad * 2
        let capsuleH = ceil(textSize.height) + vPad * 2
        let panelW = capsuleW + margin * 2
        let panelH = capsuleH + margin * 2

        let label = NSHostingController(
            rootView: HUDLabel(text: message, capsuleWidth: capsuleW, capsuleHeight: capsuleH)
        )
        label.view.frame = NSRect(x: 0, y: 0, width: panelW, height: panelH)
        // NSHostingView paints an opaque background by default inside a
        // borderless panel — clear it so the margin isn't a black box.
        label.view.wantsLayer = true
        label.view.layer?.backgroundColor = NSColor.clear.cgColor

        let newPanel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: panelW, height: panelH),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        newPanel.level = .statusBar
        newPanel.backgroundColor = .clear
        newPanel.isOpaque = false
        // Window-level shadow draws a dark box over the transparent
        // panel — the capsule carries its own SwiftUI shadow instead.
        newPanel.hasShadow = false
        newPanel.ignoresMouseEvents = true
        newPanel.contentViewController = label

        // Just above the cursor so the eye is already there.
        let mouse = NSEvent.mouseLocation
        newPanel.setFrameOrigin(NSPoint(x: mouse.x - panelW / 2, y: mouse.y + 24))

        newPanel.alphaValue = 0
        newPanel.orderFront(nil)
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.15
            newPanel.animator().alphaValue = 1
        }

        panel = newPanel
        dismissTask = Task {
            try? await Task.sleep(for: .milliseconds(1400))
            guard !Task.isCancelled else { return }
            NSAnimationContext.runAnimationGroup({ ctx in
                ctx.duration = 0.3
                newPanel.animator().alphaValue = 0
            }, completionHandler: {
                newPanel.orderOut(nil)
                if panel === newPanel { panel = nil }
            })
        }
    }

    private struct HUDLabel: View {
        let text: String
        let capsuleWidth: CGFloat
        let capsuleHeight: CGFloat

        var body: some View {
            Text(text)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.white)
                .frame(width: capsuleWidth, height: capsuleHeight)
                .background(
                    Capsule().fill(
                        LinearGradient(
                            colors: [
                                Color(red: 0.16, green: 0.17, blue: 0.24),
                                Color(red: 0.09, green: 0.10, blue: 0.16)
                            ],
                            startPoint: .top, endPoint: .bottom
                        )
                    )
                )
                .overlay(
                    Capsule().strokeBorder(
                        Ember.Palette.amber.opacity(0.35), lineWidth: 0.8
                    )
                )
                .shadow(color: .black.opacity(0.35), radius: 8, y: 3)
                // Center the capsule in the (larger) panel so the
                // shadow has transparent room on every side.
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}
