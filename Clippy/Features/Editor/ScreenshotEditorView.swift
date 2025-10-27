//
//  ScreenshotEditorView.swift
//  Clippy
//
//  Created by Gemini Code Assist on 11.10.2025.
//

import SwiftUI
import Combine
import Vision

/// Düzenleme araçlarını temsil eden enum.
enum DrawingTool: String, CaseIterable, Identifiable {
    case move, arrow, rectangle, text, pixelate, eraser, highlighter

    var icon: String {
        switch self {
        case .move: return "arrow.up.and.down.and.arrow.left.and.right"
        case .arrow: return "arrow.up.right"
        case .rectangle: return "square"
        case .text: return "textformat"
        case .pixelate: return "square.grid.3x3.fill"
        case .eraser: return "eraser.line.dashed"
        case .highlighter: return "highlighter"
        }
    }
    
    var id: String {
        self.rawValue
    }
}

// Çizilen her bir şekli temsil eden yapı.
struct Annotation: Identifiable {
    let id = UUID()
    var rect: CGRect
    var color: Color
    var lineWidth: CGFloat = 4
    var tool: DrawingTool
    var text: String = ""
    var startPoint: CGPoint? // Ok ve çizgi gibi yönlü araçlar için
    var endPoint: CGPoint?   // Ok ve çizgi gibi yönlü araçlar için
}

/// Arka plan doldurma modelini tip güvenli şekilde temsil eder.
enum BackdropFillModel: Equatable {
    case solid(Color)
    case linearGradient(start: Color, end: Color, startPoint: UnitPoint, endPoint: UnitPoint)
}

/// Ekran görüntüsü düzenleyicisinin durumunu ve mantığını yöneten sınıf.
class ScreenshotEditorViewModel: ObservableObject {
    @Published var annotations: [Annotation] = []

    // Geri alma/yineleme fonksiyonları
    func addAnnotation(_ annotation: Annotation, undoManager: UndoManager?) {
        annotations.append(annotation)
        undoManager?.registerUndo(withTarget: self) { target in
            target.removeLastAnnotation(undoManager: undoManager)
        }
        objectWillChange.send()
    }

    func removeLastAnnotation(undoManager: UndoManager?) {
        guard let lastAnnotation = annotations.popLast() else { return }
        undoManager?.registerUndo(withTarget: self) { target in
            target.addAnnotation(lastAnnotation, undoManager: undoManager)
        }
        objectWillChange.send()
    }
    
    func moveAnnotation(at index: Int, to newRect: CGRect, from oldRect: CGRect, undoManager: UndoManager?) {
        guard index < annotations.count else { return }
        let originalRect = annotations[index].rect
        annotations[index].rect = newRect
        undoManager?.registerUndo(withTarget: self) { target in
            target.moveAnnotation(at: index, to: originalRect, from: newRect, undoManager: undoManager)
        }
        objectWillChange.send()
    }
    
    func removeAnnotation(with id: UUID, undoManager: UndoManager?) {
        guard let index = annotations.firstIndex(where: { $0.id == id }) else { return }
        let removedAnnotation = annotations.remove(at: index)
        
        undoManager?.registerUndo(withTarget: self) { target in
            target.insertAnnotation(removedAnnotation, at: index, undoManager: undoManager)
        }
        objectWillChange.send()
    }
    
    func insertAnnotation(_ annotation: Annotation, at index: Int, undoManager: UndoManager?) {
        guard index <= annotations.count else { return }
        annotations.insert(annotation, at: index)
        undoManager?.registerUndo(withTarget: self) { target in
            target.removeAnnotation(with: annotation.id, undoManager: undoManager)
        }
        objectWillChange.send()
    }
    
    // Metin güncelleme için geri alma desteği
    func updateAnnotationText(at index: Int, newText: String, oldText: String, undoManager: UndoManager?) {
        guard index < annotations.count else { return }
        annotations[index].text = newText
        undoManager?.registerUndo(withTarget: self) { target in
            target.updateAnnotationText(at: index, newText: oldText, oldText: newText, undoManager: undoManager)
        }
        objectWillChange.send()
    }
}

struct ScreenshotEditorView: View {
    @State var image: NSImage
    @EnvironmentObject var settings: SettingsManager
    var clipboardMonitor: ClipboardMonitor // AppDelegate'den geçirilmeli

    @StateObject private var viewModel = ScreenshotEditorViewModel()
    @State private var selectedTool: DrawingTool = .rectangle
    @State private var selectedColor: Color = .red
    @State private var selectedLineWidth: CGFloat = 4
    
    // Metin girişi için
    @State private var isEditingText: Bool = false
    @FocusState private var isTextFieldFocused: Bool
    @State private var editingTextIndex: Int?
    
    // Taşıma işlemi için
    @State private var movingAnnotationID: UUID?
    @State private var dragOffset: CGSize = .zero
    
    // OCR butonu için durum
    @State private var ocrButtonIcon = "text.viewfinder"
    @State private var isPerformingOCR = false
    
    // Renk kodunu kopyalamak için durum
    @State private var showColorCopied = false
    
    // Backdrop efektleri için durumlar
    @State private var showEffectsPanel = false
    @State private var backdropPadding: CGFloat = 40
    @State private var screenshotShadowRadius: CGFloat = 25
    @State private var screenshotCornerRadius: CGFloat = 12
    @State private var backdropCornerRadius: CGFloat = 16
    @State private var backdropFill: AnyShapeStyle = AnyShapeStyle(Color(nsColor: .windowBackgroundColor).opacity(0.8))
    // Tip güvenli karşılığı; renderFinalImage bununla çalışır.
    @State private var backdropModel: BackdropFillModel = .solid(Color(nsColor: .windowBackgroundColor).opacity(0.8))
    @State private var backdropColor: Color = Color(nsColor: .windowBackgroundColor).opacity(0.8)
    
    @Environment(\.undoManager) private var undoManager

