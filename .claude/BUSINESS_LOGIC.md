# FitCat Business Logic

## Overview

FitCat is a cat food nutrition label scanner that helps users analyze carbohydrate content in cat food products. It combines OCR scanning, API lookups, and manual entry to gather nutrition data.

## Data Sources

The app combines data from three sources, listed in priority order:

1. **OCR Scanning** (highest priority) - Values scanned from nutrition labels
2. **API Data** (medium priority) - Product information from Open Pet Food Facts
3. **Manual Entry** (lowest priority) - User-entered values

### Data Source Priority

When displaying and calculating nutrition values, the app uses this fallback logic:

```swift
let protein = ocrProtein ?? apiProduct?.apiProtein ?? manualValue
```

- OCR values take precedence over API values
- API values take precedence over manual entry
- Missing values are represented as `nil`, not `0`

## Core Business Rules

### 1. Nutrition Value Display

**Nutrition Tiles:**
- Display all 5 nutrition values: Protein, Fat, Fiber, Moisture, Ash
- Only appear once at least one value is available from any source
- Show icon indicating source:
  - Camera icon = OCR scanned value
  - Cloud icon = API value
- Missing values show as `"--"` with red styling (red background, red border, red text)
- Present values show with normal styling

**Code location:** `OCRScannerView.swift:404-450`

### 2. Carbohydrate Calculation

**Formula:**
```
carbs% = 100 × (100 - protein - fat - fiber - moisture - ash) / (100 - moisture)
```

**When Carbs Meter Appears:**
- Only when ALL 5 nutrition values are available (protein, fat, fiber, moisture, ash)
- Values can come from any source (OCR + API combined)
- Example: OCR provides protein + fat, API provides fiber + moisture + ash → carbs meter shows

**Carbs Level Thresholds:**
- Good (green): < 5%
- Moderate (yellow): 5% - 10%
- High (red): > 10%

**Code location:** `OCRScannerView.swift:455-483`

```swift
// Combine values from all sources (OCR takes priority)
let protein = ocrProtein ?? apiProduct?.apiProtein
let fat = ocrFat ?? apiProduct?.apiFat
let fiber = ocrFiber ?? apiProduct?.apiFiber
let moisture = ocrMoisture ?? apiProduct?.apiMoisture
let ash = ocrAsh ?? apiProduct?.apiAsh

// Only show carbs meter when ALL 5 values present
let hasAllValues = protein != nil && fat != nil && fiber != nil &&
                   moisture != nil && ash != nil

if hasAllValues {
    // Calculate and display carbs meter
}
```

### 3. Validation Rules

There are three types of validation in the app:

#### A. OCR Validation (Individual Fields)

**When It Runs:**
- As each value is scanned from the nutrition label
- Before accepting the value into the UI

