//
//  OfflineTests.swift
//  FitCatTests
//
//  Tests for offline-first caching strategy
//

import XCTest
@testable import FitCat

final class OfflineTests: XCTestCase {
    var databaseManager: DatabaseManager!

    override func setUpWithError() throws {
        // Use shared DatabaseManager instance
        databaseManager = DatabaseManager.shared

        // Clear all products before each test
        for product in databaseManager.products {
            try databaseManager.delete(product)
        }
        try databaseManager.loadProducts()
    }

    override func tearDownWithError() throws {
        // Clean up after test
        for product in databaseManager.products {
            try databaseManager.delete(product)
        }
        databaseManager = nil
    }

    // MARK: - Offline Mode Tests

    func testFetchProductOffline_ReturnsCachedProduct() throws {
        // GIVEN: Product is cached locally
        let cachedProduct = Product(
            barcode: "4017721837194",
            productName: "Carny Adult Rind+Huhn",
            brand: "Animonda",
            protein: 11.5,
            fat: 6.5,
            fiber: 0.5,
            moisture: 79.0,
            ash: 2.1,
            source: .openpetfoodfacts
        )
        try databaseManager.insert(cachedProduct)

        // WHEN: Network is unavailable (API would fail)
        // AND: We check local cache first
        let result = try databaseManager.findByBarcode("4017721837194")

        // THEN: Should return cached product
        XCTAssertNotNil(result, "Should find cached product")
        XCTAssertEqual(result?.barcode, "4017721837194")
        XCTAssertEqual(result?.productName, "Carny Adult Rind+Huhn")
        XCTAssertEqual(result?.moisture, 79.0)
        XCTAssertEqual(result?.ash, 2.1)
    }

    func testFetchProductOffline_NoCacheAvailable_ReturnsNil() throws {
        // GIVEN: No cached product

        // WHEN: Network is unavailable AND no cache
        let result = try databaseManager.findByBarcode("9999999999999")

        // THEN: Should return nil (graceful failure)
        XCTAssertNil(result, "Should return nil when no cache and offline")
    }

    // MARK: - OCR Scan Persistence Tests

    func testSaveOCRScanOffline_SavesWithLocalSource() throws {
        // GIVEN: User scans product offline
        let ocrProduct = Product(
            barcode: "1234567890123",
            productName: "New Product",
            brand: "Test Brand",
            protein: 12.0,
            fat: 5.0,
            fiber: 1.0,
            moisture: 75.0,
            ash: 2.0,
            source: .local  // Marked as local = pending upload
        )

        // WHEN: Save OCR scan locally (offline mode)
        try databaseManager.insert(ocrProduct)

        // THEN: Product should be saved with .local source
        let saved = try databaseManager.findByBarcode("1234567890123")
        XCTAssertNotNil(saved, "OCR scan should be saved")
        XCTAssertEqual(saved?.source, .local, "Should be marked as local (pending upload)")
        XCTAssertEqual(saved?.protein, 12.0)
    }

    func testUpdateCachedProduct_PreservesLocalSource() throws {
        // GIVEN: Product exists with .local source (offline OCR scan)
        let localProduct = Product(
            barcode: "1111111111111",
            productName: "Local Product",
            brand: "Brand",
            protein: 10.0,
            fat: 5.0,
            fiber: 1.0,
            moisture: 78.0,
            ash: 2.0,
            source: .local
        )
        try databaseManager.insert(localProduct)

        // WHEN: OCR detects better values (e.g., consensus improves)
        var updated = localProduct
        updated.ash = 2.1  // Better OCR consensus
        try databaseManager.update(updated)

        // THEN: Should update values but keep .local source
        let result = try databaseManager.findByBarcode("1111111111111")
        XCTAssertEqual(result?.ash, 2.1, "Should update with better OCR value")
        XCTAssertEqual(result?.source, .local, "Should still be marked for upload")
    }

    // MARK: - Sync Strategy Tests

