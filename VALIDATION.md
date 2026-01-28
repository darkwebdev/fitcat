# FitCat Nutrition Validation System

## Overview

The FitCat app includes a comprehensive validation system to catch OCR errors and ensure nutrition data accuracy. Validation occurs in real-time during scanning and when manually entering product data.

## Validation Rules

### Total Percentage

**Rule**: Sum of all nutrients must not exceed 102%

```
Total = Protein + Fat + Fiber + Moisture + Ash
Valid: Total ≤ 102%
```

**Reasoning**:
- Guaranteed analysis values should sum to approximately 100%
- Allow 2% margin for:
  - Rounding (e.g., 10.5% rounded to 11%)
  - Testing variability
  - Normal measurement error
- Values >102% indicate OCR errors or data entry mistakes

**Example**:
```
✓ Valid:   Protein 10.5% + Fat 6.5% + Fiber 0.5% + Moisture 79% + Ash 2.1% = 98.6%
✗ Invalid: Protein 10.5% + Fat 65% + Fiber 0.5% + Moisture 79% + Ash 2.1% = 157.1%
           (OCR misread "6.5%" as "65%")
```

---

### Moisture

**Rule**: Different ranges for dry, semi-moist, and wet food

| Food Type   | Valid Range | Notes |
|-------------|-------------|-------|
| Dry food    | 6-12%       | Standard kibble |
| Semi-moist  | 15-30%      | Uncommon category |
| Wet food    | 70-90%      | Includes high-moisture products, broths |
| Unusual     | 12-15%, 30-70%, 90-100% | Triggers warning |
| Invalid     | <6% or ≥100% | Error |

**Error Messages**:
- `< 6%`: "Moisture X% is too low. Dry food: 6-12%, wet food: 70-90%."
- `12-15%, 30-70%, 90-100%`: "Moisture X% is unusual. Dry food: 6-12%, semi-moist: 15-30%, wet food: 70-90%."
- `≥ 100%`: "Moisture X% is invalid. Must be less than 100%."

**Examples**:
```
✓ Valid dry:        10.0%  (kibble)
✓ Valid semi-moist: 25.0%  (soft treats)
✓ Valid wet:        79.0%  (pate)
✓ Valid wet:        88.5%  (high-moisture food)
⚠ Unusual:          45.0%  (between categories)
✗ Invalid:          2.0%   (too low)
✗ Invalid:          105.0% (impossible)
```

---

### Protein

**Rule**: Different limits for wet vs dry food (based on moisture > 50%)

| Food Type | Maximum | Typical Range |
|-----------|---------|---------------|
| Wet food  | 20%     | 7-15% |
| Dry food  | 60%     | 30-50% |

**Error Message**:
- "Protein X% is unusually high. Typical range: 7-15% (wet) or 30-50% (dry)."

**Examples**:
```
✓ Valid wet:  11.5%  (moisture 79%)
✓ Valid dry:  35.0%  (moisture 10%)
✗ Invalid:    25.0%  (moisture 79% - too high for wet food)
✗ Invalid:    65.0%  (moisture 10% - too high even for dry food)
```

---

### Fat

**Rule**: Different limits for wet vs dry food (based on moisture > 50%)

| Food Type | Maximum | Typical Range |
|-----------|---------|---------------|
| Wet food  | 15%     | 2-10% |
| Dry food  | 30%     | 10-25% |

**Error Message**:
- "Fat X% is unusually high. Typical range: 2-10% (wet) or 10-25% (dry)."

**Examples**:
```
✓ Valid wet:  6.5%   (moisture 79%)
✓ Valid dry:  18.0%  (moisture 10%)
✗ Invalid:    16.0%  (moisture 79% - too high for wet food)
✗ Invalid:    35.0%  (moisture 10% - too high even for dry food)
```

---

### Fiber

**Rule**: Upper limit only, no lower limit

| Limit | Value | Notes |
|-------|-------|-------|
| Maximum | 5% | Typical range: 0.5-3% |
| Minimum | None | 0% is acceptable (pure meat products) |

**Error Message**:
- "Fiber X% is unusually high. Typical range: 0.5-3%."

**Examples**:
```
✓ Valid:   0.0%  (pure meat wet food)
✓ Valid:   0.2%  (low-fiber pate)
✓ Valid:   2.5%  (standard dry food)
✗ Invalid: 6.0%  (unusually high)
```