    var body: some View {
        VStack(spacing: 0) {
            topToolbar

            ZStack { // Ana içerik ZStack'i
                Color(nsColor: .textBackgroundColor)
                    .edgesIgnoringSafeArea(.all)

                ZStack { // Backdrop Grubu
                    // 1. Arka Plan (Backdrop)
                    RoundedRectangle(cornerRadius: backdropCornerRadius)
                        .fill(backdropFill) // AnyShapeStyle ile doldur
                        .shadow(radius: screenshotShadowRadius / 2)

                    // DÜZELTME: Görüntü ve Canvas'ı, boyutlarını doğru alabilmesi için GeometryReader içine al.
                    GeometryReader { geometry in
                        // 2. Görüntü ve Çizimleri
                        Image(nsImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .clipShape(RoundedRectangle(cornerRadius: screenshotCornerRadius))
                            .shadow(radius: screenshotShadowRadius)
                            .overlay(
                                ZStack {
                                    Image(nsImage: image)
                                        .resizable()
                                        .aspectRatio(contentMode: .fit)
                                    DrawingCanvasView(image: image, viewModel: viewModel, selectedTool: $selectedTool, selectedColor: $selectedColor, selectedLineWidth: $selectedLineWidth, movingAnnotationID: $movingAnnotationID, dragOffset: $dragOffset, editingTextIndex: $editingTextIndex, onTextAnnotationCreated: { [weak viewModel] id in
                                        // DÜZELTME: `self` (struct) yerine `viewModel` (class) üzerinde weak capture yap.
                                        guard let viewModel = viewModel else { return }
                                        if let index = viewModel.annotations.lastIndex(where: { $0.id == id }) {
                                            startEditingText(at: index)
                                        }
                                    })
                                    
                                    if isEditingText, let index = editingTextIndex, index < viewModel.annotations.count {
                                        let annotation = viewModel.annotations[index]
                                        CustomTextEditor(
                                            text: Binding(
                                                get: { viewModel.annotations[index].text },
                                                set: { newText in
                                                    let oldText = viewModel.annotations[index].text
                                                    if newText != oldText {
                                                        viewModel.updateAnnotationText(at: index, newText: newText, oldText: oldText, undoManager: undoManager)
                                                    }
                                                }
                                            ),
                                        font: .systemFont(ofSize: annotation.lineWidth * 4),
                                        textColor: NSColor(annotation.color),
                                        onHeightChange: { newHeight in
                                            // Yükseklik değiştiğinde annotation'ı güncelle.
                                            if viewModel.annotations[index].rect.size.height != newHeight {
                                                viewModel.annotations[index].rect.size.height = newHeight
                                            }
                                        }
                                        )
                                            .focused($isTextFieldFocused)
                                        .frame(width: annotation.rect.width, height: annotation.rect.height)
                                        .position(x: annotation.rect.midX, y: annotation.rect.midY)
                                            .onSubmit { stopEditingText() }
                                            .onExitCommand { stopEditingText() }
                                    }
                                }
                            )
                            .padding(backdropPadding) // Inset
                    }
                }
            } 
            .cursor(currentCursor) // İmleci ayarla
            .frame(maxWidth: .infinity, maxHeight: .infinity) // Tüm alanı kapla
        }
        .frame(minWidth: 600, minHeight: 400)
    }

    
    /// Seçili olan araca göre uygun fare imlecini döndürür.
    private var currentCursor: NSCursor {
        switch selectedTool {
        case .move:
            return movingAnnotationID != nil ? .closedHand : .openHand
        case .rectangle, .arrow, .text, .pixelate, .eraser, .highlighter:
            return .crosshair
        }
    }
    
    /// Modern üst araç çubuğu
    private var topToolbar: some View {
        HStack(spacing: 15) {
            // Sol Taraf (Geri Al/Yinele)
            HStack {
                Button(action: { undoManager?.undo() }) {
                    Image(systemName: "arrow.uturn.backward")
                }
                .disabled(!(undoManager?.canUndo ?? false))
                
                Button(action: { undoManager?.redo() }) {
                    Image(systemName: "arrow.uturn.forward")
                }
                .disabled(!(undoManager?.canRedo ?? false))
            }
            .buttonStyle(.plain)
            
            Divider()
            
            // Çizim Araçları
            ForEach(DrawingTool.allCases) { tool in
                Button(action: { selectedTool = tool }) {
                    Image(systemName: tool.icon)
                        .font(.title3)
                        .foregroundColor(selectedTool == tool ? .accentColor : .secondary)
                        .frame(width: 28, height: 28)
                        .background(selectedTool == tool ? Color.accentColor.opacity(0.15) : Color.clear)
                        .cornerRadius(6)
                }
                .buttonStyle(.plain)
            }
            
            Divider()
            
            // Renk ve Kalınlık Seçimi
            ColorPicker("", selection: $selectedColor, supportsOpacity: false)
                .labelsHidden()
                .frame(width: 28, height: 28)
            
            Text(showColorCopied ? "Copied!" : selectedColor.hexString)
                .font(.system(.caption, design: .monospaced))
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.secondary.opacity(0.1))
                .cornerRadius(6)
                .help("Click to copy Hex code")
                .onTapGesture {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(selectedColor.hexString, forType: .string)
                    showColorCopied = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        showColorCopied = false
                    }
                }
            
            Picker("", selection: $selectedLineWidth) {
                Text("S").tag(CGFloat(4))
                Text("M").tag(CGFloat(8))
                Text("L").tag(CGFloat(12))
            }
            .pickerStyle(.segmented)
            .frame(width: 100)
            
            Divider()
            
            // Efektler Paneli Butonu
            Button(action: { showEffectsPanel.toggle() }) {
                Image(systemName: "wand.and.rays")
                    .font(.title3)
            }
            .buttonStyle(.plain)
            .popover(isPresented: $showEffectsPanel, arrowEdge: .bottom) {
                EffectsInspectorView(isPresented: $showEffectsPanel,
                                     backdropPadding: $backdropPadding,
                                     shadowRadius: $screenshotShadowRadius,
                                     screenshotCornerRadius: $screenshotCornerRadius,
                                     backdropCornerRadius: $backdropCornerRadius,
                                     backdropFill: $backdropFill,
                                     backdropModel: $backdropModel)
            }
            
            Spacer() // Ortadaki boşluk
            
            // Sağ Taraf (Bilgi, Kaydet, Kapat)
            HStack(spacing: 10) {
                Text("\(Int(image.size.width))x\(Int(image.size.height))")
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.secondary.opacity(0.1))
                    .cornerRadius(6)
                
                Button(action: performOCR) {
                    Image(systemName: ocrButtonIcon)
                }
                .buttonStyle(.plain)
                .help("Copy Text from Image (OCR)")
                .disabled(isPerformingOCR)
                
                if settings.showImagesTab {
                    Button(action: saveToClippy) {
                        Image(systemName: "internaldrive")
                    }
                    .buttonStyle(.plain)
                    .help("Save to Clippy History")
                }
                
                Divider()
                
                Button(action: saveImage) {
                    Image(systemName: "square.and.arrow.down")
                    Text("Save")
                }
                .buttonStyle(.borderedProminent)
                .help("Save to a file...")
                .keyboardShortcut("s", modifiers: .command)
                
                Button(action: { NSApp.keyWindow?.close() }) {
                    Image(systemName: "xmark")
                }
                .buttonStyle(.plain)
                .help("Close Editor")
                .keyboardShortcut(.escape, modifiers: [])
            }
        }
        .padding(10)
        .background(.bar)
        .fixedSize(horizontal: false, vertical: true)
    }

    /// Tüm çizimleri Canvas üzerine işleyen fonksiyon
    private func drawAnnotations(context: inout GraphicsContext, canvasSize: CGSize) {
        // Bu fonksiyon artık sadece final render için kullanılıyor, bu yüzden sadece kaydedilmiş çizimleri çizer.
        for annotation in viewModel.annotations {
            var currentRect = annotation.rect
            if annotation.id == movingAnnotationID {
                currentRect = currentRect.offsetBy(dx: dragOffset.width, dy: dragOffset.height)
                context.addFilter(.shadow(color: .black.opacity(0.5), radius: 5))
            }
            drawSingleAnnotation(annotation, rect: currentRect, in: &context, canvasSize: canvasSize)
        }
    }
    
    /// Tek bir annotation'ı çizen yardımcı fonksiyon
    private func drawSingleAnnotation(_ annotation: Annotation, rect: CGRect, in context: inout GraphicsContext, canvasSize: CGSize) {
        switch annotation.tool {
        case .rectangle:
            context.stroke(Path(rect), with: .color(annotation.color), lineWidth: annotation.lineWidth)
        case .highlighter:
            context.fill(Path(rect), with: .color(annotation.color.opacity(0.3)))
        case .arrow:
            let startPoint = CGPoint(x: rect.minX, y: rect.minY)
            let endPoint = CGPoint(x: rect.maxX, y: rect.maxY)
            if hypot(endPoint.x - startPoint.x, endPoint.y - startPoint.y) > annotation.lineWidth * 2 {
                let path = Path.arrow(from: startPoint, to: endPoint, tailWidth: annotation.lineWidth, headWidth: annotation.lineWidth * 3, headLength: annotation.lineWidth * 3)
                context.fill(path, with: .color(annotation.color))
            }
        case .pixelate: // This was the missed reference
            // DÜZELTME: Efekti, kırpıp yapıştırmak yerine doğrudan context üzerine çiziyoruz.
            // Bu, zoom ve pan sırasında kayma sorununu çözer.
            context.addFilter(.blur(radius: 20))
            context.clip(to: Path(rect))

            if let resolvedImage = context.resolveSymbol(id: "sourceImage") {
                context.draw(resolvedImage, in: CGRect(origin: .zero, size: canvasSize))
            }
        case .text:
            if !annotation.text.isEmpty {
                let text = Text(annotation.text)
                    .font(.system(size: annotation.lineWidth * 4))
                    .foregroundColor(annotation.color)
                // Metni rect'in sol üst köşesinden başlayarak çiz
                context.draw(text, in: rect)
            } else if (editingTextIndex == viewModel.annotations.firstIndex(where: {$0.id == annotation.id})) {
                let path = Path(rect)
                context.stroke(path, with: .color(.gray), style: StrokeStyle(lineWidth: 1, dash: [4]))
            }
        case .move, .eraser:
            break
        }
    }


    private func renderFinalImage() -> NSImage {
        // 1. ADIM: Sadece Görüntü ve Çizimleri Render Et
        let annotationsView = ZStack {
            Image(nsImage: image)
                .resizable()
            
            Canvas { context, size in
                // Annotation'lar zaten orijinal görüntü koordinatlarında saklandığı için
                // ek bir dönüşüme gerek yok.
                drawAnnotations(context: &context, canvasSize: size)
            }
        }
        .frame(width: image.size.width, height: image.size.height)
        .clipped()

        let renderer = ImageRenderer(content: annotationsView)
        renderer.scale = NSScreen.main?.backingScaleFactor ?? 2.0
        
        guard let annotatedImage = renderer.nsImage else {
            print("❌ Annotation Renderer başarısız oldu, orijinal görüntü döndürülüyor.")
            return image
        }

        // 2. ADIM: Arka Planı ve Efektleri Ekleyerek Son Görüntüyü Oluştur
        let totalWidth = image.size.width + (backdropPadding * 2)
        let totalHeight = image.size.height + (backdropPadding * 2)
        let finalSize = NSSize(width: totalWidth, height: totalHeight)

        let finalImage = NSImage(size: finalSize)
        finalImage.lockFocus()

        guard let context = NSGraphicsContext.current?.cgContext else {
            finalImage.unlockFocus()
            print("❌ CGContext alınamadı.")
            return annotatedImage
        }

        // Arka Planı Çiz
        let backgroundRect = CGRect(origin: .zero, size: finalSize)
        let backgroundPath = NSBezierPath(roundedRect: NSRect(origin: .zero, size: finalSize),
                                            xRadius: backdropCornerRadius,
                                            yRadius: backdropCornerRadius)
        
        switch backdropModel {
        case .solid(let color):
            NSColor(color).setFill()
            backgroundPath.fill()
            
        case .linearGradient(let start, let end, let startPoint, let endPoint):
            // CGGradient ile çizim
            let colors = [NSColor(start).cgColor, NSColor(end).cgColor] as CFArray
            guard let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: [0.0, 1.0]) else {
                // Fallback: solid end color
                NSColor(end).setFill()
                backgroundPath.fill()
                break
            }
            context.saveGState()
            let clipPath = NSBezierPath(roundedRect: backgroundRect, xRadius: backdropCornerRadius, yRadius: backdropCornerRadius)
            clipPath.addClip()
            
            // UnitPoint -> CGPoint (backgroundRect koordinatlarında)
            let sp = CGPoint(x: backgroundRect.minX + startPoint.x * backgroundRect.width,
                             y: backgroundRect.minY + startPoint.y * backgroundRect.height)
            let ep = CGPoint(x: backgroundRect.minX + endPoint.x * backgroundRect.width,
                             y: backgroundRect.minY + endPoint.y * backgroundRect.height)
            context.drawLinearGradient(gradient, start: sp, end: ep, options: [])
            context.restoreGState()
        }

        // Çizimli Görüntüyü Ortaya Çiz
        let imageRect = NSRect(x: backdropPadding,
                               y: backdropPadding,
                               width: image.size.width,
                               height: image.size.height)
        
        // Görüntüye Köşe Yuvarlatma ve Gölge Ekleme
        context.saveGState()
        let imageClipPath = NSBezierPath(roundedRect: imageRect,
                                         xRadius: screenshotCornerRadius,
                                         yRadius: screenshotCornerRadius)
        imageClipPath.addClip()
        
        context.setShadow(offset: CGSize(width: 0, height: -screenshotShadowRadius / 2),
                          blur: screenshotShadowRadius,
                          color: NSColor.black.withAlphaComponent(0.5).cgColor)
        
        annotatedImage.draw(in: imageRect)
        
        context.restoreGState()

        finalImage.unlockFocus()
        
        return finalImage
    }

    private func saveImage() {
        let finalImage = renderFinalImage()

        let savePanel = NSSavePanel()
        savePanel.canCreateDirectories = true
        savePanel.showsTagField = false
        savePanel.nameFieldStringValue = "screenshot-\(Int(Date().timeIntervalSince1970)).png"
        savePanel.level = .modalPanel
        savePanel.begin { response in
            if response == .OK, let url = savePanel.url {
                guard let tiffData = finalImage.tiffRepresentation,
                      let bitmap = NSBitmapImageRep(data: tiffData),
                      let pngData = bitmap.representation(using: .png, properties: [:]) else {
                    print("❌ Görüntü PNG formatına dönüştürülemedi.")
                    return
                }
                do {
                    try pngData.write(to: url)
                    print("✅ Görüntü şuraya kaydedildi: \(url.path)")
                } catch {
                    print("❌ Görüntü kaydetme hatası: \(error.localizedDescription)")
                }
            }
        }
    }

    private func renderFinalImage_OLD() -> NSImage {
        // DÜZELTME: Bu yöntem, padding (inset) olduğunda kaymaya neden olduğu için
        // artık kullanılmıyor. Yerine iki adımlı render yöntemi kullanılıyor.
        let finalWidth = image.size.width + (backdropPadding * 2)
        let finalHeight = image.size.height + (backdropPadding * 2)
        
        let viewToRender = ZStack {
            RoundedRectangle(cornerRadius: backdropCornerRadius)
                .fill(backdropFill)
                .shadow(radius: screenshotShadowRadius / 2)

            ZStack {
                Image(nsImage: image)
                    .resizable()
                    .clipShape(RoundedRectangle(cornerRadius: screenshotCornerRadius))
                    .shadow(radius: screenshotShadowRadius)
                
                Canvas { context, size in
                    // Annotation'lar zaten model koordinatlarında saklandığı için
                    // ek bir dönüşüme gerek yok.
                    drawAnnotations(context: &context, canvasSize: image.size)
                }
            }
            .padding(backdropPadding)
        }
        .frame(width: finalWidth, height: finalHeight)

        let renderer = ImageRenderer(content: viewToRender)
        renderer.scale = NSScreen.main?.backingScaleFactor ?? 2.0 // Retina ekranlar için kaliteyi artır.
        return renderer.nsImage ?? image // Render başarısız olursa orijinal görüntüyü döndür.
    }

    private func saveToClippy() {
        let finalImage = renderFinalImage()
        clipboardMonitor.addImageToHistory(image: finalImage)
        print("✅ Görüntü Clippy geçmişine kaydedildi.")
        NSApp.keyWindow?.close()
    }
    
    private func performOCR() {
        guard !isPerformingOCR else { return }
        isPerformingOCR = true
        
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            isPerformingOCR = false
            return
        }

        let request = VNRecognizeTextRequest { (request, error) in
            guard let observations = request.results as? [VNRecognizedTextObservation], error == nil else {
                DispatchQueue.main.async { self.isPerformingOCR = false }
                return
            }
            
            let recognizedText = observations.compactMap { $0.topCandidates(1).first?.string }.joined(separator: "\n")
            
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(recognizedText, forType: .string)
            
            DispatchQueue.main.async {
                self.ocrButtonIcon = "checkmark"
                self.isPerformingOCR = false
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    self.ocrButtonIcon = "text.viewfinder"
                }
            }
        }
        
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                try VNImageRequestHandler(cgImage: cgImage, options: [:]).perform([request])
            } catch {
                print("❌ OCR hatası: \(error)")
                DispatchQueue.main.async { self.isPerformingOCR = false }
            }
        }
    }
        
    private func pixelate(image: NSImage, in rect: CGRect) -> NSImage? {
        guard let tiffData = image.tiffRepresentation,
              let ciImage = CIImage(data: tiffData) else {
            return nil
        }
        // Görüntünün tamamını değil, sadece ilgili alanı filtrelemek daha verimli olabilir
        let sourceRect = CGRect(origin: .zero, size: image.size)
        let rectInSource = rect.intersection(sourceRect) // İlgili alanın görüntü sınırları içinde kalmasını sağla
        if rectInSource.isEmpty { return nil }

        guard let filter = CIFilter(name: "CIPixellate") else { return nil }
        
        // CIImage koordinat sistemi için rect'i dönüştür (sol alt köşe başlangıç)
        let ciRect = CGRect(x: rectInSource.origin.x, y: ciImage.extent.height - rectInSource.origin.y - rectInSource.size.height, width: rectInSource.size.width, height: rectInSource.size.height)

        // Filtreyi sadece ilgili alana uygula
        let croppedImage = ciImage.cropped(to: ciRect)
        filter.setValue(croppedImage, forKey: kCIInputImageKey)
        filter.setValue(20, forKey: kCIInputScaleKey) // Piksel boyutu
        
        guard let outputImage = filter.outputImage else { return nil }
        
        // Çıktıyı tekrar NSImage'a dönüştürürken boyutları koru
        let rep = NSCIImageRep(ciImage: outputImage)
        let nsImage = NSImage(size: rectInSource.size) // Kırpılan alanın boyutunu kullan
        nsImage.addRepresentation(rep)
        return nsImage
    }
    
    private func findAnnotation(at point: CGPoint) -> (id: UUID, index: Int)? {
        if let index = viewModel.annotations.lastIndex(where: { $0.rect.contains(point) }) {
            return (viewModel.annotations[index].id, index)
        }
        return nil
    }
    
    private func startEditingText(at index: Int) {
        editingTextIndex = index
        isEditingText = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            isTextFieldFocused = true
        }
    }

    private func stopEditingText() {
        isEditingText = false
        editingTextIndex = nil
        // İsteğe bağlı: Boş metin kutularını sil
        // viewModel.annotations.removeAll { $0.tool == .text && $0.text.isEmpty }
    }
}

