# FitCat - Manual Testing Checklist

## ⚠️ REQUIRES PHYSICAL DEVICE TESTING

The following features cannot be fully tested in the iOS Simulator and require a physical iPhone:

### ProductFormView - Add/Edit Product Form

**Access**: Tap the blue "+" button in the top-right corner of the home screen

#### Test Case 1: Manual Product Entry
1. **Open form**: Tap "+" button
2. **Fill in product info**:
   - Product Name: "Test Cat Food"
   - Brand: "Test Brand"
   - Barcode: "123456789012" (optional)
   - Serving Size: "1 can (85g)" (optional)

3. **Fill in nutrition values** (test with your Google Sheet example):
   - Protein: 11.5
   - Fat: 6.5
   - Fiber: 0.5
   - Moisture: 79
   - Ash/Minerals: 1.8

4. **Verify real-time calculation**:
   - Watch "Calculated Carbohydrates" section update as you type
   - Should show: **Carbs: 3.33%**
   - Status should show: **Excellent** (in green)

5. **Test Save button**:
   - Tap "Save" button (top-right)
   - Form should close
   - Product should appear in home list with green circle showing "3.3"

#### Test Case 2: Real-time Calculation Updates
1. Open form again
2. Enter values one by one and watch the carbs % update:
   - After Protein (11.5): Carbs will be incorrect (needs all values)
   - After Fat (6.5): Still updating...
   - After Fiber (0.5): Still updating...
   - After Moisture (79): Almost there...
   - After Ash (1.8): **Final: 3.33%** ✅

#### Test Case 3: Color Changes
Test different nutrition profiles to verify color coding:

**Green Test** (already done):
- P=11.5, F=6.5, Fi=0.5, M=79, A=1.8 → **3.33% green**

**Yellow Test**:
- P=30, F=10, Fi=2, M=50, A=4.5 → **~7% yellow**
- Status should show "Acceptable"

**Red Test**:
- P=40, F=18, Fi=3, M=10, A=8 → **~23% red**
- Status should show "Too High"

#### Test Case 4: Validation
1. **Empty fields**: Save button should be disabled
2. **Invalid values**: Try entering:
   - Negative numbers → Should not allow
   - Values > 100 → Should not allow
   - Letters in number fields → Should not allow
3. **Total > 100%**: Enter P=50, F=30, Fi=20, M=10, A=10
   - Total = 120% → Save should be disabled

#### Test Case 5: Edit Existing Product
1. Tap on "Classic Pate Chicken" from the list
2. Tap menu (•••) in top-right
3. Select "Edit"
4. Change Protein from 11.5 to 12.0
5. Watch carbs recalculate
6. Save changes
7. Verify updated values in list

#### Test Case 6: Keyboard Types
- **Number fields** (nutrition values): Should show numeric keyboard with decimal
- **Barcode field**: Should show number pad (no decimal needed)
- **Text fields** (name, brand): Should show standard keyboard

---

### Camera Scanning (Requires Physical Device)

#### Test Case 7: Barcode Scanner
1. Switch to "Scan" tab
2. Select "Barcode" mode
3. Point camera at a cat food can barcode
4. **Expected behavior**:
   - Green rectangle overlay appears
   - Barcode is detected automatically
   - Haptic feedback (vibration) on detection
   - If in database: Navigate to product details
   - If not in database: Switch to OCR mode or show form

#### Test Case 8: OCR Scanner
1. Switch to "Scan" tab
2. Select "Nutrition Label" mode
3. Point camera at nutrition label
4. Tap "Capture" button
5. **Expected behavior**:
   - "Scanning..." progress indicator appears
   - OCR extracts text from label
   - Form opens with pre-filled values
   - User can adjust any incorrect values
   - Save to add product

#### Test Case 9: Camera Permissions
1. First launch: App should request camera permission
2. If denied: Should show "Camera Access Required" screen
3. Tap "Open Settings" → Should open iOS Settings app
4. Enable camera → Return to app → Scanner should work

---

### GitHub Sync (Requires Network)

#### Test Case 10: Initial Sync
1. Create `products.json` in GitHub repository
2. Open app → Settings tab
3. Enter GitHub URL in text field
4. Tap "Sync Now"
5. **Expected behavior**:
   - Progress spinner appears
   - Products download and appear in list
   - "Last Synced: Just now" appears
   - Local products (source=local) are preserved

