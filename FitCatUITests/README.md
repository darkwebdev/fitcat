# FitCat UI Automation Tests

## Overview

This directory contains XCUITest automation tests for the FitCat iOS app. These tests verify the user interface and user interactions work correctly.

## Test Coverage

### ✅ Home Screen Tests
- Empty state display
- Navigation to add product form
- Search bar presence

### ✅ Product Form Tests
- All form fields exist (product info + nutrition values)
- Cancel button functionality
- Save button disabled when empty
- Adding product with valid data
- Real-time carbs calculation
- Color-coded status (Green/Yellow/Red)
- Form validation (rejects invalid totals >100%)

### ✅ Product List Tests
- Products display in list
- Carbs indicator shows correct percentage
- Nutrition badges (P, F, M) display
- Navigation to product detail

### ✅ Search Tests
- Search filters products correctly
- Clear search restores all products

### ✅ Tab Navigation Tests
- Switch between Products/Scan/Settings tabs

### ✅ Product Detail Tests
- All product information displays
- Carbs meter visible
- Menu button accessible

### ✅ Settings Tests
- Settings screen loads
- Sync section visible
- App info displayed

## Running the Tests

### Option 1: Using Xcode
1. Open `FitCat.xcodeproj` in Xcode
2. Select the `FitCat` scheme
3. Press `Cmd+U` to run all tests
4. Or press `Cmd+6` to open Test Navigator and run individual tests

### Option 2: Using Command Line
```bash
cd /Users/tmanyanov/build/fitcat

# Run all UI tests
./run-ui-tests.sh

# Or run specific test
xcodebuild test \
    -scheme FitCat \
    -sdk iphonesimulator \
    -destination 'platform=iOS Simulator,name=iPhone 15 Pro' \
    -only-testing:FitCatUITests/FitCatUITests/testAddProductWithValidData
```

### Option 3: Using xcodebuild directly
```bash
xcodebuild test \
    -scheme FitCat \
    -sdk iphonesimulator \
    -destination 'platform=iOS Simulator,name=iPhone 15 Pro' \
    -only-testing:FitCatUITests
```

## Test Data

The tests use predefined nutrition values:

**Low Carbs (Green - 3.33%)**:
- Protein: 11.5%
- Fat: 6.5%
- Fiber: 0.5%
- Moisture: 79%
- Ash: 1.8%

**Medium Carbs (Yellow - ~7%)**:
- Protein: 30%
- Fat: 10%
- Fiber: 2%
- Moisture: 50%
- Ash: 4.5%

**High Carbs (Red - 23.33%)**:
- Protein: 40%
- Fat: 18%
- Fiber: 3%
- Moisture: 10%
- Ash: 8%

## Test Structure

### Helper Methods

**`openAddProductForm()`**
- Navigates to the product form (handles both empty state and existing products)

**`fillNutritionField(label: String, value: String)`**
- Fills a nutrition input field with the specified value
- Handles keyboard interaction and dismissal

**`addTestProduct(name: String, brand: String)`**
- Complete flow to add a product with standard test values
- Uses low-carb values by default

## Debugging Tests

### View Test Results
1. Open Xcode
2. Press `Cmd+9` to open Reports Navigator
3. Click on latest test run
4. View passed/failed tests and screenshots

### Enable UI Testing Debug
Add breakpoints in test methods and use:
```swift
print(app.debugDescription)  // Print UI hierarchy
sleep(5)  // Pause to inspect UI
```

### Take Screenshots During Tests
```swift
let screenshot = app.screenshot()
let attachment = XCTAttachment(screenshot: screenshot)
attachment.lifetime = .keepAlways
add(attachment)
```

## CI/CD Integration

### GitHub Actions Example
```yaml
name: UI Tests

on: [push, pull_request]

jobs:
  test:
    runs-on: macos-latest
    steps:
      - uses: actions/checkout@v3
      - name: Select Xcode
        run: sudo xcode-select -s /Applications/Xcode.app
      - name: Run UI Tests
        run: |
          cd /path/to/fitcat
          ./run-ui-tests.sh
```

## Known Limitations

### Camera Features
UI tests **cannot** test camera-related features in the simulator:
- Barcode scanning
- OCR nutrition label scanning

These require physical device testing.

### Async Operations
Some tests use `sleep()` to wait for calculations/animations. In production, prefer:
```swift
XCTAssertTrue(element.waitForExistence(timeout: 2))
```

## Writing New Tests

### Test Naming Convention
```swift
func test<Feature><Action><ExpectedResult>() {
    // Example: testProductFormSaveButtonDisabledWhenEmpty()
}
```

### Best Practices
1. **Arrange**: Set up test data
2. **Act**: Perform user action
3. **Assert**: Verify expected outcome

Example:
```swift
func testNewFeature() throws {
    // Arrange
    addTestProduct(name: "Test", brand: "Brand")

    // Act
    app.buttons["SomeButton"].tap()

    // Assert
    XCTAssertTrue(app.staticTexts["Expected Result"].exists)
}
```

## Troubleshooting

### Test Fails: "Element not found"
- Add `waitForExistence(timeout:)` before accessing element
- Check element accessibility identifiers
- Use `app.debugDescription` to inspect UI hierarchy

### Test Fails: "Keyboard not dismissed"
- Ensure `app.toolbars.buttons["Done"].tap()` is called
- Or use `app.swipeDown()` to dismiss keyboard

### Test Runs Slowly
- Reduce use of `sleep()`
- Use `waitForExistence()` instead
- Run tests on faster simulators (newer iPhone models)

## Test Results

All tests should pass on:
- ✅ iPhone 15 Pro (iOS 17.2+)
- ✅ iPhone SE (3rd gen) (iOS 16.0+)
- ✅ iPad Pro 11-inch (iOS 16.0+)

## Maintenance

### When Adding New Features
1. Write UI test first (TDD approach)
2. Implement feature
3. Verify test passes
4. Add to this README

### When Modifying UI
1. Run affected tests
2. Update tests if UI structure changed
3. Keep tests in sync with UI changes
