import Foundation
import ScreenCaptureKit
import AppKit
import Combine

@MainActor
final class LivePreviewService: NSObject {
    static let shared = LivePreviewService()

    // MARK: - Properties

    private var activeStreams: [CGWindowID: SCStream] = [:]
    private var streamOutputs: [CGWindowID: StreamOutput] = [:]
    private var availableContent: SCShareableContent?

    // Publishers for live frames
    private var frameSubjects: [CGWindowID: PassthroughSubject<CGImage, Never>] = [:]

    // Dedicated background queue for SCStream sample delivery. The
    // per-frame CVPixelBuffer → CGImage conversion (Core Image) is the
    // single most expensive step; running it here keeps it OFF the main
    // thread. Previously the sample handler ran on `.main`, so at 5 FPS ×
    // N windows the UI paid for every conversion — the real cause of the
    // hitch when a multi-window preview opened.
    private static let sampleQueue = DispatchQueue(
        label: "com.yarasa.Clippy.livePreview.samples",
        qos: .userInitiated
    )

    private override init() {
        super.init()
        Task {
            await refreshAvailableContent()
        }
    }

    deinit {
        Task { @MainActor in
            await stopAllStreams()
        }
    }

    // MARK: - Content Discovery

    func refreshAvailableContent() async {
        do {
            availableContent = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
        } catch {
            // An empty `catch` here meant a missing Screen Recording
            // permission — by far the most common failure — left
            // `availableContent` nil forever with nothing recorded anywhere:
            // live preview just never worked and there was no way to find out
            // why. Clearing it keeps callers honest (they already treat nil
            // as "no live preview"), and the log line makes the cause
            // visible in Console instead of vanishing.
            availableContent = nil
            NSLog("[Clippy] SCShareableContent failed — Screen Recording permission is the usual cause: \(error.localizedDescription)")
        }
    }

    // MARK: - Stream Management

    func startLivePreview(for windowID: CGWindowID) -> AnyPublisher<CGImage, Never>? {
        // Check if already streaming
        if let existing = frameSubjects[windowID] {
            return existing.eraseToAnyPublisher()
        }

        // Find the window in available content
        guard let window = availableContent?.windows.first(where: { $0.windowID == windowID }) else {
            return nil
        }

        // Create filter for this specific window
        let filter = SCContentFilter(desktopIndependentWindow: window)

        // Configure stream - AGGRESSIVE CPU optimization
        let config = SCStreamConfiguration()
        config.width = 800   // Reduced from 1200 for ~40% less pixels to process
        config.height = 533  // Maintain 3:2 aspect ratio
        config.minimumFrameInterval = CMTime(value: 1, timescale: 5) // 5 FPS (reduced from 10 for ~50% CPU savings)
        config.queueDepth = 2  // Reduced from 3 to 2 for ~10MB RAM savings per window
        config.showsCursor = false
        config.scalesToFit = true
        config.backgroundColor = .clear

        // Create output handler
        let output = StreamOutput(windowID: windowID)
        streamOutputs[windowID] = output

        // Create subject for this window
        let subject = PassthroughSubject<CGImage, Never>()
        frameSubjects[windowID] = subject
        output.framePublisher = subject

        // Create stream
        do {
            let stream = SCStream(filter: filter, configuration: config, delegate: self)

            Task {
                do {
                    try stream.addStreamOutput(output, type: .screen, sampleHandlerQueue: Self.sampleQueue)
                    try await stream.startCapture()

                    activeStreams[windowID] = stream
                } catch {
                    frameSubjects.removeValue(forKey: windowID)
                    streamOutputs.removeValue(forKey: windowID)
                }
            }

            return subject.eraseToAnyPublisher()
        }
    }

    func stopLivePreview(for windowID: CGWindowID) async {
        guard let stream = activeStreams[windowID] else { return }

        // Drop our references whatever `stopCapture` does.
        //
        // The three `removeValue` calls used to sit after the throwing call
        // inside `do`, so a failed stop skipped all of them and left the
        // stream in `activeStreams` forever — a leaked ScreenCaptureKit
        // stream per failure, and `startLivePreview` would keep handing back
        // the dead subject for that window because it looked still active.
        defer {
            activeStreams.removeValue(forKey: windowID)
            streamOutputs.removeValue(forKey: windowID)
            frameSubjects.removeValue(forKey: windowID)
        }

        do {
            try await stream.stopCapture()
        } catch {
            NSLog("[Clippy] stopCapture failed for window \(windowID): \(error.localizedDescription)")
        }
    }

    func stopAllStreams() async {
        let windowIDs = Array(activeStreams.keys)
        for windowID in windowIDs {
            await stopLivePreview(for: windowID)
        }
    }

    // MARK: - Helper

    func isStreaming(windowID: CGWindowID) -> Bool {
        return activeStreams[windowID] != nil
    }
}

// MARK: - SCStreamDelegate

extension LivePreviewService: SCStreamDelegate {
    nonisolated func stream(_ stream: SCStream, didStopWithError error: Error) {

        Task { @MainActor in
            // Find and remove the failed stream
            if let windowID = activeStreams.first(where: { $0.value === stream })?.key {
                await stopLivePreview(for: windowID)
            }
        }
    }
}

// MARK: - StreamOutput

@MainActor
private class StreamOutput: NSObject, SCStreamOutput {
    let windowID: CGWindowID
    weak var framePublisher: PassthroughSubject<CGImage, Never>?

    // Reuse CIContext across frames - MAJOR CPU optimization!
    // Creating CIContext every frame costs ~5-10% CPU per window
    private let ciContext = CIContext(options: [.useSoftwareRenderer: false])

    init(windowID: CGWindowID) {
        self.windowID = windowID
        super.init()
    }

    nonisolated func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of type: SCStreamOutputType) {
        // Extract CGImage from sample buffer
        guard type == .screen,
              let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            return
        }

        // Create CGImage from CVPixelBuffer using REUSED context
        let ciImage = CIImage(cvPixelBuffer: imageBuffer)

        guard let cgImage = self.ciContext.createCGImage(ciImage, from: ciImage.extent) else {
            return
        }

        // Publish to main thread
        Task { @MainActor in
            self.framePublisher?.send(cgImage)
        }
    }
}