// Color'a HEX string'e dönüştürme yeteneği
extension Color {
    var hexString: String {
        guard let components = NSColor(self).usingColorSpace(.sRGB)?.cgColor.components, components.count >= 3 else { return "#000000" }
        let r = Int(components[0] * 255.0)
        let g = Int(components[1] * 255.0)
        let b = Int(components[2] * 255.0)
        return String(format: "#%02X%02X%02X", r, g, b)
    }
    
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB, red: Double(r) / 255, green: Double(g) / 255, blue: Double(b) / 255, opacity: Double(a) / 255
        )
    }
}

// MARK: - Effects Inspector Panel
// Gradient yönleri için yardımcı struct
struct NamedUnitPoint: Identifiable, Hashable {
    let id = UUID()
    let name: String
    let point: UnitPoint
}

struct EffectsInspectorView: View {
    @Binding var isPresented: Bool
    @Binding var backdropPadding: CGFloat
    @Binding var shadowRadius: CGFloat
    @Binding var screenshotCornerRadius: CGFloat
    @Binding var backdropCornerRadius: CGFloat
    @Binding var backdropFill: AnyShapeStyle
    @Binding var backdropModel: BackdropFillModel

    @State private var selectedTab: Int = 0
    @State private var solidColor: Color = .white // Başlangıç rengi
    @State private var gradientStartColor: Color = .blue
    @State private var gradientEndColor: Color = .cyan
    @State private var gradientStartPoint: UnitPoint = .topLeading
    
