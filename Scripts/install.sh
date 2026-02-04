#!/bin/bash

# SURGE v1.0 - Local Installation Script
# For use when repository is already cloned
# For remote install, use: curl -fsSL https://raw.githubusercontent.com/juliusmarkwei/surge/main/install.sh | bash

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Print colored output
print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Print banner
print_banner() {
    echo ""
    echo -e "${CYAN}"
    echo "   -----       ____    _   _    ____     ____    ____"
    echo "   -          / ___|  | | | |  |  _ \\   / ___|  | ___|"
    echo "   ------     \\___ \\  | | | |  | |_) | | |  _   |  _|"
    echo "   ----        ___) | | |_| |  |  _ <  | |_| |  | |___"
    echo "   --         |____/   \\___/   |_| \\_\\  \\____|  |_____|"
    echo "   -------"
    echo -e "${NC}"
    echo ""
    echo -e "  ${GREEN}Version: 1.0.0${NC}  │  ${YELLOW}Released: 2026-02-04${NC}  │  ${CYAN}Created by: SURGE Contributors${NC}"
    echo ""
}

# Check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Detect OS
detect_os() {
    if [[ "$OSTYPE" == "linux-gnu"* ]]; then
        echo "linux"
    elif [[ "$OSTYPE" == "darwin"* ]]; then
        echo "macos"
    else
        echo "unknown"
    fi
}

# Check Rust installation
check_rust() {
    print_info "Checking Rust installation..."

    if ! command_exists cargo; then
        print_error "Rust is not installed!"
        echo ""
        echo "Please install Rust from: https://rustup.rs/"
        echo "Run: curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh"
        echo ""
        exit 1
    fi

    RUST_VERSION=$(rustc --version | awk '{print $2}')
    print_success "Rust ${RUST_VERSION} detected"
}

# Check if we're in the surge directory
check_directory() {
    if [[ ! -f "Cargo.toml" ]] || [[ ! -f "README.md" ]]; then
        print_error "This script must be run from the SURGE project directory"
        echo ""
        echo "Please run:"
        echo "  cd /path/to/surge"
        echo "  ./Scripts/install.sh"
        echo ""
        exit 1
    fi
}

# Build the project
build_release() {
    print_info "Building SURGE in release mode..."
    echo ""

    if cargo build --release 2>&1 | grep -v "warning:" | grep -E "Compiling|Finished|error"; then
        print_success "Build completed successfully"
    else
        print_error "Build failed"
        exit 1
    fi
}

# Install binary
install_binary() {
    local OS=$(detect_os)
    local BINARY_NAME="surge"
    local SOURCE_PATH="./target/release/${BINARY_NAME}"

    print_info "Installing SURGE binary..."

    # Check if binary exists
    if [[ ! -f "$SOURCE_PATH" ]]; then
        print_error "Binary not found at ${SOURCE_PATH}"
        exit 1
    fi

    # Determine installation path
    if [[ -w "/usr/local/bin" ]]; then
        INSTALL_PATH="/usr/local/bin/surge"
        print_info "Installing to /usr/local/bin/surge (system-wide)"
        cp "$SOURCE_PATH" "$INSTALL_PATH"
        chmod +x "$INSTALL_PATH"
    elif [[ -d "$HOME/.cargo/bin" ]]; then
        INSTALL_PATH="$HOME/.cargo/bin/surge"
        print_info "Installing to ~/.cargo/bin/surge (user)"
        cp "$SOURCE_PATH" "$INSTALL_PATH"
        chmod +x "$INSTALL_PATH"
    else
        print_warning "Could not determine installation path"
        echo ""
        echo "Manual installation:"
        echo "  sudo cp ${SOURCE_PATH} /usr/local/bin/surge"
        echo "  sudo chmod +x /usr/local/bin/surge"
        echo ""
        exit 1
    fi

    print_success "Binary installed to ${INSTALL_PATH}"
}

