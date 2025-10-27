//
//  ScreenshotManager.swift
//  Clippy
//
//  Created by Gemini Code Assist on 6.10.2025.
//

import AppKit

class ScreenshotManager {
    static let shared = ScreenshotManager()

    enum CaptureMode {
        case interactive // Kullanıcı alan seçer!
        case window      // Pencere seçer
        case fullScreen  // Tüm ekran
    }

    /// Belirtilen modda bir ekran görüntüsü alır ve sonucu bir `NSImage` olarak döndürür.
    /// - Parameters:
    ///   - mode: Yakalama modu (`.interactive`, `.window`, `.fullScreen`).
    ///   - completion: Yakalanan `NSImage`'i içeren bir kapanış.
    func captureArea(mode: CaptureMode, completion: @escaping (NSImage) -> Void) {
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("screenshot-\(UUID().uuidString).png")
        
        let task = Process()
        task.launchPath = "/usr/sbin/screencapture"

        var arguments: [String] = []
        switch mode {
        case .interactive:
            arguments.append("-i") // İnteraktif mod
        case .window:
            arguments.append("-w") // Pencere modu
        case .fullScreen:
            arguments.append("-C") // İmleci dahil et
        }
        
        arguments.append(tempURL.path)

        task.arguments = arguments

        task.terminationHandler = { process in
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                // Geçici dosyanın her durumda silinmesini garantile.
                defer {
                    try? FileManager.default.removeItem(at: tempURL)
                }

                guard process.terminationStatus == 0,
                      let image = NSImage(contentsOf: tempURL) else {
                    if process.terminationStatus != 0 {
                        print("ℹ️ Ekran görüntüsü alma işlemi kullanıcı tarafından iptal edildi veya bir hata oluştu (status: \(process.terminationStatus)).")
                    } else {
                        print("❌ Ekran görüntüsü dosyası oluşturulamadı veya okunamadı. İzinleri kontrol edin.")
                    }
                    return
                }
                print("✅ Ekran görüntüsü başarıyla alındı.")
                completion(image)
            }
        }

        task.launch()
    }
    
    /// Uygulamanın ekran kaydı iznine sahip olup olmadığını kontrol eder. Bu, kullanıcıya gereksiz uyarılar göstermemek için kullanılır.
    // TODO: Kaydırmalı ekran görüntüsü (scrolling screenshot) mantığı buraya eklenebilir.
}
