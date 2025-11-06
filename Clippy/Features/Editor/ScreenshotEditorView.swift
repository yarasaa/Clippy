//
//  ScreenshotEditorView.swift
//  Clippy
//
//  Created by Mehmet Akbaba on 11.10.2025.
//

import SwiftUI
import Combine
import Vision

/// PreferenceKey for capturing view size
struct ViewSizeKey: PreferenceKey {
    static var defaultValue: CGSize = .zero
    static func reduce(value: inout CGSize, nextValue: () -> CGSize) {
        value = nextValue()
    }
}

/// Numara şekli
enum NumberShape: String, CaseIterable {
    case circle = "Circle"
    case square = "Square"
    case roundedSquare = "Rounded Square"
}

/// Şekil dolgu modu (fill mode)
enum FillMode: String, CaseIterable {
    case stroke = "Stroke"      // Sadece kenarlık
    case fill = "Fill"          // Sadece dolgu
    case both = "Both"          // Hem kenarlık hem dolgu

    var icon: String {
        switch self {
        case .stroke: return "square"
        case .fill: return "square.fill"
        case .both: return "square.inset.filled"
        }
    }
}

/// Düzenleme araçlarını temsil eden enum.
enum DrawingTool: String, CaseIterable, Identifiable {
    case select, move, arrow, rectangle, ellipse, line, text, pin, pixelate, eraser, highlighter, spotlight, emoji, pen

    var icon: String {
        switch self {
        case .select: return "cursorarrow.click"
        case .move: return "arrow.up.and.down.and.arrow.left.and.right"
        case .arrow: return "arrow.up.right"
        case .rectangle: return "square"
        case .ellipse: return "circle"
        case .line: return "line.diagonal"
        case .text: return "textformat"
        case .pin: return "mappin.and.ellipse"
        case .pixelate: return "square.grid.3x3.fill"
        case .eraser: return "eraser.line.dashed"
        case .highlighter: return "highlighter"
        case .spotlight: return "scope"
        case .emoji: return "face.smiling"
        case .pen: return "pencil.tip"
        }
    }

    var id: String {
        self.rawValue
    }

    /// Shape tool'lar mı?
    var isShape: Bool {
        switch self {
        case .rectangle, .ellipse, .line:
            return true
        default:
            return false
        }
    }

    /// Tool'un görünen adı (İngilizce - fallback)
    var displayName: String {
        switch self {
        case .select: return "Select"
        case .move: return "Move"
        case .arrow: return "Arrow"
        case .rectangle: return "Rectangle"
        case .ellipse: return "Ellipse"
        case .line: return "Line"
        case .text: return "Text"
        case .pin: return "Pin"
        case .pixelate: return "Redact"
        case .eraser: return "Eraser"
        case .highlighter: return "Highlighter"
        case .spotlight: return "Spotlight"
        case .emoji: return "Emoji"
        case .pen: return "Pen"
        }
    }

    /// Tool'un localize edilmiş adı
    var localizedName: String {
        let key: String
        switch self {
        case .select: key = "tool.select"
        case .move: key = "tool.move"
        case .arrow: key = "tool.arrow"
        case .rectangle: key = "tool.rectangle"
        case .ellipse: key = "tool.ellipse"
        case .line: key = "tool.line"
        case .text: key = "tool.text"
        case .pin: key = "tool.pin"
        case .pixelate: key = "tool.pixelate"
        case .eraser: key = "tool.eraser"
        case .highlighter: key = "tool.highlighter"
        case .spotlight: key = "tool.spotlight"
        case .emoji: key = "tool.emoji"
        case .pen: key = "tool.pen"
        }

        let localized = NSLocalizedString(key, tableName: nil, bundle: .main, value: displayName, comment: "")
        return localized
    }
}

/// Kalem (freehand) çizim için fırça stilleri
enum BrushStyle: String, CaseIterable, Identifiable {
    case solid = "Düz"
    case dashed = "Kesikli"
    case marker = "Marker"

    var id: String { self.rawValue }

    var displayName: String {
        switch self {
        case .solid: return "Solid"
        case .dashed: return "Dashed"
        case .marker: return "Marker"
        }
    }

    var localizedName: String {
        let key: String
        switch self {
        case .solid: key = "brush.solid"
        case .dashed: key = "brush.dashed"
        case .marker: key = "brush.marker"
        }

        let localized = NSLocalizedString(key, tableName: nil, bundle: .main, value: displayName, comment: "")
        return localized
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
    var number: Int? // Numaralandırma için
    var numberShape: NumberShape? // Numara şekli
    var startPoint: CGPoint? // Ok ve çizgi gibi yönlü araçlar için
    var endPoint: CGPoint?   // Ok ve çizgi gibi yönlü araçlar için
    var cornerRadius: CGFloat = 0 // Rectangle için köşe yuvarlama
    var fillMode: FillMode = .stroke // Şekiller için dolgu modu (stroke/fill/both)
    var spotlightShape: SpotlightShape? // Spotlight için şekil
    var emoji: String? // Emoji için seçilen emoji karakteri
    var path: [CGPoint]? // Freehand çizim için nokta dizisi
    var brushStyle: BrushStyle? // Pen tool için fırça stili
    var backgroundColor: Color? // Text için arka plan rengi (nil = şeffaf)
}

/// Spotlight için şekil seçenekleri
enum SpotlightShape: String, CaseIterable {
    case ellipse
    case rectangle

    var displayName: String {
        switch self {
        case .ellipse: return "Ellipse"
        case .rectangle: return "Rectangle"
        }
    }
}

/// Arka plan doldurma modelini tip güvenli şekilde temsil eder.
enum BackdropFillModel: Equatable {
    case solid(Color)
    case linearGradient(start: Color, end: Color, startPoint: UnitPoint, endPoint: UnitPoint)
}

/// Ekran görüntüsü düzenleyicisinin durumunu ve mantığını yöneten sınıf.
class ScreenshotEditorViewModel: ObservableObject {
    @Published var annotations: [Annotation] = []
    @Published var currentNumber: Int = 1 // Numaralandırma için sayaç

    deinit {
        // ViewModel temizlenirken annotations'ları da temizle
        annotations.removeAll()
        print("🧹 ScreenshotEditorViewModel: Deinit - Bellek serbest bırakıldı")
    }

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

