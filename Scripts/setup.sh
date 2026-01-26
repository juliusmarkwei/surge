#!/bin/bash
#
# setup.sh
# Initial project setup script
#

set -e

echo "🚀 Setting up SURGE..."

# Check for Swift
if ! command -v swift &> /dev/null; then
    echo "❌ Swift is not installed. Please install Xcode and command line tools."
    exit 1
fi

echo "✅ Swift found: $(swift --version | head -n 1)"

# Resolve dependencies
echo "📦 Resolving Swift package dependencies..."
swift package resolve

# Build the project
echo "🔨 Building project..."
swift build

echo ""
echo "✅ Setup complete!"
echo ""
echo "Next steps:"
echo "  1. Run: .build/debug/SURGE"
echo "  2. Approve the privileged helper in System Settings"
echo "  3. Check the menu bar for the app icon"
echo ""
echo "For development with Xcode:"
echo "  open Package.swift"