#### Test Case 11: Offline Mode
1. Enable Airplane Mode
2. Close and reopen app
3. **Expected behavior**:
   - All previously synced products still visible
   - Can add/edit/delete local products
   - Sync shows "Last Synced: X time ago"
   - No error messages

#### Test Case 12: Sync Conflict Resolution
1. Add product manually with barcode "123456"
2. Add same barcode to GitHub database with different values
3. Trigger sync
4. **Expected behavior**:
   - Local product (source=local) is preserved
   - GitHub version is ignored
   - No duplicate entries

---

### Product Detail View

#### Test Case 13: View Product Details
1. Tap on any product from the list
2. **Should display**:
   - Large circular carbs meter at top
   - Product name and brand
   - Barcode (if available)
   - Serving size (if available)
   - Nutrition grid with all 6 values (P, F, Fi, M, A, Carbs)
   - Calorie breakdown (protein cal, fat cal, carbs cal)
   - Total calories per 100g
   - Source indicator (Manually Added / From Database)

3. **Verify carbs meter**:
   - Circular progress ring
   - Percentage in center
   - Color matches product list (green/yellow/red)
   - Status text below ("Excellent" / "Acceptable" / "Too High")

#### Test Case 14: Delete Product
1. Open product detail
2. Tap menu (•••)
3. Select "Delete"
4. Confirm deletion
5. **Expected behavior**:
   - Alert: "Are you sure you want to delete [product name]?"
   - Tap "Delete" → Product removed from list
   - Returns to home screen

---

### Search Functionality

#### Test Case 15: Search Products
1. On home screen, tap search bar
2. Type "Fancy"
3. **Expected behavior**:
   - List filters to show only "Classic Pate Chicken" (brand: Fancy Feast)
4. Clear search
5. Type "chicken"
6. Should show all products with "chicken" in name
7. Type "xyz123" (non-existent)
8. Should show empty list

---

## Code-Level Tests (Already Verified)

### ✅ NutritionCalculator Tests
Run: `cmd+U` in Xcode

Tests verify:
- Carbs formula accuracy
- Google Sheet example (11.5/6.5/0.5/79/1.8 → 3.33%)
- High carbs example (40/18/3/10/8 → 23.33%)
- Edge cases (zero moisture, 100% moisture)
- Color level determination
- Calorie calculations

### ✅ Database Tests
Verified via simulator:
- Products persist after app restart
- Multiple products stored correctly
- Sorting by update time works
- SQLite schema created properly

---

## Performance Tests

### Test Case 16: Large Product List
1. Add 100+ products to database
2. Scroll through list
3. **Expected behavior**:
   - Smooth scrolling
   - No lag or stuttering
   - Search remains fast

### Test Case 17: Rapid Input
1. Open product form
2. Quickly type random numbers in all fields
3. **Expected behavior**:
   - Carbs calculation updates smoothly
   - No crashes or freezes
   - UI remains responsive

---

## Accessibility Tests

### Test Case 18: VoiceOver
1. Enable VoiceOver in iOS Settings
2. Navigate through app
3. **Expected behavior**:
   - All buttons have labels
   - Product cards are readable
   - Form fields have proper labels
   - Carbs meter announces percentage and status

### Test Case 19: Dynamic Type
1. Change text size in iOS Settings (Settings → Display → Text Size)
2. Reopen app
3. **Expected behavior**:
   - Text scales appropriately
   - No text truncation
   - Layout remains functional

---

## Edge Cases

### Test Case 20: Very Long Names
- Product Name: "Super Ultra Premium Grain-Free Organic Chicken and Turkey Formula with Added Vitamins"
- **Expected**: Name truncates with "..." in list view, full name in detail view

### Test Case 21: Zero Values
- Enter all zeros (P=0, F=0, Fi=0, M=0, A=0)
- **Expected**: Division by zero protection, shows 0% or error

### Test Case 22: 100% Moisture
- Enter M=100
- **Expected**: Division by zero protection, shows 0% carbs

### Test Case 23: Impossible Values
- Try: P=50, F=40, Fi=30, M=20, A=10 (total=150%)
- **Expected**: Save button disabled, validation error

---

## Summary

**Simulator Tested**: ✅
- Product list display
- Carbs calculation accuracy
- Color-coded meters
- Database persistence
- UI rendering

**Requires Physical Device**: ⚠️
- Product form input fields
- Camera barcode scanning
- Camera OCR scanning
- GitHub sync
- Full user interaction flow

**Next Steps**:
1. Test on physical iPhone
2. Verify all form interactions
3. Test camera scanning features
4. Setup GitHub database
5. Test sync functionality
