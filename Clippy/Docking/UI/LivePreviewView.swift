import SwiftUI
import AppKit
import Combine

// ViewModel to manage the live preview stream lifecycle
@MainActor
class LivePreviewViewModel: ObservableObject {
    @Published var currentImage: CGImage {
        didSet {
            frameCount += 1
            // Reduced logging frequency from every 10 frames to every 50 frames
            if frameCount % 50 == 0 {
                print("🖼️ [LivePreview-\(windowID)] Frame update #\(frameCount)")
            }
        }
    }
    private var cancellable: AnyCancellable?
    let windowID: CGWindowID
    private var frameCount = 0

    init(windowID: CGWindowID, initialImage: CGImage) {
        self.windowID = windowID
        self.currentImage = initialImage
        print("🆕 [LivePreview-\(windowID)] ViewModel INIT")
    }

    func startStream() {
        guard SettingsManager.shared.enableAutoRefresh else {
            print("⚠️ [LivePreview-\(windowID)] Live preview DISABLED in settings")
            return
        }

        // Prevent multiple subscriptions
        guard cancellable == nil else {
            print("⚠️ [LivePreview-\(windowID)] Stream ALREADY RUNNING - ignoring startStream()")
            return
        }

        print("▶️ [LivePreview-\(windowID)] Starting stream...")
        if let publisher = LivePreviewService.shared.startLivePreview(for: windowID) {
            cancellable = publisher
                .receive(on: DispatchQueue.main)
                .sink { [weak self] newFrame in
                    guard let self = self else { return }
                    self.currentImage = newFrame
                }
            print("✅ [LivePreview-\(windowID)] Stream STARTED, subscription active")
        } else {
            print("❌ [LivePreview-\(windowID)] Failed to get publisher from service")
        }
    }

    func stopStream() {
        print("🛑 [LivePreview-\(windowID)] Stopping stream... (frames received: \(frameCount))")
        cancellable?.cancel()
        cancellable = nil

        Task { @MainActor in
            await LivePreviewService.shared.stopLivePreview(for: windowID)
            print("✅ [LivePreview-\(windowID)] Stream STOPPED")
        }
    }

    deinit {
        cancellable?.cancel()
        cancellable = nil
        print("🗑️ [LivePreview-\(windowID)] ViewModel DEINIT (frames: \(frameCount))")
    }
}

struct LivePreviewView: View {
    let windowID: CGWindowID
    let maxWidth: CGFloat
    let maxHeight: CGFloat

    @StateObject private var viewModel: LivePreviewViewModel

    init(windowID: CGWindowID, initialImage: CGImage, maxWidth: CGFloat, maxHeight: CGFloat) {
        self.windowID = windowID
        self.maxWidth = maxWidth
        self.maxHeight = maxHeight
        _viewModel = StateObject(wrappedValue: LivePreviewViewModel(windowID: windowID, initialImage: initialImage))
        print("🏗️ [LivePreviewView-\(windowID)] View INIT")
    }

    var body: some View {
        Image(decorative: viewModel.currentImage, scale: 1.0)
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(maxWidth: maxWidth, maxHeight: maxHeight)
            .drawingGroup() // Use GPU rendering for smoother, animation-free updates
            .task {
                print("📌 [LivePreviewView-\(windowID)] .task modifier triggered")
                viewModel.startStream()
            }
            .onDisappear {
                print("👋 [LivePreviewView-\(windowID)] onDisappear triggered")
                viewModel.stopStream()
            }
    }
}
