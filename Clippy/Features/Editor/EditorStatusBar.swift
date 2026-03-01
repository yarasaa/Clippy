//
//  EditorStatusBar.swift
//  Clippy
//

import SwiftUI

struct EditorStatusBar: View {
    var imageSize: CGSize
    @Binding var zoomScale: CGFloat
    @Binding var lastZoomScale: CGFloat
    var selectedTool: DrawingTool
    var annotationCount: Int
    var onFitToWindow: (() -> Void)?

    var body: some View {
        HStack(spacing: 0) {
            // MARK: Left - Image Info
            HStack(spacing: 8) {
                Label {
                    Text("\(Int(imageSize.width)) × \(Int(imageSize.height))")
                        .font(.system(size: 10, design: .monospaced))
                } icon: {
                    Image(systemName: "photo")
                        .font(.system(size: 9))
                }
                .foregroundColor(.secondary)

                if annotationCount > 0 {
                    Text("\(annotationCount) annotation\(annotationCount == 1 ? "" : "s")")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary.opacity(0.7))
                }
            }
            .padding(.leading, 12)

            Spacer()

            // MARK: Center - Active Tool
            HStack(spacing: 4) {
                Image(systemName: selectedTool.icon)
                    .font(.system(size: 9))
                Text(selectedTool.displayName)
                    .font(.system(size: 10, weight: .medium))
            }
            .foregroundColor(.secondary.opacity(0.7))

            Spacer()

            // MARK: Right - Zoom Controls
            HStack(spacing: 4) {
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.15)) {
                        zoomScale = max(0.5, zoomScale - 0.25)
                        lastZoomScale = zoomScale
                    }
                }) {
                    Image(systemName: "minus")
                        .font(.system(size: 9, weight: .semibold))
                        .frame(width: 18, height: 18)
                }
                .buttonStyle(.plain)
                .disabled(zoomScale <= 0.5)
                .help("Zoom Out (Cmd+-)")

                Button(action: {
                    withAnimation(.easeInOut(duration: 0.15)) {
                        onFitToWindow?()
                    }
                }) {
                    Image(systemName: "arrow.up.left.and.arrow.down.right")
                        .font(.system(size: 9, weight: .semibold))
                        .frame(width: 18, height: 18)
                }
                .buttonStyle(.plain)
                .help("Fit to Window (Cmd+0)")

                Button(action: {
                    withAnimation(.easeInOut(duration: 0.15)) {
                        zoomScale = 1.0
                        lastZoomScale = 1.0
                    }
                }) {
                    Text("\(Int(zoomScale * 100))%")
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .frame(minWidth: 36)
                }
                .buttonStyle(.plain)
                .help("Actual Size (Cmd+1)")

                Button(action: {
                    withAnimation(.easeInOut(duration: 0.15)) {
                        zoomScale = min(4.0, zoomScale + 0.25)
                        lastZoomScale = zoomScale
                    }
                }) {
                    Image(systemName: "plus")
                        .font(.system(size: 9, weight: .semibold))
                        .frame(width: 18, height: 18)
                }
                .buttonStyle(.plain)
                .disabled(zoomScale >= 4.0)
                .help("Zoom In (Cmd+=)")
            }
            .foregroundColor(.secondary)
            .padding(.trailing, 12)
        }
        .frame(height: 24)
        .background(Color(nsColor: .windowBackgroundColor))
    }
}
