# SURGE v2.0 - Terminal TUI System Cleaner

<div align="center">

**Cross-platform system cleaner and optimizer for macOS and Linux**

[![Rust](https://img.shields.io/badge/rust-1.93%2B-orange.svg)](https://www.rust-lang.org/)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Platform](https://img.shields.io/badge/platform-macOS%20%7C%20Linux-lightgrey.svg)]()

</div>

## Overview

SURGE is a powerful, interactive terminal-based system cleaner built with Rust. It provides real-time scanning, visualization, and cleanup of your system storage with a rich Terminal User Interface (TUI).

**Key Features:**
- 🚀 Real-time storage scanning (like npkill)
- 🔒 Multi-layer security validation
- 🗑️ 30-day quarantine system for safe recovery
- 🎨 Interactive TUI with keyboard navigation
- 🌍 Cross-platform (macOS + Linux)
- ⚡ High performance with async scanning
- 🛡️ Built-in malware detection

## Technology Stack

- **Rust** - Systems programming language for performance and safety
- **Ratatui 0.26** - Terminal UI framework with rich widgets
- **Crossterm 0.27** - Cross-platform terminal control
- **Tokio 1.35** - Async runtime for concurrent scanning
- **sysinfo 0.30** - Cross-platform system information

## Features

### 1. Smart Care
One-click optimization for common system cleanup tasks.

### 2. Storage Cleanup
Category-based cleanup with real-time scanning:
- System Caches (`/Library/Caches`, `/System/Library/Caches`)
- User Caches (`~/Library/Caches`)
- Log Files (`/var/log`, `~/Library/Logs`)
- Trash (`~/.Trash`)
- Downloads (`~/Downloads`)
- Developer Caches (npm, yarn, cargo, gradle, Xcode)
- Browser Data (Chrome, Firefox, Safari)

### 3. Disk TreeMap
Visual disk usage analyzer showing directory sizes recursively.

### 4. Duplicate Finder
SHA-256 content-based duplicate file detection.

### 5. Large/Old File Scanner
Find files larger than 100MB or older than 1 year.

### 6. Performance Monitor
Real-time CPU, RAM, and disk usage monitoring.

### 7. Security Scanner
Signature-based malware detection for persistence locations.

### 8. System Maintenance
Spotlight rebuild, DNS cache clear, and other maintenance tasks.

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
- No persistent root daemon (unlike v1.0)
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

### From Source

```bash
# Clone the repository
git clone https://github.com/yourusername/surge-tui.git
cd surge-tui

# Build with Cargo
cargo build --release

# Run
./target/release/surge-tui
```

### Using Cargo

```bash
cargo install surge-tui
```

## Usage

### Quick Start

```bash
# Run the application
surge-tui

# Preview mode (dry-run, no deletion)
surge-tui --preview

# Scan a specific directory
surge-tui --scan ~/Downloads

# Enable debug logging
surge-tui --debug
```

### Keyboard Shortcuts

**Navigation:**
- `↑↓` or `j/k` - Move up/down in lists
- `←→` or `l` - Move left/right (tabs)
- `1-8` - Jump to feature screen
- `Esc` - Go back / Cancel
- `q` - Quit application

**Selection:**
- `Space` - Toggle item selection
- `a` - Select all items
- `n` - Select none

**Actions:**
- `Enter` - Confirm action / Start scan
- `d` - Delete selected items
- `h` or `?` - Show help screen

### Example Workflow

1. **Launch SURGE**: `surge-tui`
2. **Navigate to Storage Cleanup**: Press `2`
3. **Start Scanning**: Press `Enter`
4. **Review Items**: Use `↑↓` to navigate
5. **Select Items**: Press `Space` to toggle or `a` to select all
6. **Confirm Deletion**: Press `Enter`
7. **Recovery**: Items are in `/tmp/.SURGE-Quarantine` for 30 days

## Project Structure

```
surge-tui/
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

## Differences from v1.0 (SwiftUI)

### Removed
- ❌ XPC client-server architecture
- ❌ Persistent privileged helper daemon
- ❌ Code signature validation
- ❌ macOS-only support

### Added
- ✅ Cross-platform support (macOS + Linux)
- ✅ Terminal-based interactive UI
- ✅ Real-time scanning with progress
- ✅ Simpler privilege model (sudo for one-shot operations)
- ✅ Async scanning with Tokio

### Preserved
- ✅ Path sanitization & security validation
- ✅ Age-based protection (7-day rule)
- ✅ Quarantine system (30-day retention)
- ✅ All 7 major features
- ✅ Blacklist/whitelist system

## Roadmap

### Phase 1: Foundation ✅
- [x] Project structure
- [x] Security modules (sanitizer, blacklist)
- [x] Basic TUI with home screen
- [x] System stats monitoring

### Phase 2: Core Cleanup (Next)
- [ ] Real-time category scanning
- [ ] File selection UI
- [ ] Delete with sudo integration
- [ ] Quarantine implementation

### Phase 3: Advanced Features
- [ ] TreeMap visualization
- [ ] Duplicate finder (SHA-256)
- [ ] Large/old file scanner
- [ ] Performance monitoring

### Phase 4: Security & Maintenance
- [ ] Malware scanner with signatures
- [ ] Maintenance tasks
- [ ] Help system
- [ ] Error recovery

### Phase 5: Polish
- [ ] Cross-platform testing
- [ ] Performance optimization
- [ ] Package for distribution
- [ ] Documentation

## Contributing

Contributions are welcome! Please see [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines.

## License

MIT License - see [LICENSE](LICENSE) for details.

## Acknowledgments

- Inspired by [npkill](https://github.com/voidcosmos/npkill) for real-time scanning UI
- Built with [Ratatui](https://github.com/ratatui-org/ratatui) for the awesome TUI framework
- Original SURGE v1.0 SwiftUI implementation for feature inspiration

---

**Note:** SURGE v2.0 is a complete rewrite from Swift/SwiftUI to Rust with a terminal-based interface. All core security features have been preserved and enhanced for cross-platform support.
