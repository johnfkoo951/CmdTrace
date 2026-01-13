#!/bin/bash
# Build CmdTrace.dmg for distribution
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
BUILD_DIR="$SCRIPT_DIR/build"
APP_NAME="CmdTrace"
APP_PATH="$BUILD_DIR/$APP_NAME.app"

# Use absolute path for defaults read (relative paths don't work reliably)
VERSION=$(/usr/bin/defaults read "$APP_PATH/Contents/Info.plist" CFBundleShortVersionString 2>/dev/null || echo "2.0.0")
BUILD_NUMBER=$(/usr/bin/defaults read "$APP_PATH/Contents/Info.plist" CFBundleVersion 2>/dev/null || echo "1")
DMG_NAME="${APP_NAME}-${VERSION}-build${BUILD_NUMBER}"
DMG_PATH="$BUILD_DIR/${DMG_NAME}.dmg"
VOLUME_NAME="$APP_NAME"

# Check if app exists
if [ ! -d "$APP_PATH" ]; then
    echo "❌ App not found. Run ./build-app.sh first."
    exit 1
fi

echo "📦 Creating DMG: $DMG_NAME"
echo "   App: $APP_PATH"
echo ""

# Remove old DMG if exists
rm -f "$DMG_PATH"

# Create temporary DMG directory
DMG_TEMP_DIR="$BUILD_DIR/dmg-temp"
rm -rf "$DMG_TEMP_DIR"
mkdir -p "$DMG_TEMP_DIR"

# Copy app to temp directory
cp -R "$APP_PATH" "$DMG_TEMP_DIR/"

# Create Applications symlink
ln -s /Applications "$DMG_TEMP_DIR/Applications"

# Create compressed DMG directly
hdiutil create -srcfolder "$DMG_TEMP_DIR" -volname "$VOLUME_NAME" \
    -fs HFS+ -format UDZO -imagekey zlib-level=9 "$DMG_PATH"

# Clean up
rm -rf "$DMG_TEMP_DIR"

# Calculate size and checksum
DMG_SIZE=$(du -h "$DMG_PATH" | cut -f1)
DMG_SHA256=$(shasum -a 256 "$DMG_PATH" | cut -d' ' -f1)

echo ""
echo "✅ DMG created successfully!"
echo ""
echo "📁 File: $DMG_PATH"
echo "📦 Size: $DMG_SIZE"
echo "🔐 SHA256: $DMG_SHA256"
echo ""
echo "To install:"
echo "  1. Open $DMG_PATH"
echo "  2. Drag CmdTrace to Applications"
