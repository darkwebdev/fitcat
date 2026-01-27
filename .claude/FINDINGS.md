# FitCat - Important Findings & Design Decisions

## OCR & Nutrition Detection

### 1. OCR Errors Are Discrete, Not Continuous

**Finding:** OCR doesn't make small measurement errors - it makes discrete reading errors:
- Missing decimal point: `2.1` → `21`
- Extra decimal point: `21` → `2.1`
- Digit confusion: `1` → `7`, `0` → `8`
- Decimal separator: `.` → `,` (regional variants)

**Wrong Approach:**
```swift
// ❌ Averaging combines correct and wrong values
let avg = values.reduce(0, +) / values.count
// [2.1, 21, 2.1] → 8.4% (WRONG!)
```

**Correct Approach:**
```swift
// ✅ Use MODE (most frequent value)
let mode = mostFrequentValue(values)
// [2.1, 21, 2.1] → 2.1% (CORRECT!)
```

**Implementation:** `getConsensusValue` uses frequency map to find MODE

---

### 2. Regex Patterns Must Handle (min)/(max) Qualifiers

**Finding:** Real nutrition labels have qualifiers between nutrient name and value:
- `Moisture (max) 79.0%`
- `Ash (max) 2.1%`
- `Protein (min) 11.5%`

**Wrong Pattern:**
```swift
#"moisture\s*(\d+[,\.]?\d*)\s*%"#  // ❌ Fails on "Moisture (max) 79%"
```

**Correct Pattern:**
```swift
#"moisture(?:\s*\((?:min|max)\))?\s*(\d+[,\.]?\d*)\s*%"#  // ✅ Works
```

**Files Updated:**
- `NutritionParser.swift` - Added `(?:\s*\((?:min|max)\))?` to all patterns

---

### 3. API Data Has Different Reliability by Field Type

**Finding:** API data reliability varies:

| Field | Reliability | Changes Over Time |
|-------|-------------|-------------------|
| Product Name | ✅ High | Never |
| Brand | ✅ High | Never |
| Wet/Dry Type | ✅ High | Never |
| Nutrition Values | ❌ Low | Yes (reformulations) |

**Reason:**
- Products get reformulated (nutrition changes)
- API is crowd-sourced (may be missing/outdated)
- OCR reads current label (source of truth)

**Strategy:**
1. Use API for product metadata (name, brand, type)
2. Use OCR for nutrition values
3. Detect when OCR differs from API (outdated indicator)
4. Upload OCR consensus to improve API database

**Implementation:**
```swift
private var isWetFood: Bool {
    // 1. Keywords (product type doesn't change)
    if wetKeywords.contains(where: { productText.contains($0) }) { return true }

    // 2. API moisture only (reliable for classification)
    if let moisture = apiProduct?.moisture { return moisture > 50.0 }

    // 3. OCR consensus (multiple detections)
    if ocrMoistureValues.count >= 2 {
        let avg = ocrMoistureValues.reduce(0, +) / Double(ocrMoistureValues.count)
        return avg > 50.0
    }

    // 4. Default: wet food (safer, broader ranges)
    return true
}
```

---

### 4. Validation Timing & Circular Dependencies

**Bug Found:** Ash validation failed because of circular dependency:

**Problem Flow:**
1. OCR detects: `moisture=79.0%, ash=2.1%`
2. Validate ash → checks `isWetFood`
3. `isWetFood` checks `ocrMoisture` (from `ocrMoistureValues` array)
4. But `ocrMoistureValues` is empty (moisture not added yet!)
5. `isWetFood` defaults to `false` (dry food)
6. Ash 2.1% fails dry food validation (needs 3.5-12%)
7. Should pass wet food validation (1.5-4%)

**Solution:** Pass current scan's moisture to validation:
```swift
// ✅ Use moisture from THIS scan, not historical array
if let ash = nutrition.ash {
    if isValidAsh(ash, moisture: nutrition.moisture) {
        validAsh = ash
    }
}

private func isValidAsh(_ ash: Double, moisture: Double? = nil) -> Bool {
    let wetFood = moisture.map { $0 > 50.0 } ?? isWetFood
    // ... validation based on wetFood
}
```

**Files Updated:**
- `OCRScannerView.swift:1572` - Pass `nutrition.moisture` to validator
- `OCRScannerView.swift:1064` - Accept optional `moisture` parameter

---

### 5. Progressive Value Display Strategy

**Finding:** Users want to see values immediately, updated as confidence improves

**Strategy:**
1. **First detection** → Show immediately (single value)
2. **Multiple detections** → Update to MODE automatically
3. **API available** → Show as temporary placeholder
4. **OCR arrives** → Replace API with fresh OCR