    let solidColors: [Color] = [
        .blue, .green, .red, .orange, .purple, .yellow,
        .pink, .cyan, .indigo, .mint, .white, .black
    ]
    let presetGradients: [[Color]] = [
        [.blue, .cyan], [.pink, .purple], [.orange, .red],
        [.green, .mint], [.purple, .indigo], [.yellow, .orange],
        [Color(hex: "#833ab4"), Color(hex: "#fd1d1d"), Color(hex: "#fcb045")],
        [Color(hex: "#00c6ff"), Color(hex: "#0072ff")],
        [Color(hex: "#43e97b"), Color(hex: "#38f9d7")],
        [Color(hex: "#f857a6"), Color(hex: "#ff5858")],
        [Color(hex: "#e0c3fc"), Color(hex: "#8ec5fc")],
        [Color(hex: "#f093fb"), Color(hex: "#f5576c")]
    ]
    let gradientDirections: [NamedUnitPoint] = [
        .init(name: "Top Left", point: .topLeading), .init(name: "Top", point: .top), .init(name: "Top Right", point: .topTrailing),
        .init(name: "Left", point: .leading), .init(name: "Center", point: .center), .init(name: "Right", point: .trailing),
        .init(name: "Bottom Left", point: .bottomLeading), .init(name: "Bottom", point: .bottom), .init(name: "Bottom Right", point: .bottomTrailing)
    ]
    
