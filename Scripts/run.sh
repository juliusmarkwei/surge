#!/bin/bash
# Run script for SURGE TUI

set -e

# Build first
./Scripts/build.sh

echo ""
echo "Starting SURGE TUI..."
echo "Press 'q' to quit, 'h' or '?' for help"
echo ""
sleep 1

# Run the application
./target/debug/surge-tui "$@"
