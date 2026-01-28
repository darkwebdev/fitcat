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

struct NutritionValidation {
    enum ValidationError {
        case totalTooHigh(Double)
        case proteinTooHigh(Double)
        case fatTooHigh(Double)
        case fiberTooHigh(Double)
        case moistureTooHigh(Double)
        case moistureTooLow(Double)
        case moistureUnusualRange(Double)
        case ashTooHigh(Double)
        case carbsHigh(Double)
        case carbsTooHigh(Double)

        var message: String {
            switch self {
            case .totalTooHigh(let total):
                return "Total \(String(format: "%.1f", total))% exceeds 100%. Please verify values."
            case .proteinTooHigh(let value):
                return "Protein \(String(format: "%.1f", value))% is unusually high. Typical range: 7-15% (wet) or 30-50% (dry)."
            case .fatTooHigh(let value):
                return "Fat \(String(format: "%.1f", value))% is unusually high. Typical range: 2-10% (wet) or 10-25% (dry)."
            case .fiberTooHigh(let value):
                return "Fiber \(String(format: "%.1f", value))% is unusually high. Typical range: 0.5-3%."
            case .moistureTooHigh(let value):
                return "Moisture \(String(format: "%.1f", value))% is invalid. Must be less than 100%."
            case .moistureTooLow(let value):
                return "Moisture \(String(format: "%.1f", value))% is too low. Dry food: 6-12%, wet food: 70-85%."
            case .moistureUnusualRange(let value):
                return "Moisture \(String(format: "%.1f", value))% is unusual. Dry food: 6-12%, semi-moist: 15-30%, wet food: 70-85%."
            case .ashTooHigh(let value):
                return "Ash \(String(format: "%.1f", value))% is unusually high. Typical range: 1-3% (wet) or 5-10% (dry)."
            case .carbsHigh(let value):
                return "Carbs \(String(format: "%.1f", value))% is high. Ideally under 10%, but up to 30% is common in dry food."
            case .carbsTooHigh(let value):
                return "Carbs \(String(format: "%.1f", value))% is extremely high. Should be under 30% for cat food."
            }
        }
    }

    /// Validates nutrition values and returns any errors found
    static func validate(
        protein: Double?,
        fat: Double?,
        fiber: Double?,
        moisture: Double?,
        ash: Double?
    ) -> [ValidationError] {
        var errors: [ValidationError] = []

        // Check total percentage
        let p = protein ?? 0
        let f = fat ?? 0
        let fi = fiber ?? 0
        let m = moisture ?? 0
        let a = ash ?? 0
        let total = p + f + fi + m + a

        if total > 105 {
            errors.append(.totalTooHigh(total))
        }

        // Determine food type based on moisture
        // Dry: 6-12%, Semi-moist: 15-30%, Wet: 70-85%
        let isDryFood = m >= 6 && m <= 12
        let isSemiMoist = m >= 15 && m <= 30
        let isWetFood = m >= 70 && m <= 85

        // For validation ranges, use wet food thresholds if moisture > 50%
        let useWetFoodLimits = m > 50

        // Validate protein
        if let proteinValue = protein {
            let maxProtein = useWetFoodLimits ? 20.0 : 60.0
            if proteinValue > maxProtein {
                errors.append(.proteinTooHigh(proteinValue))
            }
        }

        // Validate fat
        if let fatValue = fat {
            let maxFat = useWetFoodLimits ? 15.0 : 30.0
            if fatValue > maxFat {
                errors.append(.fatTooHigh(fatValue))
            }
        }

        // Validate fiber
        if let fiberValue = fiber, fiberValue > 5.0 {
            errors.append(.fiberTooHigh(fiberValue))
        }

        // Validate moisture - most critical for determining food type
        if let moistureValue = moisture {
            if moistureValue >= 100 {
                // Impossible value
                errors.append(.moistureTooHigh(moistureValue))
            } else if moistureValue < 6 {
                // Too low for any cat food
                errors.append(.moistureTooLow(moistureValue))
            } else if moistureValue >= 6 && moistureValue <= 12 {
                // Dry food range - OK
            } else if moistureValue > 12 && moistureValue < 15 {
                // Below semi-moist range
                errors.append(.moistureUnusualRange(moistureValue))
            } else if moistureValue >= 15 && moistureValue <= 30 {
                // Semi-moist range - OK but uncommon
            } else if moistureValue > 30 && moistureValue < 70 {
                // Unusual middle range
                errors.append(.moistureUnusualRange(moistureValue))
            } else if moistureValue >= 70 && moistureValue <= 85 {
                // Wet food range - OK
            } else if moistureValue > 85 && moistureValue < 100 {
                // Too high for wet food but technically possible
                errors.append(.moistureUnusualRange(moistureValue))
            }
        }

        // Validate ash
        if let ashValue = ash {
            let maxAsh = useWetFoodLimits ? 5.0 : 12.0
            if ashValue > maxAsh {
                errors.append(.ashTooHigh(ashValue))
            }
        }

        // Validate calculated carbs
        if protein != nil && fat != nil && fiber != nil && moisture != nil && ash != nil {
            let carbs = NutritionCalculator.calculateCarbs(
                protein: p,
                fat: f,
                fiber: fi,
                moisture: m,
                ash: a
            )
            if carbs > 30.0 {
                // Extremely high - likely an error
                errors.append(.carbsTooHigh(carbs))
            } else if carbs > 10.0 {
                // High but not uncommon, especially in dry food
                errors.append(.carbsHigh(carbs))
            }
        }

        return errors
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
