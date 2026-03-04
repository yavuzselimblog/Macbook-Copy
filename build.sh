#!/bin/bash

# Navigate to script directory
cd "$(dirname "$0")"

APP_NAME="softwarencodercopylist"
BUNDLE_DIR="$APP_NAME.app/Contents"
MACOS_DIR="$BUNDLE_DIR/MacOS"
RESOURCES_DIR="$BUNDLE_DIR/Resources"

echo "Creating App Bundle Directory Structure..."
# Create directories
mkdir -p "$MACOS_DIR"
mkdir -p "$RESOURCES_DIR"

echo "Compiling Swift Source Code..."
# Compile swift file
swiftc -parse-as-library MacCopy.swift -o "$MACOS_DIR/$APP_NAME"

# Check if compile succeeded
if [ $? -eq 0 ]; then
    echo "Compilation successful."
else
    echo "Compilation failed."
    exit 1
fi

echo "Copying MyIcon.icns..."
# Copy icon
cp MyIcon.icns "$RESOURCES_DIR/"

echo "Copying Info.plist..."
# Copy Info.plist
cp Info.plist "$BUNDLE_DIR/"

echo "-----------------------------------"
echo "Build complete! "
echo "The application is located at $pwd/$APP_NAME.app"
echo "You can double click '$APP_NAME.app' to run it."
