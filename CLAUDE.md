# FitCat Project Notes

## App Configuration

**Bundle Identifier**: `com.darkwebdev.fitcat`

## iOS Development Workflow

### Building and Running in Simulator

Build and install in one command:
```bash
xcodebuild -scheme FitCat -configuration Debug -sdk iphonesimulator -derivedDataPath build build && xcrun simctl install booted build/Build/Products/Debug-iphonesimulator/FitCat.app && xcrun simctl launch booted com.darkwebdev.fitcat
```

Individual commands:
```bash
# Build
xcodebuild -scheme FitCat -configuration Debug -sdk iphonesimulator -derivedDataPath build build

# Install (reinstalls on each build)
xcrun simctl install booted build/Build/Products/Debug-iphonesimulator/FitCat.app

# Launch
xcrun simctl launch booted com.darkwebdev.fitcat
```

### Building and Installing on Physical Device

Build and install:
```bash
# Build with signing
xcodebuild -scheme FitCat -configuration Debug -sdk iphoneos -derivedDataPath build -destination 'platform=iOS,id=00008110-00194C9E3480A01E' build

# Install on device
xcrun devicectl device install app --device 00008110-00194C9E3480A01E build/Build/Products/Debug-iphoneos/FitCat.app
```

Note: `xcrun simctl install` automatically reinstalls the app on each build, replacing the previous version.
