#!/bin/bash

# Test script for FitCat OCR scanner with automated image selection
# This script builds the app, adds test images to simulator, and runs tests

set -e

echo "🔨 Building FitCat app..."
xcodebuild -scheme FitCat -sdk iphonesimulator \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro' \
  build 2>&1 | grep -E '(BUILD|error|warning)' || true

echo ""
echo "📸 Creating test nutrition label images..."
mkdir -p /tmp/fitcat-test-images

# Create test image 1 (wet food - low carbs)
magick -size 800x1200 xc:white \
  -pointsize 40 -font Helvetica-Bold -fill black \
  -annotate +50+100 'CAT FOOD NUTRITION' \
  -pointsize 30 -font Helvetica \
  -annotate +50+200 'Product: Premium Cat Food' \
  -annotate +50+250 'Brand: Test Brand' \
  -pointsize 35 -font Helvetica-Bold \
  -annotate +50+350 'GUARANTEED ANALYSIS' \
  -pointsize 28 -font Helvetica \
  -annotate +50+420 'Crude Protein (min) ..... 11.5%' \
  -annotate +50+470 'Crude Fat (min) ........... 6.5%' \
  -annotate +50+520 'Crude Fiber (max) ......... 0.5%' \
  -annotate +50+570 'Moisture (max) ............ 79.0%' \
  -annotate +50+620 'Ash (max) .................. 1.8%' \
  -pointsize 24 \
  -annotate +50+720 'Barcode: 4001234567890' \
  -quality 85 /tmp/fitcat-test-images/wet-food.jpg

# Create test image 2 (dry food - medium carbs)
magick -size 800x1200 xc:white \
  -pointsize 40 -font Helvetica-Bold -fill black \
  -annotate +50+100 'NUTRITION FACTS' \
  -pointsize 30 -font Helvetica \
  -annotate +50+200 'Product: Chicken Formula' \
  -annotate +50+250 'Brand: Premium Brand' \
  -pointsize 35 -font Helvetica-Bold \
  -annotate +50+350 'ANALYSIS' \
  -pointsize 28 -font Helvetica \
  -annotate +50+420 'Protein ................ 40.0%' \
  -annotate +50+470 'Fat ..................... 18.0%' \
  -annotate +50+520 'Fiber .................... 3.0%' \
  -annotate +50+570 'Moisture ............... 10.0%' \
  -annotate +50+620 'Ash ....................... 8.0%' \
  -pointsize 24 \
  -annotate +50+720 'EAN: 5001234567890' \
  -quality 85 /tmp/fitcat-test-images/dry-food.jpg

# Create test image 3 (barcode only)
magick -size 400x200 xc:white \
  -pointsize 60 -font Courier -fill black \
  -annotate +50+100 '4001234567890' \
  -quality 85 /tmp/fitcat-test-images/barcode-only.jpg

echo "Created $(ls /tmp/fitcat-test-images/*.jpg | wc -l) test images"

echo ""
echo "📱 Installing app on simulator..."
xcrun simctl install booted \
  ~/Library/Developer/Xcode/DerivedData/FitCat-*/Build/Products/Debug-iphonesimulator/FitCat.app

echo ""
echo "🖼️  Adding test images to simulator photo library..."
xcrun simctl addmedia booted /tmp/fitcat-test-images/*.jpg

echo ""
echo "🚀 Launching FitCat app..."
xcrun simctl terminate booted com.darkwebdev.fitcat 2>/dev/null || true
sleep 1
xcrun simctl launch booted com.darkwebdev.fitcat

echo ""
echo "✅ Setup complete!"
echo ""
echo "📋 Manual test steps:"
echo "1. Go to Scan tab in the app"
echo "2. Tap the screen to open photo picker"
echo "3. Select multiple test images (wet-food.jpg, dry-food.jpg)"
echo "4. Verify the app processes them without crashing"
echo "5. Check that nutrition values are detected"
echo ""
echo "🧪 To run automated UI tests:"
echo "xcodebuild test -scheme FitCat -sdk iphonesimulator \\"
echo "  -destination 'platform=iOS Simulator,name=iPhone 16 Pro' \\"
echo "  -only-testing:FitCatUITests/FitCatUITests/testImageProcessingDoesNotCrash"
