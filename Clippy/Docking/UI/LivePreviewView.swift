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
            }
        }
    }
    private var cancellable: AnyCancellable?
    let windowID: CGWindowID
    private var frameCount = 0

    init(windowID: CGWindowID, initialImage: CGImage) {
        self.windowID = windowID
        self.currentImage = initialImage
    }

    func startStream() {
        guard SettingsManager.shared.enableAutoRefresh else {
            return
        }

        // Prevent multiple subscriptions
        guard cancellable == nil else {
            return
        }

        if let publisher = LivePreviewService.shared.startLivePreview(for: windowID) {
            cancellable = publisher
                .receive(on: DispatchQueue.main)
                .sink { [weak self] newFrame in
                    guard let self = self else { return }
                    self.currentImage = newFrame
                }
        } else {
        }
    }

    func stopStream() {
        cancellable?.cancel()
        cancellable = nil

        Task { @MainActor in
            await LivePreviewService.shared.stopLivePreview(for: windowID)
        }
    }

    deinit {
        cancellable?.cancel()
        cancellable = nil
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
    }

    var body: some View {
        Image(decorative: viewModel.currentImage, scale: 1.0)
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(maxWidth: maxWidth, maxHeight: maxHeight)
            .drawingGroup() // Use GPU rendering for smoother, animation-free updates
            .task {
                viewModel.startStream()
            }
            .onDisappear {
                viewModel.stopStream()
            }
    }
}
