//
//  LiveTextImageView.swift
//  Clippy
//
//  SwiftUI wrapper around `NSImageView` + VisionKit's
//  `ImageAnalysisOverlayView`. Gives image screenshots the same
//  Live-Text selection that macOS Photos has: hover, drag-select,
//  Cmd+C to copy any text inside the image. URLs and phone numbers
//  auto-link.
//
//  Sizing is delegated to SwiftUI — the wrapper does NOT publish an
//  intrinsicContentSize. Callers should constrain it with
//  `.aspectRatio(image.size, contentMode: .fit) + .frame(maxWidth:
//  .infinity, maxHeight: .infinity)`. This avoids the "container
//  grows to fill the universe" failure mode that earlier attempts
//  at this hit.
//

import AppKit
import SwiftUI
import VisionKit

struct LiveTextImageView: NSViewRepresentable {
    let image: NSImage

    func makeNSView(context: Context) -> LiveTextContainerView {
        let view = LiveTextContainerView()
        view.update(with: image)
        return view
    }

    func updateNSView(_ nsView: LiveTextContainerView, context: Context) {
        nsView.update(with: image)
    }

    /// Accept whatever size SwiftUI proposes instead of imposing the
    /// image's native pixel size. NSImageView's `intrinsicContentSize`
    /// is the image's native dimensions, which was making large
    /// screenshots overflow the detail view (the user had to enlarge
    /// the window to see the whole image). Returning the proposal lets
    /// the outer `.aspectRatio(.fit)` + `.frame` fully control sizing,
    /// while `imageScaling = .scaleProportionallyDown` fits the pixels.
    func sizeThatFits(_ proposal: ProposedViewSize,
                      nsView: LiveTextContainerView,
                      context: Context) -> CGSize? {
        guard let width = proposal.width, let height = proposal.height,
              width.isFinite, height.isFinite else {
            return nil
        }
        return CGSize(width: width, height: height)
    }
}

/// AppKit container that pairs an NSImageView with an
/// ImageAnalysisOverlayView. Centralizes analysis lifecycle so we
/// don't re-analyze on every SwiftUI body re-evaluation.
final class LiveTextContainerView: NSView {
    private let imageView: NSImageView = {
        let v = NSImageView()
        // `.scaleProportionallyDown` lets the image shrink to fit
        // the container without ever scaling up past 1:1. Combined
        // with SwiftUI's `.aspectRatio(.fit)` outside, the image
        // always appears at the largest size that fits.
        v.imageScaling = .scaleProportionallyDown
        v.imageAlignment = .alignCenter
        v.translatesAutoresizingMaskIntoConstraints = false
        return v
    }()

    private let overlay: ImageAnalysisOverlayView = {
        let v = ImageAnalysisOverlayView()
        // Text selection is the only interaction we want — leaving
        // `.dataDetectors` enabled would also turn detected dates /
        // phones into popovers that conflict with Clippy's own
        // badges on the card view.
        v.preferredInteractionTypes = .textSelection
        v.translatesAutoresizingMaskIntoConstraints = false
        return v
    }()

    private let analyzer = ImageAnalyzer()
    private weak var currentImage: NSImage?
    private var analysisTask: Task<Void, Never>?

    /// Never impose a size on the SwiftUI layout — the container
    /// takes whatever frame it's given and scales the image to fit.
    override var intrinsicContentSize: NSSize {
        NSSize(width: NSView.noIntrinsicMetric, height: NSView.noIntrinsicMetric)
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupViews()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupViews()
    }

    private func setupViews() {
        // Let the image view shrink/stretch to the container instead of
        // pushing the container out to the image's native size.
        imageView.setContentHuggingPriority(.defaultLow, for: .horizontal)
        imageView.setContentHuggingPriority(.defaultLow, for: .vertical)
        imageView.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        imageView.setContentCompressionResistancePriority(.defaultLow, for: .vertical)

        addSubview(imageView)
        addSubview(overlay)
        NSLayoutConstraint.activate([
            imageView.topAnchor.constraint(equalTo: topAnchor),
            imageView.bottomAnchor.constraint(equalTo: bottomAnchor),
            imageView.leadingAnchor.constraint(equalTo: leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: trailingAnchor),
            overlay.topAnchor.constraint(equalTo: imageView.topAnchor),
            overlay.bottomAnchor.constraint(equalTo: imageView.bottomAnchor),
            overlay.leadingAnchor.constraint(equalTo: imageView.leadingAnchor),
            overlay.trailingAnchor.constraint(equalTo: imageView.trailingAnchor),
        ])
        overlay.trackingImageView = imageView
    }

    /// Set the image and (re-)analyze it for Live Text. Skips
    /// re-analysis when the same image instance is set twice in a
    /// row — analyzer.analyze() is the expensive part.
    func update(with image: NSImage) {
        if currentImage === image { return }
        currentImage = image
        imageView.image = image
        overlay.analysis = nil

        analysisTask?.cancel()
        analysisTask = Task { [weak self] in
            guard let self else { return }
            let config = ImageAnalyzer.Configuration([.text, .machineReadableCode])
            do {
                let analysis = try await self.analyzer.analyze(
                    image, orientation: .up, configuration: config
                )
                if Task.isCancelled { return }
                // Hop one runloop tick before assigning `overlay.analysis`.
                // ImageAnalysisOverlayView triggers a layout pass when
                // analysis is set, which sometimes lands inside our
                // own layout cycle and produces the
                // "_NSDetectedLayoutRecursion" warning. Deferring breaks
                // the chain harmlessly — the overlay still appears as
                // soon as VisionKit finishes laying out.
                await MainActor.run {
                    DispatchQueue.main.async { [weak self] in
                        self?.overlay.analysis = analysis
                    }
                }
            } catch {
                // Analysis can fail on tiny / all-black / unsupported
                // images — leave the image visible without overlay.
            }
        }
    }
}
