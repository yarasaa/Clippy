//
//  FileConverterPanelController.swift
//  Clippy
//

import AppKit
import SwiftUI

class FileConverterPanelController {
    static let shared = FileConverterPanelController()

    private var window: NSWindow?
    private var viewModel: FileConverterViewModel?

    var isVisible: Bool {
        window?.isVisible ?? false
    }

    private init() {}

    func show() {
        if let window = window {
            if window.isMiniaturized { window.deminiaturize(nil) }
            NSApp.activate(ignoringOtherApps: true)
            window.makeKeyAndOrderFront(nil)
            window.orderFrontRegardless()
            return
        }

        let vm = FileConverterViewModel()
        self.viewModel = vm

        let converterView = FileConverterView(viewModel: vm)

        let hostingController = NSHostingController(rootView: converterView)
        let newWindow = NSWindow(contentViewController: hostingController)
        newWindow.title = "File Converter"
        newWindow.styleMask = [.titled, .closable, .miniaturizable, .resizable]
        newWindow.setContentSize(NSSize(width: 700, height: 500))
        newWindow.minSize = NSSize(width: 560, height: 400)
        newWindow.center()
        newWindow.level = .normal
        newWindow.isReleasedWhenClosed = false

        NotificationCenter.default.addObserver(
            forName: NSWindow.willCloseNotification,
            object: newWindow,
            queue: .main
        ) { [weak self] _ in
            self?.window = nil
            self?.viewModel = nil
        }

        self.window = newWindow
        NSApp.activate(ignoringOtherApps: true)
        newWindow.makeKeyAndOrderFront(nil)
        newWindow.orderFrontRegardless()
    }

    func setWindowLevel(floating: Bool) {
        window?.level = floating ? .floating : .normal
    }

    func hide() {
        window?.close()
    }
}
