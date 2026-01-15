//
//  GitHubSyncService.swift
//  FitCat
//
//  Downloads product database from GitHub
//

import Foundation

class GitHubSyncService: ObservableObject {
    @Published var isSyncing = false
    @Published var lastSyncDate: Date?
    @Published var syncError: Error?

    private let databaseManager: DatabaseManager
    private let githubURL: URL
    private let syncInterval: TimeInterval = 24 * 60 * 60 // 24 hours

    init(
        databaseManager: DatabaseManager,
        githubURL: String = "https://raw.githubusercontent.com/YOUR_USERNAME/fitcat-database/main/products.json"
    ) {
        self.databaseManager = databaseManager
        self.githubURL = URL(string: githubURL)!

        // Load last sync date
        if let lastSync = try? databaseManager.getLastSyncTime() {
            self.lastSyncDate = lastSync
        }
    }

    /// Checks if sync is needed based on last sync time
    func shouldSync() -> Bool {
        guard let lastSync = lastSyncDate else {
            return true // Never synced
        }

        let timeSinceLastSync = Date().timeIntervalSince(lastSync)
        return timeSinceLastSync > syncInterval
    }

    /// Performs sync from GitHub
    @MainActor
    func sync() async {
        guard !isSyncing else { return }

        isSyncing = true
        syncError = nil

        do {
            let products = try await downloadProducts()
            try await mergeProducts(products)

            // Update last sync time
            try databaseManager.setLastSyncTime(Date())
            lastSyncDate = Date()

            isSyncing = false
        } catch {
            syncError = error
            isSyncing = false
            print("Sync error: \(error)")
        }
    }

    /// Forces a manual sync regardless of interval
    @MainActor
    func forceSync() async {
        await sync()
    }

    private func downloadProducts() async throws -> [Product] {
        let (data, response) = try await URLSession.shared.data(from: githubURL)

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw SyncError.networkError
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        let productCollection = try decoder.decode(ProductCollection.self, from: data)
        return productCollection.products
    }

    private func mergeProducts(_ products: [Product]) async throws {
        let mergeService = DataMergeService(databaseManager: databaseManager)
        try await mergeService.merge(remoteProducts: products)
    }
}

// MARK: - Product Collection Model
struct ProductCollection: Codable {
    let version: String
    let updatedAt: Date
    let products: [Product]

    enum CodingKeys: String, CodingKey {
        case version
        case updatedAt = "updated_at"
        case products
    }
}

// MARK: - Sync Errors
enum SyncError: LocalizedError {
    case networkError
    case invalidData
    case databaseError

    var errorDescription: String? {
        switch self {
        case .networkError:
            return "Failed to connect to GitHub. Check your internet connection."
        case .invalidData:
            return "Invalid data format from GitHub."
        case .databaseError:
            return "Failed to update local database."
        }
    }
}