    // Hesaplanan bitiş noktası
    private var gradientEndPoint: UnitPoint {
        // Basitçe tersini alıyoruz
        UnitPoint(x: 1.0 - gradientStartPoint.x, y: 1.0 - gradientStartPoint.y)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            
            // --- 1. SLIDER'LAR ---
            VStack(alignment: .leading, spacing: 8) {
                HStack { Text("Inset").font(.caption); Spacer(); Text("\(Int(backdropPadding))").font(.caption2) }
                Slider(value: $backdropPadding, in: 0...150) // Max değeri artırdık
                
                HStack { Text("Shadow").font(.caption); Spacer(); Text("\(Int(shadowRadius))").font(.caption2) }
                Slider(value: $shadowRadius, in: 0...100)
                
                HStack { Text("Outer Radius").font(.caption); Spacer(); Text("\(Int(backdropCornerRadius))").font(.caption2) }
                Slider(value: $backdropCornerRadius, in: 0...100) // Max değeri artırdık
                
                HStack { Text("Inner Radius").font(.caption); Spacer(); Text("\(Int(screenshotCornerRadius))").font(.caption2) }
                Slider(value: $screenshotCornerRadius, in: 0...100) // Max değeri artırdık
            }
            
            Divider()
            
            // --- 2. SEKMELER (TABS) ---
            Picker("Color Type", selection: $selectedTab) {
                Text("Solid").tag(0)
                Text("Colormix").tag(1)
                Text("Image").tag(2)
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            
            // --- 3. SEKMEYE GÖRE İÇERİK ---
            Group {
                if selectedTab == 0 { // Solid
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 24), spacing: 8)], spacing: 8) {
                        ForEach(solidColors, id: \.self) { color in
                            Button {
                                solidColor = color
                                backdropFill = AnyShapeStyle(solidColor)
                                backdropModel = .solid(solidColor)
                            } label: {
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(color)
                                    .frame(width: 24, height: 24)
                                    .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.primary.opacity(0.2), lineWidth: 1))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    ColorPicker("Custom Color", selection: $solidColor)
                        .padding(.top, 8)
                        .onChange(of: solidColor) {
                            backdropFill = AnyShapeStyle($0)
                            backdropModel = .solid($0)
                        }
                    
                } else if selectedTab == 1 { // Colormix
                    VStack(alignment: .leading) {
                        Text("Presets").font(.caption)
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 24), spacing: 8)], spacing: 8) {
                            ForEach(presetGradients, id: \.self) { colors in
                                Button {
                                    gradientStartColor = colors.first ?? .white
                                    gradientEndColor = colors.count > 1 ? colors[1] : .black
                                    updateBackdropFillWithGradient()
                                } label: {
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing))
                                        .frame(width: 24, height: 24)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        
                        Divider().padding(.vertical, 5)
                        Text("Custom Gradient").font(.caption)
                        HStack {
                            ColorPicker("Start", selection: $gradientStartColor)
                            ColorPicker("End", selection: $gradientEndColor)
                            Spacer()
                        }
                        
                        Picker("Direction", selection: $gradientStartPoint) {
                            ForEach(gradientDirections) { Text($0.name).tag($0.point) }
                        }
                        .pickerStyle(.menu)

                        RoundedRectangle(cornerRadius: 6)
                            .fill(LinearGradient(gradient: Gradient(colors: [gradientStartColor, gradientEndColor]),
                                                 startPoint: gradientStartPoint,
                                                 endPoint: gradientEndPoint))
                            .frame(height: 30)
                            .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.primary.opacity(0.2)))
                            .onChange(of: gradientStartColor) { _ in updateBackdropFillWithGradient() }
                            .onChange(of: gradientEndColor) { _ in updateBackdropFillWithGradient() }
                            .onChange(of: gradientStartPoint) { _ in updateBackdropFillWithGradient() }
                    }
                } else { // Image
                    VStack {
                        Image(systemName: "photo.on.rectangle.angled")
                            .font(.largeTitle).foregroundColor(.secondary)
                        Text("Select an image for the backdrop").font(.caption).foregroundColor(.secondary)
                        Button("Browse...") { /* TODO: Resim seçme ekle */ }
                    }
                    .frame(maxWidth: .infinity, minHeight: 100)
                }
            }
            .frame(maxHeight: .infinity)

            Spacer()
            
            // --- 4. ALT BUTONLAR ---
            HStack {
                Button("Remove", role: .destructive) {
                    backdropPadding = 0
                    shadowRadius = 0
                    screenshotCornerRadius = 0
                    backdropCornerRadius = 0
                    let defaultColor = Color(nsColor: .windowBackgroundColor).opacity(0.8)
                    backdropFill = AnyShapeStyle(defaultColor)
                    backdropModel = .solid(defaultColor)
                    solidColor = defaultColor // Solid rengi de sıfırla
                }
                Spacer()
                Button("Ok") { isPresented = false }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding()
        .frame(width: 280, height: 450)
        .onAppear(perform: setupInitialStateFromFill) // Başlangıç durumunu ayarla
    }
    
    // Ana görünümdeki backdropFill'i güncelleyen fonksiyon
    private func updateBackdropFillWithGradient() {
        let gradient = LinearGradient(gradient: Gradient(colors: [gradientStartColor, gradientEndColor]), startPoint: gradientStartPoint, endPoint: gradientEndPoint)
        backdropFill = AnyShapeStyle(gradient)
        backdropModel = .linearGradient(start: gradientStartColor, end: gradientEndColor, startPoint: gradientStartPoint, endPoint: gradientEndPoint)
    }
    
    // Panel açıldığında, mevcut backdropFill'e göre state'leri ayarla
    private func setupInitialStateFromFill() {
        // AnyShapeStyle introspection yok; mevcut backdropModel üzerinden state’i eşitle
        switch backdropModel {
        case .solid(let color):
            solidColor = color
            selectedTab = 0
        case .linearGradient(let start, let end, let sp, _):
            gradientStartColor = start
            gradientEndColor = end
            gradientStartPoint = sp
            // ep, gradientEndPoint ile uyumlu olacak şekilde gösterim amaçlı.
            selectedTab = 1
        }
    }
}

