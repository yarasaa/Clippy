//
//  ThumbnailStore.swift
//  Clippy
//
//  Shared, cost-aware thumbnail cache for stored clipboard images.
//
//  Why this exists: a JPEG that's 200 KB on disk decodes to ~5.5 MB in
//  memory, and a full-screen Retina grab to ~56 MB. Anywhere the UI shows
//  a *small* version of an image — a 160pt card row, a 26pt icon — fully
//  decoding the original wastes tens of megabytes and milliseconds per
//  item. ImageIO can decode straight to a reduced size instead, which
//  measured 64x less memory and 7.2x faster on a 5120x2880 screenshot.
//
//  It's a shared store rather than a method on ClipboardMonitor because
//  the Quick Preview panel has no monitor reference and was doing its own
//  full-size, *uncached* decode for a 26pt icon.
//

import AppKit
import ImageIO

enum ThumbnailStore {

    private static let cache: NSCache<NSString, NSImage> = {
        let cache = NSCache<NSString, NSImage>()
        cache.countLimit = 200
        // Enforced, because every insert below passes `cost:`. Without a
        // cost NSCache treats entries as free and this limit does nothing.
        cache.totalCostLimit = 40 * 1024 * 1024 // 40MB of thumbnails
        return cache
    }()

    private static let sizeLock = NSLock()
    private static var pixelSizes: [String: CGSize] = [:]

    /// On-disk location of a stored clipboard image.
    static func imageURL(for path: String) -> URL? {
        guard let appSupport = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            return nil
        }
        return appSupport
            .appendingPathComponent("Clippy/Images")
            .appendingPathComponent(path)
    }

    /// Thumbnail decoded at reduced resolution — the full-size bitmap is
    /// never materialised.
    static func thumbnail(for path: String, maxPixel: CGFloat = 640) -> NSImage? {
        let key = "\(path)@\(Int(maxPixel))" as NSString
        if let cached = cache.object(forKey: key) { return cached }

        guard let url = imageURL(for: path),
              let source = CGImageSourceCreateWithURL(url as CFURL, nil) else {
            return nil
        }

        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixel
        ]
        guard let cg = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
            return nil
        }

        let image = NSImage(cgImage: cg, size: NSSize(width: cg.width, height: cg.height))
        cache.setObject(image, forKey: key, cost: cg.width * cg.height * 4)
        return image
    }

    /// Pixel dimensions straight from the file header — no decode at all.
    /// Cards display "W × H" and previously got it by decoding the whole
    /// image just to read two integers.
    static func pixelSize(for path: String) -> CGSize? {
        sizeLock.lock()
        if let cached = pixelSizes[path] {
            sizeLock.unlock()
            return cached
        }
        sizeLock.unlock()

        guard let url = imageURL(for: path),
              let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let props = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let width = props[kCGImagePropertyPixelWidth] as? Int,
              let height = props[kCGImagePropertyPixelHeight] as? Int else {
            return nil
        }

        let size = CGSize(width: width, height: height)
        sizeLock.lock()
        if pixelSizes.count > 500 { pixelSizes.removeAll() }
        pixelSizes[path] = size
        sizeLock.unlock()
        return size
    }

    /// Drop everything — used when history is cleared or images are pruned.
    static func purge() {
        cache.removeAllObjects()
        sizeLock.lock()
        pixelSizes.removeAll()
        sizeLock.unlock()
    }
}
