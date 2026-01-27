#!/bin/bash

echo "Building and running FitCat with live logs..."
echo ""

# Build the app
echo "Building FitCat..."
xcodebuild -scheme FitCat -configuration Debug -sdk iphonesimulator -derivedDataPath build build -quiet

if [ $? -ne 0 ]; then
    echo "Build failed"
    exit 1
fi

echo "Build succeeded"
echo ""

# Install to simulator
echo "Installing to simulator..."
xcrun simctl install booted build/Build/Products/Debug-iphonesimulator/FitCat.app

if [ $? -ne 0 ]; then
    echo "Install failed"
    exit 1
fi

echo "Installed"
echo ""

# Kill any existing log stream processes for FitCat
pkill -f "log stream.*FitCat" 2>/dev/null

# Set up tmux pane with live log stream BEFORE launching app
echo "Setting up live logs pane..."
if [ "$(tmux display-message -p '#{window_panes}' 2>/dev/null)" -gt 1 ]; then
    # Right pane exists - restart log stream in it
    echo "Reusing existing tmux pane for logs"
    tmux select-pane -t right
    tmux send-keys C-c
    sleep 0.5
    tmux send-keys "xcrun simctl spawn booted log stream --predicate 'process == \"FitCat\"' --level info --style compact 2>&1 | grep --line-buffered -E '(FITCAT|Error|error)'" Enter
    tmux select-pane -t left
else
    # No right pane - create it with log stream
    echo "Creating tmux pane for logs"
    tmux split-window -h -p 30 "xcrun simctl spawn booted log stream --predicate 'process == \"FitCat\"' --level info --style compact 2>&1 | grep --line-buffered -E '(FITCAT|Error|error)'"
    tmux select-pane -t left

    # Verify pane was created
    if [ "$(tmux display-message -p '#{window_panes}' 2>/dev/null)" -le 1 ]; then
        echo "WARNING: Failed to create tmux pane. Logs will not be visible."
        echo "You may not be running inside a tmux session."
    fi
fi

# Wait a moment for log stream to start
sleep 1

# Launch app (so log stream catches the launch)
echo "Launching FitCat..."
xcrun simctl launch booted com.darkwebdev.fitcat

echo ""
echo "FitCat is running. Logs are visible in the right pane."
echo "To stop: xcrun simctl terminate booted com.darkwebdev.fitcat"
