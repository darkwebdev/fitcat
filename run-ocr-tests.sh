#!/bin/bash

# Run OCR integration tests and capture output
echo "🧪 Running OCR Integration Tests..."

# Get booted simulator ID
SIMULATOR_ID=$(xcrun simctl list devices booted | grep iPhone | head -1 | sed -E 's/.*\(([A-F0-9-]+)\).*/\1/')

if [ -z "$SIMULATOR_ID" ]; then
    echo "❌ No booted simulator found. Please boot a simulator first."
    exit 1
fi

echo "📱 Using booted simulator: $SIMULATOR_ID"
echo ""

# Build for testing
echo "📦 Building tests..."
xcodebuild build-for-testing \
  -scheme FitCat \
  -sdk iphonesimulator \
  -destination "id=$SIMULATOR_ID" \
  -quiet

if [ $? -ne 0 ]; then
    echo "❌ Build failed"
    exit 1
fi

echo "✅ Build succeeded"
echo ""
echo "🧪 Running tests..."

# Run tests
xcodebuild test-without-building \
  -scheme FitCat \
  -sdk iphonesimulator \
  -destination "id=$SIMULATOR_ID" \
  -only-testing FitCatTests/OCRIntegrationTests 2>&1 | \
  grep -E "(Test Case|📸|📝|✅|⚠️|passed|failed|error)" || echo "No test output captured"

echo ""
echo "📊 Test Summary:"
xcodebuild test-without-building \
  -scheme FitCat \
  -sdk iphonesimulator \
  -destination "id=$SIMULATOR_ID" \
  -only-testing FitCatTests/OCRIntegrationTests 2>&1 | \
  grep -E "(Test Suite|Executed|passed|failed)" | tail -10
