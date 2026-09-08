//
//  PinnedImagePanel.swift
//  Clippy
//
//  Keeps an image floating above every other window so it stays visible
//  while you work somewhere else — a reference screenshot, a design, a
//  number you keep re-reading. Capture it once, pin it, stop switching
//  windows to check.
//
//  Pins are deliberately parentless. Their entire point is to outlive the
//  thing that created them: the popover closes, the editor closes, the pin
//  stays. Attaching one as a child window would tie its lifetime and its
//  ordering to a window that is about to disappear.
//

import AppKit
import SwiftUI
import Combine

/// Borderless panels refuse key status by default, which would leave Esc
/// with nowhere to land. Each pin owns its own dismissal.
final class PinPanel: NSPanel {
    var onCancel: (() -> Void)?
    override var canBecomeKey: Bool { true }
    override func cancelOperation(_ sender: Any?) { onCancel?() }
}

@MainActor
final class PinnedImageController {
    static let shared = PinnedImageController()

    /// Every live pin. A set rather than a single slot because pinning is
    /// only useful if you can have several up at once — that's the whole
    /// workflow, comparing two things while working on a third.
    private var panels: [UUID: PinPanel] = [:]

    /// One monitor for every pin, installed with the first and removed with
    /// the last.
    private var clickThroughMonitor: Any?

    private init() {}

    var count: Int { panels.count }

    /// Hold ⌥ and pins stop taking the mouse, so you can work with whatever
    /// is underneath without unpinning.
    ///
    /// Deliberately a held modifier rather than a toggle. A pin that ignores
    /// the mouse also ignores the click that would turn the mode back off —
    /// its chrome doesn't even appear, because that needs a hover. Any
    /// toggle here is a trap; holding a key cannot be.
    private func installClickThroughMonitor() {
        guard clickThroughMonitor == nil else { return }
        clickThroughMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.flagsChanged]) { [weak self] event in
            guard let self else { return }
            let through = event.modifierFlags.contains(.option)
            for panel in self.panels.values {
                panel.ignoresMouseEvents = through
            }
        }
    }

    private func removeClickThroughMonitorIfIdle() {
        guard panels.isEmpty, let monitor = clickThroughMonitor else { return }
        NSEvent.removeMonitor(monitor)
        clickThroughMonitor = nil
    }

    @discardableResult
    func pin(image: NSImage, near anchor: NSPoint? = nil) -> UUID {
        let id = UUID()

        // Start at half size for Retina captures, clamped so a huge capture
        // doesn't cover the screen and a tiny one stays legible.
        let visible = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
        let natural = image.size
        let maxSide = min(visible.width * 0.5, visible.height * 0.5)
        let scale = min(1.0, maxSide / max(natural.width, natural.height))
        // Width carries the floor; height follows from the aspect ratio.
        // Flooring both independently and then recomputing height threw the
        // height floor away, which is how a tiny image ended up shorter than
        // its own `minSize`.
        var size = NSSize(width: max(120, natural.width * scale), height: 90)
        if natural.width > 0, natural.height > 0 {
            size.height = size.width * (natural.height / natural.width)
        } else {
            size.height = max(90, natural.height * scale)
        }

        let origin = placement(for: size, near: anchor, in: visible)

        let panel = PinPanel(
            contentRect: NSRect(origin: origin, size: size),
            styleMask: [.borderless, .nonactivatingPanel, .resizable],
            backing: .buffered,
            defer: false
        )
        panel.isFloatingPanel = true
        panel.level = .floating
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = true
        // Survive the app losing focus — a pin that vanishes when you click
        // into another app is the opposite of what it's for.
        panel.hidesOnDeactivate = false
        panel.isMovableByWindowBackground = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        // Resizing an image freely just distorts it; lock the proportions and
        // let any edge drag scale the whole thing.
        if natural.width > 0, natural.height > 0 {
            panel.aspectRatio = natural
        }
        // Derive the floor from the image's own proportions. A flat 120×90
        // floor fights `aspectRatio` on anything wider or taller than 4:3 —
        // a small wide image sized to 120×60 would be forced back up to 90
        // tall and come out stretched.
        let minWidth: CGFloat = 120
        panel.minSize = NSSize(
            width: minWidth,
            height: natural.width > 0 ? minWidth * (natural.height / natural.width) : 90
        )
        panel.onCancel = { [weak self] in self?.close(id) }

        let view = PinnedImageView(
            image: image,
            onClose: { [weak self] in self?.close(id) },
            onCopy: { [weak self] in self?.copy(image) }
        )
        // `contentView`, not `contentViewController`.
        //
        // Assigning a hosting *controller* lets it drive the window size, and
        // this view has no intrinsic size to give — it's all
        // `maxWidth: .infinity`. The panel ended up at some size of AppKit's
        // choosing with the image adrift in the middle of it. A hosting view
        // pinned to the frame we already computed does what it's told.
        let host = NSHostingView(rootView: view)
        host.frame = NSRect(origin: .zero, size: size)
        host.autoresizingMask = [.width, .height]
        panel.contentView = host
        panel.setFrame(NSRect(origin: origin, size: size), display: false)
        panel.orderFrontRegardless()

        panels[id] = panel
        installClickThroughMonitor()
        return id
    }

    func close(_ id: UUID) {
        guard let panel = panels.removeValue(forKey: id) else { return }
        panel.onCancel = nil
        panel.contentViewController = nil
        panel.orderOut(nil)
        removeClickThroughMonitorIfIdle()
    }

    func closeAll() {
        for id in panels.keys { close(id) }
    }

    private func copy(_ image: NSImage) {
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.writeObjects([image])
    }

    /// Where a new pin lands.
    ///
    /// Near the anchor when there is one, otherwise the top-right — and
    /// offset from any pin already there, so pinning twice doesn't stack one
    /// exactly on top of the other and look like nothing happened.
    private func placement(for size: NSSize, near anchor: NSPoint?, in visible: NSRect) -> NSPoint {
        var origin: NSPoint
        if let anchor {
            origin = NSPoint(x: anchor.x - size.width / 2, y: anchor.y - size.height - 12)
        } else {
            origin = NSPoint(x: visible.maxX - size.width - 24, y: visible.maxY - size.height - 24)
        }

        let step: CGFloat = 24
        var guard_ = 0
        while panels.values.contains(where: { abs($0.frame.origin.x - origin.x) < 4 && abs($0.frame.origin.y - origin.y) < 4 }),
              guard_ < 20 {
            origin.x -= step
            origin.y -= step
            guard_ += 1
        }

        origin.x = min(max(visible.minX, origin.x), visible.maxX - size.width)
        origin.y = min(max(visible.minY, origin.y), visible.maxY - size.height)
        return origin
    }
}
