//
//  Product.swift
//  FitCat
//
//  Core data model for cat food products
//

import Foundation

enum ProductSource: String, Codable {
    case local   // User-entered data
    case github  // Downloaded from GitHub database
    case openpetfoodfacts  // Open Pet Food Facts API
}

struct Product: Identifiable, Codable, Equatable {
    let id: UUID
    var barcode: String?
    var productName: String
    var brand: String
    var protein: Double        // %
    var fat: Double            // %
    var fiber: Double          // %
    var moisture: Double       // %
    var ash: Double            // %
    var servingSize: String?
    var createdAt: Date
    var updatedAt: Date
    var source: ProductSource
    var categoriesTags: [String]?  // API categories for wet/dry detection

    // Computed properties
    var carbs: Double {
        NutritionCalculator.calculateCarbs(
            protein: protein,
            fat: fat,
            fiber: fiber,
            moisture: moisture,
            ash: ash
        )
    }

    var carbsLevel: CarbsLevel {
        NutritionCalculator.getCarbsLevel(carbs: carbs)
    }

    var calories: (proteinCal: Double, fatCal: Double, carbsCal: Double) {
        NutritionCalculator.calculateCalories(
            protein: protein,
            fat: fat,
            carbs: carbs
        )
    }

    var totalCalories: Double {
        let cals = calories
        return cals.proteinCal + cals.fatCal + cals.carbsCal
    }

    // Initializer
    init(
        id: UUID = UUID(),
        barcode: String? = nil,
        productName: String,
        brand: String,
        protein: Double,
        fat: Double,
        fiber: Double,
        moisture: Double,
        ash: Double,
        servingSize: String? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        source: ProductSource = .local,
        categoriesTags: [String]? = nil
    ) {
        self.id = id
        self.barcode = barcode
        self.productName = productName
        self.brand = brand
        self.protein = protein
        self.fat = fat
        self.fiber = fiber
        self.moisture = moisture
        self.ash = ash
        self.servingSize = servingSize
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.source = source
        self.categoriesTags = categoriesTags
    }

    // Coding keys for JSON serialization
    enum CodingKeys: String, CodingKey {
        case id
        case barcode
        case productName = "product_name"
        case brand
        case protein
        case fat
        case fiber
        case moisture
        case ash
        case servingSize = "serving_size"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case source
        case categoriesTags = "categories_tags"
    }
}

// MARK: - NutritionInfo (for OCR scanning results)
struct NutritionInfo {
    var protein: Double?
    var fat: Double?
    var fiber: Double?
    var moisture: Double?
    var ash: Double?

    var isComplete: Bool {
        protein != nil &&
        fat != nil &&
        fiber != nil &&
        moisture != nil &&
        ash != nil
    }

    var totalPercentage: Double {
        let p = protein ?? 0
        let f = fat ?? 0
        let fi = fiber ?? 0
        let m = moisture ?? 0
        let a = ash ?? 0
        return p + f + fi + m + a
    }

    var isValid: Bool {
        totalPercentage <= 100
    }
}
