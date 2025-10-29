//
//  ScreenshotManager.swift
//  Clippy
//
//  Created by Mehmet Akbaba on 6.10.2025.
//
@preconcurrency import ImageIO
import AppKit
import UniformTypeIdentifiers
import AVFoundation
import ScreenCaptureKit

@available(macOS 12.3, *)
class ScreenshotManager: NSObject {
    static let shared = ScreenshotManager()
    
    private var recordingStream: SCStream?
    private var capturedFrames: [CGImage] = []
    private var recordingCompletion: ((URL?) -> Void)?
    private var selectionWindow: NSWindow?
    private var eventMonitor: Any? // ESC tuşu için event monitor referansı
    private var isRecording = false
    private var recordingStartTime: Date?
    var onRecordingStateChanged: ((Bool) -> Void)?
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
                        print("ℹ️ Ekran görüntüsü alma işlemi kullanıcı tarafından iptal edildi.")
                    } else {
                        print("❌ Ekran görüntüsü dosyası oluşturulamadı.")
                    }
                    return
                }
                print("✅ Ekran görüntüsü başarıyla alındı.")
                completion(image)
            }
        }

        task.launch()
    }
    
    /// Kullanıcının ekranın bir bölümünü seçip GIF olarak kaydetmesini sağlar.
    func recordGIF(completion: @escaping (URL?) -> Void) {
        self.recordingCompletion = completion
        
        // İlk olarak ekran kaydı iznini kontrol et
        checkAndRequestPermission { [weak self] hasPermission in
            guard let self = self else { return }
            
            guard hasPermission else {
                print("❌ Ekran kaydı izni verilmedi.")
                DispatchQueue.main.async {
                    self.showPermissionAlert()
                    completion(nil)
                }
                return
            }
            
            // İzin varsa, alan seçim penceresini göster
            DispatchQueue.main.async {
                self.showAreaSelectionWindow()
            }
        }
    }
    
    /// Ekran kaydı izni kontrolü ve istek
    private func checkAndRequestPermission(completion: @escaping (Bool) -> Void) {
        Task {
            do {
                // İzin kontrolü - SCShareableContent çağrısı izin yoksa otomatik olarak ister
                let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
                completion(!content.displays.isEmpty)
            } catch {
                print("❌ İzin kontrolü başarısız: \(error.localizedDescription)")
                completion(false)
            }
        }
    }
    
    /// İzin uyarısı göster
    private func showPermissionAlert() {
        let alert = NSAlert()
        alert.messageText = "Ekran Kaydı İzni Gerekli"
        alert.informativeText = "GIF oluşturmak için ekran kaydı iznine ihtiyaç var.\n\nSistem Ayarları > Gizlilik ve Güvenlik > Ekran Kaydı\n\nUygulamayı işaretleyin ve yeniden başlatın."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Sistem Ayarlarını Aç")
        alert.addButton(withTitle: "İptal")
        
        if alert.runModal() == .alertFirstButtonReturn {
            NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture")!)
        }
    }
    
    /// Alan seçim penceresi göster
    private func showAreaSelectionWindow() {
        // Tam ekran transparan overlay
        guard let screen = NSScreen.main else { return }
        
        let window = SelectionWindow(
            contentRect: screen.frame,
            styleMask: [.borderless, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        
        window.backgroundColor = NSColor.black.withAlphaComponent(0.3)
        window.isOpaque = false
        window.level = .floating
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        window.ignoresMouseEvents = false
        
        let selectionView = AreaSelectionView(frame: screen.frame)
        selectionView.onSelectionComplete = { [weak self] rect in
            self?.startRecording(in: rect)
            window.close()
        }
        selectionView.onCancel = { [weak self] in
            print("ℹ️ Alan seçimi iptal edildi.")
            window.close()
            self?.onRecordingStateChanged?(false) // İptal edildiğinde durumu bildir
            self?.recordingCompletion?(nil)
        }
        
        window.contentView = selectionView
        window.makeKeyAndOrderFront(nil)
        
        self.selectionWindow = window
    }
    
    /// Seçilen alanda kaydı başlat
    private func startRecording(in rect: CGRect) {
        Task {
            do {
                let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
                guard let display = content.displays.first else {
                    print("❌ Ekran bulunamadı.")
                    await MainActor.run {
                        self.recordingCompletion?(nil)
                    }
                    return
                }
                
                // Frame listesini temizle
                await MainActor.run {
                    self.capturedFrames.removeAll()
                    self.isRecording = true
                    self.onRecordingStateChanged?(true) // Kayıt başladığında durumu bildir
                    self.recordingStartTime = Date()
                }
                
                // Stream yapılandırması
                let config = SCStreamConfiguration()
                config.width = Int(rect.width)
                config.height = Int(rect.height)
                config.minimumFrameInterval = CMTime(value: 1, timescale: 15) // 15 FPS
                config.queueDepth = 5
                config.sourceRect = rect
                
                // Content filter
                let filter = SCContentFilter(display: display, excludingWindows: [])
                
                // Stream oluştur
                let stream = SCStream(filter: filter, configuration: config, delegate: nil)
                
                await MainActor.run {
                    self.recordingStream = stream
                }
                
                // Output handler ekle
                try stream.addStreamOutput(self, type: .screen, sampleHandlerQueue: DispatchQueue(label: "com.clippy.capture"))
                
                // Kaydı başlat
                try await stream.startCapture()
                
                await MainActor.run {
                    print("🎬 Kayıt başladı! ESC tuşuna basarak durdurun. (Menü çubuğu ikonunu kontrol edin)")
                    // DÜZELTME: ESC tuşu için event monitor'ü burada ekle
                    self.eventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
                        if event.keyCode == 53 { // ESC
                            Task { await self?.stopRecording() }
                            return nil // Event'i tüket
                        }
                        return event // Diğer event'leri ilet
                    }
                }
                
            } catch {
                print("❌ Kayıt başlatılamadı: \(error.localizedDescription)")
                await MainActor.run {
                    self.onRecordingStateChanged?(false) // Hata durumunda durumu bildir
                    self.recordingCompletion?(nil)
                }
            }
        }
    }
    
    // DÜZELTME: showRecordingOverlay() fonksiyonu kaldırıldı.
    // Kayıt sırasında görsel bir overlay gösterilmeyecek.
    
    /// Kaydı durdur
    private func stopRecording() async {
        guard let stream = recordingStream, isRecording else { return }
        
        do {
            // DÜZELTME: Event monitor'ü burada kaldır.
            // Bu, referans döngülerini ve çökme sorunlarını önler.
            if let monitor = self.eventMonitor {
                NSEvent.removeMonitor(monitor)
                self.eventMonitor = nil
            }

            try await stream.stopCapture()
            
            await MainActor.run {
                self.isRecording = false
                self.recordingStream = nil
                self.onRecordingStateChanged?(false) // Durumu bildir
                
                let frameCount = self.capturedFrames.count
                print("✅ Kayıt durduruldu. \(frameCount) frame yakalandı.")
                
                if frameCount > 0 {
                    // GIF oluştur
                    self.createGIFFromFrames()
                } else {
                    print("❌ Hiç frame yakalanmadı.")
                    self.recordingCompletion?(nil)
                }
            }
        } catch {
            print("❌ Kayıt durdurulurken hata: \(error.localizedDescription)")
            await MainActor.run {
                self.onRecordingStateChanged?(false) // Hata durumunda durumu bildir
                self.recordingCompletion?(nil)
            }
        }
    }
    
    /// Yakalanan frame'lerden GIF oluştur
    private func createGIFFromFrames() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            // Format seçim diyalogu göster
            self.showFormatSelectionDialog { format in
                guard let format = format else {
                    self.onRecordingStateChanged?(false) // İptal edildiğinde durumu bildir
                    self.recordingCompletion?(nil)
                    self.capturedFrames.removeAll()
                    return
                }
                
                // Kayıt yeri seçim diyalogu göster
                self.showSaveDialog(format: format) { saveURL in
                    guard let saveURL = saveURL else {
                        self.onRecordingStateChanged?(false) // İptal edildiğinde durumu bildir
                        self.recordingCompletion?(nil)
                        self.capturedFrames.removeAll()
                        return
                    }
                    
                    // Seçilen formatta kaydet
                    DispatchQueue.global(qos: .userInitiated).async {
                        switch format {
                        case .gif:
                            self.saveAsGIF(to: saveURL)
                        case .mp4:
                            self.saveAsVideo(to: saveURL)
                        }
                    }
                }
            }
        }
    }
    
    /// Format seçim diyalogu
    private func showFormatSelectionDialog(completion: @escaping (ExportFormat?) -> Void) {
        let alert = NSAlert()
        alert.messageText = "Kayıt Formatı Seçin"
        alert.informativeText = "Kaydı hangi formatta kaydetmek istersiniz?"
        alert.alertStyle = .informational
        
        alert.addButton(withTitle: "GIF") // .alertFirstButtonReturn
        alert.addButton(withTitle: "MP4 Video") // .alertSecondButtonReturn
        alert.addButton(withTitle: "İptal") // .alertThirdButtonReturn
        
        let response = alert.runModal()
        
        switch response {
        case .alertFirstButtonReturn:
            completion(.gif)
        case .alertSecondButtonReturn:
            completion(.mp4)
        default:
            completion(nil)
        }
    }
    
    /// Kayıt yeri seçim diyalogu
    private func showSaveDialog(format: ExportFormat, completion: @escaping (URL?) -> Void) {
        let savePanel = NSSavePanel()
        savePanel.title = "Kaydet"
        savePanel.message = "\(format.rawValue.uppercased()) dosyasını kaydedin"
        savePanel.nameFieldStringValue = "Ekran Kaydı \(DateFormatter.localizedString(from: Date(), dateStyle: .short, timeStyle: .short))"
        savePanel.allowedContentTypes = [format.contentType]
        savePanel.canCreateDirectories = true
        savePanel.isExtensionHidden = false
        
        savePanel.begin { response in
            if response == .OK {
                completion(savePanel.url)
            } else {
                completion(nil)
            }
        }
    }
    
    /// GIF olarak kaydet
    private func saveAsGIF(to url: URL) {
        guard let destination = CGImageDestinationCreateWithURL(
            url as CFURL,
            UTType.gif.identifier as CFString,
            self.capturedFrames.count,
            nil
        ) else {
            print("❌ GIF dosyası oluşturulamadı.")
            DispatchQueue.main.async {
                self.recordingCompletion?(nil)
                self.capturedFrames.removeAll()
            }
            return
        }
        
        // GIF özellikleri
        let fileProps = [
            kCGImagePropertyGIFDictionary: [
                kCGImagePropertyGIFLoopCount: 0
            ]
        ]
        CGImageDestinationSetProperties(destination, fileProps as CFDictionary)
        
        // Frame özellikleri (15 FPS için delay)
        let frameProps = [
            kCGImagePropertyGIFDictionary: [
                kCGImagePropertyGIFDelayTime: 0.0667 // 1/15
            ]
        ]
        
        // Tüm frame'leri ekle
        for frame in self.capturedFrames {
            CGImageDestinationAddImage(destination, frame, frameProps as CFDictionary)
        }
        
        let success = CGImageDestinationFinalize(destination)
        
        DispatchQueue.main.async {
            if success {
                print("✅ GIF başarıyla kaydedildi: \(url.path)")
                self.showSuccessNotification(url: url)
                self.recordingCompletion?(url)
            } else {
                print("❌ GIF kaydedilemedi.")
                self.recordingCompletion?(nil)
            }
            
            self.capturedFrames.removeAll()
        }
    }
    
    /// Video (MP4) olarak kaydet
    private func saveAsVideo(to url: URL) {
        guard let firstFrame = capturedFrames.first else {
            DispatchQueue.main.async {
                self.recordingCompletion?(nil)
                self.capturedFrames.removeAll()
            }
            return
        }
        
        let width = firstFrame.width
        let height = firstFrame.height
        
        do {
            // Video writer oluştur
            let writer = try AVAssetWriter(outputURL: url, fileType: .mp4)

            // İYİLEŞTİRME: Daha iyi uyumluluk ve kalite için H.264 profilini ve bitrate'i belirtmek faydalıdır.
            let compressionProperties: [String: Any] = [
                AVVideoProfileLevelKey: AVVideoProfileLevelH264BaselineAutoLevel,
                AVVideoAverageBitRateKey: width * height * 10 // Kaliteyi artırmak için bitrate
            ]

            let videoSettings: [String: Any] = [
                AVVideoCodecKey: AVVideoCodecType.h264,
                AVVideoWidthKey: width,
                AVVideoHeightKey: height,
                AVVideoCompressionPropertiesKey: compressionProperties
            ]
            
            let writerInput = AVAssetWriterInput(mediaType: .video, outputSettings: videoSettings)
            writerInput.expectsMediaDataInRealTime = false
            
            let adaptor = AVAssetWriterInputPixelBufferAdaptor(
                assetWriterInput: writerInput,
                sourcePixelBufferAttributes: [
                    kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32ARGB,
                    kCVPixelBufferWidthKey as String: width,
                    kCVPixelBufferHeightKey as String: height
                ]
            )
            
            // İYİLEŞTİRME: Input'u eklemeden önce writer'ın ekleyebileceğinden emin ol.
            guard writer.canAdd(writerInput) else {
                throw NSError(domain: "ScreenshotManager", code: 1, userInfo: [NSLocalizedDescriptionKey: "AVAssetWriter, video input'u ekleyemiyor."])
            }
            writer.add(writerInput)
            writer.startWriting()
            writer.startSession(atSourceTime: .zero)
            
            let frameDuration = CMTime(value: 1, timescale: 15) // 15 FPS
            
            for (index, cgImage) in capturedFrames.enumerated() {
                while !writerInput.isReadyForMoreMediaData {
                    // İYİLEŞTİRME: CPU'yu daha az yormak için çok kısa bir bekleme.
                    Thread.sleep(forTimeInterval: 0.005)
                }
                
                let presentationTime = CMTimeMultiply(frameDuration, multiplier: Int32(index))
                
                // İYİLEŞTİRME: Her döngüyü bir autoreleasepool içine almak,
                // uzun kayıtlarda bellek kullanımını optimize eder ve olası çökmeleri önler.
                autoreleasepool {
                    if let pixelBuffer = cgImage.toPixelBuffer(width: width, height: height) {
                        adaptor.append(pixelBuffer, withPresentationTime: presentationTime)
                    }
                }
            }
            
            writerInput.markAsFinished()
            writer.finishWriting {
                DispatchQueue.main.async {
                    if writer.status == .completed {
                        print("✅ Video başarıyla kaydedildi: \(url.path)")
                        self.showSuccessNotification(url: url)
                        self.recordingCompletion?(url)
                    } else {
                        print("❌ Video kaydedilemedi: \(writer.error?.localizedDescription ?? "Bilinmeyen hata")")
                        self.recordingCompletion?(nil)
                    }
                    
                    self.capturedFrames.removeAll()
                }
            }
            
        } catch {
            print("❌ Video writer oluşturulamadı: \(error.localizedDescription)")
            DispatchQueue.main.async {
                self.recordingCompletion?(nil)
                self.capturedFrames.removeAll()
            }
        }
    }
    
    /// Başarı bildirimi göster
    private func showSuccessNotification(url: URL) {
        let alert = NSAlert()
        alert.messageText = "✅ Başarıyla Kaydedildi"
        alert.informativeText = "Dosya: \(url.lastPathComponent)\n\nKlasörde görmek ister misiniz?"
        alert.alertStyle = .informational
        alert.addButton(withTitle: "Finder'da Göster")
        alert.addButton(withTitle: "Tamam")
        
        if alert.runModal() == .alertFirstButtonReturn {
            NSWorkspace.shared.activateFileViewerSelecting([url])
        }
    }
    
    enum ExportFormat: String {
        case gif = "gif"
        case mp4 = "mp4"
        
        var contentType: UTType {
            switch self {
            case .gif: return .gif
            case .mp4: return .mpeg4Movie
            }
        }
    }
}

// MARK: - SCStreamOutput
@available(macOS 12.3, *)
extension ScreenshotManager: SCStreamOutput {
    func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of type: SCStreamOutputType) {
        guard isRecording,
              type == .screen,
              let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            return
        }
        
        // CVPixelBuffer'dan CGImage oluştur
        let ciImage = CIImage(cvPixelBuffer: imageBuffer)
        let context = CIContext()
        
        guard let cgImage = context.createCGImage(ciImage, from: ciImage.extent) else {
            return
        }
        
        // Frame'i kaydet
        DispatchQueue.main.async { [weak self] in
            guard let self = self, self.isRecording else { return }
            
            // Max 300 frame (20 saniye @ 15fps)
            if self.capturedFrames.count < 300 {
                self.capturedFrames.append(cgImage)
            } else if self.capturedFrames.count == 300 {
                print("⚠️ Maksimum süre (20 saniye) doldu. Kayıt otomatik durduruluyor...")
                Task { await self.stopRecording() }
            }
        }
    }
}

// MARK: - CGImage Extension
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