// MARK: - Drawing Canvas View

/// Çizim mantığını kendi içinde yöneten, daha performanslı ve stabil bir Canvas görünümü.
struct DrawingCanvasView: View {
    let image: NSImage
    @ObservedObject var viewModel: ScreenshotEditorViewModel
    @Binding var selectedTool: DrawingTool
    @Binding var selectedColor: Color
    @Binding var selectedLineWidth: CGFloat
    @Binding var movingAnnotationID: UUID?
    @Binding var dragOffset: CGSize
    @Binding var editingTextIndex: Int?
    var onTextAnnotationCreated: (UUID) -> Void
    
    @Environment(\.undoManager) private var undoManager

    // Canlı çizim için yerel state'ler
    @State private var liveDrawingStart: CGPoint?
    @State private var liveDrawingEnd: CGPoint?
    
    // Performans için CIImage'ı önbelleğe al.
    @State private var sourceCIImage: CIImage?

    var body: some View {
        // DÜZELTME: TimelineView kaldırıldı. Canvas, @State değişkenleri değiştikçe güncellenecek.
        Canvas { context, size in

                // 1. Mevcut (kaydedilmiş) çizimleri çiz
                for annotation in viewModel.annotations {
                    var currentRect = annotation.rect
                    if annotation.id == movingAnnotationID {
                        currentRect = currentRect.offsetBy(dx: dragOffset.width, dy: dragOffset.height)
                        context.addFilter(.shadow(color: .black.opacity(0.5), radius: 5))
                    }
                    drawSingleAnnotation(annotation, rect: currentRect, in: &context, canvasSize: size)
                }

                // 2. Canlı (o an çizilen) şekli çiz
                if let start = liveDrawingStart, let end = liveDrawingEnd {
                    let rect = CGRect(from: start, to: end)
                    // DÜZELTME: Canlı önizleme için de başlangıç ve bitiş noktalarını ata.
                    var liveAnnotation = Annotation(rect: rect, color: selectedColor, lineWidth: selectedLineWidth, tool: selectedTool)
                    liveAnnotation.startPoint = start
                    liveAnnotation.endPoint = end
                    drawSingleAnnotation(liveAnnotation, rect: rect, in: &context, canvasSize: size)
                }
            }
        .gesture(drawingGesture)
        .onAppear {
            // View ilk göründüğünde, NSImage'ı bir kez CIImage'a dönüştür.
            if let tiffData = image.tiffRepresentation {
                self.sourceCIImage = CIImage(data: tiffData)
            }
        }
    }

