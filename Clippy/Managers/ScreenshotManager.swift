//
//  ScreenshotManager.swift
//  Clippy
//
//  Created by Mehmet Akbaba on 6.10.2025.
//

@preconcurrency import ImageIO
import AppKit
import UniformTypeIdentifiers

class ScreenshotManager: NSObject {
    static let shared = ScreenshotManager()

    enum CaptureMode {
        case interactive
        case window
        case fullScreen
    }

    func captureArea(mode: CaptureMode, completion: @escaping (NSImage) -> Void) {
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("screenshot-\(UUID().uuidString).png")

        let task = Process()
        task.launchPath = "/usr/sbin/screencapture"

        var arguments: [String] = []
        switch mode {
        case .interactive:
            arguments.append("-i")
        case .window:
            arguments.append("-w")
        case .fullScreen:
            arguments.append("-C")
        }

        arguments.append(tempURL.path)
        task.arguments = arguments

        task.terminationHandler = { process in
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                defer {
                    try? FileManager.default.removeItem(at: tempURL)
                }

                guard process.terminationStatus == 0,
                      let image = NSImage(contentsOf: tempURL) else {
                    if process.terminationStatus != 0 {
                    } else {
                    }
                    return
                }
                completion(image)
            }
        }

        task.launch()
    }

    private func showSuccessNotification(url: URL) {
        let alert = NSAlert()
        alert.messageText = "Saved Successfully"
        alert.informativeText = "File: \(url.lastPathComponent)\n\nWould you like to show it in Finder?"
        alert.alertStyle = .informational
        alert.addButton(withTitle: "Show in Finder")
        alert.addButton(withTitle: "OK")

        if alert.runModal() == .alertFirstButtonReturn {
            NSWorkspace.shared.activateFileViewerSelecting([url])
        }
    }
}

extension CGImage {
    func toPixelBuffer(width: Int, height: Int) -> CVPixelBuffer? {
        let attrs = [
            kCVPixelBufferCGImageCompatibilityKey: kCFBooleanTrue,
            kCVPixelBufferCGBitmapContextCompatibilityKey: kCFBooleanTrue
        ] as CFDictionary

        var pixelBuffer: CVPixelBuffer?
        let status = CVPixelBufferCreate(
            kCFAllocatorDefault,
            width,
            height,
            kCVPixelFormatType_32ARGB,
            attrs,
            &pixelBuffer
        )

        guard status == kCVReturnSuccess, let buffer = pixelBuffer else {
            return nil
        }

        CVPixelBufferLockBaseAddress(buffer, [])
        defer { CVPixelBufferUnlockBaseAddress(buffer, []) }

        guard let context = CGContext(
            data: CVPixelBufferGetBaseAddress(buffer),
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: CVPixelBufferGetBytesPerRow(buffer),
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.noneSkipFirst.rawValue
        ) else {
            return nil
        }

        context.draw(self, in: CGRect(x: 0, y: 0, width: width, height: height))

        return buffer
    }
}
