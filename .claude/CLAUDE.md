# FitCat - Project Instructions

## App Information

- **Bundle ID**: `com.darkwebdev.fitcat`
- **App Name**: FitCat
- **Platform**: iOS (SwiftUI)
- **Description**: Cat food nutrition label scanner using OCR

## Running the App

**Quick start** with live logs:
```bash
./run-with-logs.sh
```

Manual build and install:
```bash
xcodebuild -scheme FitCat -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 16 Pro' build
xcrun simctl install booted /Users/tmanyanov/Library/Developer/Xcode/DerivedData/FitCat-*/Build/Products/Debug-iphonesimulator/FitCat.app
xcrun simctl launch --console booted com.darkwebdev.fitcat
```

## Screenshots

Always convert to JPG and save to `/tmp`:
```bash
xcrun simctl io booted screenshot /tmp/fitcat.png
magick /tmp/fitcat.png -quality 85 /tmp/fitcat.jpg
```
