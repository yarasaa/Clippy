//
//  CaptureCountdown.swift
//  Clippy
//
//  The visible half of a delayed capture.
//
//  Delayed capture worked before this: you picked the menu item and three
//  seconds later the editor opened. Nothing in between said anything, so
//  the three seconds you were meant to spend arranging the screen were
//  spent wondering whether the click had registered. A countdown is not
//  decoration here — it is the only thing that tells you the feature is
//  running, and the only way to call it off.
//

import AppKit
import SwiftUI

@MainActor
final class CaptureCountdown {
    static let shared = CaptureCountdown()

    private var panel: NSPanel?
    private var timer: Timer?
    private var escapeMonitor: Any?
    private var onFinish: (() -> Void)?
    private var remaining = 0

    private init() {}

    /// Count `seconds` down, then call `then`. Escape cancels, and `then`
    /// never runs.
    func start(seconds: Int, then: @escaping () -> Void) {
        cancel()   // a second invocation replaces the first rather than racing it

        remaining = seconds
        onFinish = then
        present()

        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.tick() }
        }

        // The panel is non-activating, so it never becomes key and never
        // receives keyDown. A local monitor is how Escape reaches us.
        escapeMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard event.keyCode == 53 else { return event }
            Task { @MainActor in self?.cancel() }
            return nil
        }
    }

    func cancel() {
        timer?.invalidate()
        timer = nil
        if let escapeMonitor {
            NSEvent.removeMonitor(escapeMonitor)
            self.escapeMonitor = nil
        }
        panel?.orderOut(nil)
        panel = nil
        onFinish = nil
    }

    private func tick() {
        remaining -= 1
        if remaining > 0 {
            present()
            return
        }

        let finish = onFinish
        cancel()

        // Take the panel off screen and let a runloop turn or two pass
        // before capturing. `orderOut` doesn't wait for the window server
        // to recomposite, and a countdown baked into the middle of the
        // screenshot would be a poor start for a screenshot tool.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
            finish?()
        }
    }

    private func present() {
        let hosting = NSHostingView(rootView: CountdownView(remaining: remaining))
        hosting.frame = NSRect(x: 0, y: 0, width: 168, height: 96)

        if panel == nil {
            let newPanel = NSPanel(
                contentRect: hosting.frame,
                styleMask: [.borderless, .nonactivatingPanel],
                backing: .buffered,
                defer: false
            )
            newPanel.isFloatingPanel = true
            newPanel.level = .popUpMenu
            newPanel.backgroundColor = .clear
            newPanel.isOpaque = false
            newPanel.hasShadow = false
            newPanel.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
            panel = newPanel
        }

        guard let panel else { return }
        panel.contentView = hosting

        if let screen = NSScreen.main {
            let frame = screen.visibleFrame
            panel.setFrameOrigin(NSPoint(
                x: frame.midX - hosting.frame.width / 2,
                y: frame.maxY - hosting.frame.height - 80
            ))
        }
        panel.orderFrontRegardless()
    }
}

private struct CountdownView: View {
    let remaining: Int

    var body: some View {
        VStack(spacing: 6) {
            Text("\(remaining)")
                .font(.system(size: 40, weight: .semibold, design: .rounded))
                .foregroundColor(.white)
                .monospacedDigit()
            Text("esc to cancel")
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(.white.opacity(0.55))
        }
        .frame(width: 168, height: 96)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(.black.opacity(0.72))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Ember.Palette.amber.opacity(0.35), lineWidth: 1)
        )
    }
}