**What It Checks:**
- Each nutrient is within valid range for the food type
- Rejects invalid values (they won't populate the UI)

**Code location:** `OCRScannerView.swift:808-927, 1020-1053`

```swift
if let protein = nutrition.protein {
    if self.isValidProtein(protein, moisture: nutrition.moisture, logError: true) {
        self.ocrProtein = protein  // Accept valid value
    } else {
        // Reject invalid value, log error
    }
}
```

#### B. Comprehensive Validation (All Fields)

**When It Runs:**
- Only when all 5 OCR values are present (protein, fat, fiber, moisture, ash)
- Displays validation errors below nutrition tiles

**What It Checks:**
1. **Total Percentage** - Sum of all 5 values ≤ 102% (allows 2% margin for rounding)
2. **Food Type Detection** - Based on moisture content:
   - Dry food: 6-12% moisture
   - Semi-moist: 15-30% moisture
   - Wet food: 70-90% moisture
3. **Nutrient Ranges** - Each value within expected range for food type
4. **Carbs Calculation** - Calculated carbs within acceptable range

**Code location:** `OCRScannerView.swift:92-105`

```swift
private var validationErrors: [NutritionValidation.ValidationError] {
    // Only validate when we have all required values
    guard ocrProtein != nil && ocrFat != nil && ocrFiber != nil &&
          ocrMoisture != nil && ocrAsh != nil else {
        return []  // No comprehensive validation on partial data
    }
    return NutritionValidation.validate(...)
}
```

**Why wait for all 5 values?**
- Prevents misleading errors during scanning
- Example: Protein 10% + Fat 5% = 15% total looks wrong, but user hasn't scanned moisture (80%) yet

#### C. API Validation

**When It Runs:**
- During API product conversion (OpenPetFoodFactsService)
- Before creating a Product from API response

**What It Checks:**
- **Product info:** Always accepts product name and brand (even if nutrients missing/invalid)
- **Protein validation:** Must be 5-70%, otherwise rejected (treated as nil)
- **Fat validation:** Must be 1-35%, otherwise rejected (treated as nil)
- **Optional nutrients:** Fiber, moisture, ash accepted as-is (user can override with OCR)

**Behavior:**
- Product is ALWAYS returned with name and brand
- Invalid nutrient values are rejected individually (logged and treated as nil)
- Valid nutrients are preserved in api* fields
- User can scan or manually enter missing/invalid values

**Code location:** `OpenPetFoodFactsService.swift:213-283`

```swift
// Always get product name and brand
let productName = apiProduct.productName ?? "Unknown Product"
let brand = apiProduct.brands?.split(separator: ",").first.map(String.init) ?? "Unknown Brand"

// Validate individual nutrients - reject only invalid values
var validatedProtein: Double?
if let protein = nutriments.proteins100g {
    if protein >= 5.0 && protein <= 70.0 {
        validatedProtein = protein
    } else {
        print("⚠️ API: Rejecting protein \(protein)% - out of range (5-70%)")
    }
}

var validatedFat: Double?
if let fat = nutriments.fat100g {
    if fat >= 1.0 && fat <= 35.0 {
        validatedFat = fat
    } else {
        print("⚠️ API: Rejecting fat \(fat)% - out of range (1-35%)")
    }
}

// Return product with validated nutrients (invalid ones treated as nil)
return Product(..., apiProtein: validatedProtein, apiFat: validatedFat, ...)
```

**Validation Ranges:**
- **Protein:** 5-70% (covers both wet food 7-15% and dry food 30-50% with margin)
- **Fat:** 1-35% (covers both wet food 2-10% and dry food 10-25% with margin)

**Why validate ranges:**
- API database may contain data entry errors
- Example: 0.6% fat is unrealistically low for cat food
- Rejects obviously incorrect values while preserving product identity
- User can scan label or manually enter correct values

**Validation Details:**

**Food Type Detection:**
- Based on moisture percentage: `moisture > 50% → wet food`
- API products may include category tags (e.g., "en:wet-cat-food")

**Nutrient Ranges** (vary by food type):

**Wet Food Limits:**
- Protein: 0-20%
- Fat: 0-15%
- Fiber: 0-3% (pure meat can have 0%)
- Moisture: 70-90%
- Ash: 0-5%

**Dry Food Limits:**
- Protein: 0-60%
- Fat: 0-30%
- Fiber: 0-5%
- Moisture: 6-12%
- Ash: 0-12%

**Code location:** `NutritionCalculator.swift:84-187`

### 4. Food Type Detection

**Purpose:**
- Determines whether to use wet or dry food validation ranges
- Wet food has different nutrient limits than dry food

**Detection Priority (checked in order):**

**Code location:** `OCRScannerView.swift:730-763`

```swift
private var isWetFood: Bool {
    // 1. Check API categories first (most reliable)
    if let tags = apiProduct?.categoriesTags {
        if tags.contains(where: { $0.contains("wet") }) { return true }
        if tags.contains(where: { $0.contains("dry") }) { return false }
    }

    // 2. Check product name/brand for keywords
    let productText = (productName + " " + brand).lowercased()
    let wetKeywords = ["canned", "wet", "pâté", "gravy", "mousse", "pouch"]
    let dryKeywords = ["kibble", "dry", "biscuit", "crunch"]
    if wetKeywords.contains(where: { productText.contains($0) }) { return true }
    if dryKeywords.contains(where: { productText.contains($0) }) { return false }

    // 3. Fallback to API moisture (reliable, doesn't change)
    if let moisture = apiProduct?.moisture {
        return moisture > 50.0
    }

    // 4. Default: assume wet food (broader validation ranges, safer)
    return true
}
```

**Priority Order:**
1. **API category tags** (most reliable) - e.g., "en:wet-cat-food", "en:dry-cat-food"
2. **Product name/brand keywords** - looks for "canned", "wet", "kibble", "dry", etc.
3. **API moisture value** - `moisture > 50%` indicates wet food
4. **Default to wet food** - safer choice with broader validation ranges

**When API is not available:**

```swift
private func determineFoodType(scannedMoisture: Double? = nil) -> Bool {
    if apiProduct != nil {
        return isWetFood  // Use API-based detection above
    }

    // No API - use scanned moisture if available
    if let moisture = scannedMoisture {
        return moisture > 50.0
    }

    return true  // Default to wet food
}
```

**Used For:**
- Selecting validation ranges (wet vs dry food limits)
- Validation error messages

## Data Flow

### Barcode Scan Flow

1. User scans barcode
2. App queries Open Pet Food Facts API
3. If product found:
   - Display product name and brand (with cloud icon)
   - Store in `apiProduct` with optional `api*` fields
   - Show nutrition tiles with available API values
4. If product not found:
   - Show "Not found in database" message
5. User can then:
   - Scan nutrition label with OCR (overrides API values)
   - Manually enter missing values
   - Save product to local database

### OCR Scan Flow

1. User selects photo(s) from camera/library
2. App runs OCR to extract nutrition values
3. Values are validated as they're scanned
4. Valid values populate the nutrition tiles (with camera icon)
5. Invalid values are rejected with validation messages
6. Once all 5 values available (OCR + API combined):
   - Carbs meter appears automatically
7. User can save product with combined data

### Product Storage

**Product Model Fields:**

```swift
struct Product {
    // Main fields (all optional - may be missing)
    var protein: Double?       // % (optional - may be missing)
    var fat: Double?           // % (optional - may be missing)
    var fiber: Double?         // % (optional - may be missing)
    var moisture: Double?      // % (optional - may be missing)
    var ash: Double?           // % (optional - may be missing)

    // API fields (optional, preserve original API values)
    var apiProtein: Double?    // nil if not in API response
    var apiFat: Double?        // nil if not in API response or rejected
    var apiFiber: Double?      // nil if not in API response
    var apiMoisture: Double?   // nil if not in API response
    var apiAsh: Double?        // nil if not in API response

    var source: ProductSource  // .local, .openpetfoodfacts, .github

    // Computed properties (only available when all values present)
    var carbs: Double?         // nil if any nutrient missing
    var carbsLevel: CarbsLevel? // nil if carbs is nil
    var calories: (proteinCal: Double, fatCal: Double, carbsCal: Double)? // nil if incomplete
    var totalCalories: Double? // nil if calories is nil
}
```

**IMPORTANT: Never Use 0 as Default**
- `nil` = data is missing
- `0` = actual 0% value (e.g., 0% fiber in pure meat)
- **NEVER** use `0` as a placeholder for missing data
- All nutrition fields must be optional to preserve this distinction

**Code location:** `Product.swift:16-132`

## API Integration

### Open Pet Food Facts

**Fetch Product:**
```swift
func fetchProduct(barcode: String) async throws -> Product?
```

- Queries `https://world.openpetfoodfacts.org/api/v2/product/{barcode}.json`
- Requires at least protein and fat to create a Product
- Optional fields (fiber, moisture, ash) default to 0 in main fields, nil in api* fields
- Returns `nil` if product not found or insufficient data

**Upload Product:**
```swift
func uploadProduct(_ product: Product) async throws -> Bool
```

- Posts to `https://world.openpetfoodfacts.org/cgi/product_jqm2.pl`
- Requires authentication (credentials in APIConfig)
- Simulator mode: logs request without sending
- Returns `true` if upload successful

**Code location:** `OpenPetFoodFactsService.swift`

## Critical Rules

### NEVER Use 0 as Default for Nutrition Values

**Rule:** All nutrition values (protein, fat, fiber, moisture, ash) MUST be optional (Double?). Never use 0 as a default or placeholder for missing data.

**Why:**
- `nil` = data is missing (not provided, not scanned, not entered)
- `0` = actual 0% value (e.g., 0% fiber in pure meat products)
- Using 0 as a default breaks validation, calculations, and UI logic

**Examples:**

```swift
// ✅ CORRECT
var protein: Double? = nil      // Data not available
var fiber: Double? = 0.0        // Actual 0% fiber

// ❌ WRONG
var protein: Double = 0         // Ambiguous: missing or 0%?
let protein = nutriments.protein ?? 0  // Treats missing as 0%
```

**In Code:**
- Product model: All nutrition fields are optional
- API conversion: Return nil for missing/invalid values, never 0
- UI display: Show "--" for nil, show "0.0%" for actual 0
- Validation: Skip validation for nil values
- Calculations: Only calculate when all values are non-nil

## Key Design Decisions

### 1. nil vs 0 Distinction

**Problem:** A product with 0% fiber (pure meat) is different from missing fiber data.

**Solution:**
- Main Product fields use 0 as default (required for database)
- Optional api* fields preserve nil vs 0 from API
- UI and validation use api* fields to distinguish missing from zero

### 2. Validation Only on Complete OCR Scans

**Problem:** Showing validation errors while user is still scanning is confusing.

**Solution:**
- Validation only runs when all 5 OCR values are present
- Partial scans don't trigger validation
- API products (without OCR) aren't validated

### 3. Carbs Meter Requires All 5 Values

**Problem:** Calculating carbs with missing values gives misleading results.

**Solution:**
- Carbs meter only appears when all 5 values available
- Values can come from any source (OCR + API combined)
- No assumptions or defaults for missing values

### 4. OCR Priority Over API

**Problem:** API data might be outdated or incorrect.

**Solution:**
- OCR values always override API values
- User can verify and correct by scanning label
- Final product saves OCR values if available, falling back to API

## Error Handling

### Validation Errors

**Display:**
- Shown below nutrition tiles
- Orange background for visibility
- Specific messages for each validation type

**Types:**
- Total too high (> 102%)
- Individual nutrients out of range
- Moisture in unusual range
- Carbs too high (> 30%)

**Code location:** `NutritionCalculator.swift:43-79`

### API Errors

**Types:**
- Network errors (no connection)
- Product not found (404)
- Invalid response
- SSL errors (bypassed in DEBUG mode)

**Display:**
- Error alert with descriptive message
- User can retry or continue without API data

**Code location:** `OpenPetFoodFactsService.swift:269-290`

## Testing Considerations

### Total Percentage Tolerance

The 102% threshold (instead of strict 100%) accounts for:
- Rounding differences in source data
- Testing variability
- Real-world product label variations

### Simulator vs Device

**Simulator Mode:**
- API upload is simulated (logs only, no actual POST)
- SSL validation bypassed in DEBUG builds
- Useful for testing without network dependency

**Device Mode:**
- Full API integration
- SSL validation enforced
- Real uploads to Open Pet Food Facts
