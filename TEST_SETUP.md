# FitCat Test Setup Instructions

## Current Status

✅ **Test Code Written**:
- `FitCatTests/NutritionCalculatorTests.swift` - Unit tests
- `FitCatUITests/FitCatUITests.swift` - UI automation tests (18 tests)

❌ **Test Targets Not Configured**:
The Xcode project needs test targets added before tests can run.

## Setup Required (Do This in Xcode)

### Option 1: Use Xcode GUI (Recommended)

1. **Open project in Xcode**:
   ```bash
   open FitCat.xcodeproj
   ```

2. **Add Unit Test Target**:
   - File → New → Target...
   - Select "Unit Testing Bundle"
   - Name: `FitCatTests`
   - Target to be Tested: `FitCat`
   - Click "Finish"

3. **Add UI Test Target**:
   - File → New → Target...
   - Select "UI Testing Bundle"
   - Name: `FitCatUITests`
   - Target to be Tested: `FitCat`
   - Click "Finish"

4. **Add Test Files to Targets**:
   - Select `FitCatTests/NutritionCalculatorTests.swift` in Project Navigator
   - In File Inspector (right panel), check "FitCatTests" target membership
   - Select `FitCatUITests/FitCatUITests.swift`
   - In File Inspector, check "FitCatUITests" target membership

5. **Run Tests**:
   - Press `Cmd+U` to run all tests
   - Or use Test Navigator (`Cmd+6`) to run individual tests

### Option 2: Manual Configuration

If you prefer command line, you'll need to:

1. Manually edit `FitCat.xcodeproj/project.pbxproj` to add test targets
2. This is complex and error-prone - Xcode GUI is recommended

## After Setup

### Run Unit Tests
```bash
# In Xcode
Cmd+U

# Or command line
xcodebuild test \
    -scheme FitCat \
    -sdk iphonesimulator \
    -destination 'platform=iOS Simulator,name=iPhone 15 Pro' \
    -only-testing:FitCatTests
```

### Run UI Tests
```bash
# In Xcode
Cmd+U

# Or command line
./run-ui-tests.sh
```

## Test Files Already Created

### Unit Tests (`FitCatTests/NutritionCalculatorTests.swift`)
- ✅ Test carbs formula with Google Sheet example (11.5/6.5/0.5/79/1.8 → 3.33%)
- ✅ Test high carbs (40/18/3/10/8 → 23.33%)
- ✅ Test edge cases (zero moisture, 100% moisture)
- ✅ Test color level determination (Green/Yellow/Red)
- ✅ Test calorie calculations

### UI Tests (`FitCatUITests/FitCatUITests.swift`)
18 comprehensive tests covering:
- ✅ Empty state display
- ✅ Product form (all fields, validation, real-time calculation)
- ✅ Product list (display, carbs indicators, navigation)
- ✅ Search functionality
- ✅ Tab navigation
- ✅ Product detail view
- ✅ Settings screen
- ✅ Color-coded status (Green/Yellow/Red)

## Why Tests Aren't Running Yet

The manually created `FitCat.xcodeproj/project.pbxproj` file doesn't include test target definitions. Xcode project files are complex XML/plist structures with many interconnected IDs and references.

**Solution**: Use Xcode's GUI to add test targets (Option 1 above) - it will automatically configure everything correctly.

## Verification

Once test targets are added, verify with:

```bash
xcodebuild -list
```

Should show:
```
Targets:
    FitCat
    FitCatTests
    FitCatUITests
```

Then tests will run successfully with `Cmd+U` or the command-line options above.