**Example Timeline:**
```
[19:15:10] Scan 1: Ash 2.1% → Show "2.1%" immediately
[19:15:12] Scan 2: Ash 21%  → Still show "2.1%" (MODE, 50% confidence)
[19:15:14] Scan 3: Ash 2.1% → Show "2.1%" (MODE, 67% confidence)
```

**Logs:**
```
📊 Single detection: 2.1% (will update with better consensus)
📊 Consensus from 2.1, 21: 2.1% (appears 1/2 times, 50% confidence)
📊 Consensus from 2.1, 21, 2.1: 2.1% (appears 2/3 times, 67% confidence)
```

---

## iOS Debugging Best Practices

### TDD Workflow for Bug Fixes

**Process:**
1. **Reproduce bug in test first** (proves bug exists)
2. **Run test** (should fail initially)
3. **Identify layer** (parser ✅ vs UI/validation ❌)
4. **Add logging** (trace where value is lost)
5. **Fix** (based on log evidence)
6. **Verify** (test passes, app works)

**Example Test:**
```swift
func testAshDetectionForWetFood() {
    // BUG: Ash 2.1% detected but not displayed
    let text = """
    Moisture (max) 79.0%
    Ash (max) 2.1%
    """

    let nutrition = parser.parseNutrition(from: [text])

    XCTAssertEqual(nutrition.ash, 2.1, "Should parse ash 2.1%")
    XCTAssertNotNil(nutrition.ash, "Ash should be detected")
}
```

### Live Log Viewing in tmux

**Setup:**
```bash
# 1. Start background log streaming with clean format
xcrun simctl spawn booted log stream --predicate 'process == "FitCat"' --level debug 2>&1 | \
  grep --line-buffered "🔴 FITCAT" | \
  while IFS= read -r line; do
    echo "$line" | sed -E 's/^.* ([0-9]{2}:[0-9]{2}:[0-9]{2})\.[0-9]+.* 🔴 FITCAT/[\1]/'
  done > /tmp/fitcat-live.log &

# 2. Create tmux split pane (30% width, right side)
tmux split-window -h -p 30 "tail -f /tmp/fitcat-live.log"
tmux select-pane -t 1  # Focus back to main pane
```

**Log Format:**
```
[18:45:10] OCR: Detected text
[18:45:10] OCR: Parsed - Protein: 11.5, Fat: 6.5, Fiber: 0.5, Moisture: 79.0, Ash: 2.1
[18:45:10] OCR: Ash value detected: 2.1%, moisture=79.0, isWetFood=true
[18:45:10] OCR: Ash 2.1% passed validation (wet food range: 1.5-4%, dry: 3.5-12%)
[18:45:10] OCR: ✅ Added ash value: 2.1% (total detections: 1)
```

