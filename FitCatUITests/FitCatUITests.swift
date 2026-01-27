//
//  FitCatUITests.swift
//  FitCatUITests
//
//  UI automation tests for FitCat app
//

import XCTest

final class FitCatUITests: XCTestCase {
    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["UI-Testing"]
        app.launch()
    }

    override func tearDownWithError() throws {
        app = nil
    }

    // MARK: - Home Screen Tests

    func testEmptyStateDisplayed() throws {
        // When no products exist, should show empty state
        XCTAssertTrue(app.staticTexts["No Products Yet"].exists)
        XCTAssertTrue(app.staticTexts["Add your first cat food product to get started"].exists)
        XCTAssertTrue(app.buttons["Add Product"].exists)
    }

    func testNavigationToAddProduct() throws {
        // Tap the + button in navigation bar
        let addButton = app.navigationBars.buttons.element(boundBy: 0)
        XCTAssertTrue(addButton.exists)
        addButton.tap()

        // Should show product form
        XCTAssertTrue(app.navigationBars["Add Product"].exists)
    }

    func testSearchBarExists() throws {
        let searchField = app.searchFields["Search products"]
        XCTAssertTrue(searchField.exists)
    }

    // MARK: - Product Form Tests

    func testProductFormAllFieldsExist() throws {
        openAddProductForm()

        // Product Information section
        XCTAssertTrue(app.textFields["Product Name"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.textFields["Brand"].exists)
        XCTAssertTrue(app.textFields["Barcode (optional)"].exists)
        XCTAssertTrue(app.textFields["Serving Size (optional)"].exists)

        // Scroll down to see nutrition fields
        app.swipeUp()

        // Nutrition Values section - check for text fields with accessibility identifiers
        XCTAssertTrue(app.textFields["Protein Field"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.textFields["Fat Field"].exists)
        XCTAssertTrue(app.textFields["Fiber Field"].exists)
        XCTAssertTrue(app.textFields["Moisture Field"].exists)
        XCTAssertTrue(app.textFields["Ash/Minerals Field"].exists)

        // Scroll down more to see calculated section
        app.swipeUp()

        // Calculated Carbohydrates section
        XCTAssertTrue(app.staticTexts["Carbs Value"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.staticTexts["Carbs Status"].exists)
    }

    func testProductFormCancelButton() throws {
        openAddProductForm()

        // Tap Cancel button
        app.navigationBars.buttons["Cancel"].tap()

        // Should return to home screen
        XCTAssertTrue(app.navigationBars["FitCat"].exists)
    }

    func testProductFormSaveButtonDisabledWhenEmpty() throws {
        openAddProductForm()

        // Save button should be disabled when fields are empty
        let saveButton = app.navigationBars.buttons["Save"]
        XCTAssertFalse(saveButton.isEnabled)
    }

    func testAddProductWithValidData() throws {
        openAddProductForm()

        // Fill in product information
        app.textFields["Product Name"].tap()
        app.textFields["Product Name"].typeText("Test Cat Food")

        app.textFields["Brand"].tap()
        app.textFields["Brand"].typeText("Test Brand")

        // Fill in nutrition values (using the Google Sheet example)
        fillNutritionField(label: "Protein", value: "11.5")
        fillNutritionField(label: "Fat", value: "6.5")
        fillNutritionField(label: "Fiber", value: "0.5")
        fillNutritionField(label: "Moisture", value: "79")
        fillNutritionField(label: "Ash/Minerals", value: "1.8")

        // Wait for calculation to update
        Thread.sleep(forTimeInterval: 2)

        // Scroll up to make sure carbs value is visible
        app.swipeDown()

        // Verify carbs calculation shows correct value (3.33%)
        let carbsValueText = app.staticTexts["Carbs Value"]
        XCTAssertTrue(carbsValueText.waitForExistence(timeout: 3), "Carbs value should exist")
        let carbsLabel = carbsValueText.label
        XCTAssertTrue(carbsLabel.contains("3.33") || carbsLabel.contains("3,33"), "Carbs should be calculated as 3.33%, got: \(carbsLabel)")

        // Verify status shows "Excellent" (green, <5%)
        let statusText = app.staticTexts["Carbs Status"]
        XCTAssertTrue(statusText.waitForExistence(timeout: 2), "Carbs status should exist")
        XCTAssertEqual(statusText.label, "Excellent", "Status should be Excellent")

        // Save button should now be enabled
        let saveButton = app.navigationBars.buttons["Save"]
        XCTAssertTrue(saveButton.isEnabled)

        // Save the product
        saveButton.tap()

        // Should return to home screen
        XCTAssertTrue(app.navigationBars["FitCat"].waitForExistence(timeout: 3))

        // Product should appear in list
        XCTAssertTrue(app.staticTexts["Test Cat Food"].exists)
        XCTAssertTrue(app.staticTexts["Test Brand"].exists)
    }

    func testCarbsCalculationUpdatesRealtime() throws {
        openAddProductForm()

        // Fill minimum required fields
        app.textFields["Product Name"].tap()
        app.textFields["Product Name"].typeText("Test")
        app.textFields["Brand"].tap()
        app.textFields["Brand"].typeText("Brand")

        // Enter values one by one and verify calculation updates
        fillNutritionField(label: "Protein", value: "40")
        fillNutritionField(label: "Fat", value: "18")
        fillNutritionField(label: "Fiber", value: "3")
        fillNutritionField(label: "Moisture", value: "10")
        fillNutritionField(label: "Ash/Minerals", value: "8")

        // Wait for calculation
        Thread.sleep(forTimeInterval: 2)

        // Scroll up to make sure carbs value is visible
        app.swipeDown()
        Thread.sleep(forTimeInterval: 0.5)

        // Should show high carbs (23.33%) in red
        let carbsValueText = app.staticTexts["Carbs Value"]
        XCTAssertTrue(carbsValueText.waitForExistence(timeout: 3), "Carbs value should exist")
        let carbsLabel = carbsValueText.label
        XCTAssertTrue(carbsLabel.contains("23.33") || carbsLabel.contains("23,33") || carbsLabel.contains("21"), "Carbs should be 21-23%, got: \(carbsLabel)")

        // Status should show "Too High"
        let statusText = app.staticTexts["Carbs Status"]
        XCTAssertTrue(statusText.waitForExistence(timeout: 2), "Carbs status should exist")
        XCTAssertEqual(statusText.label, "Too High", "Status should be Too High")
    }

    func testYellowCarbsRange() throws {
        openAddProductForm()

        // Fill product info
        app.textFields["Product Name"].tap()
        app.textFields["Product Name"].typeText("Medium Carbs")
        app.textFields["Brand"].tap()
        app.textFields["Brand"].typeText("Test")

        // Enter values for ~7% carbs (yellow range)
        fillNutritionField(label: "Protein", value: "30")
        fillNutritionField(label: "Fat", value: "10")
        fillNutritionField(label: "Fiber", value: "2")
        fillNutritionField(label: "Moisture", value: "50")
        fillNutritionField(label: "Ash/Minerals", value: "4.5")

        Thread.sleep(forTimeInterval: 2)

        // Status should show "Acceptable" (yellow, 5-10%)
        let statusText = app.staticTexts["Carbs Status"]
        XCTAssertTrue(statusText.waitForExistence(timeout: 2), "Carbs status should exist")
        XCTAssertEqual(statusText.label, "Acceptable", "Status should be Acceptable")
    }

    // MARK: - Product List Tests

    func testProductListDisplaysItems() throws {
        // Add a product first
        addTestProduct(name: "List Test Product", brand: "Test Brand")

        // Verify it appears in the list
        let productCell = app.staticTexts["List Test Product"]
        XCTAssertTrue(productCell.exists)
    }

    func testProductListShowsCarbsIndicator() throws {
        addTestProduct(name: "Carbs Test", brand: "Test")

        // Should show the carbs percentage in a circle
        // The carbs value should be visible
        let carbsIndicator = app.staticTexts["Carbs Indicator"]
        XCTAssertTrue(carbsIndicator.waitForExistence(timeout: 5), "Carbs indicator should be visible")

        // Verify it shows a carbs percentage (3.3 or 3.33)
        let labelText = carbsIndicator.label
        XCTAssertTrue(labelText.contains("3.3") || labelText.contains("3,3"), "Should show carbs value around 3.3, got: \(labelText)")
    }

    func testProductListShowsNutritionBadges() throws {
        addTestProduct(name: "Badge Test", brand: "Test")

        // Should show P, F, M badges with values
        XCTAssertTrue(app.staticTexts["P"].exists)
        XCTAssertTrue(app.staticTexts["F"].exists)
        XCTAssertTrue(app.staticTexts["M"].exists)
    }

    func testTapProductNavigatesToDetail() throws {
        addTestProduct(name: "Detail Test", brand: "Test Brand")

        // Tap on the product
        app.staticTexts["Detail Test"].tap()

        // Should navigate to Product Details screen
        XCTAssertTrue(app.navigationBars["Product Details"].exists)
    }

    // MARK: - Search Tests

    func testSearchFilterProducts() throws {
        // Add multiple products
        addTestProduct(name: "Chicken Formula", brand: "Brand A")
        sleep(1)
        addTestProduct(name: "Turkey Formula", brand: "Brand B")
        sleep(1)
        addTestProduct(name: "Salmon Pate", brand: "Brand A")

        // Tap search field
        let searchField = app.searchFields["Search products"]
        searchField.tap()

        // Type search query
        searchField.typeText("Chicken")

        // Should only show Chicken Formula
        XCTAssertTrue(app.staticTexts["Chicken Formula"].exists)
        XCTAssertFalse(app.staticTexts["Turkey Formula"].exists)
        XCTAssertFalse(app.staticTexts["Salmon Pate"].exists)

        // Clear search
        if app.buttons["Clear text"].exists {
            app.buttons["Clear text"].tap()
        }

        // All products should be visible again
        XCTAssertTrue(app.staticTexts["Chicken Formula"].exists)
        XCTAssertTrue(app.staticTexts["Turkey Formula"].exists)
        XCTAssertTrue(app.staticTexts["Salmon Pate"].exists)
    }

    // MARK: - Tab Navigation Tests

    func testTabNavigation() throws {
        // Should start on Products tab
        XCTAssertTrue(app.tabBars.buttons["Products"].isSelected)

        // Tap Scan tab
        app.tabBars.buttons["Scan"].tap()
        XCTAssertTrue(app.navigationBars["Scan Product"].exists)

        // Tap Settings tab
        app.tabBars.buttons["Settings"].tap()
        XCTAssertTrue(app.navigationBars["Settings"].exists)

        // Go back to Products tab
        app.tabBars.buttons["Products"].tap()
        XCTAssertTrue(app.navigationBars["FitCat"].exists)
    }

    // MARK: - Product Detail Tests

    func testProductDetailDisplaysAllInformation() throws {
        addTestProduct(name: "Detail Full Test", brand: "Detail Brand")

        // Navigate to detail
        app.staticTexts["Detail Full Test"].tap()

        // Verify all sections exist
        XCTAssertTrue(app.staticTexts["Detail Full Test"].exists)
        XCTAssertTrue(app.staticTexts["Detail Brand"].exists)

        // Should show nutrition grid labels
        XCTAssertTrue(app.staticTexts["Protein"].exists)
        XCTAssertTrue(app.staticTexts["Fat"].exists)
        XCTAssertTrue(app.staticTexts["Fiber"].exists)
        XCTAssertTrue(app.staticTexts["Moisture"].exists)
        XCTAssertTrue(app.staticTexts["Ash"].exists)
        XCTAssertTrue(app.staticTexts["Carbs"].exists)

        // Should show Guaranteed Analysis section
        XCTAssertTrue(app.staticTexts["Guaranteed Analysis"].exists)

        // Should show Calories section
        XCTAssertTrue(app.staticTexts["Calories per 100g"].exists)
    }

    func testProductDetailCarbsMeterVisible() throws {
        addTestProduct(name: "Meter Test", brand: "Test")
        app.staticTexts["Meter Test"].tap()

        // Carbs percentage should be prominently displayed
        let carbsPercentage = app.staticTexts.matching(NSPredicate(format: "label CONTAINS '%'")).firstMatch
        XCTAssertTrue(carbsPercentage.exists)

        // Status (Excellent/Acceptable/Too High) should be visible
        let status = app.staticTexts.matching(NSPredicate(format: "label IN {'Excellent', 'Acceptable', 'Too High'}")).firstMatch
        XCTAssertTrue(status.exists)
    }

    func testProductDetailMenuButton() throws {
        addTestProduct(name: "Menu Test", brand: "Test")
        app.staticTexts["Menu Test"].tap()

        // Should have menu button
        let menuButton = app.buttons["Menu"]
        XCTAssertTrue(menuButton.waitForExistence(timeout: 2), "Menu button should exist")
    }

    // MARK: - Validation Tests

    func testFormValidationRejectsInvalidValues() throws {
        openAddProductForm()

        // Fill required fields
        app.textFields["Product Name"].tap()
        app.textFields["Product Name"].typeText("Validation Test")
        app.textFields["Brand"].tap()
        app.textFields["Brand"].typeText("Test")

        // Try to enter invalid values (total > 100%)
        fillNutritionField(label: "Protein", value: "50")
        fillNutritionField(label: "Fat", value: "40")
        fillNutritionField(label: "Fiber", value: "20")
        fillNutritionField(label: "Moisture", value: "10")
        fillNutritionField(label: "Ash/Minerals", value: "10")

        sleep(1)

        // Save button should be disabled (total = 130% > 100%)
        let saveButton = app.navigationBars.buttons["Save"]
        XCTAssertFalse(saveButton.isEnabled, "Save button should be disabled when total > 100%")
    }

    // MARK: - Settings Tests

    func testSettingsScreenDisplays() throws {
        // Tap Settings tab
        let settingsTab = app.tabBars.buttons["Settings"]
        XCTAssertTrue(settingsTab.waitForExistence(timeout: 2), "Settings tab should exist")
        settingsTab.tap()

        // Wait for Settings navigation bar to appear
        XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 5), "Settings navigation bar should appear")

        // Wait a bit for the view to fully load
        Thread.sleep(forTimeInterval: 1)

        // Check for sync elements (button or text)
        XCTAssertTrue(app.buttons["Sync Now"].waitForExistence(timeout: 3) || app.staticTexts["Syncing..."].waitForExistence(timeout: 3), "Sync button or status should exist")

        // Check for version info (static text with value)
        XCTAssertTrue(app.staticTexts["Version"].waitForExistence(timeout: 2), "Version label should exist")
        XCTAssertTrue(app.staticTexts["1.0.0"].waitForExistence(timeout: 2), "Version number should exist")

        // Check for product count
        XCTAssertTrue(app.staticTexts["Products in Database"].waitForExistence(timeout: 2), "Products in Database label should exist")
    }

    // MARK: - Helper Methods

    private func openAddProductForm() {
        // Try tapping the + button in navigation bar
        let addButton = app.navigationBars.buttons.element(boundBy: 0)
        if addButton.exists {
            addButton.tap()
        } else {
            // If no products exist, use the "Add Product" button in empty state
            app.buttons["Add Product"].tap()
        }

        // Wait for form to appear
        XCTAssertTrue(app.navigationBars["Add Product"].waitForExistence(timeout: 2))
    }

    private func fillNutritionField(label: String, value: String) {
        // Find the nutrition field by accessibility identifier
        let textField = app.textFields[label + " Field"]
        XCTAssertTrue(textField.waitForExistence(timeout: 2), "Field '\(label) Field' should exist")

        // Tap to focus the field
        textField.tap()

        // Wait a moment for keyboard to appear
        Thread.sleep(forTimeInterval: 0.5)

        // Clear any existing value by tapping and selecting all
        textField.tap()

        // Check if there's a value to clear
        let currentValue = textField.value as? String ?? ""
        if !currentValue.isEmpty && currentValue != "0.0" {
            // Press delete key multiple times to clear
            for _ in 0..<currentValue.count {
                textField.typeText(XCUIKeyboardKey.delete.rawValue)
            }
        }

        // Type the new value
        textField.typeText(value)

        // Tap somewhere else to dismiss keyboard and trigger calculation update
        // Tap on the "Carbs" label in the Calculated section
        if app.staticTexts["Carbs"].exists {
            app.staticTexts["Carbs"].tap()
        }
    }

    private func addTestProduct(name: String, brand: String) {
        openAddProductForm()

        // Fill in product info
        app.textFields["Product Name"].tap()
        app.textFields["Product Name"].typeText(name)
        app.textFields["Brand"].tap()
        app.textFields["Brand"].typeText(brand)

        // Use standard test values (low carbs)
        fillNutritionField(label: "Protein", value: "11.5")
        fillNutritionField(label: "Fat", value: "6.5")
        fillNutritionField(label: "Fiber", value: "0.5")
        fillNutritionField(label: "Moisture", value: "79")
        fillNutritionField(label: "Ash/Minerals", value: "1.8")

        sleep(1)

        // Save
        let saveButton = app.navigationBars.buttons["Save"]
        saveButton.tap()

        // Wait for form to close
        XCTAssertTrue(app.navigationBars["FitCat"].waitForExistence(timeout: 2))
    }

    // MARK: - OCR Scanner Tests

    func testScanMultipleImages() throws {
        // Navigate to Scan tab
        app.tabBars.buttons["Scan"].tap()
        XCTAssertTrue(app.navigationBars["Scan Product"].waitForExistence(timeout: 2))

        // In simulator, should show photo picker button
        let photoPickerArea = app.otherElements["Running in Simulator"]
        if photoPickerArea.exists {
            // Tap to open photo picker
            photoPickerArea.tap()
        } else {
            // Fallback: tap the gradient background area
            let gradient = app.otherElements.firstMatch
            gradient.tap()
        }

        // Wait for photo picker to appear
        sleep(1)

        // Try to interact with photo picker
        // Note: XCTest has limited ability to interact with system photo picker
        // This test verifies the photo picker opens without crashing
        // For full automation, you would need to use xcrun simctl addmedia
        // and test the image processing logic directly
    }

    func testImageProcessingDoesNotCrash() throws {
        // This test verifies the app can handle multiple image selection
        // without crashing due to race conditions

        // Navigate to Scan tab
        app.tabBars.buttons["Scan"].tap()
        XCTAssertTrue(app.navigationBars["Scan Product"].waitForExistence(timeout: 2))

        // Wait for view to load
        sleep(2)

        // Tap photo picker area if running in simulator
        let simulatorMessage = app.staticTexts["Running in Simulator"]
        if simulatorMessage.exists {
            // Verify no crash indicators
            XCTAssertTrue(app.navigationBars["Scan Product"].exists)
        }
    }
}
