import Foundation
import CoreGraphics
import AppKit

@MainActor
final class WindowCacheManager {
    static let shared = WindowCacheManager()

    private var cache: [pid_t: CacheEntry] = [:]
    private let cacheTTL: TimeInterval = 3.0
    private var workspaceObserver: NSObjectProtocol?

    struct CacheEntry {
        let windows: [CapturedWindow]
        let timestamp: Date
        let windowCount: Int
        let estimatedSize: Int64

        func isValid(ttl: TimeInterval) -> Bool {
            Date().timeIntervalSince(timestamp) < ttl
        }
    }

    private init() {
        setupWorkspaceObservers()
    }

    deinit {
        if let observer = workspaceObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(observer)
        }
    }

    // MARK: - Cache Operations

    func getCachedWindows(for pid: pid_t) -> [CapturedWindow]? {
        guard SettingsManager.shared.enableWindowCaching else {
            return nil
        }

        guard let cached = cache[pid] else {
            return nil
        }

        guard cached.isValid(ttl: cacheTTL) else {
            cache.removeValue(forKey: pid)
            return nil
        }

        return cached.windows
    }

    func cacheWindows(_ windows: [CapturedWindow], for pid: pid_t) {
        guard SettingsManager.shared.enableWindowCaching else {
            return
        }

        // Calculate estimated size
        var totalSize: Int64 = 0
        for window in windows {
            totalSize += MemoryManager.shared.estimateImageSize(window.image)
        }

        cache[pid] = CacheEntry(
            windows: windows,
            timestamp: Date(),
            windowCount: windows.count,
            estimatedSize: totalSize
        )

        // Notify MemoryManager
        MemoryManager.shared.recordCacheEntry(pid: pid, size: totalSize)
    }

    func invalidateCache(for pid: pid_t) {
        cache.removeValue(forKey: pid)
        MemoryManager.shared.removeCacheEntry(pid: pid)
    }

    func invalidateAll() {
        cache.removeAll()
        MemoryManager.shared.clearAllCaches()
    }

    // MARK: - Workspace Observers

    private func setupWorkspaceObservers() {
        workspaceObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            Task { @MainActor in
                if let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication {
                    self?.invalidateCache(for: app.processIdentifier)
                }
            }
        }
    }

    // MARK: - Cache Stats (for debugging)

    func getCacheStats() -> String {
        let validCount = cache.values.filter { $0.isValid(ttl: cacheTTL) }.count
        let expiredCount = cache.count - validCount
        return "Cache: \(validCount) valid, \(expiredCount) expired, Total: \(cache.count)"
    }
}