---

### Ash

**Rule**: Different limits for wet vs dry food (based on moisture > 50%)

| Food Type | Maximum | Typical Range |
|-----------|---------|---------------|
| Wet food  | 5%      | 1-3% |
| Dry food  | 12%     | 5-10% |

**Error Message**:
- "Ash X% is unusually high. Typical range: 1-3% (wet) or 5-10% (dry)."

**Examples**:
```
✓ Valid wet:  2.1%  (moisture 79%)
✓ Valid dry:  7.0%  (moisture 10%)
✗ Invalid:    6.0%  (moisture 79% - too high for wet food)
✗ Invalid:    13.0% (moisture 10% - too high even for dry food)
```

---

### Carbohydrates (Calculated)

**Rule**: Two warning levels - informational and error

**Formula**:
```
carbs% = 100 × (100 - protein - fat - fiber - moisture - ash) / (100 - moisture)
```

**Thresholds**:

| Level | Range | Message | Severity |
|-------|-------|---------|----------|
| Ideal | < 10% | None | ✓ |
| High  | 10-30% | "Carbs X% is high. Ideally under 10%, but up to 30% is common in dry food." | ⚠ Info |
| Too High | > 30% | "Carbs X% is extremely high. Should be under 30% for cat food." | ✗ Error |

**Reasoning**:
- Cats are obligate carnivores; low carbs (<10%) is ideal
- Many commercial dry foods have 15-30% carbs (common but not ideal)
- Values >30% indicate poor formulation or OCR error

**Examples**:
```
✓ Ideal:          6.7%   (premium wet food)
⚠ High:           18.5%  (commercial dry food)
⚠ High:           28.0%  (high-carb dry food)
✗ Extremely high: 45.0%  (likely OCR error or poor formulation)
```

---

## Validation in Practice

### Real-World Examples

#### Example 1: Valid Premium Wet Food
```
Protein:  11.5%
Fat:      6.5%
Fiber:    0.5%
Moisture: 79.0%
Ash:      2.1%
Total:    99.6%
Carbs:    6.7%

Result: ✓ All values valid, no warnings
```

#### Example 2: Valid Commercial Dry Food
```
Protein:  35.0%
Fat:      18.0%
Fiber:    2.5%
Moisture: 10.0%
Ash:      7.0%
Total:    72.5%
Carbs:    22.3%

Result: ⚠ One warning
- "Carbs 22.3% is high. Ideally under 10%, but up to 30% is common in dry food."
```

#### Example 3: OCR Error Detected (Fat misread)
```
Protein:  10.5%
Fat:      65.0%   ← OCR misread "6.5%" as "65.0%"
Fiber:    0.5%
Moisture: 79.0%
Ash:      2.1%
Total:    157.1%

Result: ✗ Multiple errors
- "Total 157.1% exceeds 100%. Please verify values."
- "Fat 65.0% is unusually high. Typical range: 2-10% (wet) or 10-25% (dry)."
```

#### Example 4: Valid High-Moisture Wet Food
```
Protein:  9.0%
Fat:      5.5%
Fiber:    0.3%
Moisture: 88.5%  ← High but valid (e.g., broth-style food)
Ash:      1.8%
Total:    105.1%

Result: ⚠ One warning
- "Total 105.1% exceeds 102%. Please check your entries."
  (Note: May need to adjust total validation for very high moisture foods)
```

#### Example 5: Valid Pure Meat Wet Food (Zero Fiber)
```
Protein:  12.0%
Fat:      7.0%
Fiber:    0.0%   ← Zero fiber is OK for pure meat
Moisture: 78.0%
Ash:      2.5%
Total:    99.5%
Carbs:    5.8%

Result: ✓ All values valid, no warnings
```

---

## UI Display

### OCR Scanner View

Validation warnings appear as orange alert banners below the nutrition tiles:

```
┌────────────────────────────────────────────────────┐
│ ⚠️ Total 157.1% exceeds 100%. Please verify values.│
└────────────────────────────────────────────────────┘

┌────────────────────────────────────────────────────┐
│ ⚠️ Fat 65.0% is unusually high. Typical range:     │
│    2-10% (wet) or 10-25% (dry).                    │
└────────────────────────────────────────────────────┘
```

### Product Form View

In the manual entry form, validation errors appear:
- Red error message if total exceeds 102%
- Save button is disabled until values are corrected

