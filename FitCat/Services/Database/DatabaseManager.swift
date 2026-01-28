//
//  DatabaseManager.swift
//  FitCat
//
//  SQLite database manager for local product storage
//

import Foundation
import SQLite

class DatabaseManager: ObservableObject {
    static let shared = DatabaseManager()

    private var db: Connection?
    @Published var products: [Product] = []

    // Table and columns
    private let productsTable = Table("products")
    private let id = Expression<String>("id")
    private let barcode = Expression<String?>("barcode")
    private let productName = Expression<String>("product_name")
    private let brand = Expression<String>("brand")
    private let protein = Expression<Double?>("protein")
    private let fat = Expression<Double?>("fat")
    private let fiber = Expression<Double?>("fiber")
    private let moisture = Expression<Double?>("moisture")
    private let ash = Expression<Double?>("ash")
    private let servingSize = Expression<String?>("serving_size")
    private let createdAt = Expression<Int64>("created_at")
    private let updatedAt = Expression<Int64>("updated_at")
    private let source = Expression<String>("source")

    private let syncMetadataTable = Table("sync_metadata")
    private let metaKey = Expression<String>("key")
    private let metaValue = Expression<String>("value")
    private let metaUpdatedAt = Expression<Int64>("updated_at")

    private init() {
        do {
            try setupDatabase()
            try loadProducts()
        } catch {
            print("Database initialization error: \(error)")
        }
    }

    private func setupDatabase() throws {
        // Use in-memory database for UI testing
        if CommandLine.arguments.contains("UI-Testing") {
            db = try Connection(.inMemory)
            print("Using in-memory database for UI testing")
        } else {
            let path = NSSearchPathForDirectoriesInDomains(
                .documentDirectory, .userDomainMask, true
            ).first!

            let dbPath = "\(path)/fitcat.sqlite3"
            print("Database path: \(dbPath)")

            db = try Connection(dbPath)
        }

        // Create tables
        try createTables()
    }

    private func createTables() throws {
        guard let db = db else { return }

        // Products table
        try db.run(productsTable.create(ifNotExists: true) { t in
            t.column(id, primaryKey: true)
            t.column(barcode)
            t.column(productName)
            t.column(brand)
            t.column(protein)
            t.column(fat)
            t.column(fiber)
            t.column(moisture)
            t.column(ash)
            t.column(servingSize)
            t.column(createdAt)
            t.column(updatedAt)
            t.column(source)
        })

        // Create indexes
        try db.run(productsTable.createIndex(barcode, ifNotExists: true))
        try db.run(productsTable.createIndex(productName, ifNotExists: true))
        try db.run(productsTable.createIndex(updatedAt, ifNotExists: true))

        // Sync metadata table
        try db.run(syncMetadataTable.create(ifNotExists: true) { t in
            t.column(metaKey, primaryKey: true)
            t.column(metaValue)
            t.column(metaUpdatedAt)
        })
    }

    // MARK: - CRUD Operations

    func loadProducts() throws {
        guard let db = db else { return }

        let rows = try db.prepare(productsTable.order(updatedAt.desc))
        products = rows.compactMap { row in
            rowToProduct(row)
        }
    }

    func insert(_ product: Product) throws {
        guard let db = db else { return }

        let insert = productsTable.insert(
            id <- product.id.uuidString,
            barcode <- product.barcode,
            productName <- product.productName,
            brand <- product.brand,
            protein <- product.protein,
            fat <- product.fat,
            fiber <- product.fiber,
            moisture <- product.moisture,
            ash <- product.ash,
            servingSize <- product.servingSize,
            createdAt <- Int64(product.createdAt.timeIntervalSince1970),
            updatedAt <- Int64(product.updatedAt.timeIntervalSince1970),
            source <- product.source.rawValue
        )

        try db.run(insert)
        try loadProducts()
    }

