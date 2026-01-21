//
//  OCRIntegrationTests.swift
//  FitCatTests
//
//  Integration tests for OCR and nutrition parsing
//

import XCTest
@testable import FitCat
import UIKit

final class OCRIntegrationTests: XCTestCase {
    var ocrService: OCRService!
    var parser: NutritionParser!

    override func setUpWithError() throws {
        ocrService = OCRService()
        parser = NutritionParser()
    }

    override func tearDownWithError() throws {
        ocrService = nil
        parser = nil
    }

    // MARK: - Image Loading Helpers

    func loadTestImage(named name: String) throws -> UIImage {
        guard let image = UIImage(named: name, in: Bundle(for: type(of: self)), compatibleWith: nil) else {
            XCTFail("Failed to load test image: \(name)")
            throw NSError(domain: "TestError", code: 1, userInfo: [NSLocalizedDescriptionKey: "Image not found"])
        }
        return image
    }

    // MARK: - Real Label Tests

    func testRealLabel_IMG2394() async throws {
        let image = try loadTestImage(named: "IMG_2394")

        // Run OCR
        let texts = try await ocrService.recognizeText(from: image)
        print("📸 IMG_2394 OCR detected \(texts.count) text items")
        print("📝 Full text:\n\(texts.joined(separator: "\n"))")

        // Verify OCR detected text
        XCTAssertFalse(texts.isEmpty, "OCR should detect text from the image")

        // Parse nutrition
        let nutrition = parser.parseNutrition(from: texts)

        print("✅ Parsed nutrition - Protein: \(nutrition.protein?.description ?? "nil"), Fat: \(nutrition.fat?.description ?? "nil"), Fiber: \(nutrition.fiber?.description ?? "nil"), Moisture: \(nutrition.moisture?.description ?? "nil"), Ash: \(nutrition.ash?.description ?? "nil")")

        // Verify at least some values were detected
        let detectedCount = [nutrition.protein, nutrition.fat, nutrition.fiber, nutrition.moisture, nutrition.ash].compactMap { $0 }.count
        XCTAssertGreaterThan(detectedCount, 0, "Should detect at least one nutrition value")

        // Report which values are missing
        if nutrition.protein == nil { print("⚠️ Protein not detected") }
        if nutrition.fat == nil { print("⚠️ Fat not detected") }
        if nutrition.fiber == nil { print("⚠️ Fiber not detected") }
        if nutrition.moisture == nil { print("⚠️ Moisture not detected") }
        if nutrition.ash == nil { print("⚠️ Ash not detected") }
    }

    func testRealLabel_IMG2395() async throws {
        let image = try loadTestImage(named: "IMG_2395")

        // Run OCR
        let texts = try await ocrService.recognizeText(from: image)
        print("📸 IMG_2395 OCR detected \(texts.count) text items")
        print("📝 Full text:\n\(texts.joined(separator: "\n"))")

        // Verify OCR detected text
        XCTAssertFalse(texts.isEmpty, "OCR should detect text from the image")

        // Parse nutrition
        let nutrition = parser.parseNutrition(from: texts)

        print("✅ Parsed nutrition - Protein: \(nutrition.protein?.description ?? "nil"), Fat: \(nutrition.fat?.description ?? "nil"), Fiber: \(nutrition.fiber?.description ?? "nil"), Moisture: \(nutrition.moisture?.description ?? "nil"), Ash: \(nutrition.ash?.description ?? "nil")")

        // Verify at least some values were detected
        let detectedCount = [nutrition.protein, nutrition.fat, nutrition.fiber, nutrition.moisture, nutrition.ash].compactMap { $0 }.count
        XCTAssertGreaterThan(detectedCount, 0, "Should detect at least one nutrition value")
    }

