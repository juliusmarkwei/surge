#!/bin/bash

# SURGE v1.0 - Installation Script
# One-liner install: curl -fsSL https://raw.githubusercontent.com/juliusmarkwei/surge/main/install.sh | bash

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Configuration
REPO_URL="https://github.com/juliusmarkwei/surge.git"
INSTALL_DIR="$HOME/.surge"
BINARY_NAME="surge"

# Print colored output
print_info() {
    echo -e "${BLUE}==>${NC} $1"
}

print_success() {
    echo -e "${GREEN}✓${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

print_error() {
    echo -e "${RED}✗${NC} $1"
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

# Check prerequisites
check_prerequisites() {
    local missing_deps=()

    print_info "Checking prerequisites..."

    # Check Git
    if ! command_exists git; then
        missing_deps+=("git")
    fi

    # Check Rust/Cargo
    if ! command_exists cargo; then
        missing_deps+=("rust")
    fi

    if [ ${#missing_deps[@]} -ne 0 ]; then
        print_error "Missing required dependencies: ${missing_deps[*]}"
        echo ""
        echo "Please install:"
        for dep in "${missing_deps[@]}"; do
            case $dep in
                git)
                    echo "  • Git: https://git-scm.com/downloads"
                    ;;
                rust)
                    echo "  • Rust: curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh"
                    ;;
            esac
        done
        echo ""
        exit 1
    fi

    print_success "All prerequisites met"
}

# Clone or update repository
setup_repository() {
    print_info "Setting up SURGE repository..."

    if [ -d "$INSTALL_DIR" ]; then
        print_info "Repository exists, updating..."
        cd "$INSTALL_DIR"
        git fetch origin main >/dev/null 2>&1 || true
        git reset --hard origin/main >/dev/null 2>&1 || true
        print_success "Repository updated"
    else
        print_info "Cloning repository..."
        git clone "$REPO_URL" "$INSTALL_DIR" >/dev/null 2>&1
        cd "$INSTALL_DIR"
        print_success "Repository cloned to $INSTALL_DIR"
    fi
}

# Build the project
build_release() {
    print_info "Building SURGE (this may take a few minutes)..."

    cd "$INSTALL_DIR"

    # Build and suppress warnings, only show errors and progress
    if ! cargo build --release 2>&1 | grep -v "warning:" | grep -E "Compiling|Finished|error" > /tmp/surge-build.log; then
        if grep -q "error" /tmp/surge-build.log; then
            print_error "Build failed"
            echo ""
            cat /tmp/surge-build.log
            echo ""
            echo "Please check the error above and try again."
            echo "You can manually build by running:"
            echo "  cd $INSTALL_DIR"
            echo "  cargo build --release"
            exit 1
        fi
    fi

    print_success "Build completed successfully"
}

# Install binary
install_binary() {
    print_info "Installing SURGE binary..."

    local SOURCE_PATH="$INSTALL_DIR/target/release/surge"
    local INSTALL_PATH=""

    # Check if binary exists
    if [[ ! -f "$SOURCE_PATH" ]]; then
        print_error "Binary not found at ${SOURCE_PATH}"
        exit 1
    fi

    # Try to install to /usr/local/bin first (requires sudo)
    if [[ -w "/usr/local/bin" ]]; then
        INSTALL_PATH="/usr/local/bin/$BINARY_NAME"
        cp "$SOURCE_PATH" "$INSTALL_PATH"
        chmod +x "$INSTALL_PATH"
        print_success "Installed to /usr/local/bin/$BINARY_NAME"
    elif command_exists sudo; then
        INSTALL_PATH="/usr/local/bin/$BINARY_NAME"
        print_info "Installing to /usr/local/bin (requires sudo)..."
        sudo mkdir -p /usr/local/bin
        sudo cp "$SOURCE_PATH" "$INSTALL_PATH"
        sudo chmod +x "$INSTALL_PATH"
        print_success "Installed to /usr/local/bin/$BINARY_NAME"
    elif [[ -d "$HOME/.cargo/bin" ]]; then
        INSTALL_PATH="$HOME/.cargo/bin/$BINARY_NAME"
        cp "$SOURCE_PATH" "$INSTALL_PATH"
        chmod +x "$INSTALL_PATH"
        print_success "Installed to ~/.cargo/bin/$BINARY_NAME"
    else
        print_error "Could not determine installation path"
        echo ""
        echo "Please manually install:"
        echo "  sudo cp $SOURCE_PATH /usr/local/bin/$BINARY_NAME"
        exit 1
    fi
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
Keywords=cleaner;optimizer;disk;cleanup;system;
EOF

    print_success "Desktop entry created"
}

# Setup shell completion (optional)
setup_shell_completion() {
    local SHELL_NAME=$(basename "$SHELL")

    case $SHELL_NAME in
        bash)
            if [ -d "$HOME/.bash_completion.d" ]; then
                echo "complete -C surge surge" > "$HOME/.bash_completion.d/surge"
            fi
            ;;
        zsh)
            if [ -d "$HOME/.zsh/completion" ]; then
                echo "compdef _gnu_generic surge" > "$HOME/.zsh/completion/_surge"
            fi
            ;;
    esac
}

