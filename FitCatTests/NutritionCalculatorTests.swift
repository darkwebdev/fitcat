//
//  NutritionCalculatorTests.swift
//  FitCatTests
//
//  Unit tests for nutrition calculations
//

import XCTest
@testable import FitCat

final class NutritionCalculatorTests: XCTestCase {
    /// Test the carbs calculation from Google Sheet example
    /// protein=11.5, fat=6.5, fiber=0.5, moisture=79, ash=1.8
    /// Expected: carbs = 100*(100-11.5-6.5-0.5-79-1.8)/(100-79) = 3.33%
    func testCarbsCalculationFromGoogleSheet() {
        let carbs = NutritionCalculator.calculateCarbs(
            protein: 11.5,
            fat: 6.5,
            fiber: 0.5,
            moisture: 79,
            ash: 1.8
        )

        XCTAssertEqual(carbs, 3.33, accuracy: 0.01)
    }

    /// Test the carbs calculation with high carb content
    /// protein=40, fat=18, fiber=3, moisture=10, ash=8
    /// Expected: carbs = 100*(100-40-18-3-10-8)/(100-10) = 23.33%
    func testCarbsCalculationHighCarbs() {
        let carbs = NutritionCalculator.calculateCarbs(
            protein: 40,
            fat: 18,
            fiber: 3,
            moisture: 10,
            ash: 8
        )

        XCTAssertEqual(carbs, 23.33, accuracy: 0.01)
    }

    /// Test edge case: zero moisture (should prevent division by zero)
    func testCarbsCalculationZeroMoisture() {
        let carbs = NutritionCalculator.calculateCarbs(
            protein: 40,
            fat: 18,
            fiber: 3,
            moisture: 0,
            ash: 8
        )

        // Should handle gracefully, likely return difference as carbs
        XCTAssertGreaterThanOrEqual(carbs, 0)
    }

    /// Test edge case: 100% moisture (should return 0)
    func testCarbsCalculation100Moisture() {
        let carbs = NutritionCalculator.calculateCarbs(
            protein: 0,
            fat: 0,
            fiber: 0,
            moisture: 100,
            ash: 0
        )

        XCTAssertEqual(carbs, 0)
    }

    /// Test negative carbs protection
    func testNegativeCarbsProtection() {
        let carbs = NutritionCalculator.calculateCarbs(
            protein: 50,
            fat: 30,
            fiber: 10,
            moisture: 10,
            ash: 10
        )

        // Total > 100, should return 0
        XCTAssertEqual(carbs, 0)
    }

    /// Test carbs level: good (<=5%)
    func testCarbsLevelGood() {
        let level = NutritionCalculator.getCarbsLevel(carbs: 3.33)
        XCTAssertEqual(level, .good)

        let level2 = NutritionCalculator.getCarbsLevel(carbs: 5.0)
        XCTAssertEqual(level2, .good)
    }

    /// Test carbs level: moderate (5-10%)
    func testCarbsLevelModerate() {
        let level = NutritionCalculator.getCarbsLevel(carbs: 7.5)
        XCTAssertEqual(level, .moderate)

        let level2 = NutritionCalculator.getCarbsLevel(carbs: 10.0)
        XCTAssertEqual(level2, .moderate)
    }

    /// Test carbs level: high (>10%)
    func testCarbsLevelHigh() {
        let level = NutritionCalculator.getCarbsLevel(carbs: 23.33)
        XCTAssertEqual(level, .high)

        let level2 = NutritionCalculator.getCarbsLevel(carbs: 15.0)
        XCTAssertEqual(level2, .high)
    }

    /// Test calorie calculations
    func testCalorieCalculations() {
        let calories = NutritionCalculator.calculateCalories(
            protein: 11.5,
            fat: 6.5,
            carbs: 3.33
        )

        // Protein: 11.5 * 3.5 = 40.25 kcal
        // Fat: 6.5 * 8.5 = 55.25 kcal
        // Carbs: 3.33 * 3.5 = 11.655 kcal

        XCTAssertEqual(calories.proteinCal, 40.25, accuracy: 0.1)
        XCTAssertEqual(calories.fatCal, 55.25, accuracy: 0.1)
        XCTAssertEqual(calories.carbsCal, 11.66, accuracy: 0.1)
    }
}
