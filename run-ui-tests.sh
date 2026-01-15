#!/bin/bash

# FitCat UI Test Runner
# Runs all UI tests on the iOS Simulator

set -e

echo "🧪 Running FitCat UI Tests..."

# Build and run tests
xcodebuild test \
    -scheme FitCat \
    -sdk iphonesimulator \
    -destination 'platform=iOS Simulator,name=iPhone 15 Pro' \
    -only-testing:FitCatUITests \
    | xcpretty --color --simple

echo "✅ UI Tests Complete"
