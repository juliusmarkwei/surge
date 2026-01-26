#!/bin/bash
#
# Build Script for SURGE App Bundle
# Creates a proper .app bundle for SMAppService compatibility
#

set -e

echo "🔨 Building SURGE..."
swift build

echo "📦 Creating app bundle..."
APP_DIR=".build/debug/SURGE.app"
mkdir -p "$APP_DIR/Contents/MacOS"
mkdir -p "$APP_DIR/Contents/Resources"
mkdir -p "$APP_DIR/Contents/Library/LaunchServices"

echo "📋 Copying binaries..."
cp .build/debug/SURGE "$APP_DIR/Contents/MacOS/"
cp .build/debug/PrivilegedHelper "$APP_DIR/Contents/Library/LaunchServices/com.surge.helper"
cp Sources/PrivilegedHelper/launchd.plist "$APP_DIR/Contents/Library/LaunchServices/com.surge.helper.plist"

echo "📄 Creating Info.plist..."
cat > "$APP_DIR/Contents/Info.plist" << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>SURGE</string>
    <key>CFBundleIdentifier</key>
    <string>com.surge.app</string>
    <key>CFBundleName</key>
    <string>SURGE</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>0.2.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>SMPrivilegedExecutables</key>
    <dict>
        <key>com.surge.helper</key>
        <string>identifier "com.surge.helper" and anchor apple generic</string>
    </dict>
</dict>
</plist>
EOF

echo "✅ App bundle created at: $APP_DIR"
echo ""
echo "To run:"
echo "  open $APP_DIR"
echo ""
echo "Or directly:"
echo "  .build/debug/SURGE.app/Contents/MacOS/SURGE"