    func updateAnnotationRect(at index: Int, newRect: CGRect, oldRect: CGRect, undoManager: UndoManager?) {
        guard index < annotations.count else { return }
        annotations[index].rect = newRect

        // Arrow ve line için startPoint ve endPoint'i de güncelle
        if annotations[index].tool == .arrow || annotations[index].tool == .line {
            annotations[index].startPoint = CGPoint(x: newRect.minX, y: newRect.minY)
            annotations[index].endPoint = CGPoint(x: newRect.maxX, y: newRect.maxY)
        }

        // Pen tool için path noktalarını scale et
        if annotations[index].tool == .pen, let path = annotations[index].path {
            let scaledPath = path.map { point in
                // Eski rect'e göre normalize et
                let normalizedX = (point.x - oldRect.minX) / oldRect.width
                let normalizedY = (point.y - oldRect.minY) / oldRect.height

                // Yeni rect'e göre scale et
                return CGPoint(
                    x: newRect.minX + normalizedX * newRect.width,
                    y: newRect.minY + normalizedY * newRect.height
                )
            }
            annotations[index].path = scaledPath
        }

        undoManager?.registerUndo(withTarget: self) { target in
            target.updateAnnotationRect(at: index, newRect: oldRect, oldRect: newRect, undoManager: undoManager)
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
    @Environment(\.dismiss) private var dismiss
    @State private var selectedTool: DrawingTool = .select
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

    // Color inspector
    @State private var showColorInspector = false
    @State private var inspectedColor: Color?
    @State private var mouseLocation: CGPoint = .zero

    // Shape ve line width seçimi için popover'lar
    @State private var showShapePicker = false
    @State private var showLineWidthPicker = false
    @State private var showEmojiPicker = false

    // Universal tool kontrol paneli
    @State private var showToolControls = false
    @State private var selectedAnnotationID: UUID? // Düzenlenmekte olan annotation

    // Tool-specific settings (varsayılan değerler, yeni annotation'lar için)
    @State private var numberSize: CGFloat = 40
    @State private var numberShape: NumberShape = .circle
    @State private var shapeCornerRadius: CGFloat = 0
    @State private var shapeFillMode: FillMode = .stroke
    @State private var spotlightShape: SpotlightShape = .ellipse // Spotlight için şekil
    @State private var selectedEmoji: String = "✅" // Emoji tool için seçili emoji
    @State private var emojiSize: CGFloat = 48 // Emoji boyutu
    @State private var selectedBrushStyle: BrushStyle = .solid // Pen tool için fırça stili

    // Zoom için durumlar
    @State private var zoomScale: CGFloat = 1.0 // 1.0 = %100, 2.0 = %200
    @State private var lastZoomScale: CGFloat = 1.0 // Magnification gesture için önceki zoom
    @State private var zoomAnchor: UnitPoint = .center // Zoom anchor noktası (mouse pozisyonu)
    @State private var contentSize: CGSize = .zero // ScrollView content size'ı takip etmek için

    // Backdrop efektleri için durumlar
    @State private var showEffectsPanel = false
    @State private var backdropPadding: CGFloat = 40
    @State private var screenshotShadowRadius: CGFloat = 25
    @State private var screenshotCornerRadius: CGFloat = 0

    @State private var backdropCornerRadius: CGFloat = 16
    @State private var backdropFill: AnyShapeStyle = AnyShapeStyle(Color(nsColor: .windowBackgroundColor).opacity(0.8))
    // Tip güvenli karşılığı; renderFinalImage bununla çalışır.
    @State private var backdropModel: BackdropFillModel = .solid(Color(nsColor: .windowBackgroundColor).opacity(0.8))
    @State private var backdropColor: Color = Color(nsColor: .windowBackgroundColor).opacity(0.8)

    // Memory management
    @State private var scrollWheelMonitor: Any?
    
    @Environment(\.undoManager) private var undoManager

    var body: some View {
        VStack(spacing: 0) {
            topToolbar

            GeometryReader { geometry in
                ScrollView([.horizontal, .vertical], showsIndicators: zoomScale > 1.0) {
                    ZStack { // Ana içerik ZStack'i
                        Color(nsColor: .textBackgroundColor)
                            .frame(
                                width: max(geometry.size.width, geometry.size.width * zoomScale),
                                height: max(geometry.size.height, geometry.size.height * zoomScale)
                            )

                        ZStack { // Backdrop Grubu
                    // 1. Arka Plan (Backdrop)
                    RoundedRectangle(cornerRadius: backdropCornerRadius)
                        .fill(backdropFill) // AnyShapeStyle ile doldur
                        .shadow(radius: screenshotShadowRadius / 2)

                    // 2. Görüntü ve Çizimleri
                    Image(nsImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .clipShape(RoundedRectangle(cornerRadius: screenshotCornerRadius))
                        .shadow(radius: screenshotShadowRadius)
                        .overlay(
                            GeometryReader { overlayGeometry in
                                    ZStack {
                                        Image(nsImage: image)
                                            .resizable()
                                            .aspectRatio(contentMode: .fit)
                                        DrawingCanvasView(image: image, viewModel: viewModel, selectedTool: $selectedTool, selectedColor: $selectedColor, selectedLineWidth: $selectedLineWidth, numberSize: $numberSize, numberShape: $numberShape, shapeCornerRadius: $shapeCornerRadius, shapeFillMode: $shapeFillMode, spotlightShape: $spotlightShape, selectedEmoji: $selectedEmoji, emojiSize: $emojiSize, selectedBrushStyle: $selectedBrushStyle, movingAnnotationID: $movingAnnotationID, dragOffset: $dragOffset, editingTextIndex: $editingTextIndex, showToolControls: $showToolControls, selectedAnnotationID: $selectedAnnotationID, isEditingText: $isEditingText, backdropPadding: backdropPadding, canvasSize: overlayGeometry.size, onTextAnnotationCreated: { [weak viewModel] id in
                                            // DÜZELTME: `self` (struct) yerine `viewModel` (class) üzerinde weak capture yap.
                                            guard let viewModel = viewModel else { return }
                                            if let index = viewModel.annotations.lastIndex(where: { $0.id == id }) {
                                                startEditingText(at: index)
                                            }
                                        }, onStartEditingText: { index in
                                            startEditingText(at: index)
                                        }, onStopEditingText: {
                                            stopEditingText()
                                        })

                                        // TÜM text annotation'ları overlay olarak göster
                                        ForEach(viewModel.annotations.filter { $0.tool == .text }) { annotation in
                                            if let index = viewModel.annotations.firstIndex(where: { $0.id == annotation.id }) {
                                                let isEditing = isEditingText && index == editingTextIndex

                                            // overlayGeometry, overlay içindeki gerçek alanı veriyor
                                            let imageSize = image.size
                                            let canvasSize = overlayGeometry.size

                                            // Scale faktörü - aspect fit
                                            let scale = min(canvasSize.width / imageSize.width, canvasSize.height / imageSize.height)

                                            // Ölçeklenmiş image'ın boyutu
                                            let scaledImageSize = CGSize(
                                                width: imageSize.width * scale,
                                                height: imageSize.height * scale
                                            )

                                            // Image aspect-fit ile ortalandığı için offset hesapla
                                            let imageOffset = CGPoint(
                                                x: (canvasSize.width - scaledImageSize.width) / 2,
                                                y: (canvasSize.height - scaledImageSize.height) / 2
                                            )

                                            // Canvas'ta annotation'ın gerçek konumu ve boyutu
                                            let canvasRect = CGRect(
                                                x: annotation.rect.origin.x * scale + imageOffset.x,
                                                y: annotation.rect.origin.y * scale + imageOffset.y,
                                                width: annotation.rect.width * scale,
                                                height: annotation.rect.height * scale
                                            )

                                            if isEditing {
                                                // Editing mode: TextEditor
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
                                                    font: .systemFont(ofSize: annotation.lineWidth * 4 * scale),
                                                    textColor: NSColor(annotation.color),
                                                    backgroundColor: annotation.backgroundColor.map { NSColor($0) },
                                                    onHeightChange: { newHeight in
                                                        // Yükseklik değiştiğinde annotation'ı güncelle (image koordinatlarında)
                                                        let imageHeight = newHeight / scale
                                                        if viewModel.annotations[index].rect.size.height != imageHeight {
                                                            viewModel.annotations[index].rect.size.height = imageHeight
                                                        }
                                                    },
                                                    onSizeChange: { newSize in
                                                        // Hem genişlik hem yükseklik değiştiğinde annotation'ı güncelle (image koordinatlarında)
                                                        let imageSize = CGSize(width: newSize.width / scale, height: newSize.height / scale)
                                                        if viewModel.annotations[index].rect.size != imageSize {
                                                            viewModel.annotations[index].rect.size = imageSize
                                                        }
                                                    }
                                                )
                                                .focused($isTextFieldFocused)
                                                .frame(width: canvasRect.width, height: canvasRect.height)
                                                .position(x: canvasRect.midX, y: canvasRect.midY)
                                                .onSubmit { stopEditingText() }
                                                .onExitCommand { stopEditingText() }
                                            }
                                            // Display mode: Text artık Canvas'ta çiziliyor, overlay'e gerek yok
                                            }
                                        }
                                    } // ZStack
                                } // GeometryReader
                        )
                        .clipShape(RoundedRectangle(cornerRadius: screenshotCornerRadius))
                        .padding(backdropPadding) // Inset
                }
                .frame(width: geometry.size.width, height: geometry.size.height) // Backdrop grubunu pencereye sığdır
                .frame(maxWidth: .infinity, maxHeight: .infinity) // ScrollView içinde ortala
                .scaleEffect(zoomScale, anchor: zoomAnchor) // Zoom uygula (mouse pozisyonuna göre)
                .coordinateSpace(name: "zoomableContent") // Koordinat uzayı tanımla
                .gesture(
                    MagnificationGesture()
                        .onChanged { value in
                            // Gesture değeri lastZoomScale'e göre hesaplanır
                            let newZoom = lastZoomScale * value
                            zoomScale = max(0.5, min(4.0, newZoom))
                        }
                        .onEnded { value in
                            // Gesture bittiğinde son zoom seviyesini kaydet
                            lastZoomScale = zoomScale
                        }
                )
            } // Ana içerik ZStack'i kapanışı
            } // ScrollView kapanışı
            .background(
                GeometryReader { scrollGeometry in
                    Color.clear.preference(key: ViewSizeKey.self, value: scrollGeometry.size)
                }
            )
            .onPreferenceChange(ViewSizeKey.self) { size in
                contentSize = size
            }
            .onAppear {
                // Mouse scroll wheel desteği için - event monitor'ı sakla
                scrollWheelMonitor = NSEvent.addLocalMonitorForEvents(matching: .scrollWheel) { event in
                    if event.modifierFlags.contains(.command) {
                        // Mouse pozisyonunu hesapla
                        if let window = event.window,
                           contentSize.width > 0 && contentSize.height > 0 {
                            // Window içindeki mouse pozisyonu
                            let mouseLocation = event.locationInWindow

                            // Window'un content view'ını al
                            if let contentView = window.contentView {
                                // Content view koordinatlarına çevir
                                let locationInContent = contentView.convert(mouseLocation, from: nil)

                                // Content view'ın frame'ini al
                                let contentFrame = contentView.frame

                                // Toolbar yüksekliğini hesaba kat (yaklaşık 60pt)
                                // SwiftUI koordinatları (sol-üst) ile AppKit (sol-alt) farkını düzelt
                                let adjustedY = contentFrame.height - locationInContent.y

                                // GeometryReader'ın başladığı noktayı bul
                                // Toolbar yaklaşık 60pt, bu yüzden çıkar
                                let toolbarHeight: CGFloat = 60
                                let relativeY = adjustedY - toolbarHeight

                                // Normalize et (0-1 arası)
                                let normalizedX = locationInContent.x / contentSize.width
                                let normalizedY = relativeY / contentSize.height

                                // Anchor'ı güncelle
                                zoomAnchor = UnitPoint(
                                    x: max(0, min(1, normalizedX)),
                                    y: max(0, min(1, normalizedY))
                                )
                            }
                        }

                        // Cmd + Scroll = Zoom (mouse pozisyonuna göre)
                        let delta = event.scrollingDeltaY
                        if delta > 0 {
                            // Zoom in
                            zoomScale = min(4.0, zoomScale + 0.1)
                        } else if delta < 0 {
                            // Zoom out
                            zoomScale = max(0.5, zoomScale - 0.1)
                        }
                        lastZoomScale = zoomScale
                        return nil // Event'i consume et
                    }
                    return event // Normal scroll için event'i geçir
                }
            }
            .onDisappear {
                // View kapatılırken belleği temizle
                cleanupResources()
            }
            } // GeometryReader kapanışı
            .cursor(currentCursor) // İmleci ayarla
            .frame(maxWidth: .infinity, maxHeight: .infinity) // Tüm alanı kapla
            .overlay(
                // Universal Tool Control Panel (sağ tarafta)
                HStack {
                    Spacer()

                    if showToolControls && selectedAnnotationID != nil {
                        ToolControlPanel(
                            isPresented: $showToolControls,
                            selectedAnnotationID: $selectedAnnotationID,
                            viewModel: viewModel,
                            selectedTool: selectedTool,
                            selectedColor: $selectedColor,
                            selectedLineWidth: $selectedLineWidth,
                            numberSize: $numberSize,
                            numberShape: $numberShape,
                            shapeCornerRadius: $shapeCornerRadius,
                            shapeFillMode: $shapeFillMode,
                            spotlightShape: $spotlightShape,
                            selectedEmoji: $selectedEmoji,
                            emojiSize: $emojiSize,
                            selectedBrushStyle: $selectedBrushStyle
                        )
                        .transition(.move(edge: .trailing).combined(with: .opacity))
                        .padding(.trailing, 20)
                        .padding(.top, 80)
                    }
                }
                , alignment: .topTrailing
            )
        }
        .frame(minWidth: 900, minHeight: 500)
    }

    
    /// Seçili olan araca göre uygun fare imlecini döndürür.
    private var currentCursor: NSCursor {
        switch selectedTool {
        case .select:
            return .arrow
        case .move:
            return movingAnnotationID != nil ? .closedHand : .openHand
        case .rectangle, .ellipse, .line, .arrow, .text, .pin, .pixelate, .eraser, .highlighter, .spotlight, .emoji, .pen:
            return .crosshair
        }
    }
    
    /// Modern üst araç çubuğu
    private var topToolbar: some View {
        HStack(spacing: 6) {
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

            // Shape Tool - Popover ile seçim
            Button(action: { showShapePicker.toggle() }) {
                VStack(spacing: 2) {
                    Image(systemName: selectedTool.isShape ? selectedTool.icon : "square")
                        .font(.title3)
                        .foregroundColor(selectedTool.isShape ? .accentColor : .secondary)
                        .frame(width: 28, height: 28)
                    Text(L("Shapes", settings: settings))
                        .font(.system(size: 9))
                        .foregroundColor(selectedTool.isShape ? .accentColor : .secondary)
                }
                .background(selectedTool.isShape ? Color.accentColor.opacity(0.15) : Color.clear)
                .cornerRadius(6)
            }
            .buttonStyle(.plain)
            .popover(isPresented: $showShapePicker, arrowEdge: .bottom) {
                ShapePickerView(selectedTool: $selectedTool, isPresented: $showShapePicker)
            }

            // Diğer Çizim Araçları (shape olmayan)
            ForEach(DrawingTool.allCases.filter { !$0.isShape }) { tool in
                Button(action: {
                    selectedTool = tool
                    // Spotlight için control panel'i aç
                    if tool == .spotlight {
                        showToolControls = true
                    }
                    // Pen için control panel'i aç
                    if tool == .pen {
                        showToolControls = true
                    }
                    // Emoji için emoji picker'ı aç
                    if tool == .emoji {
                        showEmojiPicker = true
                    }
                }) {
                    VStack(spacing: 2) {
                        Image(systemName: tool.icon)
                            .font(.title3)
                            .foregroundColor(selectedTool == tool ? .accentColor : .secondary)
                            .frame(width: 28, height: 28)
                        Text(tool.localizedName)
                            .font(.system(size: 9))
                            .foregroundColor(selectedTool == tool ? .accentColor : .secondary)
                    }
                    .background(selectedTool == tool ? Color.accentColor.opacity(0.15) : Color.clear)
                    .cornerRadius(6)
                }
                .buttonStyle(.plain)
                .popover(isPresented: tool == .emoji ? $showEmojiPicker : .constant(false), arrowEdge: .bottom) {
                    if tool == .emoji {
                        EmojiPickerView(selectedEmoji: $selectedEmoji, isPresented: $showEmojiPicker)
                    }
                }
            }

            // Number Controls (sadece number tool seçiliyken göster)
            if selectedTool == .pin {
                // Reset Button
                Button(action: { viewModel.currentNumber = 1 }) {
                    HStack(spacing: 4) {
                        Text("\(viewModel.currentNumber)")
                            .font(.caption.bold())
                            .foregroundColor(.accentColor)
                        Image(systemName: "arrow.counterclockwise")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    .frame(width: 40, height: 28)
                    .background(Color.secondary.opacity(0.1))
                    .cornerRadius(6)
                }
                .buttonStyle(.plain)
                .help(L("Reset numbering", settings: settings))
            }

            Divider()

            // Hand Tool - Image'ı sürükle-bırak ile kopyala
            Button(action: { startImageDrag() }) {
                VStack(spacing: 2) {
                    Image(systemName: "hand.raised.fill")
                        .font(.title3)
                        .foregroundColor(.accentColor)
                        .frame(width: 28, height: 28)
                    Text(L("Copy", settings: settings))
                        .font(.system(size: 9))
                        .foregroundColor(.accentColor)
                }
                .background(Color.accentColor.opacity(0.15))
                .cornerRadius(6)
            }
            .buttonStyle(.plain)

            Divider()

            // Renk ve Kalınlık Seçimi
            ColorPicker("", selection: $selectedColor, supportsOpacity: false)
                .labelsHidden()
                .frame(width: 28, height: 28)
            
            Text(showColorCopied ? L("Copied!", settings: settings) : selectedColor.hexString)
                .font(.system(.caption, design: .monospaced))
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.secondary.opacity(0.1))
                .cornerRadius(6)
                .help(L("Click to copy Hex code", settings: settings))
                .onTapGesture {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(selectedColor.hexString, forType: .string)
                    showColorCopied = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        showColorCopied = false
                    }
                }
            
            // Line Width - Görsel Popover
            Button(action: { showLineWidthPicker.toggle() }) {
                HStack(spacing: 4) {
                    Circle()
                        .fill(Color.secondary)
                        .frame(width: selectedLineWidth / 2, height: selectedLineWidth / 2)
                    Text(selectedLineWidth == 4 ? "S" : selectedLineWidth == 8 ? "M" : "L")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(width: 50, height: 28)
                .background(Color.secondary.opacity(0.1))
                .cornerRadius(6)
            }
            .buttonStyle(.plain)
            .help(L("Line Width", settings: settings))
            .popover(isPresented: $showLineWidthPicker, arrowEdge: .bottom) {
                LineWidthPickerView(selectedLineWidth: $selectedLineWidth, isPresented: $showLineWidthPicker)
            }
            
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

            // Zoom Controls
            HStack(spacing: 4) {
                Button(action: {
                    zoomScale = max(0.5, zoomScale - 0.25)
                    lastZoomScale = zoomScale
                }) {
                    Image(systemName: "minus.magnifyingglass")
                }
                .disabled(zoomScale <= 0.5)
                .buttonStyle(.plain)
                .help("Zoom Out")

                Text("\(Int(zoomScale * 100))%")
                    .font(.caption)
                    .frame(minWidth: 40)
                    .foregroundColor(.secondary)

                Button(action: {
                    zoomScale = min(4.0, zoomScale + 0.25)
                    lastZoomScale = zoomScale
                }) {
                    Image(systemName: "plus.magnifyingglass")
                }
                .disabled(zoomScale >= 4.0)
                .buttonStyle(.plain)
                .help("Zoom In")

                Button(action: {
                    zoomScale = 1.0
                    lastZoomScale = 1.0
                }) {
                    Image(systemName: "1.magnifyingglass")
                }
                .disabled(zoomScale == 1.0)
                .buttonStyle(.plain)
                .help("Reset Zoom (100%)")
            }

            Divider()

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
                .help(L("Copy Text from Image (OCR)", settings: settings))
                .disabled(isPerformingOCR)
                
                if settings.showImagesTab {
                    Button(action: saveToClippy) {
                        Image(systemName: "internaldrive")
                    }
                    .buttonStyle(.plain)
                    .help(L("Save to Clippy History", settings: settings))
                }
                
                Divider()

                Button(action: applyAnnotations) {
                    Image(systemName: "checkmark.circle.fill")
                    Text(L("Apply", settings: settings))
                }
                .buttonStyle(.bordered)
                .help(L("Apply annotations to image", settings: settings))
                .disabled(viewModel.annotations.isEmpty)
                .keyboardShortcut("a", modifiers: .command)

                Button(action: clearAllAnnotations) {
                    Image(systemName: "trash")
                    Text(L("Clear All", settings: settings))
                }
                .buttonStyle(.bordered)
                .help(L("Remove all annotations", settings: settings))
                .disabled(viewModel.annotations.isEmpty)
                .keyboardShortcut("k", modifiers: [.command, .shift])

                Button(action: saveImage) {
                    Image(systemName: "square.and.arrow.down")
                    Text("Save")
                }
                .buttonStyle(.borderedProminent)
                .help(L("Save to a file...", settings: settings))
                .keyboardShortcut("s", modifiers: .command)
                
                Button(action: {
                    // Cleanup yap sonra kapat
                    cleanupResources()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        NSApp.keyWindow?.close()
                    }
                }) {
                    Image(systemName: "xmark")
                }
                .buttonStyle(.plain)
                .help(L("Close Editor", settings: settings))
                .keyboardShortcut(.escape, modifiers: [])
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(height: 52)
        .background(.bar)
    }

    /// Tüm çizimleri Canvas üzerine işleyen fonksiyon
    private func drawAnnotations(context: inout GraphicsContext, canvasSize: CGSize) {
        // Bu fonksiyon artık sadece final render için kullanılıyor, bu yüzden sadece kaydedilmiş çizimleri çizer.
        print("🎨 [DEBUG] drawAnnotations called: \(viewModel.annotations.count) annotations, canvasSize: \(canvasSize)")
        for (index, annotation) in viewModel.annotations.enumerated() {
            var currentRect = annotation.rect
            print("🎨 [DEBUG] Annotation \(index): tool=\(annotation.tool), rect=\(currentRect)")
            if annotation.id == movingAnnotationID {
                currentRect = currentRect.offsetBy(dx: dragOffset.width, dy: dragOffset.height)
                context.addFilter(.shadow(color: .black.opacity(0.5), radius: 5))
            }
            drawSingleAnnotation(annotation, rect: currentRect, in: &context, canvasSize: canvasSize, nsImage: image)
        }
    }
    
    /// Tek bir annotation'ı çizen yardımcı fonksiyon
    private func drawSingleAnnotation(_ annotation: Annotation, rect: CGRect, in context: inout GraphicsContext, canvasSize: CGSize, nsImage: NSImage? = nil) {
        switch annotation.tool {
        case .rectangle:
            context.stroke(Path(rect), with: .color(annotation.color), lineWidth: annotation.lineWidth)
        case .ellipse:
            context.stroke(Path(ellipseIn: rect), with: .color(annotation.color), lineWidth: annotation.lineWidth)
        case .line:
            if let start = annotation.startPoint, let end = annotation.endPoint {
                var path = Path()
                path.move(to: start)
                path.addLine(to: end)
                context.stroke(path, with: .color(annotation.color), lineWidth: annotation.lineWidth)
            }
        case .highlighter:
            context.fill(Path(rect), with: .color(annotation.color.opacity(0.3)))
        case .arrow:
            let startPoint = CGPoint(x: rect.minX, y: rect.minY)
            let endPoint = CGPoint(x: rect.maxX, y: rect.maxY)
            if hypot(endPoint.x - startPoint.x, endPoint.y - startPoint.y) > annotation.lineWidth * 2 {
                let path = Path.arrow(from: startPoint, to: endPoint, tailWidth: annotation.lineWidth, headWidth: annotation.lineWidth * 3, headLength: annotation.lineWidth * 3)
                context.fill(path, with: .color(annotation.color))
            }
        case .pixelate:
            // GÜVENLİK: Tamamen opak siyah - parlaklık oynatılarak içerik görülemesin
            context.fill(Path(rect), with: .color(.black))
        case .pin:
            // Numara şekli - kullanıcının seçimine göre
            let diameter = rect.width
            let shapeRect = CGRect(x: rect.minX, y: rect.minY, width: diameter, height: diameter)

            // Arka plan şekli
            let shape = annotation.numberShape ?? .circle
            let shapePath: Path
            switch shape {
            case .circle:
                shapePath = Path(ellipseIn: shapeRect)
            case .square:
                shapePath = Path(shapeRect)
            case .roundedSquare:
                shapePath = Path(roundedRect: shapeRect, cornerRadius: diameter * 0.2)
            }
            context.fill(shapePath, with: .color(annotation.color))

            // Numara metni - tam merkezlenmiş
            if let number = annotation.number {
                let fontSize = diameter * 0.55
                let numberText = "\(number)"

                // Text'i merkeze hizalamak için resolved text kullan
                let text = Text(numberText)
                    .font(.system(size: fontSize, weight: .bold))
                    .foregroundColor(.white)

                // Text'i resolve et
                let resolved = context.resolve(text)

                // Text'i shape rect'in tam ortasına çiz - anchor point ile
                context.draw(resolved, at: CGPoint(x: shapeRect.midX, y: shapeRect.midY), anchor: .center)
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
        case .emoji:
            // Emoji çiz
            if let emoji = annotation.emoji {
                let fontSize = rect.width * 0.8 // Emoji boyutunu rect'e göre ayarla
                let emojiText = Text(emoji)
                    .font(.system(size: fontSize))

                // Text'i resolve et
                let resolved = context.resolve(emojiText)

                // Emoji'yi rect'in tam ortasına çiz
                context.draw(resolved, at: CGPoint(x: rect.midX, y: rect.midY), anchor: .center)
            }

        case .pen:
            // Freehand çizim - path noktalarını çiz
            if let path = annotation.path, path.count > 1 {
                var bezierPath = Path()
                bezierPath.move(to: path[0])
                for i in 1..<path.count {
                    bezierPath.addLine(to: path[i])
                }

                // Brush style'a göre çiz
                let brushStyle = annotation.brushStyle ?? .solid
                switch brushStyle {
                case .solid:
                    context.stroke(bezierPath, with: .color(annotation.color), lineWidth: annotation.lineWidth)
                case .dashed:
                    context.stroke(bezierPath, with: .color(annotation.color), style: StrokeStyle(lineWidth: annotation.lineWidth, dash: [10, 5]))
                case .marker:
                    context.stroke(bezierPath, with: .color(annotation.color.opacity(0.5)), style: StrokeStyle(lineWidth: annotation.lineWidth * 2, lineCap: .round, lineJoin: .round))
                }
            }

        case .spotlight:
            // Spotlight: Seçilen alan dışını karartma (even-odd rule ile)
            // Tüm canvas ve spotlight alanını içeren combined path oluştur
            var fullScreenPath = Path(CGRect(origin: .zero, size: canvasSize))

            // Spotlight alanını ekle
            let spotPath: Path
            if annotation.spotlightShape == .rectangle {
                spotPath = Path(roundedRect: rect, cornerRadius: 8)
            } else {
                spotPath = Path(ellipseIn: rect)
            }
            fullScreenPath.addPath(spotPath)

            // Even-odd fill rule ile spotlight alanı dışındaki her yeri karart
            context.fill(fullScreenPath, with: .color(.black.opacity(0.6)), style: FillStyle(eoFill: true))

            // Seçilen alanın etrafına ince kenarlık
            context.stroke(spotPath, with: .color(.white.opacity(0.5)), lineWidth: 2)

        case .move, .eraser, .select:
            break
        }

        // NOT: Highlight özelliği kaldırıldı - kullanıcı seçili annotation'ı kontrol panelinden anlayacak
    }


    private func renderFinalImage() -> NSImage {
        // OPTIMIZATION: Autoreleasepool ile RAM kullanımını minimize et
        return autoreleasepool {
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

            return createFinalImageWithBackdrop(annotatedImage: annotatedImage)
        }
    }

    private func createFinalImageWithBackdrop(annotatedImage: NSImage) -> NSImage {

        // 2. ADIM: Arka Planı ve Efektleri Ekleyerek Son Görüntüyü Oluştur
        let totalWidth = image.size.width + (backdropPadding * 2)
        let totalHeight = image.size.height + (backdropPadding * 2)
        let finalSize = NSSize(width: totalWidth, height: totalHeight)

        let finalImage = NSImage(size: finalSize)
        finalImage.cacheMode = .never // Memory optimization
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

    /// Annotations'ları görüntüye kalıcı olarak uygular
    private func applyAnnotations() {
        guard !viewModel.annotations.isEmpty else { return }

        let imageSize = image.size

        // Copy original image using bitmap representation - optimize memory
        guard let tiffData = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData) else {
            print("❌ Failed to get bitmap")
            return
        }

        // Mevcut image'ı release etmek için yeni bir referans oluştur
        let newImage = NSImage(size: imageSize)
        newImage.cacheMode = .never // Cache'lemeyi devre dışı bırak
        newImage.addRepresentation(bitmap)
        newImage.lockFocus()

        // Draw annotations with Y-coordinate conversion (SwiftUI Canvas -> AppKit)
        let imageHeight = image.size.height

        // ÖNCE tüm normal annotation'ları çiz
        for annotation in viewModel.annotations where annotation.tool != .spotlight {
            drawAnnotation(annotation, imageHeight: imageHeight)
        }

        // SON OLARAK spotlight'ları çiz (diğer annotation'ların ÜSTÜNe overlay olarak)
        let spotlights = viewModel.annotations.filter { $0.tool == .spotlight }
        if !spotlights.isEmpty {
            drawSpotlightsOverlay(spotlights, imageHeight: imageHeight)
        }

        newImage.unlockFocus()

        // Update - annotation'ları silmiyoruz, böylece üzerine daha fazla çizim yapılabilir
        image = newImage
        // viewModel.annotations.removeAll() // Artık silmiyoruz - non-destructive editing

        // Apply'dan sonra undo stack'i temizle - artık geri dönüş yok
        // Yeni annotation eklenince tekrar undo aktif olacak
        undoManager?.removeAllActions()
    }

    /// Tüm annotation'ları temizler
    private func clearAllAnnotations() {
        guard !viewModel.annotations.isEmpty else { return }

        viewModel.annotations.removeAll()
    }

    private func drawAnnotation(_ a: Annotation, imageHeight: CGFloat) {
        let c = NSColor(a.color)

        // Convert Y-coordinate from SwiftUI (top-left origin) to AppKit (bottom-left origin)
        func flipY(_ y: CGFloat) -> CGFloat {
            return imageHeight - y
        }

        func flipRect(_ rect: CGRect) -> CGRect {
            return CGRect(x: rect.origin.x,
                         y: flipY(rect.origin.y + rect.height),
                         width: rect.width,
                         height: rect.height)
        }

        switch a.tool {
        case .rectangle:
            let flipped = flipRect(a.rect)
            let cornerRadius = a.cornerRadius
            let p = NSBezierPath(roundedRect: flipped, xRadius: cornerRadius, yRadius: cornerRadius)

            // Fill mode'a göre çiz
            switch a.fillMode {
            case .fill:
                // Sadece dolgu
                c.setFill()
                p.fill()
            case .stroke:
                // Sadece kenarlık
                c.setStroke()
                p.lineWidth = a.lineWidth
                p.stroke()
            case .both:
                // Hem dolgu hem kenarlık
                c.withAlphaComponent(0.3).setFill()
                p.fill()
                c.setStroke()
                p.lineWidth = a.lineWidth
                p.stroke()
            }

        case .ellipse:
            let flipped = flipRect(a.rect)
            let p = NSBezierPath(ovalIn: flipped)

            // Fill mode'a göre çiz
            switch a.fillMode {
            case .fill:
                // Sadece dolgu
                c.setFill()
                p.fill()
            case .stroke:
                // Sadece kenarlık
                c.setStroke()
                p.lineWidth = a.lineWidth
                p.stroke()
            case .both:
                // Hem dolgu hem kenarlık
                c.withAlphaComponent(0.3).setFill()
                p.fill()
                c.setStroke()
                p.lineWidth = a.lineWidth
                p.stroke()
            }

        case .line:
            guard let s = a.startPoint, let e = a.endPoint else { return }
            let flippedStart = CGPoint(x: s.x, y: flipY(s.y))
            let flippedEnd = CGPoint(x: e.x, y: flipY(e.y))

            c.setStroke()
            let p = NSBezierPath()
            p.move(to: flippedStart)
            p.line(to: flippedEnd)
            p.lineWidth = a.lineWidth
            p.stroke()

        case .highlighter:
            c.withAlphaComponent(0.3).setFill()
            NSBezierPath(rect: flipRect(a.rect)).fill()

        case .arrow:
            guard let s = a.startPoint, let e = a.endPoint else { return }
            let flippedStart = CGPoint(x: s.x, y: flipY(s.y))
            let flippedEnd = CGPoint(x: e.x, y: flipY(e.y))

            c.setFill()
            let len = hypot(flippedEnd.x - flippedStart.x, flippedEnd.y - flippedStart.y)
            guard len > a.lineWidth * 2 else { return }

            let w = a.lineWidth
            let t = NSAffineTransform()
            t.translateX(by: flippedStart.x, yBy: flippedStart.y)
            t.rotate(byRadians: atan2(flippedEnd.y - flippedStart.y, flippedEnd.x - flippedStart.x))

            let pts: [NSPoint] = [
                NSPoint(x: 0, y: w/2),
                NSPoint(x: len - w*3, y: w/2),
                NSPoint(x: len - w*3, y: w*1.5),
                NSPoint(x: len, y: 0),
                NSPoint(x: len - w*3, y: -w*1.5),
                NSPoint(x: len - w*3, y: -w/2),
                NSPoint(x: 0, y: -w/2)
            ]

            let p = NSBezierPath()
            p.move(to: t.transform(pts[0]))
            pts.dropFirst().forEach { p.line(to: t.transform($0)) }
            p.close()
            p.fill()

        case .pin:
            guard let number = a.number else { return }
            let flippedRect = flipRect(a.rect)
            let diameter = flippedRect.width
            let shapeRect = CGRect(x: flippedRect.minX, y: flippedRect.minY, width: diameter, height: diameter)

            // Arka plan şekli - kullanıcının seçimine göre
            c.setFill()
            let shape = a.numberShape ?? .circle
            let shapePath: NSBezierPath
            switch shape {
            case .circle:
                shapePath = NSBezierPath(ovalIn: shapeRect)
            case .square:
                shapePath = NSBezierPath(rect: shapeRect)
            case .roundedSquare:
                shapePath = NSBezierPath(roundedRect: shapeRect, xRadius: diameter * 0.2, yRadius: diameter * 0.2)
            }
            shapePath.fill()

            // Numara metni - tam merkezlenmiş
            let numText = "\(number)"
            let paragraphStyle = NSMutableParagraphStyle()
            paragraphStyle.alignment = .center

            let attrs: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: diameter * 0.55, weight: .bold),
                .foregroundColor: NSColor.white,
                .paragraphStyle: paragraphStyle
            ]

            let textSize = numText.size(withAttributes: attrs)
            // Y ekseninde tam ortala (AppKit'te baseline compensation gerekli)
            let textRect = CGRect(
                x: shapeRect.minX,
                y: shapeRect.midY - textSize.height / 2 + diameter * 0.05, // Küçük offset ile görsel merkezleme
                width: diameter,
                height: textSize.height
            )
            numText.draw(in: textRect, withAttributes: attrs)

        case .text:
            guard !a.text.isEmpty else { return }
            let attrs: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: a.lineWidth * 4),
                .foregroundColor: c
            ]
            a.text.draw(in: flipRect(a.rect), withAttributes: attrs)

        case .pixelate:
            // Güvenlik için tamamen opak siyah - parlaklık oynatılarak içerik görülemesin
            NSColor.black.setFill()
            NSBezierPath(rect: flipRect(a.rect)).fill()

        case .spotlight:
            // Spotlight artık drawSpotlights() fonksiyonunda işleniyor
            // Burası boş bırakılabilir veya warning için break
            break

        case .pen:
            // Freehand çizim (Apply için - NSBezierPath)
            guard let path = a.path, path.count > 1 else { return }

            // Path noktalarını Y ekseni çevirisi ile oluştur
            let flippedPath = path.map { CGPoint(x: $0.x, y: flipY($0.y)) }

            c.setStroke()
            let bezierPath = NSBezierPath()
            bezierPath.move(to: flippedPath[0])
            for i in 1..<flippedPath.count {
                bezierPath.line(to: flippedPath[i])
            }

            // Brush style'a göre çiz
            let brushStyle = a.brushStyle ?? .solid
            switch brushStyle {
            case .solid:
                bezierPath.lineWidth = a.lineWidth
                bezierPath.stroke()
            case .dashed:
                bezierPath.lineWidth = a.lineWidth
                bezierPath.setLineDash([10, 5], count: 2, phase: 0)
                bezierPath.stroke()
            case .marker:
                // Marker: Kalın, yarı saydam
                c.withAlphaComponent(0.5).setStroke()
                bezierPath.lineWidth = a.lineWidth * 2
                bezierPath.lineCapStyle = .round
                bezierPath.lineJoinStyle = .round
                bezierPath.stroke()
                // Rengi geri yükle
                c.setStroke()
            }

        case .emoji:
            // Emoji çiz (Apply için)
            guard let emoji = a.emoji else { return }
            let flippedRect = flipRect(a.rect)
            let fontSize = flippedRect.width * 0.8

            let attrs: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: fontSize)
            ]

