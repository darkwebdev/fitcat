//
//  DataMergeService.swift
//  FitCat
//
//  Merges remote GitHub data with local database
//

import Foundation

class DataMergeService {
    private let databaseManager: DatabaseManager

    init(databaseManager: DatabaseManager) {
        self.databaseManager = databaseManager
    }

    /// Merges remote products with local database
    /// Strategy:
    /// - Preserve local user-entered products (source = .local)
    /// - Update GitHub products (source = .github)
    /// - Insert new GitHub products
    func merge(remoteProducts: [Product]) async throws {
        // Mark all remote products with .github source
        let githubProducts = remoteProducts.map { product -> Product in
            var updated = product
            updated.source = .github
            return updated
        }

        try databaseManager.bulkInsertOrUpdate(githubProducts)
    }
}
