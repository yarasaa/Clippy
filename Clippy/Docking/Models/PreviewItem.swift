import AppKit

struct PreviewItem: Identifiable {
    let id: CGWindowID
    let image: NSImage
    let title: String?
}