# Verify installation
verify_installation() {
    print_info "Verifying installation..."

    if command_exists surge; then
        INSTALLED_PATH=$(which surge)
        print_success "SURGE installed at: ${INSTALLED_PATH}"

        # Test if it runs
        if surge --version >/dev/null 2>&1; then
            print_success "Installation verified successfully"
        fi
    else
        print_warning "SURGE command not found in PATH"
        echo ""
        echo "Please add one of these to your PATH:"
        echo "  export PATH=\"/usr/local/bin:\$PATH\""
        echo "  export PATH=\"\$HOME/.cargo/bin:\$PATH\""
        echo ""
        echo "Add the line to your shell config (~/.bashrc, ~/.zshrc, etc.)"
    fi
}

# Print post-install instructions
print_instructions() {
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    print_success "SURGE v1.0 installed successfully!"
    echo ""
    echo -e "${GREEN}Quick Start:${NC}"
    echo ""
    echo "  surge                    # Run SURGE"
    echo "  surge --preview          # Preview mode (dry-run)"
    echo "  surge --scan ~/Downloads # Scan specific directory"
    echo "  surge --debug            # Show debug info on startup"
    echo "  surge --help             # Show help"
    echo ""
    echo -e "${CYAN}Keyboard Shortcuts:${NC}"
    echo ""
    echo "  Navigation              Actions"
    echo "  ────────────────────   ─────────────────"
    echo "  1-8        Features    Space    Toggle"
    echo "  ↑↓ j/k     Move        Enter    Confirm"
    echo "  PgUp/PgDn  Fast        a        Select all"
    echo "  Ctrl+U/D   Jump        n        Select none"
    echo "  g          Home        d        Delete"
    echo "  h/?        Help        q        Quit"
    echo ""
    echo -e "${CYAN}Features:${NC}"
    echo ""
    echo "  • Storage Cleanup      - Clean system & user caches"
    echo "  • Disk TreeMap         - Visual disk usage analyzer"
    echo "  • Duplicate Finder     - Find duplicate files"
    echo "  • Large Files          - Find large/old files"
    echo "  • Performance Monitor  - CPU/RAM/Disk stats"
    echo "  • Security Scanner     - Malware detection"
    echo ""
    echo -e "${CYAN}Documentation:${NC}"
    echo ""
    echo "  $INSTALL_DIR/README.md"
    echo "  $INSTALL_DIR/QUICKSTART.md"
    echo ""
    echo -e "${CYAN}Repository:${NC}"
    echo ""
    echo "  $REPO_URL"
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
}

# Uninstall function
uninstall() {
    print_info "Uninstalling SURGE..."

    # Remove binaries
    if [[ -f "/usr/local/bin/$BINARY_NAME" ]]; then
        if [[ -w "/usr/local/bin" ]]; then
            rm "/usr/local/bin/$BINARY_NAME"
        else
            sudo rm "/usr/local/bin/$BINARY_NAME"
        fi
        print_success "Removed /usr/local/bin/$BINARY_NAME"
    fi

    if [[ -f "$HOME/.cargo/bin/$BINARY_NAME" ]]; then
        rm "$HOME/.cargo/bin/$BINARY_NAME"
        print_success "Removed ~/.cargo/bin/$BINARY_NAME"
    fi

    # Remove desktop entry (Linux)
    if [[ -f "$HOME/.local/share/applications/surge.desktop" ]]; then
        rm "$HOME/.local/share/applications/surge.desktop"
        print_success "Removed desktop entry"
    fi

    # Ask about removing source
    echo ""
    read -p "Remove source directory ($INSTALL_DIR)? [y/N] " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        rm -rf "$INSTALL_DIR"
        print_success "Removed $INSTALL_DIR"
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
        echo "SURGE v1.0 - Installation Script"
        echo ""
        echo "Usage:"
        echo "  curl -fsSL https://raw.githubusercontent.com/juliusmarkwei/surge/main/install.sh | bash"
        echo ""
        echo "Options:"
        echo "  bash -s -- --help        Show this help"
        echo "  bash -s -- --uninstall   Uninstall SURGE"
        echo ""
        echo "What this script does:"
        echo "  1. Checks for Git and Rust"
        echo "  2. Clones/updates SURGE repository to ~/.surge"
        echo "  3. Builds release binary"
        echo "  4. Installs to /usr/local/bin or ~/.cargo/bin"
        echo "  5. Creates desktop entry (Linux)"
        echo ""
        exit 0
    fi

    # Run installation steps
    check_prerequisites
    setup_repository
    build_release
    install_binary
    create_desktop_entry
    setup_shell_completion
    verify_installation
    print_instructions
}

# Run main function with all arguments
main "$@"
