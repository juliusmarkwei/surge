# SURGE v1.0 - Terminal TUI System Cleaner

<div align="center">

**Cross-platform system cleaner and optimizer for macOS and Linux**

[![Rust](https://img.shields.io/badge/rust-1.93%2B-orange.svg)](https://www.rust-lang.org/)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Platform](https://img.shields.io/badge/platform-macOS%20%7C%20Linux-lightgrey.svg)]()

</div>

## Overview

SURGE is a powerful, interactive terminal-based system cleaner built with Rust. It provides real-time scanning, visualization, and cleanup of your system storage with a rich Terminal User Interface (TUI).

**Key Features:**
- 🚀 Real-time storage scanning and cleanup
- 📊 Interactive disk usage visualization (TreeMap)
- 🔍 File preview with support for text, images, videos, audio
- 🔒 Multi-layer security validation
- 🎨 Beautiful terminal UI with fast navigation
- 🌍 Cross-platform (macOS + Linux)
- ⚡ High performance with async scanning
- ⌨️ Vim-style keyboard shortcuts

## Quick Install

```bash
curl -fsSL https://raw.githubusercontent.com/juliusmarkwei/surge/main/install.sh | bash
```

Run SURGE:
```bash
surge
```

See [Installation](#installation) for more options.

## Technology Stack

- **Rust** - Systems programming language for performance and safety
- **Ratatui 0.26** - Terminal UI framework with rich widgets
- **Crossterm 0.27** - Cross-platform terminal control
- **Tokio 1.35** - Async runtime for concurrent scanning
- **sysinfo 0.30** - Cross-platform system information

## Features

### ✅ Implemented Features

#### Storage Cleanup
Interactive category-based cleanup with real-time scanning:
- System Caches (`/Library/Caches`, `/System/Library/Caches`)
- User Caches (`~/Library/Caches`)
- Log Files (`/var/log`, `~/Library/Logs`)
- Trash (`~/.Trash`)
- Downloads (`~/Downloads`)
- Developer Caches (npm, yarn, cargo, gradle, Xcode)
- Browser Data (Chrome, Firefox, Safari)
- File selection with Space, a (all), n (none)
- Preview before deletion
- Sort by size (s key)

#### Disk TreeMap
Visual disk usage analyzer with interactive navigation:
- Recursive directory scanning with depth limiting
- Real-time size calculation and visualization
- Navigate directories with Enter/Esc
- File preview panel (toggle with 'p')
- Text file preview (code, logs, subtitles)
- Image metadata display
- Video/Audio file information
- Open files with system default app ('o' key)
- Fast navigation (PageUp/PageDown, Ctrl+U/D)

#### Performance Monitor
Real-time system statistics in status bar:
- CPU usage percentage
- RAM usage (used/total with percentage)
- Disk usage (used/total with percentage)
- Updates every 100ms

### 🚧 Planned Features

The following features are planned for future releases:
- Smart Care - One-click optimization
- Duplicate Finder - SHA-256 content-based detection
- Large/Old File Scanner - Find files by size and age
- Security Scanner - Malware detection
- System Maintenance - Spotlight rebuild, DNS cache clear

## Security Model

SURGE implements **five layers of security**:

### 1. Path Validation & Sanitization
- Blacklisted system directories (never deletable)
- Whitelist validation for safe paths
- Path traversal attack prevention
- Symlink resolution and canonicalization

### 2. Age-Based Protection
- Files modified in the last 7 days are protected
- Prevents deletion of actively used files

### 3. Quarantine System
- Files moved to `/tmp/.SURGE-Quarantine` instead of immediate deletion
- 30-day retention period for recovery
- Timestamped filenames for tracking

### 4. Privilege Separation
- No persistent root daemon required
- Uses `sudo` for one-shot operations when needed
- User-level operations don't require elevation

### 5. Mandatory Preview
- Users must review files before cleanup
- No automatic deletion without confirmation

**Blacklisted Paths (Never Deleted):**
```
/System, /bin, /sbin, /usr/bin, /usr/sbin, /etc, /dev
/Library/Apple, /Library/Frameworks, /var
~/Documents, ~/Desktop, ~/Pictures, ~/Music
```

## Installation

### Quick Install (Recommended)

```bash
curl -fsSL https://raw.githubusercontent.com/juliusmarkwei/surge/main/install.sh | bash
```

This one-liner will:
- ✅ Check prerequisites (Git, Rust)
- ✅ Clone repository to `~/.surge`
- ✅ Build SURGE in release mode
- ✅ Install binary to `/usr/local/bin` or `~/.cargo/bin`
- ✅ Create desktop entry (Linux only)
- ✅ Verify installation

**Uninstall:**
```bash
curl -fsSL https://raw.githubusercontent.com/juliusmarkwei/surge/main/install.sh | bash -s -- --uninstall
```

This removes:
- ✅ Binary from `/usr/local/bin/surge` or `~/.cargo/bin/surge`
- ✅ Desktop entry (Linux)
- ✅ Source directory `~/.surge` (with confirmation)

### Alternative: From Source

```bash
# Clone the repository
git clone https://github.com/juliusmarkwei/surge.git
cd surge

# Run the installation script
./install.sh
```

### Manual Installation

```bash
# Clone the repository
git clone https://github.com/juliusmarkwei/surge.git
cd surge

# Build with Cargo
cargo build --release

# Install manually
sudo cp target/release/surge /usr/local/bin/surge
sudo chmod +x /usr/local/bin/surge

# Run
surge
```

### Using Cargo (Future)

```bash
# Once published to crates.io
cargo install surge
```

## Usage

### Quick Start

```bash
# Run the application
surge

# Preview mode (dry-run, no deletion)
surge --preview

# Scan a specific directory
surge --scan ~/Downloads

# Enable debug logging
surge --debug
```

### Keyboard Shortcuts

**Navigation:**
- `↑↓` or `j/k` - Move up/down one item
- `PageUp/PageDown` - Jump 10 items (fast navigation)
- `Ctrl+U/Ctrl+D` - Jump 5 items (medium navigation)
- `g` or `Home` - Go to home screen
- `1-6` - Jump to feature screen
- `Esc` - Go back one level
- `q` - Quit application

**Selection (Storage Cleanup):**
- `Space` - Toggle item selection
- `a` - Select all items
- `n` - Select none
- `s` - Sort by size (cycle: default → largest → smallest)

**TreeMap Actions:**
- `Enter` - Enter directory / Open file
- `o` - Open file with system default app
- `p` - Toggle preview panel
- `Esc` - Go back to parent directory

**Global:**
- `h` or `?` - Show help screen
- `Enter` - Confirm action / Start scan
- `d` - Delete selected items (Storage Cleanup)

### Example Workflows

**Storage Cleanup:**
1. **Launch SURGE**: `surge`
2. **Navigate to Storage Cleanup**: Press `2`
3. **Start Scanning**: Press `Enter`
4. **Review Items**: Use `↑↓` or `PageUp/PageDown` to navigate
5. **Select Items**: Press `Space` to toggle or `a` to select all
6. **Sort (optional)**: Press `s` to sort by size
7. **Confirm Deletion**: Press `Enter`
8. **Recovery**: Items are in `/tmp/.SURGE-Quarantine` for 30 days

**Disk TreeMap:**
1. **Launch SURGE**: `surge`
2. **Navigate to Disk TreeMap**: Press `3`
3. **Browse Directories**: Press `Enter` to enter, `Esc` to go back
4. **Fast Navigation**: Use `PageUp/PageDown` to jump quickly
5. **Toggle Preview**: Press `p` to show/hide file preview
6. **Open Files**: Press `o` to open with system default app
7. **Go Home**: Press `g` to return to main menu

## Project Structure

```
surge/
├── src/
│   ├── main.rs                    # Entry point, event loop
│   ├── app/
│   │   └── state.rs               # App state machine
│   ├── ui/
│   │   ├── screens/               # 10 screens (home, cleanup, etc.)
│   │   └── widgets/               # Reusable widgets
│   ├── scanner/
│   │   └── cleanup.rs             # Category scanning
│   ├── operations/
│   │   └── delete.rs              # File deletion (sudo when needed)
│   ├── security/
│   │   ├── sanitizer.rs           # Path validation
│   │   └── blacklist.rs           # Protected paths
│   ├── system/
│   │   └── stats.rs               # CPU/RAM/Disk monitoring
│   └── models/                    # Data structures
└── tests/
```

## Development

### Building

```bash
# Development build
cargo build

# Release build (optimized)
cargo build --release

# Run tests
cargo test

# Run with logging
RUST_LOG=debug cargo run
```

### Testing

```bash
# Run all tests
cargo test

# Run specific test
cargo test sanitizer

# Run with output
cargo test -- --nocapture
```

## Platform-Specific Notes

### macOS
- User caches: `~/Library/Caches`
- System caches: `/Library/Caches`, `/System/Library/Caches`
- Logs: `/private/var/log`, `~/Library/Logs`
- Trash: `~/.Trash`

### Linux
- User caches: `~/.cache`
- System caches: `/var/cache`
- Logs: `/var/log`
- Trash: `~/.local/share/Trash`

## Architecture Highlights

### Core Features
- ✅ Cross-platform support (macOS + Linux)
- ✅ Terminal-based interactive UI
- ✅ Real-time scanning with progress
- ✅ Simple privilege model (sudo for one-shot operations)
- ✅ Async scanning with Tokio

### Security Features
- ✅ Path sanitization & security validation
- ✅ Age-based protection (7-day rule)
- ✅ Quarantine system (30-day retention)
- ✅ Multi-layer security checks
- ✅ Blacklist/whitelist system

## Roadmap

### ✅ Completed (v1.0)
- [x] Project structure and Rust TUI framework
- [x] Security modules (sanitizer, blacklist, quarantine)
- [x] Interactive home screen with navigation
- [x] Real-time system stats monitoring
- [x] Storage cleanup with category scanning
- [x] File selection UI with preview
- [x] TreeMap visualization with interactive navigation
- [x] File preview panel (text, images, videos, audio)
- [x] Fast navigation (PageUp/PageDown, Ctrl+U/D)
- [x] One-liner installation script
- [x] Cross-platform support (macOS + Linux)
- [x] Help system
- [x] Documentation

### 🚧 In Progress
- [ ] Delete operations with sudo integration
- [ ] Quarantine implementation
- [ ] Error recovery and handling

### 📋 Planned Features
- [ ] Smart Care - One-click optimization
- [ ] Duplicate finder (SHA-256 content hashing)
- [ ] Large/old file scanner (size and age filters)
- [ ] Security scanner with malware signatures
- [ ] System maintenance tasks (Spotlight, DNS cache)
- [ ] Configuration file support
- [ ] Export functionality (CSV, JSON reports)

### 🎯 Future Enhancements
- [ ] Package for distribution (AUR, Homebrew)
- [ ] Colorized themes
- [ ] Plugin system for custom scanners
- [ ] Scheduled scans (cron integration)

## Contributing

Contributions are welcome! Please see [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines.

## License

MIT License - see [LICENSE](LICENSE) for details.

## Acknowledgments

- Inspired by [npkill](https://github.com/voidcosmos/npkill) for real-time scanning UI
- Built with [Ratatui](https://github.com/ratatui-org/ratatui) for the awesome TUI framework

---

**Note:** SURGE is a powerful cross-platform system cleaner built with Rust, featuring a terminal-based interface with comprehensive security features for safe system maintenance.
