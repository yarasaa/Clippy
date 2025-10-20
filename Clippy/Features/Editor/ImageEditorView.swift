//
//  ImageEditorView.swift
//  Clippy

import SwiftUI

/// Bir resimden renk seçmek için kullanılan özel görünüm.
struct ImageEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var settings: SettingsManager

    let image: NSImage
    
    @State private var zoomScale: CGFloat = 1.0
    @State private var viewOffset: CGVector = .zero
    
    @State private var showCopiedBanner = false
    @State private var copiedColorHex: String = ""

    var body: some View {
        VStack(spacing: 0) {
            ZStack(alignment: .bottom) {
                DrawingCanvas(
                    image: image,
                    zoomScale: $zoomScale,
                    viewOffset: $viewOffset,
                    onColorPick: { color in
                        copyColorToClipboard(color)
                    }
                )
                
                if showCopiedBanner {
                    Text(String(format: L("Saved %@ to History", settings: settings), copiedColorHex))
                        .padding(.vertical, 8)
                        .padding(.horizontal, 12)
                        .background(.bar)
                        .cornerRadius(8)
                        .shadow(radius: 5)
                        .padding(.bottom)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                        .onAppear {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                                withAnimation {
                                    showCopiedBanner = false
                                }
                            }
                        }
                }
            }
        }
        .overlay(alignment: .bottomLeading) {
            Button {
                zoomScale = 1.0
                viewOffset = .zero
            } label: {
                Image(systemName: "arrow.up.left.and.down.right.magnifyingglass")
            }
            .help(L("Reset View", settings: settings))
            .padding()
            .opacity(zoomScale == 1.0 && viewOffset == .zero ? 0 : 1)
        }
        .overlay(alignment: .topTrailing) {
            Button(action: { dismiss() }) {
                Image(systemName: "xmark")
            }
            .buttonStyle(.plain)
            .padding()
        }
        .frame(minWidth: 600, idealWidth: max(600, image.size.width),
               minHeight: 400, idealHeight: max(400, image.size.height + 100))
    }

    private func copyColorToClipboard(_ color: NSColor) {
        guard let rgbColor = color.usingColorSpace(.sRGB) else { return }
        let red = Int(round(rgbColor.redComponent * 255))
        let green = Int(round(rgbColor.greenComponent * 255))
        let blue = Int(round(rgbColor.blueComponent * 255))

        let hexString = String(format: "#%02X%02X%02X", red, green, blue)
        
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(hexString, forType: .string)
        
        // Yeni bir pano öğesi oluştur ve geçmişe ekle.
        let newItem = ClipboardItem(contentType: .text(hexString), date: Date(), sourceAppName: L("Color Picker", settings: settings), sourceAppBundleIdentifier: "com.yarasa.Clippy.ColorPicker")
        PasteManager.shared.clipboardMonitor?.addNewItem(newItem)
        
        copiedColorHex = hexString
        withAnimation {
            showCopiedBanner = true
        }
    }
}

// MARK: - Drawing Canvas

struct DrawingCanvas: NSViewRepresentable {
    let image: NSImage
    @Binding var zoomScale: CGFloat
    @Binding var viewOffset: CGVector
    let onColorPick: (NSColor) -> Void

    func makeNSView(context: Context) -> DrawingNSView {
        let view = DrawingNSView(image: image)
        view.zoomScale = zoomScale
        view.viewOffset = viewOffset
        view.delegate = context.coordinator
        context.coordinator.onColorPick = onColorPick
        return view
        
    }

    func updateNSView(_ nsView: DrawingNSView, context: Context) {
        if nsView.zoomScale != zoomScale { nsView.zoomScale = zoomScale }
        if nsView.viewOffset != viewOffset { nsView.viewOffset = viewOffset }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    class Coordinator: NSObject, DrawingNSViewDelegate {
        var parent: DrawingCanvas
        var onColorPick: ((NSColor) -> Void)?

        init(parent: DrawingCanvas) {
            self.parent = parent
        }
        
        func didPickColor(_ color: NSColor) {
            onColorPick?(color)
        }
        
        func didUpdateZoom(scale: CGFloat, offset: CGVector) {
            parent.zoomScale = scale
            parent.viewOffset = offset
        }
    }
}