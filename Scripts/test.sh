#!/bin/bash
# Test script for SURGE TUI

set -e

echo "Running tests..."

# Check if cargo is installed
if ! command -v cargo &> /dev/null; then
    echo "Error: Cargo is not installed. Please install Rust from https://rustup.rs/"
    exit 1
fi

# Run tests
cargo test "$@"

echo ""
echo "✅ All tests passed!"