    func testRealLabel_Nutrition() async throws {
        let image = try loadTestImage(named: "nutrition")

        // Run OCR
        let texts = try await ocrService.recognizeText(from: image)
        print("📸 nutrition.jpeg OCR detected \(texts.count) text items")
        print("📝 Full text:\n\(texts.joined(separator: "\n"))")

        // Verify OCR detected text
        XCTAssertFalse(texts.isEmpty, "OCR should detect text from the image")

        // Parse nutrition
        let nutrition = parser.parseNutrition(from: texts)

        print("✅ Parsed nutrition - Protein: \(nutrition.protein?.description ?? "nil"), Fat: \(nutrition.fat?.description ?? "nil"), Fiber: \(nutrition.fiber?.description ?? "nil"), Moisture: \(nutrition.moisture?.description ?? "nil"), Ash: \(nutrition.ash?.description ?? "nil")")

        // Verify at least some values were detected
        let detectedCount = [nutrition.protein, nutrition.fat, nutrition.fiber, nutrition.moisture, nutrition.ash].compactMap { $0 }.count
        XCTAssertGreaterThan(detectedCount, 0, "Should detect at least one nutrition value")
    }

    // MARK: - Dry Food Label Tests

    func testDryFoodLabelOCR() async throws {
        let image = try loadTestImage(named: "label-dry-food")

        // Run OCR
        let texts = try await ocrService.recognizeText(from: image)

        // Verify OCR detected text
        XCTAssertFalse(texts.isEmpty, "OCR should detect text from the image")

        // Parse nutrition
        let nutrition = parser.parseNutrition(from: texts)

        // Verify parsed values
        XCTAssertNotNil(nutrition.protein, "Should detect protein")
        XCTAssertNotNil(nutrition.fat, "Should detect fat")
        XCTAssertNotNil(nutrition.fiber, "Should detect fiber")
        XCTAssertNotNil(nutrition.moisture, "Should detect moisture")
        XCTAssertNotNil(nutrition.ash, "Should detect ash")

        // Verify values are approximately correct
        if let protein = nutrition.protein {
            XCTAssertEqual(protein, 40.0, accuracy: 1.0, "Protein should be ~40%")
        }
        if let fat = nutrition.fat {
            XCTAssertEqual(fat, 18.0, accuracy: 1.0, "Fat should be ~18%")
        }
        if let fiber = nutrition.fiber {
            XCTAssertEqual(fiber, 3.0, accuracy: 0.5, "Fiber should be ~3%")
        }
        if let moisture = nutrition.moisture {
            XCTAssertEqual(moisture, 10.0, accuracy: 1.0, "Moisture should be ~10%")
        }
        if let ash = nutrition.ash {
            XCTAssertEqual(ash, 8.0, accuracy: 1.0, "Ash should be ~8%")
        }
    }

    // MARK: - Parser Tests with Known Text

    func testParserWithKnownText() {
        let text = """
        GUARANTEED ANALYSIS
        Crude Protein (min) 11.5%
        Crude Fat (min) 6.5%
        Crude Fiber (max) 0.5%
        Moisture (max) 79.0%
        Ash (max) 1.8%
        """

        let nutrition = parser.parseNutrition(from: [text])

        XCTAssertEqual(nutrition.protein, 11.5, "Should parse protein correctly")
        XCTAssertEqual(nutrition.fat, 6.5, "Should parse fat correctly")
        XCTAssertEqual(nutrition.fiber, 0.5, "Should parse fiber correctly")
        XCTAssertEqual(nutrition.moisture, 79.0, "Should parse moisture correctly")
        XCTAssertEqual(nutrition.ash, 1.8, "Should parse ash correctly")
    }

    func testParserWithVariousFormats() {
        // Test different formats that might appear on labels
        let formats = [
            ("Protein 12%", 12.0),
            ("Crude Protein (min) 12.5%", 12.5),
            ("Protein (min) ........... 12.5%", 12.5),
            ("PROTEIN: 12%", 12.0)
        ]

        for (text, expected) in formats {
            let nutrition = parser.parseNutrition(from: [text])
            XCTAssertNotNil(nutrition.protein, "Failed to parse: '\(text)'")
            if let protein = nutrition.protein {
                XCTAssertEqual(protein, expected, accuracy: 0.1, "Failed to parse: '\(text)'")
            }
        }
    }

