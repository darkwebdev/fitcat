# FitCat - Cat Food Nutrition Calculator

FitCat is an iOS app that helps cat owners calculate carbohydrate percentages in cat food by scanning product barcodes and nutrition labels.

## Features

- **Barcode Scanning**: Quickly scan cat food cans to look up products in the database
- **OCR Nutrition Label Scanning**: Extract nutrition values directly from product labels using your camera
- **Carbs Calculation**: Automatically calculates carbohydrate percentage using the formula:
  ```
  carbs% = 100 × (100 - protein - fat - fiber - moisture - ash) / (100 - moisture)
  ```
- **Color-Coded Meter**: Visual feedback on carb levels:
  - 🟢 Green (≤5%): Excellent - ideal for cats
  - 🟡 Yellow (5-10%): Acceptable
  - 🔴 Red (>10%): Too high - not recommended
- **Local Database**: All products stored locally with SQLite for offline access
- **GitHub Sync**: Periodically downloads a community database of cat food products from GitHub
- **Manual Entry**: Add products manually if scanning doesn't work

## Requirements

- iOS 16.0 or later
- Xcode 15.0 or later
- Swift 5.9 or later
- Camera access for barcode/OCR scanning

## Installation

### 1. Clone the repository
```bash
cd fitcat
```

### 2. Open in Xcode
```bash
open FitCat.xcodeproj
```

### 3. Install dependencies
The project uses Swift Package Manager. Dependencies will be automatically resolved:
- SQLite.swift (v0.15.0+)

### 4. Configure Info.plist
Update `FitCat/Info.plist` with your bundle identifier:
```xml
<key>CFBundleIdentifier</key>
<string>com.yourname.fitcat</string>
```

### 5. Build and Run
Select a target device/simulator and press Cmd+R to build and run.

## GitHub Database Setup

FitCat can sync with a GitHub-hosted database of cat food products.

### 1. Create a GitHub repository
```bash
mkdir fitcat-database
cd fitcat-database
git init
```

### 2. Create products.json
```json
{
  "version": "1.0",
  "updated_at": "2026-01-15T00:00:00Z",
  "products": [
    {
      "id": "550e8400-e29b-41d4-a716-446655440000",
      "barcode": "012345678901",
      "product_name": "Premium Wet Cat Food",
      "brand": "Fancy Feast",
      "protein": 11.5,
      "fat": 6.5,
      "fiber": 0.5,
      "moisture": 79.0,
      "ash": 1.8,
      "serving_size": "1 can (85g)",
      "created_at": "2026-01-01T00:00:00Z",
      "updated_at": "2026-01-15T00:00:00Z"
    }
  ]
}
```

### 3. Push to GitHub
```bash
git add products.json
git commit -m "Initial database"
git push origin main
```

### 4. Configure in app
Open Settings in the app and set the GitHub URL:
```
https://raw.githubusercontent.com/YOUR_USERNAME/fitcat-database/main/products.json
```

## Usage

### Scanning a Product

1. **Tap "Scan" tab**
2. **Choose scan mode**:
   - Barcode: For quick lookup of known products
   - Nutrition Label: To extract values via OCR
3. **Scan the product**:
   - If barcode is found: View product details immediately
   - If not found: Switch to OCR or manual entry
4. **Review and save**

### Adding Manually

1. **Tap "+" button** on home screen
2. **Fill in product information**:
   - Product name and brand
   - Nutrition values (protein, fat, fiber, moisture, ash)
3. **Watch carbs calculate in real-time**
4. **Tap "Save"**

### Understanding the Results

The app displays:
- **Carbs Meter**: Visual indicator showing carb percentage
- **Nutrition Grid**: All guaranteed analysis values
- **Calorie Breakdown**: kcal per 100g from protein, fat, and carbs
- **Color-coded status**: Green (good), Yellow (acceptable), Red (too high)

## Testing

### Unit Tests
Run unit tests in Xcode:
```bash
cmd+U
```

Key test files:
- `NutritionCalculatorTests.swift`: Tests carbs formula accuracy

### UI Automation Tests
Run UI tests to verify the full user experience:

```bash
# Using the test runner script
./run-ui-tests.sh

# Or directly with xcodebuild
xcodebuild test \
    -scheme FitCat \
    -sdk iphonesimulator \
    -destination 'platform=iOS Simulator,name=iPhone 15 Pro' \
    -only-testing:FitCatUITests
```

**UI Test Coverage**:
- ✅ Product form input and validation
- ✅ Real-time carbs calculation
- ✅ Color-coded status (Green/Yellow/Red)
- ✅ Product list display
- ✅ Search functionality
- ✅ Tab navigation
- ✅ Product detail view
- ✅ Settings screen

See `FitCatUITests/README.md` for detailed test documentation.

## Architecture

- **MVVM Pattern**: Clear separation between Views, ViewModels, and Models
- **SwiftUI**: Modern declarative UI framework
- **SQLite**: Local database for offline-first experience
- **Vision Framework**: Apple's native OCR and barcode detection
- **Offline-First**: App works fully without internet after initial setup

## File Structure

```
FitCat/
├── App/
│   └── FitCatApp.swift                 # App entry point
├── Models/
│   └── Product.swift                   # Core data model
├── Views/
│   ├── Main/
│   │   ├── MainView.swift             # Root tab view
│   │   ├── HomeView.swift             # Product list
│   │   └── SettingsView.swift         # App settings
│   ├── Product/
│   │   ├── ProductDetailView.swift    # Product details
│   │   ├── ProductFormView.swift      # Add/edit form
│   │   └── CarbsMeterView.swift       # Visual carbs meter
│   └── Scan/
│       ├── ScannerView.swift          # Scanner coordinator
│       ├── BarcodeScannerView.swift   # Barcode scanner
│       └── OCRScannerView.swift       # OCR scanner
├── Services/
│   ├── Calculations/
│   │   └── NutritionCalculator.swift  # Carbs formula
│   ├── Database/
│   │   └── DatabaseManager.swift      # SQLite wrapper
│   ├── Scanning/
│   │   ├── BarcodeScanner.swift       # Vision barcode
│   │   ├── OCRService.swift           # Vision text recognition
│   │   └── NutritionParser.swift      # Parse OCR text
│   └── Sync/
│       ├── GitHubSyncService.swift    # Download from GitHub
│       └── DataMergeService.swift     # Merge strategy
└── Resources/
    └── Info.plist                      # App configuration
```

## Why Low Carbs Matter

Cats are obligate carnivores and have limited ability to digest carbohydrates. High-carb diets can lead to:
- Obesity
- Diabetes
- Digestive issues
- Poor nutrition

**Recommendations:**
- ✅ Ideal: ≤5% carbs (Green)
- ⚠️ Acceptable: 5-10% carbs (Yellow)
- ❌ Avoid: >10% carbs (Red)

## Contributing

Contributions to the GitHub database are welcome! Add more cat food products to help the community:

1. Fork the database repository
2. Add products to `products.json`
3. Submit a pull request

## License

MIT License - See LICENSE file for details

## Support

For issues or questions:
- Open an issue on GitHub
- Check existing issues for solutions

## Roadmap

- [ ] Support for multiple languages
- [ ] Ingredient analysis
- [ ] Recommendation engine based on cat health
- [ ] Export nutrition history
- [ ] Widget for quick access
- [ ] Share products with friends

---

Made with ❤️ for cat health