    func update(_ product: Product) throws {
        guard let db = db else { return }

        let productRow = productsTable.filter(id == product.id.uuidString)
        let update = productRow.update(
            barcode <- product.barcode,
            productName <- product.productName,
            brand <- product.brand,
            protein <- product.protein,
            fat <- product.fat,
            fiber <- product.fiber,
            moisture <- product.moisture,
            ash <- product.ash,
            servingSize <- product.servingSize,
            updatedAt <- Int64(Date().timeIntervalSince1970),
            source <- product.source.rawValue
        )

        try db.run(update)
        try loadProducts()
    }

    func delete(_ product: Product) throws {
        guard let db = db else { return }

        let productRow = productsTable.filter(id == product.id.uuidString)
        try db.run(productRow.delete())
        try loadProducts()
    }

    func findByBarcode(_ barcodeValue: String) throws -> Product? {
        guard let db = db else { return nil }

        let query = productsTable.filter(barcode == barcodeValue)
        if let row = try db.pluck(query) {
            return rowToProduct(row)
        }
        return nil
    }

    func search(query: String) throws -> [Product] {
        guard let db = db else { return [] }

        let searchQuery = productsTable.filter(
            productName.like("%\(query)%") || brand.like("%\(query)%")
        ).order(updatedAt.desc)

        let rows = try db.prepare(searchQuery)
        return rows.compactMap { rowToProduct($0) }
    }

    // MARK: - Sync Metadata

    func getLastSyncTime() throws -> Date? {
        guard let db = db else { return nil }

        let query = syncMetadataTable.filter(metaKey == "last_sync")
        if let row = try db.pluck(query) {
            let timestamp = row[metaUpdatedAt]
            return Date(timeIntervalSince1970: TimeInterval(timestamp))
        }
        return nil
    }

    func setLastSyncTime(_ date: Date) throws {
        guard let db = db else { return }

        let timestamp = Int64(date.timeIntervalSince1970)
        let insert = syncMetadataTable.insert(
            or: .replace,
            metaKey <- "last_sync",
            metaValue <- ISO8601DateFormatter().string(from: date),
            metaUpdatedAt <- timestamp
        )

        try db.run(insert)
    }

    // MARK: - Bulk Operations (for GitHub sync)

    func bulkInsertOrUpdate(_ products: [Product]) throws {
        guard let db = db else { return }

        try db.transaction {
            for product in products {
                // Check if exists
                let query = productsTable.filter(barcode == product.barcode)
                if let existing = try db.pluck(query),
                   let existingProduct = rowToProduct(existing),
                   existingProduct.source == .local {
                    // Skip - preserve user data
                    continue
                }

                // Insert or update
                let upsert = productsTable.insert(
                    or: .replace,
                    id <- product.id.uuidString,
                    barcode <- product.barcode,
                    productName <- product.productName,
                    brand <- product.brand,
                    protein <- product.protein,
                    fat <- product.fat,
                    fiber <- product.fiber,
                    moisture <- product.moisture,
                    ash <- product.ash,
                    servingSize <- product.servingSize,
                    createdAt <- Int64(product.createdAt.timeIntervalSince1970),
                    updatedAt <- Int64(product.updatedAt.timeIntervalSince1970),
                    source <- product.source.rawValue
                )

                try db.run(upsert)
            }
        }

        try loadProducts()
    }

    // MARK: - Helper

    private func rowToProduct(_ row: Row) -> Product? {
        guard let uuid = UUID(uuidString: row[id]) else { return nil }

        return Product(
            id: uuid,
            barcode: row[barcode],
            productName: row[productName],
            brand: row[brand],
            protein: row[protein],
            fat: row[fat],
            fiber: row[fiber],
            moisture: row[moisture],
            ash: row[ash],
            servingSize: row[servingSize],
            createdAt: Date(timeIntervalSince1970: TimeInterval(row[createdAt])),
            updatedAt: Date(timeIntervalSince1970: TimeInterval(row[updatedAt])),
            source: ProductSource(rawValue: row[source]) ?? .local
        )
    }
}