    // Tüm çizim, silme ve taşıma işlemlerini yöneten tek gesture
    private var drawingGesture: some Gesture {
        DragGesture(minimumDistance: 0, coordinateSpace: .local)
            .onChanged { value in
                switch selectedTool {
                case .move:
                    if movingAnnotationID == nil { // Taşıma yeni başladıysa
                        if let (id, _) = findAnnotation(at: value.location) {
                            movingAnnotationID = id
                            dragOffset = .zero
                        }
                    }
                    if movingAnnotationID != nil {
                        dragOffset = value.translation
                    }
                case .eraser:
                     if let (id, _) = findAnnotation(at: value.location) {
                        viewModel.removeAnnotation(with: id, undoManager: undoManager)
                    }
                default: // Diğer tüm çizim araçları
                    if liveDrawingStart == nil {
                        liveDrawingStart = value.location
                    }
                    liveDrawingEnd = value.location
                }
            }
            .onEnded { value in
                switch selectedTool {
                case .move:
                    if let movingID = movingAnnotationID, let index = viewModel.annotations.firstIndex(where: { $0.id == movingID }) {
                        let originalRect = viewModel.annotations[index].rect
                        let newRect = originalRect.offsetBy(dx: value.translation.width, dy: value.translation.height)
                        viewModel.moveAnnotation(at: index, to: newRect, from: originalRect, undoManager: undoManager)
                    }
                    movingAnnotationID = nil
                    dragOffset = .zero
                case .eraser:
                    break // Silme işlemi onChanged'de yapılıyor.
                default: // Diğer tüm çizim araçları
                    if let start = liveDrawingStart {
                        let rect = CGRect(from: start, to: value.location)
                        if rect.width > 2 || rect.height > 2 { // Çok küçük çizimleri engelle
                            var newAnnotation = Annotation(rect: rect, color: selectedColor, lineWidth: selectedLineWidth, tool: selectedTool)
                            newAnnotation.startPoint = start
                            newAnnotation.endPoint = value.location
                            viewModel.addAnnotation(newAnnotation, undoManager: undoManager)
                            if newAnnotation.tool == .text {
                                onTextAnnotationCreated(newAnnotation.id)
                            }
                        }
                    }
                }
                // Her durumda canlı çizim state'lerini sıfırla
                liveDrawingStart = nil
                liveDrawingEnd = nil
            }
    }
    
    private func findAnnotation(at point: CGPoint) -> (id: UUID, index: Int)? {
        if let index = viewModel.annotations.lastIndex(where: { $0.rect.contains(point) }) {
            return (viewModel.annotations[index].id, index)
        }
        return nil
    }
    
    // Bu fonksiyon, ana View'daki ile aynı olmalı.
    private func drawSingleAnnotation(_ annotation: Annotation, rect: CGRect, in context: inout GraphicsContext, canvasSize: CGSize) {
        switch annotation.tool {
        case .rectangle:
            context.stroke(Path(rect), with: .color(annotation.color), lineWidth: annotation.lineWidth)
        case .highlighter:
            // DÜZELTME: Highlighter'ı doğru çalışan haline geri getir.
            // .multiply blend modu, rengin alttaki metni karartmasını engeller.
            context.blendMode = .multiply
            context.fill(Path(rect), with: .color(annotation.color.opacity(0.5)))
        case .arrow:
            // DÜZELTME: `rect` yerine, kaydedilmiş başlangıç ve bitiş noktalarını kullan.
            // Canlı çizim sırasında da bu noktalar anlık olarak güncellenir.
            let start = annotation.startPoint ?? rect.origin
            let end = annotation.endPoint ?? rect.endPoint
            if hypot(end.x - start.x, end.y - start.y) > annotation.lineWidth * 2 {
                let path = Path.arrow(from: start, to: end, tailWidth: annotation.lineWidth, headWidth: annotation.lineWidth * 3, headLength: annotation.lineWidth * 3)
                context.fill(path, with: .color(annotation.color))
            }
        case .pixelate:
            // DÜZELTME: Görüntünün ilgili bölümünü kırp, filtrele ve sonucu çiz.
            // Önce alttaki görüntünün görünmemesi için bir arka plan çiz.
            context.fill(Path(rect), with: .color(.black))
            if let pixelatedImage = pixelate(in: rect) {
                context.draw(Image(nsImage: pixelatedImage), in: rect)
            }

        case .text:
            // DÜZELTME: Eğer bu metin kutusu şu an düzenleniyorsa, Canvas'ta tekrar çizme.
            // Bu, "çift yazı" sorununu çözer.
            if !annotation.text.isEmpty && editingTextIndex != viewModel.annotations.firstIndex(where: { $0.id == annotation.id }) {
                let text = Text(annotation.text)
                    .font(.system(size: annotation.lineWidth * 4))
                    .foregroundColor(annotation.color)
                // DÜZELTME: `draw(at:)` yerine `draw(in:)` kullanarak metnin rect içinde kalmasını ve alt satıra geçmesini sağla.
                context.draw(text, in: rect)
            } else {
                // Kullanıcı metin alanı çizerken görsel geri bildirim sağlar.
                let path = Path(rect)
                context.stroke(path, with: .color(.gray), style: StrokeStyle(lineWidth: 1, dash: [4]))
            }
        case .move, .eraser:
            break
        }
    }
    
    /// Görüntünün belirtilen alanını pikselleştiren fonksiyon.
    private func pixelate(in rect: CGRect) -> NSImage? {
        return autoreleasepool {
            // Önceden oluşturulmuş CIImage'ı kullan.
            guard let sourceImage = sourceCIImage else {
                return nil
            }

            guard let filter = CIFilter(name: "CIPixellate") else { return nil }
            
            // Filtreyi ayarla.
            filter.setValue(sourceImage, forKey: kCIInputImageKey)
            filter.setValue(selectedLineWidth * 5, forKey: kCIInputScaleKey)

            guard let outputImage = filter.outputImage else { return nil }

            // Paylaşılan bir CIContext kullanmak performansı artırır.
            let context = CIContext()
            
            // Filtrelenmiş CIImage'dan, belirtilen rect boyutlarında bir CGImage oluştur.
            if let cgImage = context.createCGImage(outputImage, from: rect) {
                return NSImage(cgImage: cgImage, size: rect.size)
            }
            
            return nil
        }
    }
}

extension CGRect {
    init(from: CGPoint, to: CGPoint) {
        self.init(x: min(from.x, to.x), y: min(from.y, to.y), width: abs(from.x - to.x), height: abs(from.y - to.y))
    }
}


// MARK: - CheckerboardView
struct CheckerboardView: View {
    let squareSize: CGFloat = 16
    let lightColor = Color(nsColor: .windowBackgroundColor).opacity(0.8)
    let darkColor = Color(nsColor: .underPageBackgroundColor)

