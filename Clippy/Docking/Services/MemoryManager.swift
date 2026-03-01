import Foundation
import AppKit

@MainActor
final class MemoryManager {
    static let shared = MemoryManager()

    // MARK: - Properties

    private var memoryPressureSource: DispatchSourceMemoryPressure?
    private(set) var currentCacheSize: Int64 = 0

    var maxCacheSize: Int64 {
        let mbValue = SettingsManager.shared.maxCacheSizeMB
        return Int64(mbValue) * 1024 * 1024 // Convert MB to bytes
    }

    // MARK: - Cache Statistics

    private var cacheEntries: [(pid: pid_t, size: Int64, timestamp: Date)] = []

    private init() {
        if SettingsManager.shared.enableMemoryPressureHandling {
            startMonitoring()
        }
    }

    deinit {
        memoryPressureSource?.cancel()
        memoryPressureSource = nil
    }

    // MARK: - Monitoring

    func startMonitoring() {
        guard memoryPressureSource == nil else { return }

        memoryPressureSource = DispatchSource.makeMemoryPressureSource(eventMask: [.warning, .critical], queue: .main)

        memoryPressureSource?.setEventHandler { [weak self] in
            guard let self = self else { return }
            guard let source = self.memoryPressureSource else { return }

            let event = source.data
            Task { @MainActor in
                self.handleMemoryPressure(event)
            }
        }

        memoryPressureSource?.resume()
    }

    func stopMonitoring() {
        memoryPressureSource?.cancel()
        memoryPressureSource = nil
    }

    // MARK: - Memory Pressure Handling

    private func handleMemoryPressure(_ event: DispatchSource.MemoryPressureEvent) {
        if event.contains(.warning) {
            let targetSize = currentCacheSize / 2
            clearOldestCaches(until: targetSize)
        }

        if event.contains(.critical) {
            clearAllCaches()
        }
    }

    // MARK: - Cache Management

    func recordCacheEntry(pid: pid_t, size: Int64) {
        currentCacheSize += size
        cacheEntries.append((pid: pid, size: size, timestamp: Date()))


        // Check if we exceeded max cache size
        if currentCacheSize > maxCacheSize {
            let targetSize = Int64(Double(maxCacheSize) * 0.8) // Reduce to 80% of max
            clearOldestCaches(until: targetSize)
        }
    }

    func removeCacheEntry(pid: pid_t) {
        if let index = cacheEntries.firstIndex(where: { $0.pid == pid }) {
            let entry = cacheEntries[index]
            currentCacheSize -= entry.size
            cacheEntries.remove(at: index)
        }
    }

    func clearOldestCaches(until targetSize: Int64) {
        guard currentCacheSize > targetSize else { return }


        // Sort by timestamp (oldest first)
        cacheEntries.sort { $0.timestamp < $1.timestamp }

        var pidsToInvalidate: [pid_t] = []

        while currentCacheSize > targetSize && !cacheEntries.isEmpty {
            let entry = cacheEntries.removeFirst()
            currentCacheSize -= entry.size
            pidsToInvalidate.append(entry.pid)
        }

        // Invalidate caches
        for pid in pidsToInvalidate {
            WindowCacheManager.shared.invalidateCache(for: pid)
        }

    }

    func clearAllCaches() {
        cacheEntries.removeAll()
        currentCacheSize = 0
        WindowCacheManager.shared.invalidateAll()
    }

    // MARK: - Statistics

    func getCacheStats() -> (count: Int, size: Int64, maxSize: Int64, percentage: Double) {
        let percentage = maxCacheSize > 0 ? (Double(currentCacheSize) / Double(maxCacheSize)) * 100.0 : 0.0
        return (count: cacheEntries.count, size: currentCacheSize, maxSize: maxCacheSize, percentage: percentage)
    }

    func getFormattedStats() -> String {
        let stats = getCacheStats()
        return "Cache: \(stats.count) entries, \(formatBytes(stats.size)) / \(formatBytes(stats.maxSize)) (\(String(format: "%.1f", stats.percentage))%)"
    }

    // MARK: - Helpers

    private func formatBytes(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB, .useGB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }

    func estimateImageSize(_ image: CGImage) -> Int64 {
        let width = image.width
        let height = image.height
        let bytesPerPixel = 4 // RGBA
        return Int64(width * height * bytesPerPixel)
    }
}
