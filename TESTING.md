# FitCat Testing Guide

## Fixed Issues

### 1. Image Picker Crash on Multiple Image Selection

**Problem:** The app crashed when selecting multiple images from the photo picker due to a race condition in `ImagePicker.swift`.

**Root Cause:** Multiple async threads were appending to the same `loadedImages` array without synchronization (lines 52-74).

**Fix:** Added thread-safe access using a dedicated serial dispatch queue:
```swift
let syncQueue = DispatchQueue(label: "com.fitcat.imagepicker.sync")
var loadedImages: [UIImage] = []

// ... in async completion handler:
syncQueue.sync {
    loadedImages.append(image)
}
```

**Location:** `FitCat/Views/Scan/ImagePicker.swift:52-74`

### 2. Crash When Adding Second Image Sequentially

**Problem:** The app crashed when:
1. Selecting first image (e.g., IMG_2395.HEIC)
2. Waiting for nutrition values to appear
3. Selecting second image (e.g., IMG_2394.HEIC)
4. App crashes

**Root Cause:** Multiple race conditions in `OCRScannerView.swift`:
- Timer from first session still running when second session starts
- Processing task not properly cancelled before starting new one
- State variables (`isProcessing`, `imageStreamCache`) accessed from multiple threads
- No synchronization between cleanup and new session initialization

**Fixes Applied:**

1. **Added processing guard** - Prevents starting new session while previous is active:
```swift
if isProcessing {
    // Wait and retry
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
        self.startImageStreamProcessing(images: images)
    }
    return
}
```

2. **Added @MainActor isolation** - Ensures all state access happens on main thread:
```swift
let task = Task { @MainActor in
    defer { self.isProcessing = false }
    // ... processing logic
}
```

3. **Added defer cleanup** - Guarantees `isProcessing` is reset even if task fails or is cancelled

4. **Extended cleanup delay** - Changed from 0.1s to 0.3s to ensure proper cleanup:
```swift
DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
    self.selectedImages = nil
}
```

**Locations:**
- `FitCat/Views/Scan/OCRScannerView.swift:588-603` (onChange handler)
- `FitCat/Views/Scan/OCRScannerView.swift:1324-1420` (startImageStreamProcessing)
- `FitCat/Views/Scan/OCRScannerView.swift:1385-1418` (Task creation)

## Automated Testing Setup

### Quick Start

Run the automated test setup script:

```bash
./test-image-picker.sh
```

This script will:
1. Build the app
2. Create test nutrition label images
3. Install the app in the simulator
4. Add test images to the simulator's photo library
5. Launch the app

### Manual Testing Steps

After running the script:

1. Navigate to the **Scan** tab in the app
2. Tap the screen to open the photo picker
3. Select **multiple test images** (e.g., wet-food.jpg, dry-food.jpg)
4. Verify the app processes them **without crashing**
5. Check that nutrition values are detected correctly

### Test Images

The script creates three test images in `/tmp/fitcat-test-images/`:

1. **wet-food.jpg** - Wet cat food with low carbs (3.3%)
   - Protein: 11.5%
   - Fat: 6.5%
   - Fiber: 0.5%
   - Moisture: 79.0%
   - Ash: 1.8%
   - Barcode: 4001234567890

2. **dry-food.jpg** - Dry cat food with medium carbs (21%)
   - Protein: 40.0%
   - Fat: 18.0%
   - Fiber: 3.0%
   - Moisture: 10.0%
   - Ash: 8.0%
   - Barcode: 5001234567890

3. **barcode-only.jpg** - Just a barcode for testing barcode detection

### Using `xcrun simctl addmedia`

The key to automated e2e testing in iOS simulators is `xcrun simctl addmedia`:

```bash
# Add images to simulator photo library
xcrun simctl addmedia booted /path/to/images/*.jpg
```

**Benefits:**
- No need to manually interact with the photo picker UI
- Images are available immediately in the Photos app
- Can be scripted for CI/CD pipelines
- Works with any image format (JPG, PNG, HEIC, etc.)

**Limitations:**
- XCTest cannot directly select photos from the system photo picker
- The photo picker is a system modal that XCTest cannot fully control
- Manual testing or custom test doubles are needed for full automation

## Running UI Tests

Run all UI tests:

```bash
xcodebuild test -scheme FitCat -sdk iphonesimulator \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro'
```

Run specific test:

```bash
xcodebuild test -scheme FitCat -sdk iphonesimulator \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro' \
  -only-testing:FitCatUITests/FitCatUITests/testImageProcessingDoesNotCrash
```

## Test Coverage

### Existing UI Tests (`FitCatUITests.swift`)

- ✅ Empty state display
- ✅ Navigation flows
- ✅ Product form validation
- ✅ Carbs calculation (all three ranges: green/yellow/red)
- ✅ Product list display
- ✅ Search functionality
- ✅ Tab navigation
- ✅ Product detail view

### New Tests Added

- ✅ `testScanMultipleImages()` - Verifies photo picker opens without crashing
- ✅ `testImageProcessingDoesNotCrash()` - Validates app stability with multiple images

## CI/CD Integration

To integrate into CI/CD:

1. Add the test images to your repository under `FitCatUITests/TestImages/`
2. In your CI script, run:
   ```bash
   # Boot simulator
   xcrun simctl boot "iPhone 16 Pro" || true

   # Add test images
   xcrun simctl addmedia booted FitCatUITests/TestImages/*.jpg

   # Run tests
   xcodebuild test -scheme FitCat -sdk iphonesimulator \
     -destination 'platform=iOS Simulator,name=iPhone 16 Pro'
   ```

## Creating Custom Test Images

To create nutrition label test images:

```bash
magick -size 800x1200 xc:white \
  -pointsize 40 -font Helvetica-Bold -fill black \
  -annotate +50+100 'CAT FOOD NUTRITION' \
  -pointsize 28 -font Helvetica \
  -annotate +50+420 'Crude Protein (min) ..... 11.5%' \
  -annotate +50+470 'Crude Fat (min) ........... 6.5%' \
  -quality 85 output.jpg
```

Adjust text and values as needed for different test scenarios.

## Troubleshooting

### Crash on multiple image selection
- **Fixed** - Update to latest code with synchronized array access

### Photo picker doesn't open
- Ensure you're running in the iOS Simulator
- Check that the "Tap to select photos" message is visible

### Test images not appearing in Photos
- Verify images were added: `xcrun simctl addmedia booted /tmp/fitcat-test-images/*.jpg`
- Check Photos app manually in the simulator

### Tests fail in CI
- Ensure simulator is booted before adding media
- Add explicit waits after `addmedia` command (1-2 seconds)

## Future Improvements

1. **Mock Photo Picker** - Create a test double that doesn't rely on system UI
2. **Integration Tests** - Test OCR processing directly with known images
3. **Performance Tests** - Measure OCR processing time for various image sizes
4. **Accessibility Tests** - Verify VoiceOver labels and navigation
