# Changelog

All notable changes to SURGE will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Phase 2: Storage Management Core (2026-01-26)

#### Added
- **Smart Care** - One-click system optimization
  - Automatic scan and cleanup
  - Progress visualization with animations
  - Results display with system health stats
  - Beautiful native macOS interface

- **Storage Management** - Full cleanup functionality
  - Category-based file browser (6 categories)
  - Real-time size calculation and item counts
  - Sortable items list with detailed info
  - Preview sheet before cleanup (safety first!)
  - Results sheet with success/error reporting
  - Progress indicators during scan and cleanup

- **Enhanced System Cleaner**
  - Extended scanning locations (14+ paths)
  - Intelligent developer tool detection
  - Per-app cache identification
  - Improved file descriptions
  - Better hidden file handling

- **Cleanup Categories**
  - System Caches (`/Library/Caches`, `/System/Library/Caches`)
  - User Caches (`~/Library/Caches`)
  - Log Files (`/var/log`, `~/Library/Logs`, `/Library/Logs`)
  - Trash (`~/.Trash`)
  - Downloads (`~/Downloads`)
  - Developer Junk (Xcode, npm, Yarn, Cargo, Homebrew, CocoaPods, etc.)

- **Safety Features**
  - Mandatory preview before deletion
  - Quarantine system (30-day retention)
  - Age-based file protection (<7 days)
  - Error reporting and partial success handling
  - Cancel at any stage

- **Tests**
  - CleanupCoordinator unit tests
  - Category selection tests
  - Size calculation tests

#### Changed
- Enhanced `SystemCleaner` with better scanning logic
- Improved file descriptions based on type and location
- Updated main window to use new Storage and Smart Care views

#### Technical
- Added `CleanupCoordinator` for orchestration
- Created `StorageViewModel` and `SmartCareViewModel`
- Implemented SwiftUI sheets for modal interactions
- Added byte count formatter utilities
- Extended XPC protocol usage

### Phase 1: Foundation (2026-01-26)

#### Added
- Initial project structure with Swift Package Manager
- Main application with menu bar integration
- Privileged helper daemon with SMAppService
- Secure XPC communication with code signature validation
- Real-time system monitoring (CPU, RAM, Disk)
- Security-first architecture:
  - Code signature validation
  - Input sanitization
  - Path traversal prevention
  - Whitelist/blacklist system
- Menu bar app with live stats
- Main window with tabbed interface
- Settings panel
- Helper installation flow with System Settings guidance

#### Security
- Multi-layer validation for all privileged operations
- Protected system paths cannot be modified
- Age-based file protection
- Quarantine instead of immediate deletion
- Comprehensive audit logging

#### Documentation
- README with project overview
- ARCHITECTURE documentation
- CONTRIBUTING guidelines
- Getting Started guide
- Phase 1 completion report

#### Tests
- Input sanitizer security tests
- Path validation tests

## Version History

### [0.2.0] - Phase 2 Complete - 2026-01-26
Storage Management Core implementation

### [0.1.0] - Phase 1 Complete - 2026-01-26
Foundation architecture and infrastructure

---

## Upcoming

### Phase 3: Advanced Storage (Target: 3 weeks)
- TreeMap disk space visualizer
- Duplicate file finder (SHA-256)
- Large/old file identification
- Application uninstaller

### Phase 4: Performance Optimization (Target: 3 weeks)
- RAM optimization
- CPU monitoring per-core
- Startup items manager
- Maintenance scripts

### Phase 5: Security Module (Target: 3 weeks)
- Malware scanner
- Community malware database
- Browser extension scanner
- Persistence location monitoring

### Phase 6: Smart Care & Polish (Target: 3 weeks)
- Enhanced Smart Care
- UI refinement
- Onboarding flow
- Comprehensive error handling

### Phase 7: Testing & Hardening (Target: 2 weeks)
- 80%+ test coverage
- Security audit
- Performance benchmarks
- Beta testing program

### Phase 8: Release Preparation (Target: 2 weeks)
- Community funding
- Code signing
- Notarization
- DMG installer
- Homebrew Cask
