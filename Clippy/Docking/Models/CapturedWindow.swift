import AppKit

/// Yakalanan bir uygulama penceresinin bilgilerini temsil eder.
struct CapturedWindow {
    /// Pencerenin ekran görüntüsü.
    let image: CGImage
    /// Pencerenin benzersiz kimliği.
    let windowID: CGWindowID
    /// Pencerenin ekran üzerindeki konumu ve boyutu.
    let frame: CGRect
    /// Pencerenin başlığı.
    let title: String?
    /// Pencerenin sahibi olan uygulamanın adı.
    let ownerName: String
    /// Pencerenin sahibi olan uygulamanın işlem kimliği.
    let pid: pid_t
    /// Pencerenin sahibi olan uygulamanın ikonu.
    let ownerIcon: NSImage?
}