    func testParserWithEuropeanNumberFormat() {
        // European format uses comma as decimal separator
        let text = """
        Protein 11,5%
        Fat 6,5%
        Fiber 0,5%
        """

        let nutrition = parser.parseNutrition(from: [text])

        XCTAssertEqual(nutrition.protein ?? 0, 11.5, "Should handle comma decimal separator")
        XCTAssertEqual(nutrition.fat ?? 0, 6.5, "Should handle comma decimal separator")
        XCTAssertEqual(nutrition.fiber ?? 0, 0.5, "Should handle comma decimal separator")
    }

    // MARK: - OCR Error Handling Tests

    func testOCRMissingDecimalPoint() {
        // OCR may miss decimal point: "2.1" becomes "21"
        // Should pick most frequent correct value, not average
        let scans = [
            "Ash 2.1%",   // Correct
            "Ash 21%",    // Missing decimal (OCR error)
            "Ash 2.1%"    // Correct
        ]

        var ashValues: [Double] = []
        for scan in scans {
            let nutrition = parser.parseNutrition(from: [scan])
            if let ash = nutrition.ash {
                ashValues.append(ash)
            }
        }

        // Should get [2.1, 21, 2.1]
        XCTAssertEqual(ashValues.count, 3, "Should detect ash from all 3 scans")

        // Consensus should pick 2.1 (appears 2x), not 21 or average
        // Note: This test validates the concept - actual consensus logic is in OCRScannerView
        let correctValues = ashValues.filter { $0 < 5.0 }  // Filter out 21
        XCTAssertEqual(correctValues.count, 2, "Should have 2 correct readings")
        XCTAssertTrue(correctValues.allSatisfy { abs($0 - 2.1) < 0.1 }, "Correct values should be ~2.1")
    }

    func testOCRDigitConfusion() {
        // OCR may confuse similar digits: 1 vs 7, 0 vs 8
        let scans = [
            "Protein 11.5%",   // Correct
            "Protein 17.5%",   // 1→7 confusion (OCR error)
            "Protein 11.5%",   // Correct
            "Protein 11.5%"    // Correct
        ]

        var proteinValues: [Double] = []
        for scan in scans {
            let nutrition = parser.parseNutrition(from: [scan])
            if let protein = nutrition.protein {
                proteinValues.append(protein)
            }
        }

        // Should get [11.5, 17.5, 11.5, 11.5]
        XCTAssertEqual(proteinValues.count, 4, "Should detect protein from all scans")

        // 11.5 appears 3x (most frequent), 17.5 appears 1x (error)
        let correctCount = proteinValues.filter { abs($0 - 11.5) < 0.1 }.count
        XCTAssertEqual(correctCount, 3, "11.5% should appear 3 times")
    }

    func testOCRDecimalSeparatorConfusion() {
        // OCR may confuse decimal point with comma
        let scans = [
            "Fat 6.5%",    // Correct (English)
            "Fat 6,5%",    // Comma separator (European) - parser should handle
            "Fat 6.5%"     // Correct
        ]

        var fatValues: [Double] = []
        for scan in scans {
            let nutrition = parser.parseNutrition(from: [scan])
            if let fat = nutrition.fat {
                fatValues.append(fat)
            }
        }

        // Parser should normalize both to 6.5
        XCTAssertEqual(fatValues.count, 3, "Should parse both comma and dot separators")
        XCTAssertTrue(fatValues.allSatisfy { abs($0 - 6.5) < 0.1 }, "All should be 6.5")
    }

