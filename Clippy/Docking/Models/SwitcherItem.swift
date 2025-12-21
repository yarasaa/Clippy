import AppKit

/// "Uygulama Değiştirici" panelinde gösterilecek tek bir pencere öğesini temsil eder.
struct SwitcherItem: Identifiable {
    var id: CGWindowID { windowID }
    
    let windowID: CGWindowID
    let pid: pid_t
    let appIcon: NSImage?
    let appName: String
    let windowTitle: String?
    let previewImage: NSImage
}