    var body: some View {
        GeometryReader { geometry in
            let columns = Int(ceil(geometry.size.width / squareSize))
            let rows = Int(ceil(geometry.size.height / squareSize))

            Canvas { context, size in
                for row in 0..<rows {
                    for col in 0..<columns {
                        let rect = CGRect(x: CGFloat(col) * squareSize, y: CGFloat(row) * squareSize, width: squareSize, height: squareSize)
                        let color = (row + col).isMultiple(of: 2) ? lightColor : darkColor
                        context.fill(Path(rect), with: .color(color))
                    }
                }
            }
        }
    }
}

// View'a .cursor() değiştiricisi eklemek için bir uzantı.
extension View {
    func cursor(_ cursor: NSCursor) -> some View {
        self.onHover { inside in
            if inside {
                cursor.push()
            } else {
                NSCursor.pop()
            }
        }
    }
}

// MARK: - Scroll Event Handling
// DÜZELTİLDİ: Çalışan Scroll Event yakalayıcısı
struct ScrollEventModifier: ViewModifier {
    var onScroll: (NSEvent) -> Void

    func body(content: Content) -> some View {
        // İçeriği, arka planına yerleştirilen bir olay yakalayıcı
        // köprüsü ile sarmalar.
        content.background(
            ScrollEventView(onScroll: onScroll)
        )
    }
}

/// Arka planda çalışan ve fare tekerleği olaylarını dinleyen görünmez bir NSView.
private struct ScrollEventView: NSViewRepresentable {
    var onScroll: (NSEvent) -> Void
    
    func makeCoordinator() -> Coordinator {
        Coordinator(onScroll: onScroll)
    }

    func makeNSView(context: Context) -> EventHandlingView {
        let view = EventHandlingView()
        view.coordinator = context.coordinator
        return view
    }

    func updateNSView(_ nsView: EventHandlingView, context: Context) {
        context.coordinator.onScroll = onScroll
    }
    
    class Coordinator {
        var onScroll: (NSEvent) -> Void
        init(onScroll: @escaping (NSEvent) -> Void) {
            self.onScroll = onScroll
        }
    }
    
    /// Olayları yakalamak için özelleştirilmiş NSView.
    /// Bu sınıf, yanıtlayıcı zincirine girerek olayları yakalar.
    class EventHandlingView: NSView {
        // DÜZELTME: Referans döngüsünü kırmak için coordinator'a zayıf referans tut.
        weak var coordinator: Coordinator?

        // 1. Bu view'un "first responder" (ilk yanıtlayıcı)
        //    olabileceğini sisteme bildiriyoruz.
        override var acceptsFirstResponder: Bool { true }

        // 2. View pencereye eklendiği anda bu fonksiyon tetiklenir.
        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            // Pencereye eklendiği gibi, bu view'ı
            // klavye/fare olayları için ilk yanıtlayıcı yap.
            window?.makeFirstResponder(self)
        }
        
        // 3. Olayı yakalayıp closure'a iletiyoruz.
        override func scrollWheel(with event: NSEvent) {
            coordinator?.onScroll(event)
        }
    }
}


// MARK: - CustomTextEditor (NSViewRepresentable)
/// SwiftUI'ın TextEditor'ındaki canlı düzenleme sırasındaki bulanıklık sorununu çözmek için
/// bir NSTextView'ı sarmalayan özel bir görünüm.
struct CustomTextEditor: NSViewRepresentable {
    @Binding var text: String
    var font: NSFont
    var textColor: NSColor
    var onHeightChange: ((CGFloat) -> Void)?

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSTextView.scrollableTextView()
        let textView = scrollView.documentView as! NSTextView

        textView.delegate = context.coordinator
        scrollView.hasVerticalScroller = false // Scroll bar'ı gizle
        textView.isRichText = false
        textView.font = font
        textView.textColor = textColor
        textView.drawsBackground = false // Arka planı saydam yapar
        textView.isSelectable = true
        textView.isEditable = true

        textView.textContainer?.lineFragmentPadding = 0
        textView.backgroundColor = .clear
        textView.insertionPointColor = textColor
        
        return scrollView
    }

    func updateNSView(_ nsView: NSScrollView, context: Context) {
        let textView = nsView.documentView as! NSTextView
        if textView.font != font {
            textView.font = font
        }
        if textView.textColor != textColor {
            textView.textColor = textColor
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, NSTextViewDelegate {
        var parent: CustomTextEditor

        init(_ parent: CustomTextEditor) {
            self.parent = parent
        }

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            self.parent.text = textView.string
            
            // Metin değiştikçe gereken yüksekliği hesapla ve bildir.
            guard let layoutManager = textView.layoutManager,
                  let textContainer = textView.textContainer else { return }
            layoutManager.ensureLayout(for: textContainer)
            let newHeight = layoutManager.usedRect(for: textContainer).height
            self.parent.onHeightChange?(newHeight)
        }
    }
}

// CGRect için yardımcı uzantılar
extension CGRect {
    var center: CGPoint {
        CGPoint(x: midX, y: midY)
    }
    var endPoint: CGPoint {
        CGPoint(x: origin.x + size.width, y: origin.y + size.height)
    }
}

// Path'e ok çizme fonksiyonu ekleyen uzantı
extension Path {
    static func arrow(from start: CGPoint, to end: CGPoint, tailWidth: CGFloat, headWidth: CGFloat, headLength: CGFloat) -> Path {
        let length = hypot(end.x - start.x, end.y - start.y)
        let tailLength = length - headLength

        let points: [CGPoint] = [
            CGPoint(x: 0, y: tailWidth / 2),
            CGPoint(x: tailLength, y: tailWidth / 2),
            CGPoint(x: tailLength, y: headWidth / 2),
            CGPoint(x: length, y: 0),
            CGPoint(x: tailLength, y: -headWidth / 2),
            CGPoint(x: tailLength, y: -tailWidth / 2),
            CGPoint(x: 0, y: -tailWidth / 2)
        ]

        let cosine = (end.x - start.x) / length
        let sine = (end.y - start.y) / length
        let transform = CGAffineTransform(a: cosine, b: sine, c: -sine, d: cosine, tx: start.x, ty: start.y)

        return Path { path in
            let transformedPoints = points.map { $0.applying(transform) }
            path.addLines(transformedPoints)
            path.closeSubpath()
        }
    }
}
