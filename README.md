# SURGE v1.0 - Terminal System Cleaner

<div align="center">

**Cross-platform system cleaner and optimizer for macOS and Linux**

[![Rust](https://img.shields.io/badge/rust-1.93%2B-orange.svg)](https://www.rust-lang.org/)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Platform](https://img.shields.io/badge/platform-macOS%20%7C%20Linux-lightgrey.svg)]()

</div>

## Overview

SURGE is a powerful, interactive terminal-based system cleaner built with Rust. Clean up your system storage with a beautiful TUI interface, real-time scanning, and built-in security features.

**Features:**
- 🚀 Real-time storage scanning and cleanup
- 📊 Interactive disk usage visualization (TreeMap)
- 🔍 File preview (text, images, videos, audio)
- 🔒 Multi-layer security validation
- 🎨 Beautiful terminal UI with vim-style navigation
- 🌍 Cross-platform (macOS + Linux)

## Quick Install

```bash
curl -fsSL https://raw.githubusercontent.com/juliusmarkwei/surge/main/install.sh | bash
```

Then run:
```bash
surge
```

**Uninstall:**
```bash
curl -fsSL https://raw.githubusercontent.com/juliusmarkwei/surge/main/install.sh | bash -s -- --uninstall
```

## Usage

```bash
surge                            # Run SURGE
surge --preview                  # Preview mode (dry-run, no deletion)
surge --scan ~/Downloads         # Scan specific directory
surge --debug                    # Show debug information on startup
surge --debug --scan ~/Projects  # Combine options
surge --help                     # Show help
```

### Navigation

- `1-2` - Jump to features (Storage Cleanup, Disk TreeMap)
- `↑↓` or `j/k` - Navigate
- `PageUp/PageDown` - Fast scroll
- `Space` - Toggle selection
- `Enter` - Confirm/Open
- `p` - Toggle preview (TreeMap only)
- `s` - Sort
- `g` - Go home
- `h/?` - Help
- `q` - Quit

## Current Features

### ✅ Available Now
- **Storage Cleanup** - Scan and clean system/user caches, logs, trash, downloads, developer caches
- **Disk TreeMap** - Visual disk usage analyzer with interactive navigation and file preview

### 🚧 Coming Soon
- **Duplicate Finder** - SHA-256 based duplicate file detection with smart selection
- **Large Files** - Find large and old files with configurable size/age filters
- **Performance Monitor** - Real-time CPU, RAM, and disk usage optimization
- **Security Scanner** - Malware detection and removal
- **Smart Care** - One-click system optimization

## Security

SURGE is designed with safety first:

- ✅ **Read-only operations** (deletion not yet implemented)
- ✅ **Path validation** - System directories are blacklisted
- ✅ **Age protection** - Files modified in last 7 days protected
- ✅ **Preview required** - No automatic deletion
- ✅ **Open source** - All code auditable on GitHub

**Protected paths:** `/System`, `/bin`, `/usr/bin`, `/Library`, `~/Documents`, `~/Desktop`, `~/Pictures`, `~/Music`

## Development

```bash
# Clone
git clone https://github.com/juliusmarkwei/surge.git
cd surge

# Build
cargo build --release

# Run
cargo run
```

## Contributing

Contributions welcome! See [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines.

## License

MIT License - see [LICENSE](LICENSE) for details.

## Links

- **Repository:** https://github.com/juliusmarkwei/surge
- **Issues:** https://github.com/juliusmarkwei/surge/issues
- **Quick Start:** See [QUICKSTART.md](QUICKSTART.md)

---

Built with ❤️ using [Rust](https://www.rust-lang.org/) and [Ratatui](https://github.com/ratatui-org/ratatui)
