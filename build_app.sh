#!/bin/bash
#
# build_app.sh — Builds ClarityBuds and packages it as a proper .app bundle.
#
# Usage:
#   ./build_app.sh
#
# This creates:
#   ./ClarityBuds.app/Contents/MacOS/ClarityBuds
#   ./ClarityBuds.app/Contents/Info.plist
#
# A proper .app bundle is required for macOS to:
#   - Show the microphone permission dialog
#   - Remember mic permission across launches
#   - Display the app name correctly in System Settings
#

set -e

# Always ensure we are running from the project directory
cd "$(dirname "$0")"

echo "🔨 Building ClarityBuds..."
swift build -c release 2>&1

echo ""
echo "📦 Creating app bundle..."

APP_DIR="ClarityBuds.app"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"

# Clean previous bundle
rm -rf "$APP_DIR"

# Create bundle structure
mkdir -p "$MACOS_DIR"
mkdir -p "$RESOURCES_DIR"

# Copy binary
cp .build/release/ClarityBuds "$MACOS_DIR/ClarityBuds"

# Create Info.plist for the bundle
cat > "$CONTENTS_DIR/Info.plist" << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>ClarityBuds</string>
    <key>CFBundleIdentifier</key>
    <string>com.claritybuds.app</string>
    <key>CFBundleName</key>
    <string>ClarityBuds</string>
    <key>CFBundleDisplayName</key>
    <string>ClarityBuds</string>
    <key>CFBundleVersion</key>
    <string>1.0.0</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0.0</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>NSMicrophoneUsageDescription</key>
    <string>ClarityBuds needs microphone access to pass ambient sound through your headphones, giving any headphones a transparency mode effect.</string>
    <key>LSUIElement</key>
    <true/>
    <key>LSApplicationCategoryType</key>
    <string>public.app-category.utilities</string>
    <key>NSHighResolutionCapable</key>
    <true/>
</dict>
</plist>
EOF

echo ""
echo "✅ ClarityBuds.app built successfully!"
echo ""
echo "To run:"
echo "  open ClarityBuds.app"
echo ""
echo "Or to install:"
echo "  cp -r ClarityBuds.app /Applications/"
echo "  open /Applications/ClarityBuds.app"
echo ""
