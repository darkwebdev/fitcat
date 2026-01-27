#!/bin/bash

# This script is designed to be run from Xcode Product > Perform Action > Run Script
# It will run the OCR tests and output the results

echo "Running OCR Integration Tests..."
echo ""

cd "${SRCROOT}"

# Use xcodebuild to run just the OCR tests
xcodebuild test \
  -project "${PROJECT_FILE_PATH}" \
  -scheme "${SCHEME}" \
  -destination "${DESTINATION}" \
  -only-testing:FitCatTests/OCRIntegrationTests \
  2>&1

echo ""
echo "Tests complete"