    func testOCRExtraDecimalPoint() {
        // OCR may add extra decimal from dirt/artifact: "21" becomes "2.1"
        // Should pick most frequent value
        let scans = [
            "Moisture 78%",    // Correct (wet food)
            "Moisture 7.8%",   // Extra decimal (OCR error - dry food range)
            "Moisture 78%"     // Correct
        ]

        var moistureValues: [Double] = []
        for scan in scans {
            let nutrition = parser.parseNutrition(from: [scan])
            if let moisture = nutrition.moisture {
                moistureValues.append(moisture)
            }
        }

        // Should get [78, 7.8, 78]
        XCTAssertEqual(moistureValues.count, 3, "Should detect moisture from all 3 scans")

        // Most frequent value is 78 (appears 2x)
        let mode = moistureValues.filter { abs($0 - 78.0) < 0.5 }
        XCTAssertEqual(mode.count, 2, "78% should appear twice")
    }

    // MARK: - Bug Reproduction Tests

    func testAshAndMoistureDetectionOrder() {
        // BUG: When ash and moisture are detected in same scan,
        // ash validation fails because moisture hasn't been added to array yet
        // This causes isWetFood=false, making ash 2.1% invalid
        let text = """
        Moisture (max) 79.0%
        Ash (max) 2.1%
        """

        let nutrition = parser.parseNutrition(from: [text])

        // Both should be detected by parser
        XCTAssertNotNil(nutrition.moisture, "Moisture should be parsed")
        XCTAssertNotNil(nutrition.ash, "Ash should be parsed")
        XCTAssertEqual(nutrition.moisture, 79.0, "Moisture should be 79.0%")
        XCTAssertEqual(nutrition.ash, 2.1, "Ash should be 2.1%")
    }

    func testAshDetectionForWetFood() {
        // Reproduce bug: Ash 2.1% is detected by OCR but not displayed
        // Product: Carny Adult (wet food with 79% moisture)
        // Expected: Ash 2.1% should be valid for wet food (range 1.5-4%)
        let text = """
        GUARANTEED ANALYSIS
        Crude Protein (min) 10.5%
        Crude Fat (min) 65.0%
        Moisture (max) 79.0%
        Ash (max) 2.1%
        """

        let nutrition = parser.parseNutrition(from: [text])

        XCTAssertEqual(nutrition.protein, 10.5, "Should parse protein")
        XCTAssertEqual(nutrition.fat, 65.0, "Should parse fat")
        XCTAssertEqual(nutrition.moisture, 79.0, "Should parse moisture")
        XCTAssertEqual(nutrition.ash, 2.1, "Should parse ash 2.1%")

        // This is the key assertion - ash should be detected!
        XCTAssertNotNil(nutrition.ash, "Ash should be detected from OCR")
    }

    func testAshValidationForWetFood() {
        // Test that ash values in wet food range (1.5-4%) are valid
        let validAshValues = [1.5, 2.0, 2.1, 3.0, 4.0]

        for ashValue in validAshValues {
            let text = "Moisture 79% Ash \(ashValue)%"
            let nutrition = parser.parseNutrition(from: [text])

            XCTAssertNotNil(nutrition.ash, "Ash should be detected")
            if let ash = nutrition.ash {
                XCTAssertEqual(ash, ashValue, accuracy: 0.1,
                              "Ash \(ashValue)% should be parsed for wet food")
            }
        }
    }

    func testAshValidationForDryFood() {
        // Test that ash values in dry food range (3.5-12%) are valid
        let validAshValues = [3.5, 5.0, 8.0, 12.0]

        for ashValue in validAshValues {
            let text = "Moisture 10% Ash \(ashValue)%"
            let nutrition = parser.parseNutrition(from: [text])

            XCTAssertNotNil(nutrition.ash, "Ash should be detected")
            if let ash = nutrition.ash {
                XCTAssertEqual(ash, ashValue, accuracy: 0.1,
                              "Ash \(ashValue)% should be parsed for dry food")
            }
        }
    }

    // MARK: - Performance Tests

    func testOCRPerformance() async throws {
        let image = try loadTestImage(named: "label-wet-food")

        measure {
            let expectation = XCTestExpectation(description: "OCR completes")
            Task {
                _ = try? await ocrService.recognizeText(from: image)
                expectation.fulfill()
            }
            wait(for: [expectation], timeout: 10.0)
        }
    }
}
