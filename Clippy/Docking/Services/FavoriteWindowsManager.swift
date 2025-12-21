import Foundation
import AppKit
import Combine

@MainActor
final class FavoriteWindowsManager: ObservableObject {
    static let shared = FavoriteWindowsManager()

    @Published var favoriteWindows: [FavoriteWindow] = []

    private let favoritesKey = "favoriteWindows"

    private init() {
        loadFavorites()
        print("⭐ [FavoriteWindowsManager] INIT: FavoriteWindowsManager initialized with \(favoriteWindows.count) favorites")
    }

    // MARK: - Public Methods

    func addToFavorites(windowID: CGWindowID, title: String?, bundleIdentifier: String?) {
        // Check if already in favorites
        if favoriteWindows.contains(where: { $0.windowID == windowID }) {
            print("⭐ [FavoriteWindowsManager] Window \(windowID) already in favorites")
            return
        }

        let favorite = FavoriteWindow(
            windowID: windowID,
            title: title ?? "Untitled Window",
            bundleIdentifier: bundleIdentifier,
            dateAdded: Date()
        )

        favoriteWindows.append(favorite)
        saveFavorites()
        print("⭐ [FavoriteWindowsManager] Added window \(windowID) to favorites")
    }

    func removeFromFavorites(windowID: CGWindowID) {
        favoriteWindows.removeAll { $0.windowID == windowID }
        saveFavorites()
        print("⭐ [FavoriteWindowsManager] Removed window \(windowID) from favorites")
    }

    func isFavorite(windowID: CGWindowID) -> Bool {
        return favoriteWindows.contains { $0.windowID == windowID }
    }

    func toggleFavorite(windowID: CGWindowID, title: String?, bundleIdentifier: String?) {
        if isFavorite(windowID: windowID) {
            removeFromFavorites(windowID: windowID)
        } else {
            addToFavorites(windowID: windowID, title: title, bundleIdentifier: bundleIdentifier)
        }
    }

    // MARK: - Persistence

    private func loadFavorites() {
        guard let data = UserDefaults.standard.data(forKey: favoritesKey),
              let decoded = try? JSONDecoder().decode([FavoriteWindow].self, from: data) else {
            return
        }
        favoriteWindows = decoded
    }

    private func saveFavorites() {
        guard let encoded = try? JSONEncoder().encode(favoriteWindows) else {
            return
        }
        UserDefaults.standard.set(encoded, forKey: favoritesKey)
    }
}

// MARK: - FavoriteWindow Model

struct FavoriteWindow: Codable, Identifiable {
    let id: UUID
    let windowID: CGWindowID
    let title: String
    let bundleIdentifier: String?
    let dateAdded: Date

    init(id: UUID = UUID(), windowID: CGWindowID, title: String, bundleIdentifier: String?, dateAdded: Date) {
        self.id = id
        self.windowID = windowID
        self.title = title
        self.bundleIdentifier = bundleIdentifier
        self.dateAdded = dateAdded
    }
}