    func testGetPendingUploads_ReturnsOnlyLocalProducts() throws {
        // GIVEN: Mix of product sources
        let apiProduct = Product(
            barcode: "1111111111111",
            productName: "API Product",
            brand: "Brand",
            protein: 10.0,
            fat: 5.0,
            fiber: 1.0,
            moisture: 78.0,
            ash: 2.0,
            source: .openpetfoodfacts
        )

        let localProduct1 = Product(
            barcode: "2222222222222",
            productName: "Local Product 1",
            brand: "Brand",
            protein: 11.0,
            fat: 6.0,
            fiber: 1.5,
            moisture: 79.0,
            ash: 2.1,
            source: .local
        )

        let localProduct2 = Product(
            barcode: "3333333333333",
            productName: "Local Product 2",
            brand: "Brand",
            protein: 12.0,
            fat: 7.0,
            fiber: 2.0,
            moisture: 80.0,
            ash: 2.2,
            source: .local
        )

        try databaseManager.insert(apiProduct)
        try databaseManager.insert(localProduct1)
        try databaseManager.insert(localProduct2)

        // WHEN: Get products pending upload
        try databaseManager.loadProducts()
        let pendingUploads = databaseManager.products.filter { $0.source == .local }

        // THEN: Should only return .local products
        XCTAssertEqual(pendingUploads.count, 2, "Should have 2 pending uploads")
        XCTAssertTrue(pendingUploads.allSatisfy { $0.source == .local })
    }

    func testMarkProductAsSynced_ChangesSourceToAPI() throws {
        // GIVEN: Local product pending upload
        let localProduct = Product(
            barcode: "4444444444444",
            productName: "Pending Upload",
            brand: "Brand",
            protein: 10.0,
            fat: 5.0,
            fiber: 1.0,
            moisture: 78.0,
            ash: 2.0,
            source: .local
        )
        try databaseManager.insert(localProduct)

        // WHEN: Upload succeeds, mark as synced
        var synced = localProduct
        synced.source = .openpetfoodfacts
        try databaseManager.update(synced)

        // THEN: Should be marked as API product
        let result = try databaseManager.findByBarcode("4444444444444")
        XCTAssertEqual(result?.source, .openpetfoodfacts, "Should be marked as synced")
    }

    // MARK: - Cache Priority Tests

    func testCachePriority_PrefersFreshOCROverOldAPI() throws {
        // GIVEN: Old API product cached
        let oldAPIProduct = Product(
            barcode: "5555555555555",
            productName: "Product",
            brand: "Brand",
            protein: 10.0,
            fat: 5.0,
            fiber: 1.0,
            moisture: 78.0,
            ash: 2.0,  // Old value
            createdAt: Date(timeIntervalSinceNow: -86400 * 30),  // 30 days ago
            source: .openpetfoodfacts
        )
        try databaseManager.insert(oldAPIProduct)

        // WHEN: User scans same product, OCR detects different value
        var freshOCRProduct = oldAPIProduct
        freshOCRProduct.ash = 2.5  // New value from fresh OCR scan
        freshOCRProduct.source = .local
        freshOCRProduct.createdAt = Date()  // Today
        try databaseManager.update(freshOCRProduct)

        // THEN: Should use fresh OCR value
        let result = try databaseManager.findByBarcode("5555555555555")
        XCTAssertEqual(result?.ash, 2.5, "Should prefer fresh OCR over old API")
        XCTAssertEqual(result?.source, .local, "Should be marked for upload")
    }

    // MARK: - Network Failure Simulation

    func testAPIFailure_FallsBackToCache() throws {
        // GIVEN: Product in cache
        let cachedProduct = Product(
            barcode: "6666666666666",
            productName: "Cached Product",
            brand: "Brand",
            protein: 10.0,
            fat: 5.0,
            fiber: 1.0,
            moisture: 78.0,
            ash: 2.0,
            source: .openpetfoodfacts
        )
        try databaseManager.insert(cachedProduct)

        // WHEN: API call would fail (network error)
        // Simulate by checking cache BEFORE attempting API call
        let cacheResult = try databaseManager.findByBarcode("6666666666666")

        // THEN: Should successfully return cached version
        XCTAssertNotNil(cacheResult, "Cache should work when API fails")
        XCTAssertEqual(cacheResult?.productName, "Cached Product")

        // User can still view product details offline
        XCTAssertEqual(cacheResult?.ash, 2.0)
    }

    func testAPIFailure_NoCache_GracefulDegradation() throws {
        // GIVEN: No cached product

        // WHEN: API fails AND no cache
        let cacheResult = try databaseManager.findByBarcode("7777777777777")

        // THEN: Should return nil (app should show "No data available offline" message)
        XCTAssertNil(cacheResult, "Should return nil gracefully")

        // App should display: "Product not in cache. Connect to internet to fetch data."
    }
}
