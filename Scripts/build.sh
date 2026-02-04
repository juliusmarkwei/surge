#!/bin/bash
# Build script for SURGE TUI

set -e

echo "Building SURGE TUI..."

# Check if cargo is installed
if ! command -v cargo &> /dev/null; then
    echo "Error: Cargo is not installed. Please install Rust from https://rustup.rs/"
    exit 1
fi

# Build the project
if [ "$1" == "release" ]; then
    echo "Building release version (optimized)..."
    cargo build --release
    echo ""
    echo "✅ Build complete!"
    echo "Run: ./target/release/surge-tui"
else
    echo "Building debug version..."
    cargo build
    echo ""
    echo "✅ Build complete!"
    echo "Run: ./target/debug/surge-tui"
fi