---

## Common OCR Errors Caught

### 1. Decimal Point Errors
- **6.5%** read as **65%** (missing decimal point)
- **0.5%** read as **5%** or **05%**

### 2. Digit Misreading
- **8** read as **3** or **9**
- **1** read as **7** or **I**
- **0** read as **O**

### 3. Percentage Signs
- **10%** read as **10** (missing %)
- **10** read as **10%** (added %)

### 4. Unusual Values
- Moisture in mid-range (e.g., 45%) - neither dry nor wet
- Very low moisture (<6%) - unrealistic
- Protein/fat exceeding reasonable limits

---

## Validation Implementation

### Code Location

- **Validation Logic**: `FitCat/Services/Calculations/NutritionCalculator.swift`
  - `NutritionValidation.validate()` - Main validation function
  - Returns array of `ValidationError` enum cases

- **UI Display**: `FitCat/Views/Scan/OCRScannerView.swift`
  - `validationErrors` computed property
  - Orange warning banners for each error

- **Form Validation**: `FitCat/Views/Product/ProductFormView.swift`
  - `isValid` computed property
  - `validationErrorMessage` for total percentage check

### Error Types

```swift
enum ValidationError {
    case totalTooHigh(Double)
    case proteinTooHigh(Double)
    case fatTooHigh(Double)
    case fiberTooHigh(Double)
    case moistureTooHigh(Double)
    case moistureTooLow(Double)
    case moistureUnusualRange(Double)
    case ashTooHigh(Double)
    case carbsHigh(Double)           // Warning
    case carbsTooHigh(Double)         // Error
}
```

---

## Validation Philosophy

### Design Principles

1. **Permissive for Common Values**
   - Don't flag values that exist in real commercial products
   - Allow for regional variations in formulations

2. **Informational vs Blocking Warnings**
   - Informational: Alert user but don't block (e.g., carbs 10-30%)
   - Blocking: Prevent saving invalid data (e.g., total >102%)

3. **Food-Type Aware**
   - Different thresholds for wet vs dry food
   - Based on moisture content (>50% = wet food limits)

4. **No Lower Limits on Some Nutrients**
   - Fiber can be 0% (pure meat products)
   - No minimum protein/fat (trust manufacturer)

5. **OCR Error Detection**
   - Primary goal: catch decimal point errors
   - Secondary: identify unusual value combinations

6. **Real-Time Feedback**
   - Validate as values are scanned
   - Show warnings immediately
   - Prevent bad data from being saved

---

## Future Improvements

### Potential Enhancements

1. **Context-Aware Validation**
   - Use product type (pate, broth, kibble) for more specific ranges
   - Consider brand reputation (premium vs budget)

2. **Machine Learning**
   - Learn from user corrections
   - Identify common OCR patterns specific to label formats

3. **Batch Validation**
   - Compare multiple scans of same product
   - Flag discrepancies for review

4. **Database Comparison**
   - Compare scanned values against known products
   - Warn if values deviate significantly from similar products

5. **User Feedback Loop**
   - Allow users to report false positives
   - Adjust validation thresholds based on feedback

---

## Testing Validation

### Manual Test Cases

Test the validation system with these scenarios:

**Total Percentage**:
- ✓ 98.6% (valid)
- ✓ 101.5% (valid, within tolerance)
- ✗ 105.0% (invalid, exceeds 102%)

**Moisture**:
- ✓ 10.0% (dry)
- ✓ 25.0% (semi-moist)
- ✓ 79.0% (wet)
- ✓ 88.5% (high-moisture wet)
- ⚠ 45.0% (unusual range)
- ✗ 2.0% (too low)

**Carbs**:
- ✓ 6.7% (ideal)
- ⚠ 22.3% (high but common)
- ✗ 45.0% (extremely high)

**Fiber**:
- ✓ 0.0% (zero is OK)
- ✓ 2.5% (normal)
- ✗ 6.0% (too high)

### Automated Tests

See `FitCatTests/` for unit tests covering:
- Edge cases (exactly at thresholds)
- Common OCR errors
- Valid product examples
- Invalid combinations

---

## Questions?

For questions or suggestions about validation rules, please refer to:
- Source code: `FitCat/Services/Calculations/NutritionCalculator.swift`
- GitHub issues: Report false positives or missed validations
- Real-world examples: Contribute examples of products that fail validation incorrectly