**Benefits:**
- Clean, readable format (no metadata clutter)
- Real-time updates during app use
- Read-only display (won't accidentally interrupt)
- Only shows relevant messages (filtered by prefix)

---

## Validation Ranges

### Wet Food (Moisture > 50%)
- **Protein**: 8-15%
- **Fat**: 2-10%
- **Fiber**: 0.1-3%
- **Moisture**: 60-85%
- **Ash**: 1.5-4%

### Dry Food (Moisture ≤ 50%)
- **Protein**: 20-45%
- **Fat**: 8-22%
- **Fiber**: 1-8%
- **Moisture**: 5-12%
- **Ash**: 3.5-12%

**Classification Priority:**
1. Product name keywords (wet: "canned", "wet", "pâté"; dry: "kibble", "dry")
2. API moisture value (reliable, doesn't change)
3. OCR moisture consensus (≥2 detections)
4. Default: wet food (broader ranges, safer)

---

## Future Improvements

### 1. Upload OCR Consensus to API
When OCR has high confidence (>75%), upload to API to improve database:
```swift
if confidence > 75 && abs(ocrValue - apiValue) > 1.0 {
    // Upload improved value to API
    uploadNutritionUpdate(barcode: barcode, nutrient: "ash", value: ocrValue)
}
```

### 2. Confidence Indicator in UI
Show visual confidence level to user:
- 🟢 High (>75%): 3+ same detections
- 🟡 Medium (50-75%): 2 detections
- 🔴 Low (<50%): Single detection or conflicting

### 3. OCR Language Support
Multilingual labels have same nutrition in multiple languages:
- Parse all languages simultaneously
- Use consensus across languages
- Higher confidence with more language agreement

---

---

## API Data Structure & Limitations

### Current API Implementation (Open Pet Food Facts)

**Fields Retrieved:**
```swift
struct OpenPetFoodFactsProduct {
    let productName: String?      // Product name
    let brands: String?            // Brand(s), comma-separated
    let nutriments: Nutriments?   // Nutrition values only
}

struct Nutriments {
    let proteins100g: Double?
    let fat100g: Double?
    let fiber100g: Double?
    let moisture100g: Double?
    let ash100g: Double?
}
```

**Missing Fields (Not Currently Used):**
- `categories` - Could contain "wet food", "dry food", "cat food", "dog food"
- `categories_tags` - Normalized category tags
- `labels` - Organic, grain-free, etc.
- `species` or `species_tags` - Explicit dog/cat classification
- `ingredients` - Ingredient list
- `allergens` - Allergen information

**Recommendation:** Expand API response parsing to include:
1. **Categories/Tags** - Better wet/dry classification
2. **Species** - Explicit cat/dog differentiation
3. **Labels** - Quality indicators (organic, grain-free, etc.)

**API Documentation:**
- [Open Pet Food Facts Data](https://world.openpetfoodfacts.org/data)
- [Open Food Facts API Reference](https://openfoodfacts.github.io/openfoodfacts-server/api/)

---

## Local Database (SQLite)

### Purpose
**File:** `DatabaseManager.swift`

SQLite is used for:
1. **User-entered products** - Store manually created products (via ProductFormView) ✅
2. **GitHub sync** - Cache products from GitHub database ✅
3. **Sync metadata** - Track last GitHub sync timestamp ✅
4. **OCR scanned products** - ❌ **NOT IMPLEMENTED** (should be added!)

### Missing Feature: Offline-First Caching Strategy

**Current Behavior:**
- Scan barcode → fetch from API → display
- No local cache
- Offline = can't scan anything
- Same barcode scanned twice = 2 API calls

**Should Implement (Offline-First):**

```swift
// 1. Check local cache first (instant, works offline)
if let cached = try? databaseManager.findByBarcode(barcode) {
    // Use cached product immediately
    self.apiProduct = cached
}

// 2. Fetch from API in background (update cache)
Task {
    if let apiProduct = try? await apiService.fetchProduct(barcode: barcode) {
        try? databaseManager.insert(apiProduct)  // Update cache
        self.apiProduct = apiProduct  // Update UI
    }
}

// 3. Save OCR results locally (for offline upload later)
if let ocrProduct = createProductFromOCR() {
    ocrProduct.source = .local  // Mark as pending upload
    try? databaseManager.insert(ocrProduct)
}

// 4. When online, upload local products to API
if isOnline {
    let localProducts = products.filter { $0.source == .local }
    for product in localProducts {
        if try await apiService.uploadProduct(product) {
            product.source = .openpetfoodfacts  // Mark as synced
            try? databaseManager.update(product)
        }
    }
}
```

**Benefits:**
1. ✅ **Works offline** - Uses cached products
2. ✅ **Faster** - Instant from cache, API updates in background
3. ✅ **Reduces API load** - Cache hits don't call API
4. ✅ **Contributes to database** - OCR improvements uploaded when online
5. ✅ **No data loss** - Offline scans saved and uploaded later

**Priority:** High - Currently app is useless without internet connection

### Schema

**Products Table:**
```sql
CREATE TABLE products (
    id TEXT PRIMARY KEY,
    barcode TEXT,
    product_name TEXT,
    brand TEXT,
    protein REAL,
    fat REAL,
    fiber REAL,
    moisture REAL,
    ash REAL,
    serving_size TEXT,
    created_at INTEGER,
    updated_at INTEGER,
    source TEXT  -- 'local', 'github', 'openpetfoodfacts'
)
```

**Sync Metadata Table:**
```sql
CREATE TABLE sync_metadata (
    key TEXT PRIMARY KEY,
    value TEXT,
    updated_at INTEGER
)
```

### Product Sources
1. **`local`** - User manually entered
2. **`github`** - Downloaded from GitHub database
3. **`openpetfoodfacts`** - Fetched from API

**Strategy:**
- API data is cached locally
- OCR updates can modify local cache
- Local changes can be pushed back to API

---

## Key Files

- `NutritionParser.swift` - OCR text parsing with regex patterns
- `OCRScannerView.swift` - UI, validation, consensus logic
- `OCRIntegrationTests.swift` - TDD tests for bug reproduction
- `OpenPetFoodFactsService.swift` - API integration
- `DatabaseManager.swift` - SQLite local storage
- `ios-debugging.md` - Debugging workflow documentation
- `FINDINGS.md` - This file
