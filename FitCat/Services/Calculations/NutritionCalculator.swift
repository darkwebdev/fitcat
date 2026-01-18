//
//  NutritionCalculator.swift
//  FitCat
//
//  Calculates carbohydrate percentage and determines carbs level (Green/Yellow/Red)
//

import Foundation
import SwiftUI

enum CarbsLevel {
    case good      // <= 5%
    case moderate  // > 5% and <= 10%
    case high      // > 10%

    var color: Color {
        switch self {
        case .good: return .green
        case .moderate: return .yellow
        case .high: return .red
        }
    }

    var description: String {
        switch self {
        case .good: return "Excellent"
        case .moderate: return "Acceptable"
        case .high: return "Too High"
        }
    }

    static func from(_ carbs: Double) -> CarbsLevel {
        if carbs < 5.0 {
            return .good
        } else if carbs < 10.0 {
            return .moderate
        } else {
            return .high
        }
    }
}

struct NutritionCalculator {
    /// Calculates carbohydrate percentage using the formula:
    /// carbs% = 100 * (100 - protein - fat - fiber - moisture - ash) / (100 - moisture)
    ///
    /// - Parameters:
    ///   - protein: Protein percentage (0-100)
    ///   - fat: Fat percentage (0-100)
    ///   - fiber: Fiber percentage (0-100)
    ///   - moisture: Moisture percentage (0-100)
    ///   - ash: Ash/minerals percentage (0-100)
    /// - Returns: Carbohydrate percentage, or 0 if calculation is invalid
    static func calculateCarbs(
        protein: Double,
        fat: Double,
        fiber: Double,
        moisture: Double,
        ash: Double
    ) -> Double {
        // Prevent division by zero
        guard moisture < 100 else { return 0 }

        let dryMatterBasis = 100 - moisture
        let carbsOnDryMatter = 100 - protein - fat - fiber - moisture - ash

        // Prevent negative carbs
        guard carbsOnDryMatter >= 0 else { return 0 }

        let carbs = 100 * carbsOnDryMatter / dryMatterBasis

        // Round to 2 decimal places
        return (carbs * 100).rounded() / 100
    }

    /// Determines the carbs level based on percentage thresholds
    ///
    /// - Parameter carbs: Carbohydrate percentage
    /// - Returns: CarbsLevel indicating quality (good/moderate/high)
    static func getCarbsLevel(carbs: Double) -> CarbsLevel {
        if carbs < 5.0 {
            return .good
        } else if carbs < 10.0 {
            return .moderate
        } else {
            return .high
        }
    }

    /// Calculates calories per 100g for each macronutrient
    ///
    /// - Parameters:
    ///   - protein: Protein percentage
    ///   - fat: Fat percentage
    ///   - carbs: Carbohydrate percentage
    /// - Returns: Tuple of (proteinCal, fatCal, carbsCal)
    static func calculateCalories(
        protein: Double,
        fat: Double,
        carbs: Double
    ) -> (proteinCal: Double, fatCal: Double, carbsCal: Double) {
        // Standard caloric values: protein = 3.5 kcal/g, fat = 8.5 kcal/g, carbs = 3.5 kcal/g
        let proteinCal = protein * 3.5
        let fatCal = fat * 8.5
        let carbsCal = carbs * 3.5

        return (
            (proteinCal * 100).rounded() / 100,
            (fatCal * 100).rounded() / 100,
            (carbsCal * 100).rounded() / 100
        )
    }
}
