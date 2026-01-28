# FitCat Project Notes

## App Configuration

**Bundle Identifier**: `com.darkwebdev.fitcat`

## Development Guidelines

### Working on Validation

**IMPORTANT**: Before implementing or modifying validation logic, read `VALIDATION.md` first.

The validation documentation contains:
- Complete validation rules for all nutrients (protein, fat, fiber, moisture, ash, carbs)
- Wet vs dry food ranges and thresholds
- Design philosophy and reasoning behind validation decisions
- Real-world examples and test cases
- Existing helper functions and patterns

**Process:**
1. Read `VALIDATION.md` to understand existing validation rules
2. Check `OCRScannerView.swift` for existing helper functions:
   - `isWetFood` - determines food type from API categories/keywords/moisture
   - `determineFoodType()` - helper for validators to determine wet/dry food
   - `isValidProtein()`, `isValidFat()`, `isValidFiber()`, `isValidMoisture()`, `isValidAsh()` - existing validators
3. Reuse existing patterns instead of duplicating logic
4. Update `VALIDATION.md` if you add new validation rules

## iOS Development Workflow

### Setup: Install xc-mcp MCP Server

**Project-specific installation** (recommended - only available in this project):

1. **Create `.mcp.json`** in project root (already done for FitCat):
```json
{
  "mcpServers": {
    "xc-mcp": {
      "command": "npx",
      "args": ["-y", "xc-mcp", "--mini", "--build-only"]
    }
  }
}
```

2. **Add to `.claude/settings.local.json`** (already done for FitCat):
```json
{
  "permissions": {
    "allow": ["mcp__xc-mcp__*"]
  },
  "enableAllProjectMcpServers": true,
  "enabledMcpjsonServers": ["xc-mcp"]
}
```

3. **Verify installation:**
```bash
claude mcp list | grep xc-mcp
# Should show: xc-mcp: npx -y xc-mcp --mini --build-only - ✓ Connected
```

**Note:** xc-mcp is already configured for this FitCat project. For new iOS projects, copy `.mcp.json` and `.claude/settings.local.json` from this project.

**For more details:** See `~/.claude/CLAUDE.md` iOS Development section for:
- Global installation (available in all projects)
- Available tools and categories
- Troubleshooting
- `/sim` skill integration

### Recommended: xc-mcp + Traditional CLI

**Use xc-mcp for building** (structured responses, smart caching, error tracking):

1. **List available simulators:**
```
mcp__xc-mcp__simctl-list()
// Returns: { cacheId, summary, quickAccess: { bootedDevices: [...] } }
// Use quickAccess.bootedDevices[0].udid for the booted simulator
```

2. **Build the project:**
```
mcp__xc-mcp__xcodebuild-build({
  projectPath: "FitCat.xcodeproj",
  scheme: "FitCat",
  destination: "platform=iOS Simulator,id=<UDID>"
})
// Returns: { buildId, success, summary, intelligence, guidance }
// Caches successful configuration for future builds
// Build completed in ~14 seconds with structured error reporting
```

3. **Install and launch** (traditional CLI):
```bash
xcrun simctl install booted build/Build/Products/Debug-iphonesimulator/FitCat.app
xcrun simctl launch booted com.darkwebdev.fitcat
```

**Benefits:**
- xc-mcp provides progressive disclosure: concise summaries, full logs on demand
- Smart caching: remembers successful configurations
- Structured errors: clear error messages instead of raw CLI output
- Performance tracking: build duration, error/warning counts
- Traditional CLI for app management: proven reliability

**Debugging build failures:**
```
// When build fails, get detailed error logs:
mcp__xc-mcp__xcodebuild-get-details({
  buildId: "<buildId from failed build>",
  detailType: "errors-only"
})
// Available detailTypes: "full-log", "errors-only", "warnings-only", "summary", "command"
```

**Get tool documentation:**
```
mcp__xc-mcp__rtfm({ categoryName: "build" })
mcp__xc-mcp__rtfm({ toolName: "xcodebuild-build" })
```

### Quick Start: Build and Run with Live Logs

**Easiest way** - Use the `run-with-logs.sh` script:
```bash
./run-with-logs.sh
```

This script:
- Builds the app with `-quiet` flag
- Installs to the booted simulator
- Launches with `--console` for live logs
- Filters logs to show only FITCAT-prefixed messages

### Alternative: Traditional CLI Only

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
