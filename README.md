# SURGE

**System Utility for Reclaiming Gigabytes Efficiently**

A free, open-source system cleaner and optimizer for macOS. SURGE helps you reclaim disk space by safely removing system junk, caches, logs, and unnecessary files.

![Status](https://img.shields.io/badge/status-active%20development-blue)
![Platform](https://img.shields.io/badge/platform-macOS%2013+-lightgrey)
![License](https://img.shields.io/badge/license-GPLv3-green)
![Progress](https://img.shields.io/badge/progress-25%25-yellow)

## Features

### Current (Phases 1-2 Complete) ✅

#### Foundation (Phase 1)
- ✅ **Menu Bar Monitoring** - Real-time CPU, memory, and disk usage
- ✅ **Privileged Helper** - Secure XPC communication with code signature validation
- ✅ **Modern Architecture** - macOS 13+ with SMAppService
- ✅ **Security-First** - Multi-layer validation, quarantine system, audit logging

#### Storage Management (Phase 2)
- ✅ **Smart Care** - One-click system optimization
  - Automatic scan and cleanup
  - Beautiful animated interface
  - Progress visualization
  - Results with system health stats

- ✅ **Storage Cleanup** - Category-based file cleanup
  - System & user caches
  - Log files (system and application)
  - Trash
  - Old downloads
  - Developer junk (Xcode, npm, Yarn, Cargo, Homebrew, CocoaPods, etc.)

- ✅ **Safe Deletion**
  - Preview before cleanup (mandatory)
  - Quarantine system (30-day retention)
  - Age-based protection (<7 days)
  - Multi-layer validation
  - Error reporting with partial success handling

- ✅ **Beautiful UI** - Native macOS design with dark mode support

### Planned (Future Phases)

- 🔄 **Advanced Storage** (Phase 3):
  - TreeMap disk space visualizer
  - Duplicate file finder (SHA-256)
  - Large/old file identification
  - Application uninstaller

- 🔄 **Performance Optimization** (Phase 4):
  - RAM optimization
  - CPU monitoring with per-core stats
  - Startup items management
  - System maintenance scripts

- 🔄 **Security Module** (Phase 5):
  - Malware/adware detection
  - Browser extension scanner
  - Persistence location monitoring

## Screenshots

### Smart Care - One-Click Optimization
```
┌────────────────────────────────────────┐
│  ✨ Smart Care                          │
│                                        │
│     [Animated Progress Circle]         │
│                                        │
│    Scanning system...                  │
│    Finding cleanable files             │
│                                        │
│    [=========>        ] 45%            │
└────────────────────────────────────────┘
```

### Storage Management - Category Browser
```
┌─────────────┬──────────────────────────┐
│ Categories  │ Items Found              │
│             │                          │
│ ✓ System    │ • Safari Cache - 150 MB  │
│ ✓ User      │ • Xcode Data - 2.3 GB    │
│ ✓ Logs      │ • npm Cache - 890 MB     │
│ ✓ Trash     │ • Old Logs - 45 MB       │
│ ✓ Downloads │                          │
│ ✓ Dev Junk  │                          │
│             │                          │
│ 3.4 GB      │                          │
│ 142 items   │                          │
│             │                          │
│ [Review &   │                          │
│  Clean]     │                          │
└─────────────┴──────────────────────────┘
```

## Requirements

- macOS 13.0 (Ventura) or later
- Xcode 15.0 or later (for building)
- Swift 5.9 or later

## Installation

### From Source

```bash
# Clone the repository
git clone https://github.com/yourusername/surge.git
cd surge

# Build the project
./Scripts/setup.sh

# Run SURGE
.build/debug/SURGE
```

### First Launch

On first launch, you'll need to approve the privileged helper:

1. The app will show an installation dialog
2. Open System Settings → General → Login Items
3. Enable "SURGE Helper" under "Allow in the Background"
4. The app will connect automatically

**The helper is required** for SURGE to perform system operations like scanning and deleting files.

## Usage

### Smart Care (One-Click)

1. Click "Smart Care" tab
2. Click "Run Smart Care"
3. Watch as SURGE automatically scans and cleans your system
4. See results with freed space and system stats

### Manual Cleanup

1. Click "Storage" tab
2. Click "Scan" to find cleanable files
3. Select categories you want to clean
4. Click "Review & Clean" to preview items
5. Review the list and click "Clean Now"
6. Files are moved to quarantine (can be restored for 30 days)

### Menu Bar Monitoring

- Always-visible system stats in menu bar
- Click icon for detailed dropdown
- Real-time CPU, memory, and disk usage
- Updates every 3 seconds

## What Gets Cleaned

### System Caches
- `/Library/Caches`
- `/System/Library/Caches`

### User Caches
- `~/Library/Caches` (per-application)

### Log Files
- `/private/var/log`
- `~/Library/Logs`
- `/Library/Logs`

### Trash
- `~/.Trash`

### Downloads
- `~/Downloads` (with file type detection)

### Developer Junk
- Xcode DerivedData and device support
- npm, Yarn, Cargo package caches
- Homebrew, CocoaPods caches
- Gradle, pip caches
- Simulator caches

## Safety Features

SURGE implements **5 layers of protection**:

1. **Code Signature Validation** - Only authorized apps can connect to helper
2. **Path Validation** - System paths are blacklisted and protected
3. **Age Protection** - Files modified in last 7 days are automatically safe
4. **Mandatory Preview** - You must review items before deletion
5. **Quarantine System** - Files kept for 30 days before permanent deletion

### Undo Deletions

All deleted files are moved to a quarantine folder (`/tmp/.SURGE-Quarantine`) and kept for 30 days. You can manually restore them if needed.

## Architecture

```
┌─────────────────────────────────┐
│      Main App (User Space)      │
│  ┌──────────────────────────┐  │
│  │  SwiftUI Views           │  │
│  │  ViewModels              │  │
│  │  XPC Client              │  │
│  └──────────────────────────┘  │
└────────────┬────────────────────┘
             │ XPC (Secure)
             │ • Code signature validation
             │ • Input sanitization
┌────────────┴────────────────────┐
│  Privileged Helper (Root)       │
│  ┌──────────────────────────┐  │
│  │  XPC Server              │  │
│  │  System Operations       │  │
│  │  Security Validation     │  │
│  └──────────────────────────┘  │
└─────────────────────────────────┘
```

- **Main App**: SwiftUI interface running in user space
- **Privileged Helper**: Root daemon for system operations
- **XPC**: Secure inter-process communication
- **Security**: Multi-layer validation and sanitization

See [ARCHITECTURE.md](Documentation/ARCHITECTURE.md) for detailed technical documentation.

## Development

### Building

```bash
# Debug build
swift build

# Release build
swift build -c release

# Run tests
swift test

# Open in Xcode
open Package.swift
```

### Project Structure

```
SURGE/
├── Sources/
│   ├── SURGE/              # Main app
│   ├── PrivilegedHelper/   # Root daemon
│   └── Shared/             # XPC protocol
├── Tests/
├── Documentation/
├── Scripts/
└── Package.swift
```

### Contributing

We welcome contributions! Please see [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines.

**Good first issues:**
- Documentation improvements
- UI polish
- Test additions
- Bug fixes

## Status

🚧 **Active Development** - Phases 1-2 complete (Foundation + Storage Management)

**Current Progress: 25%** (2 of 8 phases)
- ✅ Phase 1: Foundation
- ✅ Phase 2: Storage Management Core
- 🔄 Phase 3: Advanced Storage (Next)
- ⬜ Phase 4: Performance Optimization
- ⬜ Phase 5: Security Module
- ⬜ Phase 6: Smart Care & Polish
- ⬜ Phase 7: Testing & Hardening
- ⬜ Phase 8: Release Preparation

**Ready for testing!** SURGE can now scan and safely clean up system junk.

## Roadmap

### Phase 3: Advanced Storage (Next - 3 weeks)
- TreeMap disk visualizer
- Duplicate file finder
- Large/old file identification
- Application uninstaller

### Phase 4: Performance (3 weeks)
- RAM optimization
- CPU monitoring
- Startup items manager
- Maintenance scripts

### Phase 5: Security (3 weeks)
- Malware scanner
- Community malware database
- Browser extension scanner

### Phase 6-8: Polish, Testing, Release (7 weeks)
- UI refinement
- Comprehensive testing
- Code signing
- Notarization
- Distribution

## Documentation

- [Architecture](Documentation/ARCHITECTURE.md) - Technical architecture
- [Contributing](CONTRIBUTING.md) - Contribution guidelines
- [Getting Started](GETTING_STARTED.md) - Developer guide
- [Phase 1 Complete](Documentation/PHASE1_COMPLETE.md)
- [Phase 2 Complete](Documentation/PHASE2_COMPLETE.md)
- [Changelog](CHANGELOG.md) - Version history

## License

This project is licensed under the GNU General Public License v3.0 - see the [LICENSE](LICENSE) file for details.

GPLv3 ensures that this software and all derivatives remain free and open-source.

## Support

- **Issues**: [GitHub Issues](https://github.com/yourusername/surge/issues)
- **Discussions**: [GitHub Discussions](https://github.com/yourusername/surge/discussions)
- **Security**: Report security issues privately to security@example.com

## Acknowledgments

- Inspired by CleanMyMac by MacPaw
- Security patterns from [Objective-See](https://objective-see.com/) tools
- Built with Swift, SwiftUI, and a security-first mindset

## Disclaimer

This software is provided "as is" without warranty. Always backup your data before using system cleaning tools. The developers are not responsible for any data loss or system damage.

---

**SURGE** - Free up gigabytes on your Mac, safely and efficiently.

⭐ Star this repository if you find it useful!