# Create desktop entry (Linux only)
create_desktop_entry() {
    local OS=$(detect_os)

    if [[ "$OS" != "linux" ]]; then
        return
    fi

    print_info "Creating desktop entry..."

    local DESKTOP_DIR="$HOME/.local/share/applications"
    mkdir -p "$DESKTOP_DIR"

    cat > "$DESKTOP_DIR/surge.desktop" <<EOF
[Desktop Entry]
Version=1.0
Type=Application
Name=SURGE
Comment=System Cleaner and Optimizer
Exec=surge
Icon=utilities-system-monitor
Terminal=true
Categories=System;Utility;
Keywords=cleaner;optimizer;disk;cleanup;
EOF

    print_success "Desktop entry created"
}

# Verify installation
verify_installation() {
    print_info "Verifying installation..."

    if command_exists surge; then
        INSTALLED_PATH=$(which surge)
        print_success "SURGE is installed at: ${INSTALLED_PATH}"

        # Show version
        echo ""
        surge --version 2>/dev/null || true
    else
        print_warning "SURGE command not found in PATH"
        echo ""
        echo "Please add the installation directory to your PATH:"
        echo "  export PATH=\"\$HOME/.cargo/bin:\$PATH\""
        echo ""
    fi
}

# Print post-install instructions
print_instructions() {
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    print_success "Installation completed successfully!"
    echo ""
    echo "To run SURGE, use:"
    echo ""
    echo -e "  ${GREEN}surge${NC}                    # Run the application"
    echo -e "  ${GREEN}surge --preview${NC}          # Preview mode (dry-run)"
    echo -e "  ${GREEN}surge --scan ~/Downloads${NC} # Scan specific directory"
    echo -e "  ${GREEN}surge --debug${NC}            # Show debug info on startup"
    echo -e "  ${GREEN}surge --help${NC}             # Show help"
    echo ""
    echo "Keyboard shortcuts:"
    echo "  1-8      Jump to features"
    echo "  ↑↓ j/k   Navigate"
    echo "  PgUp/Dn  Fast scroll"
    echo "  Space    Toggle selection"
    echo "  Enter    Confirm"
    echo "  h/?      Help"
    echo "  q        Quit"
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
}

# Uninstall function
uninstall() {
    print_info "Uninstalling SURGE..."

    # Remove binary
    if [[ -f "/usr/local/bin/surge" ]]; then
        sudo rm /usr/local/bin/surge
        print_success "Removed /usr/local/bin/surge"
    fi

    if [[ -f "$HOME/.cargo/bin/surge" ]]; then
        rm "$HOME/.cargo/bin/surge"
        print_success "Removed ~/.cargo/bin/surge"
    fi

    # Remove desktop entry (Linux)
    if [[ -f "$HOME/.local/share/applications/surge.desktop" ]]; then
        rm "$HOME/.local/share/applications/surge.desktop"
        print_success "Removed desktop entry"
    fi

    print_success "Uninstallation completed"
}

# Main installation flow
main() {
    print_banner

    # Handle uninstall
    if [[ "$1" == "--uninstall" ]] || [[ "$1" == "-u" ]]; then
        uninstall
        exit 0
    fi

    # Show help
    if [[ "$1" == "--help" ]] || [[ "$1" == "-h" ]]; then
        echo "Usage: ./Scripts/install.sh [OPTIONS]"
        echo ""
        echo "Options:"
        echo "  --help, -h        Show this help message"
        echo "  --uninstall, -u   Uninstall SURGE"
        echo ""
        echo "Installation will:"
        echo "  1. Check Rust installation"
        echo "  2. Build SURGE in release mode"
        echo "  3. Install binary to /usr/local/bin or ~/.cargo/bin"
        echo "  4. Make binary executable"
        echo ""
        exit 0
    fi

    # Run installation steps
    check_directory
    check_rust
    build_release
    install_binary
    create_desktop_entry
    verify_installation
    print_instructions
}

# Run main function
main "$@"