            // Emoji'yi merkeze hizala
            let emojiSize = emoji.size(withAttributes: attrs)
            let emojiRect = CGRect(
                x: flippedRect.midX - emojiSize.width / 2,
                y: flippedRect.midY - emojiSize.height / 2,
                width: emojiSize.width,
                height: emojiSize.height
            )
            emoji.draw(in: emojiRect, withAttributes: attrs)

        default:
            break
        }
    }

    /// Tüm spotlight annotation'larını overlay olarak çizer (en üstte)
    private func drawSpotlightsOverlay(_ spotlights: [Annotation], imageHeight: CGFloat) {
        guard !spotlights.isEmpty else { return }

        func flipRect(_ rect: CGRect) -> CGRect {
            return CGRect(x: rect.origin.x,
                         y: imageHeight - (rect.origin.y + rect.height),
                         width: rect.width,
                         height: rect.height)
        }

        // Tüm spotlight alanlarını toplayan path
        let spotlightAreas = NSBezierPath()
        for spotlight in spotlights {
            let spotPath: NSBezierPath
            if spotlight.spotlightShape == .rectangle {
                spotPath = NSBezierPath(roundedRect: flipRect(spotlight.rect), xRadius: 8, yRadius: 8)
            } else {
                spotPath = NSBezierPath(ovalIn: flipRect(spotlight.rect))
            }
            spotlightAreas.append(spotPath)
        }

        // Tüm ekran path'i oluştur
        let fullScreen = NSBezierPath(rect: CGRect(origin: .zero, size: image.size))

        // Even-odd winding rule ile spotlight alanları dışındaki her yeri karart
        fullScreen.append(spotlightAreas)
        fullScreen.windingRule = .evenOdd

        // Spotlight dışındaki alanları karart
        NSColor.black.withAlphaComponent(0.6).setFill()
        fullScreen.fill()

        // Spotlight kenarlıklarını çiz
        for spotlight in spotlights {
            let spotPath: NSBezierPath
            if spotlight.spotlightShape == .rectangle {
                spotPath = NSBezierPath(roundedRect: flipRect(spotlight.rect), xRadius: 8, yRadius: 8)
            } else {
                spotPath = NSBezierPath(ovalIn: flipRect(spotlight.rect))
            }
            NSColor.white.withAlphaComponent(0.5).setStroke()
            spotPath.lineWidth = 2
            spotPath.stroke()
        }
    }

    private func saveImage() {
        // Autoreleasepool ile memory kullanımını optimize et
        autoreleasepool {
            let finalImage = renderFinalImage()

            let savePanel = NSSavePanel()
            savePanel.canCreateDirectories = true
            savePanel.showsTagField = false
            savePanel.nameFieldStringValue = "screenshot-\(Int(Date().timeIntervalSince1970)).png"
            savePanel.level = .modalPanel
            savePanel.begin { response in
                if response == .OK, let url = savePanel.url {
                    // PNG conversion için ayrı autoreleasepool
                    autoreleasepool {
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
        // Autoreleasepool ile memory kullanımını optimize et
        autoreleasepool {
            let finalImage = renderFinalImage()
            clipboardMonitor.addImageToHistory(image: finalImage)
            print("✅ Görüntü Clippy geçmişine kaydedildi.")
        }

        // Window kapatılmadan önce cleanup yap
        cleanupResources()

        // Kısa bir delay ile window'u kapat (cleanup'ın tamamlanması için)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            NSApp.keyWindow?.close()
        }
    }
    
    private func performOCR() {
        guard !isPerformingOCR else { return }
        isPerformingOCR = true

        // Autoreleasepool ile CGImage conversion optimize et
        guard let cgImage = autoreleasepool(invoking: {
            image.cgImage(forProposedRect: nil, context: nil, hints: nil)
        }) else {
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
            // OCR processing için autoreleasepool
            autoreleasepool {
                do {
                    try VNImageRequestHandler(cgImage: cgImage, options: [:]).perform([request])
                } catch {
                    print("❌ OCR hatası: \(error)")
                    DispatchQueue.main.async { self.isPerformingOCR = false }
                }
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
        print("🚀 startEditingText çağrıldı, index: \(index)")
        print("   Annotation sayısı: \(viewModel.annotations.count)")
        if index < viewModel.annotations.count {
            print("   Annotation tool: \(viewModel.annotations[index].tool)")
            print("   Annotation rect: \(viewModel.annotations[index].rect)")
        }
        editingTextIndex = index
        isEditingText = true
        print("   isEditingText: \(isEditingText), editingTextIndex: \(String(describing: editingTextIndex))")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            self.isTextFieldFocused = true
            print("   ✅ Focus ayarlandı")
        }
    }

    private func stopEditingText() {
        // Not: Rect zaten onSizeChange callback'i ile düzenleme sırasında güncellenmiş durumda
        // Sadece editing state'lerini temizle
        isEditingText = false
        editingTextIndex = nil
        // İsteğe bağlı: Boş metin kutularını sil
        // viewModel.annotations.removeAll { $0.tool == .text && $0.text.isEmpty }
    }

    private func startImageDrag() {
        // Final rendered image'ı oluştur
        let finalImage = renderFinalImage()

        // NSPasteboard'a image'ı kopyala
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.writeObjects([finalImage])

        // Kullanıcıya bildirim
        NSSound.beep()
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

// MARK: - Memory Management Extension
extension ScreenshotEditorView {
    /// Bellek temizleme fonksiyonu
    private func cleanupResources() {
        print("🧹 ScreenshotEditor: Cleanup başladı...")

        // Event monitor'ı temizle
        if let monitor = scrollWheelMonitor {
            NSEvent.removeMonitor(monitor)
            scrollWheelMonitor = nil
            print("  ✓ Event monitor temizlendi")
        }

        // Undo manager'ı temizle
        undoManager?.removeAllActions()
        print("  ✓ Undo manager temizlendi")

        // Annotations'ları temizle
        let annotationCount = viewModel.annotations.count
        viewModel.annotations.removeAll()
        print("  ✓ \(annotationCount) annotation temizlendi")

        // State'leri reset et
        selectedAnnotationID = nil
        editingTextIndex = nil
        movingAnnotationID = nil

        // Text editing'i durdur
        if isEditingText {
            isEditingText = false
        }

        // CRITICAL: NSImage'ın tüm representation'larını temizle
        // Bu büyük bellek kullanımının ana kaynağı
        let representations = image.representations
        for rep in representations {
            image.removeRepresentation(rep)
        }
        print("  ✓ Image representations temizlendi (\(representations.count) adet)")

        // Image cache'ini temizle
        image.recache()
        print("  ✓ Image cache temizlendi")

        // Zoom ve view state'lerini resetle
        zoomScale = 1.0
        lastZoomScale = 1.0

        print("🧹 ScreenshotEditor: Bellek temizlendi - Toplam serbest bırakıldı")
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

    @EnvironmentObject var settings: SettingsManager
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
        ScrollView {
        VStack(alignment: .leading, spacing: 12) {
            
            // --- 1. SLIDER'LAR ---
            VStack(alignment: .leading, spacing: 8) {
                HStack { Text(L("Inset", settings: settings)).font(.caption); Spacer(); Text("\(Int(backdropPadding))").font(.caption2) }
                Slider(value: $backdropPadding, in: 0...150) // Max değeri artırdık
                
                HStack { Text(L("Shadow", settings: settings)).font(.caption); Spacer(); Text("\(Int(shadowRadius))").font(.caption2) }
                Slider(value: $shadowRadius, in: 0...100)
                
                HStack { Text(L("Outer Radius", settings: settings)).font(.caption); Spacer(); Text("\(Int(backdropCornerRadius))").font(.caption2) }
                Slider(value: $backdropCornerRadius, in: 0...100) // Max değeri artırdık
                
                HStack { Text(L("Inner Radius", settings: settings)).font(.caption); Spacer(); Text("\(Int(screenshotCornerRadius))").font(.caption2) }
                Slider(value: $screenshotCornerRadius, in: 0...100) // Max değeri artırdık
            }
            
            Divider()
            
            // --- 2. SEKMELER (TABS) ---
            Picker(L("Color Type", settings: settings), selection: $selectedTab) {
                Text(L("Solid", settings: settings)).tag(0)
                Text(L("Colormix", settings: settings)).tag(1)
                Text(L("Image", settings: settings)).tag(2)
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
                    ColorPicker(L("Custom Color", settings: settings), selection: $solidColor)
                        .padding(.top, 8)
                        .onChange(of: solidColor) {
                            backdropFill = AnyShapeStyle($0)
                            backdropModel = .solid($0)
                        }
                    
                } else if selectedTab == 1 { // Colormix
                    VStack(alignment: .leading) {
                        Text(L("Presets", settings: settings)).font(.caption)
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
                        Text(L("Custom Gradient", settings: settings)).font(.caption)
                        HStack {
                            ColorPicker(L("Start", settings: settings), selection: $gradientStartColor)
                            ColorPicker(L("End", settings: settings), selection: $gradientEndColor)
                            Spacer()
                        }
                        
                        Picker(L("Direction", settings: settings), selection: $gradientStartPoint) {
                            ForEach(gradientDirections) { Text(L($0.name, settings: settings)).tag($0.point) }
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
                        Text(L("Select an image for the backdrop", settings: settings)).font(.caption).foregroundColor(.secondary)
                        Button(L("Browse...", settings: settings)) { /* TODO: Resim seçme ekle */ }
                    }
                    .frame(maxWidth: .infinity, minHeight: 100)
                }
            }
            .frame(maxHeight: .infinity)

            Spacer()
            
            // --- 4. ALT BUTONLAR ---
            HStack {
                Button(L("Remove", settings: settings), role: .destructive) {
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
                Button(L("Ok", settings: settings)) { isPresented = false }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding()
        }
        .frame(width: 280, height: 500)
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
    @Binding var numberSize: CGFloat
    @Binding var numberShape: NumberShape
    @Binding var shapeCornerRadius: CGFloat
    @Binding var shapeFillMode: FillMode
    @Binding var spotlightShape: SpotlightShape
    @Binding var selectedEmoji: String
    @Binding var emojiSize: CGFloat
    @Binding var selectedBrushStyle: BrushStyle
    @Binding var movingAnnotationID: UUID?
    @Binding var dragOffset: CGSize
    @Binding var editingTextIndex: Int?
    @Binding var showToolControls: Bool
    @Binding var selectedAnnotationID: UUID?
    @Binding var isEditingText: Bool
    let backdropPadding: CGFloat
    let canvasSize: CGSize  // Overlay geometry'den gelen gerçek canvas boyutu
    var onTextAnnotationCreated: (UUID) -> Void
    var onStartEditingText: (Int) -> Void
    var onStopEditingText: () -> Void

    @Environment(\.undoManager) private var undoManager

    // Canlı çizim için yerel state'ler
    @State private var liveDrawingStart: CGPoint?
    @State private var liveDrawingEnd: CGPoint?
    @State private var liveDrawingPath: [CGPoint]? // Pen tool için path

    // Resize handles için state'ler
    @State private var resizingHandle: ResizeHandle?
    @State private var originalRect: CGRect?

    enum ResizeHandle {
        case topLeft, top, topRight
        case left, right
        case bottomLeft, bottom, bottomRight
    }

    var body: some View {
        Canvas { context, size in
            // overlayGeometry'den gelen canvasSize'ı kullan
            // Ölçek faktörünü hesapla - canvas'ın image'a göre ölçeği
            let imageSize = image.size
            let scale = min(canvasSize.width / imageSize.width, canvasSize.height / imageSize.height)

            // Ölçeklenmiş image'ın boyutu
            let scaledImageSize = CGSize(
                width: imageSize.width * scale,
                height: imageSize.height * scale
            )

            // Image aspect-fit ile ortalandığı için offset hesapla
            let imageOffset = CGPoint(
                x: (canvasSize.width - scaledImageSize.width) / 2,
                y: (canvasSize.height - scaledImageSize.height) / 2
            )

                // 1. Mevcut (kaydedilmiş) çizimleri çiz - image koordinatlarından canvas koordinatlarına
                for annotation in viewModel.annotations {
                    // Image koordinatlarını canvas koordinatlarına dönüştür (scale + offset)
                    var displayRect = CGRect(
                        x: annotation.rect.origin.x * scale + imageOffset.x,
                        y: annotation.rect.origin.y * scale + imageOffset.y,
                        width: annotation.rect.width * scale,
                        height: annotation.rect.height * scale
                    )

                    let isMoving = annotation.id == movingAnnotationID
                    if isMoving {
                        displayRect = displayRect.offsetBy(dx: dragOffset.width, dy: dragOffset.height)
                        context.addFilter(.shadow(color: .black.opacity(0.5), radius: 5))
                    }

                    var displayAnnotation = annotation
                    displayAnnotation.rect = displayRect
                    displayAnnotation.lineWidth = annotation.lineWidth * scale
                    if let start = annotation.startPoint {
                        var displayStart = CGPoint(
                            x: start.x * scale + imageOffset.x,
                            y: start.y * scale + imageOffset.y
                        )
                        // Taşınıyorsa offset uygula
                        if isMoving {
                            displayStart.x += dragOffset.width
                            displayStart.y += dragOffset.height
                        }
                        displayAnnotation.startPoint = displayStart
                    }
                    if let end = annotation.endPoint {
                        var displayEnd = CGPoint(
                            x: end.x * scale + imageOffset.x,
                            y: end.y * scale + imageOffset.y
                        )
                        // Taşınıyorsa offset uygula
                        if isMoving {
                            displayEnd.x += dragOffset.width
                            displayEnd.y += dragOffset.height
                        }
                        displayAnnotation.endPoint = displayEnd
                    }
                    if let path = annotation.path {
                        displayAnnotation.path = path.map { point in
                            var displayPoint = CGPoint(
                                x: point.x * scale + imageOffset.x,
                                y: point.y * scale + imageOffset.y
                            )
                            // Taşınıyorsa offset uygula
                            if isMoving {
                                displayPoint.x += dragOffset.width
                                displayPoint.y += dragOffset.height
                            }
                            return displayPoint
                        }
                    }

                    drawSingleAnnotation(displayAnnotation, rect: displayRect, in: &context, canvasSize: size, nsImage: image)
                }

                // 2. Canlı (o an çizilen) şekli çiz
                if let start = liveDrawingStart, let end = liveDrawingEnd {
                    let rect = CGRect(from: start, to: end)
                    var liveAnnotation = Annotation(rect: rect, color: selectedColor, lineWidth: selectedLineWidth, tool: selectedTool)
                    liveAnnotation.startPoint = start
                    liveAnnotation.endPoint = end

                    // Tool-specific properties ekle (live preview için)
                    if selectedTool == .spotlight {
                        liveAnnotation.spotlightShape = spotlightShape
                    }

                    drawSingleAnnotation(liveAnnotation, rect: rect, in: &context, canvasSize: size, nsImage: image)
                }

                // 2b. Canlı freehand çizim (pen tool)
                if let path = liveDrawingPath, path.count > 1 {
                    // Path noktalarını canvas koordinatlarına dönüştür
                    let canvasPath = path.map { point in
                        CGPoint(
                            x: point.x * scale + imageOffset.x,
                            y: point.y * scale + imageOffset.y
                        )
                    }

                    // Path oluştur
                    var bezierPath = Path()
                    bezierPath.move(to: canvasPath[0])
                    for i in 1..<canvasPath.count {
                        bezierPath.addLine(to: canvasPath[i])
                    }

                    // Brush style'a göre çiz
                    let scaledLineWidth = selectedLineWidth * scale
                    switch selectedBrushStyle {
                    case .solid:
                        context.stroke(bezierPath, with: .color(selectedColor), lineWidth: scaledLineWidth)
                    case .dashed:
                        context.stroke(bezierPath, with: .color(selectedColor), style: StrokeStyle(lineWidth: scaledLineWidth, dash: [10, 5]))
                    case .marker:
                        context.stroke(bezierPath, with: .color(selectedColor.opacity(0.5)), style: StrokeStyle(lineWidth: scaledLineWidth * 2, lineCap: .round, lineJoin: .round))
                    }
                }

                // 3. Seçili annotation için resize handle'ları ve selection border çiz
                if let selectedID = selectedAnnotationID,
                   let selectedAnnotation = viewModel.annotations.first(where: { $0.id == selectedID }) {

                    // Annotation'ın display rect'ini hesapla (scale ve offset ile)
                    var originalRect = selectedAnnotation.rect

                    // Text için gerçek render boyutunu hesapla
                    if selectedAnnotation.tool == .text && !selectedAnnotation.text.isEmpty {
                        let font = NSFont.systemFont(ofSize: selectedAnnotation.lineWidth * 4)
                        let textAttributes: [NSAttributedString.Key: Any] = [.font: font]
                        let textSize = (selectedAnnotation.text as NSString).boundingRect(
                            with: CGSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude),
                            options: [.usesLineFragmentOrigin, .usesFontLeading],
                            attributes: textAttributes
                        ).size

                        // Padding ekle (8pt yatay, 4pt dikey)
                        let paddedWidth = textSize.width + 16
                        let paddedHeight = textSize.height + 8

                        originalRect = CGRect(
                            x: originalRect.origin.x,
                            y: originalRect.origin.y,
                            width: paddedWidth,
                            height: paddedHeight
                        )
                    }

                    let displayRect = CGRect(
                        x: originalRect.minX * scale + imageOffset.x,
                        y: originalRect.minY * scale + imageOffset.y,
                        width: originalRect.width * scale,
                        height: originalRect.height * scale
                    )

                    // Handle pozisyonlarını al ve çiz (tool'a göre)
                    let handlePositions = getHandlePositions(for: displayRect, tool: selectedAnnotation.tool)
                    let handleSize: CGFloat = 8

                    for (_, position) in handlePositions {
                        let handleRect = CGRect(x: position.x - handleSize / 2,
                                               y: position.y - handleSize / 2,
                                               width: handleSize,
                                               height: handleSize)

                        // Beyaz handle ile mavi kenarlık
                        context.fill(Path(ellipseIn: handleRect), with: .color(.white))
                        context.stroke(Path(ellipseIn: handleRect), with: .color(.blue), lineWidth: 2)
                    }
                }
            }
            .gesture(drawingGesture(in: canvasSize))
            .onTapGesture(count: 2) { location in
                // Çift tıklama - text annotation'ları edit moduna sokar
                handleDoubleTap(at: location, in: canvasSize)
            }
            .onContinuousHover { phase in
                switch phase {
                case .active(let location):
                    updateCursor(at: location, in: canvasSize)
                case .ended:
                    NSCursor.arrow.set()
                }
            }
    }

    // Çift tıklama handler'ı
    private func handleDoubleTap(at location: CGPoint, in canvasSize: CGSize) {
        let imageSize = image.size
        let scale = min(canvasSize.width / imageSize.width, canvasSize.height / imageSize.height)
        let scaledImageSize = CGSize(width: imageSize.width * scale, height: imageSize.height * scale)
        let imageOffset = CGPoint(
            x: (canvasSize.width - scaledImageSize.width) / 2,
            y: (canvasSize.height - scaledImageSize.height) / 2
        )

        let imageLocation = CGPoint(
            x: (location.x - imageOffset.x) / scale,
            y: (location.y - imageOffset.y) / scale
        )

        // Text annotation üzerinde mi kontrol et
        if let (id, index) = findAnnotation(at: imageLocation) {
            let annotation = viewModel.annotations[index]
            if annotation.tool == .text {
                selectedAnnotationID = id
                selectedTool = .select // Select mode'a geç
                onStartEditingText(index)
                showToolControls = true
            }
        }
    }

    // Cursor'u mouse pozisyonuna göre güncelle
    private func updateCursor(at location: CGPoint, in canvasSize: CGSize) {
        let imageSize = image.size
        let scale = min(canvasSize.width / imageSize.width, canvasSize.height / imageSize.height)
        let scaledImageSize = CGSize(width: imageSize.width * scale, height: imageSize.height * scale)
        let imageOffset = CGPoint(
            x: (canvasSize.width - scaledImageSize.width) / 2,
            y: (canvasSize.height - scaledImageSize.height) / 2
        )

        let imageLocation = CGPoint(
            x: (location.x - imageOffset.x) / scale,
            y: (location.y - imageOffset.y) / scale
        )

        // Eraser hariç tüm tool'larda annotation üzerinde move cursor göster
        if selectedTool != .eraser {
            // Önce mevcut seçili annotation'ın handle'larını kontrol et (select/move tool'da)
            if (selectedTool == .select || selectedTool == .move) {
                if let selectedID = selectedAnnotationID,
                   let annotation = viewModel.annotations.first(where: { $0.id == selectedID }),
                   !isEditingText {
                    if let _ = detectHandle(at: imageLocation, for: annotation.rect, tool: annotation.tool) {
                        // Handle üzerindeyse resize cursor göster
                        NSCursor.crosshair.set()
                        return
                    }
                }
            }

            // Herhangi bir annotation üzerinde mi kontrol et - TÜM TOOL'LARDA
            if let _ = findAnnotation(at: imageLocation) {
                NSCursor.openHand.set()
                return
            }
        }

        // Default cursor - tool'a göre
        switch selectedTool {
        case .pen:
            NSCursor.crosshair.set()
        case .eraser:
            NSCursor.crosshair.set()
        default:
            NSCursor.arrow.set()
        }
    }

    // Tüm çizim, silme ve taşıma işlemlerini yöneten tek gesture
    private func drawingGesture(in canvasSize: CGSize) -> some Gesture {
        // Koordinat dönüşümü için ölçek faktörünü ve offset'i hesapla
        let imageSize = image.size
        let scale = min(canvasSize.width / imageSize.width, canvasSize.height / imageSize.height)

        // Ölçeklenmiş image'ın boyutu
        let scaledImageSize = CGSize(
            width: imageSize.width * scale,
            height: imageSize.height * scale
        )

        // Image aspect-fit ile ortalandığı için offset hesapla
        let imageOffset = CGPoint(
            x: (canvasSize.width - scaledImageSize.width) / 2,
            y: (canvasSize.height - scaledImageSize.height) / 2
        )

        // Canvas koordinatlarını image koordinatlarına dönüştürme fonksiyonu
        func toImageCoords(_ point: CGPoint) -> CGPoint {
            return CGPoint(
                x: (point.x - imageOffset.x) / scale,
                y: (point.y - imageOffset.y) / scale
            )
        }

        func toImageSize(_ size: CGSize) -> CGSize {
            return CGSize(width: size.width / scale, height: size.height / scale)
        }

        return DragGesture(minimumDistance: 0, coordinateSpace: .local)
            .onChanged { value in
                let imageLocation = toImageCoords(value.location)

                // Annotation taşıma sadece taşıma devam ediyorsa (tüm tool'larda)
                if movingAnnotationID != nil {
                    dragOffset = value.translation
                    return
                }

                switch selectedTool {
                case .select:
                    // Select tool - resize handle kontrolü veya direkt sürükleme
                    if resizingHandle == nil, movingAnnotationID == nil {
                        if let selectedID = selectedAnnotationID,
                           let annotation = viewModel.annotations.first(where: { $0.id == selectedID }) {
                            // Text düzenleniyorsa sürüklemeyi engelle
                            let isEditingThisText = isEditingText && viewModel.annotations.firstIndex(where: { $0.id == selectedID }) == editingTextIndex

                            if !isEditingThisText {
                                // Önce handle kontrolü yap
                                if let handle = detectHandle(at: imageLocation, for: annotation.rect, tool: annotation.tool) {
                                    resizingHandle = handle
                                    originalRect = annotation.rect
                                } else if annotation.rect.contains(imageLocation) {
                                    // Handle değilse ama annotation içindeyse, taşıma başlat
                                    movingAnnotationID = selectedID
                                    dragOffset = .zero
                                } else if let (id, index) = findAnnotation(at: imageLocation) {
                                    // Başka bir annotation'a tıklandıysa
                                    let clickedAnnotation = viewModel.annotations[index]
                                    selectedAnnotationID = id

                                    // Text ise ve düzenleme modundaysa taşımayı engelle
                                    // Diğer durumlarda (text düzenleme modunda değilse veya text değilse) taşımaya başla
                                    let isEditingThisText = clickedAnnotation.tool == .text && isEditingText && editingTextIndex == index
                                    if !isEditingThisText {
                                        movingAnnotationID = id
                                        dragOffset = .zero
                                    }
                                }
                            }
                        } else if let (id, index) = findAnnotation(at: imageLocation) {
                            // Hiç seçili yoksa, tıklanan annotation'ı seç
                            let clickedAnnotation = viewModel.annotations[index]
                            selectedAnnotationID = id

                            // Text ise ve düzenleme modundaysa taşımayı engelle
                            // Diğer durumlarda taşımaya başla
                            let isEditingThisText = clickedAnnotation.tool == .text && isEditingText && editingTextIndex == index
                            if !isEditingThisText {
                                movingAnnotationID = id
                                dragOffset = .zero
                            }
                        }
                    }

                    // Handle resize sürükleme işlemi
                    if let handle = resizingHandle, let original = originalRect,
                       let selectedID = selectedAnnotationID,
                       let index = viewModel.annotations.firstIndex(where: { $0.id == selectedID }) {
                        let newRect = calculateResizedRect(originalRect: original, handle: handle, dragTo: imageLocation)
                        viewModel.annotations[index].rect = newRect

                        // startPoint ve endPoint'i de güncelle (arrow, line gibi şekiller için)
                        if viewModel.annotations[index].tool == .arrow || viewModel.annotations[index].tool == .line {
                            viewModel.annotations[index].startPoint = CGPoint(x: newRect.minX, y: newRect.minY)
                            viewModel.annotations[index].endPoint = CGPoint(x: newRect.maxX, y: newRect.maxY)
                        }
                    } else if movingAnnotationID != nil {
                        // Normal taşıma işlemi (move tool ile aynı mantık)
                        dragOffset = value.translation
                    }
                case .move:
                    // Move tool - resize handle kontrolü öncelikli
                    if resizingHandle == nil, movingAnnotationID == nil {
                        if let selectedID = selectedAnnotationID,
                           let annotation = viewModel.annotations.first(where: { $0.id == selectedID }) {
                            // Önce handle kontrolü yap
                            if let handle = detectHandle(at: imageLocation, for: annotation.rect, tool: annotation.tool) {
                                resizingHandle = handle
                                originalRect = annotation.rect
                            } else if let (id, _) = findAnnotation(at: imageLocation) {
                                // Handle değilse normal taşıma başlat
                                movingAnnotationID = id
                                dragOffset = .zero
                            }
                        } else if let (id, _) = findAnnotation(at: imageLocation) {
                            movingAnnotationID = id
                            dragOffset = .zero
                        }
                    }

                    // Handle resize sürükleme işlemi
                    if let handle = resizingHandle, let original = originalRect,
                       let selectedID = selectedAnnotationID,
                       let index = viewModel.annotations.firstIndex(where: { $0.id == selectedID }) {
                        let newRect = calculateResizedRect(originalRect: original, handle: handle, dragTo: imageLocation)
                        viewModel.annotations[index].rect = newRect

                        // startPoint ve endPoint'i de güncelle
                        if viewModel.annotations[index].tool == .arrow || viewModel.annotations[index].tool == .line {
                            viewModel.annotations[index].startPoint = CGPoint(x: newRect.minX, y: newRect.minY)
                            viewModel.annotations[index].endPoint = CGPoint(x: newRect.maxX, y: newRect.maxY)
                        }
                    } else if movingAnnotationID != nil {
                        // Normal taşıma işlemi
                        dragOffset = value.translation
                    }
                case .eraser:
                     if let (id, _) = findAnnotation(at: imageLocation) {
                        viewModel.removeAnnotation(with: id, undoManager: undoManager)
                    }
                case .pin, .emoji:
                    // Pin ve emoji toolları için önce resize handle kontrolü
                    if resizingHandle == nil,
                       let selectedID = selectedAnnotationID,
                       let annotation = viewModel.annotations.first(where: { $0.id == selectedID }) {
                        // Handle'a tıklanmış mı kontrol et
                        if let handle = detectHandle(at: imageLocation, for: annotation.rect, tool: annotation.tool) {
                            resizingHandle = handle
                            originalRect = annotation.rect
                        }
                        // Handle değilse hiçbir şey yapma - onEnded'de oluşturacak
                    } else if resizingHandle != nil {
                        // Resize işlemi devam ediyor
                        if let handle = resizingHandle, let original = originalRect,
                           let selectedID = selectedAnnotationID,
                           let index = viewModel.annotations.firstIndex(where: { $0.id == selectedID }) {
                            let newRect = calculateResizedRect(originalRect: original, handle: handle, dragTo: imageLocation)
                            viewModel.annotations[index].rect = newRect
                        }
                    }
                    // Resize değilse hiçbir şey yapma - sadece onEnded'de oluştur
                case .text:
                    // Text tool - hiçbir şey yapma, onEnded'de oluşturacak
                    // Sürüklemeye izin verme
                    break

                case .pen:
                    // Eğer annotation taşıma başladıysa, pen çizme
                    if movingAnnotationID != nil {
                        break
                    }

                    // Freehand çizim - sürekli path oluşturma
                    if liveDrawingPath == nil {
                        // Yeni path başlat
                        liveDrawingPath = [imageLocation]
                    } else {
                        // Mevcut path'e nokta ekle
                        liveDrawingPath?.append(imageLocation)
                    }
                default: // Diğer tüm çizim araçları (rectangle, ellipse, line, arrow, etc.)
                    // Eğer annotation taşıma başladıysa, bu case'de hiçbir şey yapma
                    if movingAnnotationID != nil {
                        break
                    }

                    // ÖNCELİK 1: Resize handle kontrolü (HER DURUMDA)
                    if resizingHandle == nil, liveDrawingStart == nil,
                       let selectedID = selectedAnnotationID,
                       let annotation = viewModel.annotations.first(where: { $0.id == selectedID }) {
                        // Handle'a tıklanmış mı kontrol et - tool fark etmeksizin
                        if let handle = detectHandle(at: imageLocation, for: annotation.rect, tool: annotation.tool) {
                            resizingHandle = handle
                            originalRect = annotation.rect
                        } else if annotation.tool == selectedTool {
                            // Handle değilse ve tool eşleşiyorsa normal çizime başla
                            liveDrawingStart = value.location
                            liveDrawingEnd = value.location
                        } else {
                            // Tool eşleşmiyorsa yeni şekil çiz
                            liveDrawingStart = value.location
                            liveDrawingEnd = value.location
                        }
                    } else if resizingHandle != nil {
                        // Resize işlemi devam ediyor
                        if let handle = resizingHandle, let original = originalRect,
                           let selectedID = selectedAnnotationID,
                           let index = viewModel.annotations.firstIndex(where: { $0.id == selectedID }) {
                            let newRect = calculateResizedRect(originalRect: original, handle: handle, dragTo: imageLocation)
                            viewModel.annotations[index].rect = newRect

                            // startPoint ve endPoint'i de güncelle
                            if viewModel.annotations[index].tool == .arrow || viewModel.annotations[index].tool == .line {
                                viewModel.annotations[index].startPoint = CGPoint(x: newRect.minX, y: newRect.minY)
                                viewModel.annotations[index].endPoint = CGPoint(x: newRect.maxX, y: newRect.maxY)
                            }
                        }
                    } else {
                        // Normal çizim işlemi
                        if liveDrawingStart == nil {
                            liveDrawingStart = value.location
                        }
                        liveDrawingEnd = value.location
                    }
                }
            }
            .onEnded { value in
                let imageLocation = toImageCoords(value.location)
                let imageTranslation = toImageSize(value.translation)
                let dragDistance = hypot(value.translation.width, value.translation.height)

                // UNIVERSAL ANNOTATION INTERACTION - EN YÜKSEK ÖNCELİK

                // 0. Resize işlemi tamamlandıysa (HER TOOL İÇİN)
                // Sadece gerçekten sürükleme yapıldıysa resize kaydet
                if resizingHandle != nil, let original = originalRect,
                   let selectedID = selectedAnnotationID,
                   let index = viewModel.annotations.firstIndex(where: { $0.id == selectedID }) {

                    if dragDistance >= 5 {
                        // Gerçek resize - undo'ya kaydet
                        let finalRect = viewModel.annotations[index].rect
                        viewModel.updateAnnotationRect(at: index, newRect: finalRect, oldRect: original, undoManager: undoManager)
                        resizingHandle = nil
                        self.originalRect = nil
                        // Seçili kal, menü açık kal
                        return
                    } else {
                        // Küçük hareket veya tıklama - resize state'i temizle ve normal akışa devam et
                        resizingHandle = nil
                        self.originalRect = nil
                        // Normal akışa devam et (fall through)
                    }
                }

                // 1. Eğer annotation taşıma tamamlandıysa
                if let movingID = movingAnnotationID, let index = viewModel.annotations.firstIndex(where: { $0.id == movingID }) {
                    if dragDistance >= 5 {
                        // Taşıma işlemi tamamlandı
                        let oldRect = viewModel.annotations[index].rect
                        let newRect = oldRect.offsetBy(dx: imageTranslation.width, dy: imageTranslation.height)
                        viewModel.moveAnnotation(at: index, to: newRect, from: oldRect, undoManager: undoManager)

                        // Arrow ve line için startPoint ve endPoint'i de taşı
                        let tool = viewModel.annotations[index].tool
                        if tool == .arrow || tool == .line {
                            if let start = viewModel.annotations[index].startPoint,
                               let end = viewModel.annotations[index].endPoint {
                                viewModel.annotations[index].startPoint = CGPoint(
                                    x: start.x + imageTranslation.width,
                                    y: start.y + imageTranslation.height
                                )
                                viewModel.annotations[index].endPoint = CGPoint(
                                    x: end.x + imageTranslation.width,
                                    y: end.y + imageTranslation.height
                                )
                            }
                        }

                        // Taşıma sonrası: seçili kal, menü açık kal
                        selectedAnnotationID = movingID
                        showToolControls = true
                        movingAnnotationID = nil
                        dragOffset = .zero

                        // Tüm tool state'lerini temizle
                        liveDrawingStart = nil
                        liveDrawingEnd = nil
                        liveDrawingPath = nil
                        resizingHandle = nil
                        self.originalRect = nil

                        return
                    } else {
                        // Küçük hareket - sadece seçim yap
                        selectedAnnotationID = movingID
                        showToolControls = true
                        movingAnnotationID = nil
                        dragOffset = .zero

                        liveDrawingStart = nil
                        liveDrawingEnd = nil
                        liveDrawingPath = nil

                        return
                    }
                }

                // 2. Boş alan kontrolü (sadece select/move/eraser için)
                if selectedTool == .select || selectedTool == .move {
                    if let (id, _) = findAnnotation(at: imageLocation) {
                        selectedAnnotationID = id
                        showToolControls = true
                        return
                    } else {
                        // Boş yere tıklandı - menüyü kapat, resize/taşıma state'lerini temizle
                        selectedAnnotationID = nil
                        showToolControls = false
                        resizingHandle = nil
                        self.originalRect = nil
                        movingAnnotationID = nil
                        dragOffset = .zero
                        if isEditingText {
                            onStopEditingText()
                        }
                    }
                } else if selectedTool == .eraser {
                    // Eraser için boş yere tıklayınca menüyü kapat
                    if dragDistance < 5 {
                        selectedAnnotationID = nil
                        showToolControls = false
                    }
                }
                // Diğer tool'lar: Annotation'a tıklansa bile yeni şekil çizilsin, sadece kendi annotation'ını seçsin

                switch selectedTool {
                case .select:
                    // Universal logic zaten her şeyi hallediyor
                    break
                case .move:
                    // Universal logic zaten her şeyi hallediyor
                    break
                case .eraser:
                    break // Silme işlemi onChanged'de yapılıyor.
                case .pin:
                    // Number tool - tek tıklama ile kullanıcı tarafından ayarlanmış boyutlu numara oluştur
                    let rect = CGRect(
                        x: imageLocation.x - numberSize / 2,
                        y: imageLocation.y - numberSize / 2,
                        width: numberSize,
                        height: numberSize
                    )

                    var newAnnotation = Annotation(rect: rect, color: selectedColor, lineWidth: selectedLineWidth, tool: .pin)
                    newAnnotation.number = viewModel.currentNumber
                    newAnnotation.numberShape = numberShape
                    viewModel.currentNumber += 1
                    viewModel.addAnnotation(newAnnotation, undoManager: undoManager)

                    // Kontrol panelini aç ve bu annotation'ı seç
                    selectedAnnotationID = newAnnotation.id
                    showToolControls = true

                    // Select moduna dön - böylece shapes popup kapanır
                    selectedTool = .select

                case .pen:
                    // Universal annotation interaction zaten tamamlandıysa, hiçbir şey yapma
                    if movingAnnotationID != nil {
                        break
                    }

                    // Freehand çizim tamamlandı - path'i annotation olarak kaydet
                    if let path = liveDrawingPath, path.count > 1 {
                        // Path'in bounding box'ını hesapla
                        let minX = path.map { $0.x }.min() ?? 0
                        let maxX = path.map { $0.x }.max() ?? 0
                        let minY = path.map { $0.y }.min() ?? 0
                        let maxY = path.map { $0.y }.max() ?? 0
                        let rect = CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)

                        var newAnnotation = Annotation(rect: rect, color: selectedColor, lineWidth: selectedLineWidth, tool: .pen)
                        newAnnotation.path = path
                        newAnnotation.brushStyle = selectedBrushStyle
                        viewModel.addAnnotation(newAnnotation, undoManager: undoManager)

                        // NOT: Pen tool'da kalıyoruz, select moduna dönmüyoruz
                        // Böylece kullanıcı sürekli çizim yapabilir
                    }

                    // Path'i temizle
                    liveDrawingPath = nil

                case .emoji:
                    // Universal annotation interaction zaten tamamlandıysa, hiçbir şey yapma
                    if movingAnnotationID != nil {
                        break
                    }

                    // Resize işlemi tamamlandıysa
                    if resizingHandle != nil, let original = originalRect,
                       let selectedID = selectedAnnotationID,
                       let index = viewModel.annotations.firstIndex(where: { $0.id == selectedID }) {
                        let finalRect = viewModel.annotations[index].rect
                        // Undo için kaydet
                        viewModel.updateAnnotationRect(at: index, newRect: finalRect, oldRect: original, undoManager: undoManager)
                        resizingHandle = nil
                        originalRect = nil
                    } else {
                        // Emoji tool - tek tıklama ile kullanıcının seçtiği emoji'yi yerleştir
                        let rect = CGRect(
                            x: imageLocation.x - emojiSize / 2,
                            y: imageLocation.y - emojiSize / 2,
                            width: emojiSize,
                            height: emojiSize
                        )

                        var newAnnotation = Annotation(rect: rect, color: selectedColor, lineWidth: selectedLineWidth, tool: .emoji)
                        newAnnotation.emoji = selectedEmoji
                        viewModel.addAnnotation(newAnnotation, undoManager: undoManager)

                        // Kontrol panelini aç ve bu annotation'ı seç
                        selectedAnnotationID = newAnnotation.id
                        showToolControls = true

                        // Select moduna dön - böylece shapes popup kapanır
                        selectedTool = .select
                    }

                case .text:
                    // Universal annotation interaction zaten tamamlandıysa, hiçbir şey yapma
                    if movingAnnotationID != nil {
                        break
                    }

                    // Text tool - tek tıklama ile küçük text box oluştur ve direkt düzenlemeye başla
                    if resizingHandle == nil && liveDrawingStart == nil {
                        // Tıklanan noktada küçük bir text box oluştur (başlangıç boyutu - minimum boyut)
                        let initialWidth: CGFloat = 50
                        let initialHeight: CGFloat = 30
                        let rect = CGRect(
                            x: imageLocation.x,
                            y: imageLocation.y,
                            width: initialWidth,
                            height: initialHeight
                        )

                        var newAnnotation = Annotation(rect: rect, color: selectedColor, lineWidth: selectedLineWidth, tool: .text)
                        // Text için varsayılan olarak turuncu/coral arkaplan
                        newAnnotation.backgroundColor = Color(red: 1.0, green: 0.38, blue: 0.27) // #FF6145
                        viewModel.addAnnotation(newAnnotation, undoManager: undoManager)

                        // Kontrol panelini aç ve bu annotation'ı seç
                        selectedAnnotationID = newAnnotation.id
                        showToolControls = true

                        // Select moduna geç
                        selectedTool = .select

                        // Direkt düzenleme moduna geç
                        if let index = viewModel.annotations.lastIndex(where: { $0.id == newAnnotation.id }) {
                            onStartEditingText(index)
                        }
                    }

                default: // Diğer tüm çizim araçları (arrow, rectangle, ellipse, line, spotlight, pixelate, highlighter)
                    // Resize işlemi tamamlandıysa
                    if resizingHandle != nil, let original = originalRect,
                       let selectedID = selectedAnnotationID,
                       let index = viewModel.annotations.firstIndex(where: { $0.id == selectedID }) {
                        let finalRect = viewModel.annotations[index].rect
                        // Undo için kaydet
                        viewModel.updateAnnotationRect(at: index, newRect: finalRect, oldRect: original, undoManager: undoManager)
                        resizingHandle = nil
                        originalRect = nil
                    } else if let start = liveDrawingStart {
                        // Normal çizim işlemi tamamlandı
                        // Canvas koordinatlarını image koordinatlarına dönüştür
                        let imageStart = toImageCoords(start)
                        let imageEnd = imageLocation
                        let rect = CGRect(from: imageStart, to: imageEnd)

                        if rect.width > 2 || rect.height > 2 { // Çok küçük çizimleri engelle
                            var newAnnotation = Annotation(rect: rect, color: selectedColor, lineWidth: selectedLineWidth, tool: selectedTool)
                            newAnnotation.startPoint = imageStart
                            newAnnotation.endPoint = imageEnd

                            // Tool-specific properties ekle
                            if selectedTool == .rectangle {
                                newAnnotation.cornerRadius = shapeCornerRadius
                                newAnnotation.fillMode = shapeFillMode
                            } else if selectedTool == .ellipse {
                                newAnnotation.fillMode = shapeFillMode
                            } else if selectedTool == .spotlight {
                                newAnnotation.spotlightShape = spotlightShape
                            }

                            viewModel.addAnnotation(newAnnotation, undoManager: undoManager)

                            // Kontrol panelini aç ve bu annotation'ı seç
                            selectedAnnotationID = newAnnotation.id
                            showToolControls = true

                            // Select moduna geç - böylece shapes popup kapanır
                            selectedTool = .select
                        }
                    }
                }
                // Her durumda canlı çizim state'lerini sıfırla
                liveDrawingStart = nil
                liveDrawingEnd = nil
                resizingHandle = nil
                originalRect = nil
            }
    }

    // MARK: - Helper Functions

    private func findAnnotation(at point: CGPoint) -> (id: UUID, index: Int)? {
        // Ters sırada ara (en üstteki annotation önce bulunmalı)
        for (index, annotation) in viewModel.annotations.enumerated().reversed() {
            // Arrow ve line için özel kontrol - çizgiye yakınlık
            if annotation.tool == .arrow || annotation.tool == .line {
                if let start = annotation.startPoint, let end = annotation.endPoint {
                    let distance = distanceFromPointToLine(point: point, lineStart: start, lineEnd: end)
                    let threshold: CGFloat = 10
                    if distance < threshold {
                        return (annotation.id, index)
                    }
                }
            }

            // Text için özel kontrol - annotation.rect kullan (artık doğru boyutta olmalı)
            if annotation.tool == .text && !annotation.text.isEmpty {
                // Önce annotation.rect'i dene
                if annotation.rect.contains(point) {
                    return (annotation.id, index)
                }

                // Eğer rect güncel değilse, gerçek boyutu hesapla (fallback)
                let font = NSFont.systemFont(ofSize: annotation.lineWidth * 4)
                let textAttributes: [NSAttributedString.Key: Any] = [.font: font]
                let textSize = (annotation.text as NSString).boundingRect(
                    with: CGSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude),
                    options: [.usesLineFragmentOrigin, .usesFontLeading],
                    attributes: textAttributes
                ).size

                // Padding ekle (8pt yatay, 4pt dikey)
                let paddedWidth = textSize.width + 16
                let paddedHeight = textSize.height + 8

                let textRect = CGRect(
                    x: annotation.rect.origin.x,
                    y: annotation.rect.origin.y,
                    width: paddedWidth,
                    height: paddedHeight
                )

                if textRect.contains(point) {
                    return (annotation.id, index)
                }
                continue // Rect kontrolüne geçme, text için özel kontrol yaptık
            }

            // Diğer şekiller için rect kontrolü
            if annotation.rect.contains(point) {
                return (annotation.id, index)
            }
        }
        return nil
    }

    // Noktadan çizgiye olan mesafeyi hesapla
    private func distanceFromPointToLine(point: CGPoint, lineStart: CGPoint, lineEnd: CGPoint) -> CGFloat {
        let x0 = point.x
        let y0 = point.y
        let x1 = lineStart.x
        let y1 = lineStart.y
        let x2 = lineEnd.x
        let y2 = lineEnd.y

        let numerator = abs((y2 - y1) * x0 - (x2 - x1) * y0 + x2 * y1 - y2 * x1)
        let denominator = sqrt(pow(y2 - y1, 2) + pow(x2 - x1, 2))

        if denominator == 0 {
            // Çizgi bir nokta, direkt mesafe hesapla
            return sqrt(pow(x0 - x1, 2) + pow(y0 - y1, 2))
        }

        return numerator / denominator
    }

    // MARK: - Resize Handle Functions

    /// Verilen rect ve tool için uygun resize handle'ların pozisyonlarını döndür
    private func getHandlePositions(for rect: CGRect, tool: DrawingTool) -> [ResizeHandle: CGPoint] {
        switch tool {
        case .line, .arrow:
            // Line ve arrow için sadece 2 handle (başlangıç ve bitiş noktaları)
            return [
                .topLeft: CGPoint(x: rect.minX, y: rect.minY),
                .bottomRight: CGPoint(x: rect.maxX, y: rect.maxY)
            ]
        case .text:
            // Text için handle yok - sadece tıklayınca düzenleme
            return [:]
        case .emoji:
            // Emoji için sadece 4 köşe handle (oran korunsun)
            return [
                .topLeft: CGPoint(x: rect.minX, y: rect.minY),
                .topRight: CGPoint(x: rect.maxX, y: rect.minY),
                .bottomLeft: CGPoint(x: rect.minX, y: rect.maxY),
                .bottomRight: CGPoint(x: rect.maxX, y: rect.maxY)
            ]
        case .pin:
            // Pin için handle yok
            return [:]
        case .pen:
            // Pen için bounding box resize - 8 handle
            return [
                .topLeft: CGPoint(x: rect.minX, y: rect.minY),
                .top: CGPoint(x: rect.midX, y: rect.minY),
                .topRight: CGPoint(x: rect.maxX, y: rect.minY),
                .left: CGPoint(x: rect.minX, y: rect.midY),
                .right: CGPoint(x: rect.maxX, y: rect.midY),
                .bottomLeft: CGPoint(x: rect.minX, y: rect.maxY),
                .bottom: CGPoint(x: rect.midX, y: rect.maxY),
                .bottomRight: CGPoint(x: rect.maxX, y: rect.maxY)
            ]
        case .rectangle, .ellipse, .highlighter, .pixelate, .spotlight:
            // Bu şekiller için 8 handle (4 köşe + 4 kenar)
            return [
                .topLeft: CGPoint(x: rect.minX, y: rect.minY),
                .top: CGPoint(x: rect.midX, y: rect.minY),
                .topRight: CGPoint(x: rect.maxX, y: rect.minY),
                .left: CGPoint(x: rect.minX, y: rect.midY),
                .right: CGPoint(x: rect.maxX, y: rect.midY),
                .bottomLeft: CGPoint(x: rect.minX, y: rect.maxY),
                .bottom: CGPoint(x: rect.midX, y: rect.maxY),
                .bottomRight: CGPoint(x: rect.maxX, y: rect.maxY)
            ]
        case .select, .move, .eraser:
            // Bu toollar için handle gerekmiyor (ama bu fonksiyon çağrılmamalı)
            return [:]
        }
    }

    /// Verilen noktanın hangi handle'a tıkladığını tespit et
    private func detectHandle(at point: CGPoint, for rect: CGRect, tool: DrawingTool) -> ResizeHandle? {
        let handleSize: CGFloat = 12 // Handle'ın tıklanabilir boyutu
        let positions = getHandlePositions(for: rect, tool: tool)

        for (handle, position) in positions {
            let handleRect = CGRect(x: position.x - handleSize / 2,
                                   y: position.y - handleSize / 2,
                                   width: handleSize,
                                   height: handleSize)
            if handleRect.contains(point) {
                return handle
            }
        }
        return nil
    }

    /// Handle sürüklemesine göre yeni rect hesapla
    private func calculateResizedRect(originalRect: CGRect, handle: ResizeHandle, dragTo point: CGPoint) -> CGRect {
        var newRect = originalRect

        switch handle {
        case .topLeft:
            newRect = CGRect(x: point.x, y: point.y,
                           width: originalRect.maxX - point.x,
                           height: originalRect.maxY - point.y)
        case .top:
            newRect = CGRect(x: originalRect.minX, y: point.y,
                           width: originalRect.width,
                           height: originalRect.maxY - point.y)
        case .topRight:
            newRect = CGRect(x: originalRect.minX, y: point.y,
                           width: point.x - originalRect.minX,
                           height: originalRect.maxY - point.y)
        case .left:
            newRect = CGRect(x: point.x, y: originalRect.minY,
                           width: originalRect.maxX - point.x,
                           height: originalRect.height)
        case .right:
            newRect = CGRect(x: originalRect.minX, y: originalRect.minY,
                           width: point.x - originalRect.minX,
                           height: originalRect.height)
        case .bottomLeft:
            newRect = CGRect(x: point.x, y: originalRect.minY,
                           width: originalRect.maxX - point.x,
                           height: point.y - originalRect.minY)
        case .bottom:
            newRect = CGRect(x: originalRect.minX, y: originalRect.minY,
                           width: originalRect.width,
                           height: point.y - originalRect.minY)
        case .bottomRight:
            newRect = CGRect(x: originalRect.minX, y: originalRect.minY,
                           width: point.x - originalRect.minX,
                           height: point.y - originalRect.minY)
        }

        // Minimum boyut kontrolü (en az 20x20 pixel)
        let minSize: CGFloat = 20
        if abs(newRect.width) < minSize || abs(newRect.height) < minSize {
            return originalRect
        }

        // Negatif boyut varsa normalize et
        return newRect.standardized
    }

    // Bu fonksiyon, ana View'daki ile aynı olmalı.
    private func drawSingleAnnotation(_ annotation: Annotation, rect: CGRect, in context: inout GraphicsContext, canvasSize: CGSize, nsImage: NSImage? = nil) {
        switch annotation.tool {
        case .rectangle:
            let cornerRadius = annotation.cornerRadius
            let rectPath = Path(roundedRect: rect, cornerRadius: cornerRadius)

            // Fill mode'a göre çiz
            switch annotation.fillMode {
            case .fill:
                // Sadece dolgu
                context.fill(rectPath, with: .color(annotation.color))
            case .stroke:
                // Sadece kenarlık
                context.stroke(rectPath, with: .color(annotation.color), lineWidth: annotation.lineWidth)
            case .both:
                // Hem dolgu hem kenarlık
                context.fill(rectPath, with: .color(annotation.color.opacity(0.3)))
                context.stroke(rectPath, with: .color(annotation.color), lineWidth: annotation.lineWidth)
            }

        case .ellipse:
            let ellipsePath = Path(ellipseIn: rect)

            // Fill mode'a göre çiz
            switch annotation.fillMode {
            case .fill:
                // Sadece dolgu
                context.fill(ellipsePath, with: .color(annotation.color))
            case .stroke:
                // Sadece kenarlık
                context.stroke(ellipsePath, with: .color(annotation.color), lineWidth: annotation.lineWidth)
            case .both:
                // Hem dolgu hem kenarlık
                context.fill(ellipsePath, with: .color(annotation.color.opacity(0.3)))
                context.stroke(ellipsePath, with: .color(annotation.color), lineWidth: annotation.lineWidth)
            }

        case .line:
            if let start = annotation.startPoint, let end = annotation.endPoint {
                var path = Path()
                path.move(to: start)
                path.addLine(to: end)
                context.stroke(path, with: .color(annotation.color), lineWidth: annotation.lineWidth)
            }
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
            // GÜVENLİK: Parlaklık oynatılarak içerik görülememesi için tamamen siyah overlay
            // Canlı önizlemede hafif şeffaf (kullanıcı neyi gizlediğini görebilsin)
            // Apply'dan sonra %100 opak olacak
            context.fill(Path(rect), with: .color(.black.opacity(0.85)))

        case .pin:
            // Numara şekli - kullanıcının seçimine göre
            let diameter = rect.width
            let shapeRect = CGRect(x: rect.minX, y: rect.minY, width: diameter, height: diameter)

            // Arka plan şekli
            let shape = annotation.numberShape ?? .circle
            let shapePath: Path
            switch shape {
            case .circle:
                shapePath = Path(ellipseIn: shapeRect)
            case .square:
                shapePath = Path(shapeRect)
            case .roundedSquare:
                shapePath = Path(roundedRect: shapeRect, cornerRadius: diameter * 0.2)
            }
            context.fill(shapePath, with: .color(annotation.color))

            // Numara metni - tam merkezlenmiş
            if let number = annotation.number {
                let fontSize = diameter * 0.55
                let numberText = "\(number)"

                // Text'i merkeze hizalamak için resolved text kullan
                let text = Text(numberText)
                    .font(.system(size: fontSize, weight: .bold))
                    .foregroundColor(.white)

                // Text'i resolve et
                let resolved = context.resolve(text)

                // Text'i shape rect'in tam ortasına çiz - anchor point ile
                context.draw(resolved, at: CGPoint(x: shapeRect.midX, y: shapeRect.midY), anchor: .center)
            }

        case .text:
            // Text editing mode değilse Canvas'ta çiz (overlay yerine)
            let isEditing = editingTextIndex == viewModel.annotations.firstIndex(where: { $0.id == annotation.id })

            if !isEditing && !annotation.text.isEmpty {
                // Background'ı çiz
                if let bgColor = annotation.backgroundColor {
                    let bgPath = Path(roundedRect: rect, cornerRadius: 6)
                    context.fill(bgPath, with: .color(bgColor))
                }

                // Text'i çiz
                let text = Text(annotation.text)
                    .font(.system(size: annotation.lineWidth * 4))
                    .foregroundColor(annotation.color)

                let resolved = context.resolve(text)
                // Text'i rect içinde çiz (rect zaten padding ile hesaplanmış)
                // Padding kadar içeri offset et
                context.draw(resolved, in: CGRect(
                    x: rect.minX + 8,
                    y: rect.minY + 4,
                    width: rect.width,
                    height: rect.height
                ))
            } else if annotation.text.isEmpty && isEditing {
                // Boş text kutusu - editing sırasında çizgi çiz
                let path = Path(rect)
                context.stroke(path, with: .color(.gray), style: StrokeStyle(lineWidth: 1, dash: [4]))
            }
        case .emoji:
            // Emoji çiz
            if let emoji = annotation.emoji {
                let fontSize = rect.width * 0.8 // Emoji boyutunu rect'e göre ayarla
                let emojiText = Text(emoji)
                    .font(.system(size: fontSize))

                // Text'i resolve et
                let resolved = context.resolve(emojiText)

                // Emoji'yi rect'in tam ortasına çiz
                context.draw(resolved, at: CGPoint(x: rect.midX, y: rect.midY), anchor: .center)
            }

        case .pen:
            // Freehand çizim - path noktalarını çiz
            if let path = annotation.path, path.count > 1 {
                var bezierPath = Path()
                bezierPath.move(to: path[0])
                for i in 1..<path.count {
                    bezierPath.addLine(to: path[i])
                }

                // Brush style'a göre çiz
                let brushStyle = annotation.brushStyle ?? .solid
                switch brushStyle {
                case .solid:
                    context.stroke(bezierPath, with: .color(annotation.color), lineWidth: annotation.lineWidth)
                case .dashed:
                    context.stroke(bezierPath, with: .color(annotation.color), style: StrokeStyle(lineWidth: annotation.lineWidth, dash: [10, 5]))
                case .marker:
                    context.stroke(bezierPath, with: .color(annotation.color.opacity(0.5)), style: StrokeStyle(lineWidth: annotation.lineWidth * 2, lineCap: .round, lineJoin: .round))
                }
            }

        case .spotlight:
            // Spotlight: Seçilen alan dışını karartma (even-odd rule ile)
            // Tüm canvas ve spotlight alanını içeren combined path oluştur
            var fullScreenPath = Path(CGRect(origin: .zero, size: canvasSize))

            // Spotlight alanını ekle
            let spotPath: Path
            if annotation.spotlightShape == .rectangle {
                spotPath = Path(roundedRect: rect, cornerRadius: 8)
            } else {
                spotPath = Path(ellipseIn: rect)
            }
            fullScreenPath.addPath(spotPath)

            // Even-odd fill rule ile spotlight alanı dışındaki her yeri karart
            context.fill(fullScreenPath, with: .color(.black.opacity(0.6)), style: FillStyle(eoFill: true))

            // Seçilen alanın etrafına ince kenarlık
            context.stroke(spotPath, with: .color(.white.opacity(0.5)), lineWidth: 2)

        case .move, .eraser, .select:
            break
        }

        // NOT: Highlight özelliği kaldırıldı - kullanıcı seçili annotation'ı kontrol panelinden anlayacak
    }
}

// MARK: - Helper Extensions
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
    var backgroundColor: NSColor?
    var onHeightChange: ((CGFloat) -> Void)?
    var onSizeChange: ((CGSize) -> Void)?

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSTextView.scrollableTextView()
        let textView = scrollView.documentView as! NSTextView

        textView.delegate = context.coordinator
        scrollView.hasVerticalScroller = false // Scroll bar'ı gizle
        scrollView.drawsBackground = false // ScrollView arkaplanı şeffaf
        scrollView.borderType = .noBorder

        textView.isRichText = false
        textView.font = font
        textView.textColor = textColor

        // Arka plan rengi ayarla
        if let bgColor = backgroundColor {
            textView.drawsBackground = true
            textView.backgroundColor = bgColor

            // Corner radius ve padding için layer ayarları
            textView.wantsLayer = true
            textView.layer?.cornerRadius = 6
            textView.layer?.masksToBounds = true

            // Text padding
            textView.textContainerInset = NSSize(width: 8, height: 4)
        } else {
            textView.drawsBackground = false
            textView.backgroundColor = .clear
            textView.textContainerInset = NSSize(width: 0, height: 0)
        }

        textView.isSelectable = true
        textView.isEditable = true

        textView.textContainer?.lineFragmentPadding = 0
        textView.insertionPointColor = textColor

        // Text container'ı sağa doğru genişleyebilir yap
        textView.textContainer?.widthTracksTextView = false
        textView.textContainer?.containerSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.isHorizontallyResizable = true
        textView.isVerticallyResizable = true
        textView.autoresizingMask = []

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

        // Background color değişikliklerini handle et
        if let bgColor = backgroundColor {
            if textView.backgroundColor != bgColor {
                textView.drawsBackground = true
                textView.backgroundColor = bgColor
                textView.wantsLayer = true
                textView.layer?.cornerRadius = 6
                textView.layer?.masksToBounds = true
                textView.textContainerInset = NSSize(width: 8, height: 4)
            }
        } else {
            if textView.drawsBackground {
                textView.drawsBackground = false
                textView.backgroundColor = .clear
                textView.textContainerInset = NSSize(width: 0, height: 0)
            }
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    static func dismantleNSView(_ nsView: NSScrollView, coordinator: Coordinator) {
        // TextView ve ScrollView referanslarını temizle
        if let textView = nsView.documentView as? NSTextView {
            textView.delegate = nil
            textView.string = ""
        }
    }

    class Coordinator: NSObject, NSTextViewDelegate {
        var parent: CustomTextEditor

        init(_ parent: CustomTextEditor) {
            self.parent = parent
        }

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            self.parent.text = textView.string

            // Metin değiştikçe gereken boyutu hesapla ve bildir.
            guard let layoutManager = textView.layoutManager,
                  let textContainer = textView.textContainer else { return }
            layoutManager.ensureLayout(for: textContainer)
            let usedRect = layoutManager.usedRect(for: textContainer)

            // textContainerInset ile padding zaten ekleniyor, onu hesaba kat
            let inset = textView.textContainerInset
            let horizontalInset = inset.width * 2 // Sol ve sağ
            let verticalInset = inset.height * 2 // Üst ve alt

            let minWidth: CGFloat = 50 // Minimum genişlik
            let minHeight: CGFloat = 20 // Minimum yükseklik
            let newWidth = max(minWidth, usedRect.width + horizontalInset)
            let newHeight = max(minHeight, usedRect.height + verticalInset)

            // Layout cycle dışında callback çağır
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                // Yükseklik değişikliğini bildir (eski callback)
                self.parent.onHeightChange?(usedRect.height)
                // Boyut değişikliğini bildir (yeni callback - hem genişlik hem yükseklik)
                self.parent.onSizeChange?(CGSize(width: newWidth, height: newHeight))
            }
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

// MARK: - Shape Picker View
struct ShapePickerView: View {
    @Binding var selectedTool: DrawingTool
    @Binding var isPresented: Bool
    @EnvironmentObject var settings: SettingsManager

    let shapes: [DrawingTool] = [.rectangle, .ellipse, .line]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(L("Shapes", settings: settings))
                .font(.headline)
                .padding(.horizontal, 12)
                .padding(.top, 12)
                .padding(.bottom, 8)

            ForEach(shapes) { shape in
                Button(action: {
                    selectedTool = shape
                    isPresented = false
                }) {
                    HStack(spacing: 12) {
                        // Görsel önizleme
                        ZStack {
                            if shape == .rectangle {
                                RoundedRectangle(cornerRadius: 2)
                                    .stroke(Color.accentColor, lineWidth: 2)
                                    .frame(width: 32, height: 24)
                            } else if shape == .ellipse {
                                Ellipse()
                                    .stroke(Color.accentColor, lineWidth: 2)
                                    .frame(width: 32, height: 24)
                            } else if shape == .line {
                                Path { path in
                                    path.move(to: CGPoint(x: 0, y: 12))
                                    path.addLine(to: CGPoint(x: 32, y: 12))
                                }
                                .stroke(Color.accentColor, lineWidth: 2)
                                .frame(width: 32, height: 24)
                            }
                        }
                        .frame(width: 40, height: 32)

                        Text(shape.localizedName)
                            .font(.body)

                        Spacer()

                        if selectedTool == shape {
                            Image(systemName: "checkmark")
                                .foregroundColor(.accentColor)
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .background(selectedTool == shape ? Color.accentColor.opacity(0.1) : Color.clear)
            }
        }
        .frame(width: 200)
        .padding(.bottom, 8)
    }
}

// MARK: - Emoji Picker View
struct EmojiPickerView: View {
    @Binding var selectedEmoji: String
    @Binding var isPresented: Bool
    @State private var selectedCategory: EmojiCategory = .symbols

    enum EmojiCategory: String, CaseIterable {
        case symbols = "Semboller"
        case smileys = "Yüzler"
        case hands = "Eller"
        case arrows = "Oklar"
        case nature = "Doğa"

        var icon: String {
            switch self {
            case .symbols: return "checkmark.seal.fill"
            case .smileys: return "face.smiling"
            case .hands: return "hand.thumbsup.fill"
            case .arrows: return "arrow.right.circle.fill"
            case .nature: return "leaf.fill"
            }
        }

        var emojis: [String] {
            switch self {
            case .symbols:
                return ["✅", "❌", "⚠️", "⭐️", "💯", "📌", "🔴", "🟢", "🟡", "🔵", "🟣", "🟠", "⚫️", "⚪️", "🟤", "✏️", "📝", "🎯", "⚡️", "🔥", "💥", "✨", "💫", "⭕️", "❗️", "❓", "➕", "➖", "✖️", "➗"]
            case .smileys:
                return ["😀", "😃", "😄", "😁", "😅", "😂", "🤣", "😊", "😇", "🙂", "😉", "😍", "🥰", "😘", "😋", "😎", "🤓", "🧐", "🤔", "🤨", "😐", "😑", "😶", "🙄", "😏", "😣", "😥", "😮", "🤐", "😯"]
            case .hands:
                return ["👍", "👎", "👌", "✌️", "🤞", "🤟", "🤘", "🤙", "👈", "👉", "👆", "👇", "☝️", "✋", "🤚", "🖐", "🖖", "👋", "🤝", "👏", "🙌", "👐", "🤲", "🤜", "🤛", "✊", "👊", "🤏", "💪", "🦾"]
            case .arrows:
                return ["➡️", "⬅️", "⬆️", "⬇️", "↗️", "↘️", "↙️", "↖️", "↕️", "↔️", "↩️", "↪️", "⤴️", "⤵️", "🔄", "🔃", "🔁", "🔂", "▶️", "◀️", "🔼", "🔽", "⏸", "⏯", "⏹", "⏺", "⏭", "⏮", "⏩", "⏪"]
            case .nature:
                return ["🌱", "🌿", "☘️", "🍀", "🌾", "🌵", "🌲", "🌳", "🌴", "🌻", "🌼", "🌷", "🌹", "🥀", "🌺", "🌸", "💐", "🌰", "🍁", "🍂", "🍃", "🌍", "🌎", "🌏", "🌐", "🌑", "🌒", "🌓", "🌔", "🌕"]
            }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            Text("Emoji Seç")
                .font(.headline)
                .padding(.horizontal, 12)
                .padding(.top, 12)
                .padding(.bottom, 8)

            // Tab Bar
            HStack(spacing: 4) {
                ForEach(EmojiCategory.allCases, id: \.self) { category in
                    Button(action: {
                        selectedCategory = category
                    }) {
                        VStack(spacing: 2) {
                            Image(systemName: category.icon)
                                .font(.system(size: 16))
                                .foregroundColor(selectedCategory == category ? .accentColor : .secondary)
                        }
                        .frame(width: 44, height: 32)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(selectedCategory == category ? Color.accentColor.opacity(0.15) : Color.clear)
                        )
                    }
                    .buttonStyle(.plain)
                    .help(category.rawValue)
                }
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 8)

            Divider()

            // Emoji Grid
            ScrollView {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 44))], spacing: 8) {
                    ForEach(selectedCategory.emojis, id: \.self) { emoji in
                        Button(action: {
                            selectedEmoji = emoji
                            isPresented = false
                        }) {
                            Text(emoji)
                                .font(.system(size: 28))
                                .frame(width: 44, height: 44)
                                .background(
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(selectedEmoji == emoji ? Color.accentColor.opacity(0.15) : Color.clear)
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(selectedEmoji == emoji ? Color.accentColor : Color.clear, lineWidth: 2)
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 12)
            }
            .frame(height: 280)
        }
        .frame(width: 280)
    }
}

// MARK: - Line Width Picker View
struct LineWidthPickerView: View {
    @Binding var selectedLineWidth: CGFloat
    @Binding var isPresented: Bool
    @EnvironmentObject var settings: SettingsManager

    let widths: [(label: String, value: CGFloat)] = [
        ("width.small", 4),
        ("width.medium", 8),
        ("width.large", 12)
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(L("Line Width", settings: settings))
                .font(.headline)
                .padding(.horizontal, 12)
                .padding(.top, 12)
                .padding(.bottom, 8)

            ForEach(widths, id: \.value) { width in
                Button(action: {
                    selectedLineWidth = width.value
                    isPresented = false
                }) {
                    HStack(spacing: 12) {
                        // Görsel önizleme - çizgi kalınlığı
                        ZStack {
                            Capsule()
                                .fill(Color.accentColor)
                                .frame(width: 40, height: width.value)
                        }
                        .frame(width: 50, height: 32)

                        Text(L(width.label, settings: settings))
                            .font(.body)

                        Spacer()

                        if selectedLineWidth == width.value {
                            Image(systemName: "checkmark")
                                .foregroundColor(.accentColor)
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .background(selectedLineWidth == width.value ? Color.accentColor.opacity(0.1) : Color.clear)
            }
        }
        .frame(width: 220)
        .padding(.bottom, 8)
    }
}

// MARK: - Universal Tool Control Panel (Compact Horizontal)
struct ToolControlPanel: View {
    @Binding var isPresented: Bool
    @Binding var selectedAnnotationID: UUID?
    @ObservedObject var viewModel: ScreenshotEditorViewModel
    let selectedTool: DrawingTool
    @EnvironmentObject var settings: SettingsManager
    @Binding var selectedColor: Color
    @Binding var selectedLineWidth: CGFloat

    // Number tool
    @Binding var numberSize: CGFloat
    @Binding var numberShape: NumberShape

    // Shape tools
    @Binding var shapeCornerRadius: CGFloat
    @Binding var shapeFillMode: FillMode

    // Spotlight tool
    @Binding var spotlightShape: SpotlightShape

    // Emoji tool
    @Binding var selectedEmoji: String
    @Binding var emojiSize: CGFloat

    // Pen tool
    @Binding var selectedBrushStyle: BrushStyle

    var currentAnnotation: Annotation? {
        guard let id = selectedAnnotationID else { return nil }
        return viewModel.annotations.first(where: { $0.id == id })
    }

    var body: some View {
        HStack(spacing: 12) {
            // Close button
            Button(action: { isPresented = false }) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.secondary)
                    .frame(width: 28, height: 28)
            }
            .buttonStyle(.plain)
            .help(L("Close", settings: settings))

            // Color picker (tüm tool'lar için)
            if selectedTool != .move && selectedTool != .eraser {
                ColorPicker("", selection: Binding(
                    get: { currentAnnotation?.color ?? selectedColor },
                    set: { newColor in
                        selectedColor = newColor
                        if let id = selectedAnnotationID,
                           let index = viewModel.annotations.firstIndex(where: { $0.id == id }) {
                            viewModel.annotations[index].color = newColor
                        }
                    }
                ), supportsOpacity: false)
                .labelsHidden()
                .frame(width: 32, height: 32)
                .help(L("Color", settings: settings))
            }

            // Tool-specific controls - seçili annotation'a göre değişir
            if let currentAnnotation = currentAnnotation {
                // Seçili annotation varsa, onun tipine göre kontroller göster
                switch currentAnnotation.tool {
                case .text:
                    textControls
                case .pin:
                    numberControls
                case .rectangle:
                    rectangleControls
                case .ellipse:
                    ellipseControls
                case .arrow, .line:
                    lineWidthControl
                case .spotlight:
                    spotlightControls
                case .emoji:
                    emojiControls
                case .pen:
                    penControls
                default:
                    EmptyView()
                }
            } else {
                // Seçili annotation yoksa, aktif tool'a göre göster
                switch selectedTool {
                case .text:
                    textControls
                case .pin:
                    numberControls
                case .rectangle:
                    rectangleControls
                case .ellipse:
                    ellipseControls
                case .arrow, .line:
                    lineWidthControl
                case .spotlight:
                    spotlightControls
                case .emoji:
                    emojiControls
                case .pen:
                    penControls
                default:
                    EmptyView()
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(nsColor: .windowBackgroundColor))
                .shadow(color: .black.opacity(0.2), radius: 12, y: 6)
        )
    }

    // Number tool controls (compact horizontal)
    @ViewBuilder
    var numberControls: some View {
        // Size slider
        HStack(spacing: 6) {
            Image(systemName: "circle.fill")
                .font(.system(size: 10))
                .foregroundColor(.secondary)

            Slider(value: Binding(
                get: {
                    if let annotation = currentAnnotation {
                        return annotation.rect.width
                    }
                    return numberSize
                },
                set: { newSize in
                    numberSize = newSize
                    if let id = selectedAnnotationID,
                       let index = viewModel.annotations.firstIndex(where: { $0.id == id }) {
                        let center = CGPoint(
                            x: viewModel.annotations[index].rect.midX,
                            y: viewModel.annotations[index].rect.midY
                        )
                        viewModel.annotations[index].rect = CGRect(
                            x: center.x - newSize / 2,
                            y: center.y - newSize / 2,
                            width: newSize,
                            height: newSize
                        )
                    }
                }
            ), in: 20...120, step: 5)
            .frame(width: 100)

            Image(systemName: "circle.fill")
                .font(.system(size: 16))
                .foregroundColor(.secondary)
        }

        // Shape selector
        Menu {
            ForEach(NumberShape.allCases, id: \.self) { shape in
                Button(action: {
                    numberShape = shape
                    if let id = selectedAnnotationID,
                       let index = viewModel.annotations.firstIndex(where: { $0.id == id }) {
                        viewModel.annotations[index].numberShape = shape
                    }
                }) {
                    HStack {
                        Text(shape.rawValue)
                        if (currentAnnotation?.numberShape ?? numberShape) == shape {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        } label: {
            Image(systemName: "chevron.up.chevron.down")
                .font(.system(size: 12))
                .foregroundColor(.secondary)
                .frame(width: 28, height: 28)
        }
        .menuStyle(.borderlessButton)
                .help(L("Shape", settings: settings))
    }

    // Line width control (for arrow, line)
    @ViewBuilder
    var lineWidthControl: some View {
        HStack(spacing: 6) {
            Image(systemName: "line.diagonal")
                .font(.system(size: 10))
                .foregroundColor(.secondary)

            Slider(value: Binding(
                get: { currentAnnotation?.lineWidth ?? selectedLineWidth },
                set: { newWidth in
                    selectedLineWidth = newWidth
                    if let id = selectedAnnotationID,
                       let index = viewModel.annotations.firstIndex(where: { $0.id == id }) {
                        viewModel.annotations[index].lineWidth = newWidth
                    }
                }
            ), in: 1...20, step: 1)
            .frame(width: 100)

            Text("\(Int(currentAnnotation?.lineWidth ?? selectedLineWidth))")
                .font(.caption2)
                .foregroundColor(.secondary)
                .frame(width: 20)
        }
    }

    // Rectangle tool controls (compact)
    @ViewBuilder
    var rectangleControls: some View {
        // Fill mode selector
        fillModeButtons

        // Corner radius slider
        HStack(spacing: 6) {
            Image(systemName: "square")
                .font(.system(size: 10))
                .foregroundColor(.secondary)

            Slider(value: Binding(
                get: { currentAnnotation?.cornerRadius ?? shapeCornerRadius },
                set: { newValue in
                    shapeCornerRadius = newValue
                    if let id = selectedAnnotationID,
                       let index = viewModel.annotations.firstIndex(where: { $0.id == id }) {
                        viewModel.annotations[index].cornerRadius = newValue
                    }
                }
            ), in: 0...50, step: 2)
            .frame(width: 80)

            Image(systemName: "square")
                .font(.system(size: 16))
                .foregroundColor(.secondary)
        }
    }

    // Ellipse tool controls (compact)
    @ViewBuilder
    var ellipseControls: some View {
        fillModeButtons
    }

    // Fill mode buttons (3 buttons: stroke, fill, both)
    @ViewBuilder
    var fillModeButtons: some View {
        HStack(spacing: 6) {
            ForEach(FillMode.allCases, id: \.self) { mode in
                Button(action: {
                    shapeFillMode = mode
                    if let id = selectedAnnotationID,
                       let index = viewModel.annotations.firstIndex(where: { $0.id == id }) {
                        viewModel.annotations[index].fillMode = mode
                    }
                }) {
                    Image(systemName: mode.icon)
                        .font(.system(size: 14))
                        .foregroundColor((currentAnnotation?.fillMode ?? shapeFillMode) == mode ? .accentColor : .secondary)
                        .frame(width: 28, height: 28)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill((currentAnnotation?.fillMode ?? shapeFillMode) == mode ? Color.accentColor.opacity(0.15) : Color.clear)
                        )
                }
                .buttonStyle(.plain)
                .help(L(mode.rawValue, settings: settings))
            }
        }
    }

    // Emoji tool controls - sadece boyut slider'ı
    @ViewBuilder
    var emojiControls: some View {
        HStack(spacing: 6) {
            Image(systemName: "textformat.size.smaller")
                .font(.system(size: 10))
                .foregroundColor(.secondary)

            Slider(value: Binding(
                get: {
                    if let annotation = currentAnnotation {
                        return annotation.rect.width
                    }
                    return emojiSize
                },
                set: { newSize in
                    emojiSize = newSize
                    if let id = selectedAnnotationID,
                       let index = viewModel.annotations.firstIndex(where: { $0.id == id }) {
                        let center = CGPoint(
                            x: viewModel.annotations[index].rect.midX,
                            y: viewModel.annotations[index].rect.midY
                        )
                        viewModel.annotations[index].rect = CGRect(
                            x: center.x - newSize / 2,
                            y: center.y - newSize / 2,
                            width: newSize,
                            height: newSize
                        )
                    }
                }
            ), in: 24...120, step: 4)
            .frame(width: 120)

            Image(systemName: "textformat.size.larger")
                .font(.system(size: 14))
                .foregroundColor(.secondary)
        }
    }

    var penControls: some View {
        HStack(spacing: 6) {
            // Line width slider
            Image(systemName: "line.diagonal")
                .font(.system(size: 8))
                .foregroundColor(.secondary)

            Slider(value: Binding(
                get: {
                    if let annotation = currentAnnotation {
                        return annotation.lineWidth
                    }
                    return selectedLineWidth
                },
                set: { newWidth in
                    selectedLineWidth = newWidth
                    if let id = selectedAnnotationID,
                       let index = viewModel.annotations.firstIndex(where: { $0.id == id }) {
                        viewModel.annotations[index].lineWidth = newWidth
                    }
                }
            ), in: 1...20, step: 1)
            .frame(width: 80)

            Image(systemName: "line.diagonal")
                .font(.system(size: 14))
                .foregroundColor(.secondary)

            Divider()
                .frame(height: 20)

            // Brush style menu
            Menu {
                ForEach(BrushStyle.allCases, id: \.self) { style in
                    Button(action: {
                        selectedBrushStyle = style
                        if let id = selectedAnnotationID,
                           let index = viewModel.annotations.firstIndex(where: { $0.id == id }) {
                            viewModel.annotations[index].brushStyle = style
                        }
                    }) {
                        HStack {
                            Text(style.localizedName)
                            if (currentAnnotation?.brushStyle ?? selectedBrushStyle) == style {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "paintbrush.fill")
                        .font(.system(size: 12))
                    Text((currentAnnotation?.brushStyle ?? selectedBrushStyle).localizedName)
                        .font(.system(size: 11))
                }
                .foregroundColor(.secondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.secondary.opacity(0.1))
                )
            }
            .menuStyle(.borderlessButton)
        }
    }

    var spotlightControls: some View {
        // Shape selector (ellipse or rectangle)
        HStack(spacing: 6) {
            ForEach(SpotlightShape.allCases, id: \.self) { shape in
                Button(action: {
                    spotlightShape = shape
                    if let id = selectedAnnotationID,
                       let index = viewModel.annotations.firstIndex(where: { $0.id == id }) {
                        viewModel.annotations[index].spotlightShape = shape
                    }
                }) {
                    Image(systemName: shape == .ellipse ? "circle" : "square")
                        .font(.system(size: 14))
                        .foregroundColor((currentAnnotation?.spotlightShape ?? spotlightShape) == shape ? .accentColor : .secondary)
                        .frame(width: 28, height: 28)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill((currentAnnotation?.spotlightShape ?? spotlightShape) == shape ? Color.accentColor.opacity(0.15) : Color.clear)
                        )
                }
                .buttonStyle(.plain)
                .help(shape.displayName)
            }
        }
    }

    @ViewBuilder
    var textControls: some View {
        HStack(spacing: 8) {
            // Background color toggle button
            Button(action: {
                if let id = selectedAnnotationID,
                   let index = viewModel.annotations.firstIndex(where: { $0.id == id }) {
                    if viewModel.annotations[index].backgroundColor != nil {
                        // Make transparent
                        viewModel.annotations[index].backgroundColor = nil
                    } else {
                        // Set to white as default
                        viewModel.annotations[index].backgroundColor = .white
                    }
                }
            }) {
                Image(systemName: currentAnnotation?.backgroundColor == nil ? "circle.slash" : "circle.fill")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
                    .frame(width: 28, height: 28)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color.secondary.opacity(0.1))
                    )
            }
            .buttonStyle(.plain)
            .help(currentAnnotation?.backgroundColor == nil ? "Add Background" : "Remove Background")

            // Background color picker (only shown if background is not transparent)
            if currentAnnotation?.backgroundColor != nil {
                ColorPicker("", selection: Binding(
                    get: {
                        if let id = selectedAnnotationID,
                           let annotation = viewModel.annotations.first(where: { $0.id == id }),
                           let bgColor = annotation.backgroundColor {
                            return bgColor
                        }
                        return .white
                    },
                    set: { newColor in
                        if let id = selectedAnnotationID,
                           let index = viewModel.annotations.firstIndex(where: { $0.id == id }) {
                            viewModel.annotations[index].backgroundColor = newColor
                        }
                    }
                ), supportsOpacity: true)
                .labelsHidden()
                .frame(width: 32, height: 32)
                .help("Background Color")
            }

            Divider()
                .frame(height: 24)

            // Font size control
            Image(systemName: "textformat.size")
                .font(.system(size: 12))
                .foregroundColor(.secondary)

            Slider(value: Binding(
                get: {
                    if let annotation = currentAnnotation {
                        return annotation.lineWidth
                    }
                    return selectedLineWidth
                },
                set: { newSize in
                    selectedLineWidth = newSize
                    if let id = selectedAnnotationID,
                       let index = viewModel.annotations.firstIndex(where: { $0.id == id }) {
                        viewModel.annotations[index].lineWidth = newSize

                        // Text boyutu değiştiğinde rect'i güncelle
                        let annotation = viewModel.annotations[index]
                        if annotation.tool == .text && !annotation.text.isEmpty {
                            let font = NSFont.systemFont(ofSize: newSize * 4)
                            let textAttributes: [NSAttributedString.Key: Any] = [.font: font]
                            let textSize = (annotation.text as NSString).boundingRect(
                                with: CGSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude),
                                options: [.usesLineFragmentOrigin, .usesFontLeading],
                                attributes: textAttributes
                            ).size

                            // Padding ekle (8pt yatay, 4pt dikey)
                            let paddedWidth = textSize.width + 16
                            let paddedHeight = textSize.height + 8

                            // Rect'i güncelle (origin aynı, boyut değişti)
                            viewModel.annotations[index].rect.size = CGSize(width: paddedWidth, height: paddedHeight)
                        }
                    }
                }
            ), in: 3...12, step: 1)
            .frame(width: 100)
        }
    }
}
