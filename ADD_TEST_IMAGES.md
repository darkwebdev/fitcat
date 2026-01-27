# Adding Test Images to FitCatTests

## Manual Steps

1. **Open Xcode project**: `FitCat.xcodeproj`

2. **Navigate to FitCatTests** in the project navigator

3. **Add the TestImages folder:**
   - Right-click on `FitCatTests` folder
   - Select "Add Files to FitCat..."
   - Navigate to `/Users/tmanyanov/build/fitcat/FitCatTests/TestImages`
   - Select the `TestImages` folder
   - **IMPORTANT:** Check these options:
     - ✅ "Copy items if needed" (unchecked - files are already in place)
     - ✅ "Create folder references" (NOT "Create groups")
     - ✅ Add to targets: **FitCatTests** only

4. **Verify:**
   - TestImages should appear as a blue folder (folder reference)
   - All images (IMG_2394.HEIC, IMG_2395.HEIC, nutrition.jpeg) should be visible
   - Images should be in FitCatTests target membership

## Files to Add

```
FitCatTests/TestImages/
├── IMG_2394.HEIC       (1.4 MB)
├── IMG_2395.HEIC       (102 KB)
├── nutrition.jpeg      (452 KB)
├── label-dry-food.jpg  (18 KB)
└── label-wet-food.jpg  (25 KB)
```

## Running the Tests

After adding the images:

```bash
# Run all OCR tests
xcodebuild test -scheme FitCat -sdk iphonesimulator \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro' \
  -only-testing:FitCatTests/OCRIntegrationTests

# Run specific test
xcodebuild test -scheme FitCat -sdk iphonesimulator \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro' \
  -only-testing:FitCatTests/OCRIntegrationTests/testRealLabel_IMG2394
```

The tests will:
1. Load the real nutrition label images from the test bundle
2. Run OCR on them
3. Parse the nutrition values
4. Print what was detected and what's missing
5. Help identify why fiber/ash aren't being detected
