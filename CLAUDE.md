# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

SURGE v1.0 is a free, open-source **cross-platform terminal-based system cleaner** for macOS and Linux, built with **Rust + Ratatui + Crossterm**. It provides an interactive TUI (Terminal User Interface) similar to npkill for real-time system cleanup.

## Essential Commands

### Building and Running

```bash
# Quick build and run
./Scripts/build.sh        # Build debug version
./Scripts/build.sh release # Build release version
./Scripts/run.sh          # Build and run

# Manual cargo commands
cargo build              # Debug build
cargo build --release    # Release build (optimized)
cargo run                # Build and run
cargo run --release      # Run release version

# Run tests
./Scripts/test.sh
cargo test
cargo test sanitizer     # Run specific test
```

### Development

```bash
# Check for errors without building
cargo check

# Format code
cargo fmt

# Lint code
cargo clippy

# Clean build artifacts
cargo clean

# Update dependencies
cargo update
```

## Architecture

### Project Structure

```
src/
├── main.rs                    # Entry point, event loop, keyboard handling
├── app/
│   └── state.rs               # App state machine, screen navigation
├── ui/
│   ├── screens/               # 10 screens (home, cleanup, treemap, etc.)
│   │   ├── home.rs            # Main menu
│   │   ├── cleanup.rs         # Storage cleanup UI
│   │   ├── treemap.rs         # Disk visualization
│   │   ├── duplicates.rs      # Duplicate finder UI
│   │   ├── large_files.rs     # Large files UI
│   │   ├── performance.rs     # Performance monitor UI
│   │   ├── security.rs        # Security scan UI
│   │   ├── maintenance.rs     # Maintenance tasks UI
│   │   ├── smart_care.rs      # Smart care UI
│   │   └── help.rs            # Help screen
│   └── widgets/               # Reusable UI widgets
├── scanner/
│   └── cleanup.rs             # Category-based file scanning
├── operations/
│   └── delete.rs              # File deletion with sudo (future)
├── security/
│   ├── sanitizer.rs           # Path validation (CRITICAL)
│   ├── blacklist.rs           # Protected paths (CRITICAL)
│   └── mod.rs
├── system/
│   └── stats.rs               # CPU/RAM/Disk monitoring
└── models/
    └── mod.rs                 # Data structures (DTOs)
```

### Event-Driven Architecture

```
Crossterm Event Loop (main.rs)
    ↓
Keyboard Input → handle_key()
    ↓
App State Machine (app/state.rs)
    ↓
┌─────────────────┬─────────────────┬──────────────┐
│  Scan Tasks     │  Operations     │  UI Render   │
│  (Async Tokio)  │  (Async)        │  (Ratatui)   │
└─────────────────┴─────────────────┴──────────────┘
```

## Security Model (CRITICAL)

SURGE implements **five layers of security** to prevent privilege escalation and system damage:

### 1. Path Validation & Sanitization (`security/sanitizer.rs`)
- **Blacklisted paths**: System directories that can NEVER be touched
- **Path canonicalization**: Resolve symlinks and relative paths
- **Traversal protection**: Prevent `../` attacks
- **Home directory expansion**: Safely handle `~/` paths

**IMPORTANT**: Never bypass or weaken `PathSanitizer` - it's security-critical.

### 2. Age-Based Protection
- Files modified in the last 7 days are automatically protected
- Prevents deletion of actively used files
- Configurable with `.with_min_age(days)`

### 3. Blacklist System (`security/blacklist.rs`)
Protected paths (platform-specific):
- **macOS**: `/System`, `/bin`, `/usr/bin`, `/Library/Apple`, `/Applications/Utilities`
- **Linux**: `/bin`, `/sbin`, `/usr/bin`, `/etc`, `/sys`, `/proc`
- **User**: `~/Documents`, `~/Desktop`, `~/Pictures`, `~/Music`

### 4. Quarantine System (Future)
- Files moved to `/tmp/.SURGE-Quarantine` instead of deletion
- 30-day retention period
- Timestamped filenames

### 5. Mandatory Preview
- Users MUST review files before cleanup
- No automatic deletion

## Code Patterns

### Error Handling
```rust
use anyhow::{Result, anyhow};

// Use Result<T> for fallible functions
fn scan_directory(path: &Path) -> Result<Vec<Item>> {
    // Propagate errors with ?
    let metadata = path.metadata()?;

    // Create custom errors
    if !path.exists() {
        return Err(anyhow!("Path does not exist: {}", path.display()));
    }

    Ok(items)
}
```

### Async/Await (Future)
```rust
use tokio::task;

// Spawn async task
async fn scan_async(path: PathBuf) -> Result<Vec<Item>> {
    let handle = task::spawn(async move {
        // Do work
    });

    handle.await?
}
```

### UI Rendering (Ratatui)
```rust
use ratatui::{Frame, widgets::{Block, Borders, Paragraph}};

pub fn render(frame: &mut Frame, app: &App, area: Rect) {
    let widget = Paragraph::new("Hello")
        .block(Block::default().borders(Borders::ALL));
    frame.render_widget(widget, area);
}
```

### Platform-Specific Code
```rust
#[cfg(target_os = "macos")]
fn get_cache_dir() -> PathBuf {
    PathBuf::from("/Library/Caches")
}

#[cfg(target_os = "linux")]
fn get_cache_dir() -> PathBuf {
    PathBuf::from("/var/cache")
}
```

## Adding New Features

### Adding a New Scanner

1. **Create scanner module** in `src/scanner/`:
   ```rust
   // src/scanner/duplicates.rs
   pub struct DuplicateScanner;
   impl DuplicateScanner {
       pub fn scan(&self, paths: &[PathBuf]) -> Result<Vec<DuplicateGroup>> {
           // Implementation
       }
   }
   ```

2. **Add to `src/scanner/mod.rs`**:
   ```rust
   pub mod duplicates;
   ```

3. **Use in UI** via `app/state.rs` and create corresponding screen

### Adding a New UI Screen

1. **Create screen** in `src/ui/screens/`:
   ```rust
   // src/ui/screens/my_screen.rs
   use ratatui::{Frame, layout::Rect};
   use crate::app::App;

   pub fn render(frame: &mut Frame, app: &App, area: Rect) {
       // Render UI
   }
   ```

2. **Add to `src/ui/screens/mod.rs`**:
   ```rust
   pub mod my_screen;
   ```

3. **Add screen to enum** in `src/app/state.rs`:
   ```rust
   pub enum Screen {
       // ...
       MyScreen,
   }
   ```

4. **Add to render match** in `src/app/state.rs`:
   ```rust
   match self.current_screen {
       Screen::MyScreen => screens::my_screen::render(frame, self, area),
   }
   ```

5. **Add keyboard shortcut** in `src/main.rs`:
   ```rust
   KeyCode::Char('9') => app.navigate_to_screen(9),
   ```

### Adding Dependencies

1. **Edit `Cargo.toml`**:
   ```toml
   [dependencies]
   new-crate = "1.0"
   ```

2. **Update with Cargo**:
   ```bash
   cargo add new-crate
   cargo add new-crate --features feature1,feature2
   ```

## Testing Strategy

### Unit Tests
```rust
#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_sanitizer() {
        let sanitizer = PathSanitizer::default();
        assert!(sanitizer.sanitize_path(Path::new("/System")).is_err());
    }
}
```

### Integration Tests
```rust
// tests/integration_test.rs
use surge_tui::scanner::cleanup::CleanupScanner;

#[test]
fn test_scanner() {
    let scanner = CleanupScanner::new();
    // Test
}
```

### Running Tests
```bash
# All tests
cargo test

# Specific test
cargo test test_sanitizer

# With output
cargo test -- --nocapture

# Specific test file
cargo test --test integration_test
```

## Common Pitfalls

1. **Never modify paths without sanitization** - Always use `PathSanitizer::sanitize_path()` first
2. **Don't bypass age protection** - The 7-day rule is critical for safety
3. **Handle platform differences** - Use `#[cfg(target_os = "...")]` for OS-specific code
4. **Check file existence** - Always verify paths exist before operations
5. **Use `Result<T>` for fallible operations** - Propagate errors with `?`
6. **Don't panic in library code** - Return `Result` instead
7. **Test on both platforms** - macOS and Linux have different paths
8. **Format before committing** - Run `cargo fmt`

## File Organization

```
SURGE v1.0/
├── src/                       # Source code
├── tests/                     # Integration tests
├── Scripts/                   # Build scripts
│   ├── build.sh              # Build helper
│   ├── run.sh                # Run helper
│   └── test.sh               # Test helper
├── Cargo.toml                # Dependencies and metadata
├── Cargo.lock                # Locked dependencies (git-ignored)
├── README.md                 # User-facing documentation
├── CLAUDE.md                 # This file (development guide)
├── LICENSE                   # MIT License
└── .gitignore                # Git ignore rules
```

## Dependencies

Core dependencies:
- **ratatui 0.26** - Terminal UI framework
- **crossterm 0.27** - Cross-platform terminal control
- **tokio 1.35** - Async runtime (with "full" features)
- **walkdir 2.4** - Directory traversal
- **sysinfo 0.30** - System stats (CPU/RAM/Disk)
- **sha2 0.10** - SHA-256 hashing
- **clap 4.4** - CLI argument parsing
- **anyhow 1.0** - Error handling
- **chrono 0.4** - Date/time (with "serde" feature)
- **humansize 2.1** - Human-readable sizes
- **dirs 5.0** - Platform-specific directories

## Development Phases

### Phase 1: Foundation ✅ (Current)
- [x] Project structure
- [x] Security modules (sanitizer, blacklist)
- [x] Basic TUI with home screen
- [x] System stats monitoring
- [x] All UI screens (placeholders)
- [x] Keyboard navigation

### Phase 2: Core Cleanup (Next)
- [ ] Connect cleanup scanner to UI
- [ ] Real-time scanning with progress
- [ ] File selection and toggle
- [ ] Delete operations with sanitization
- [ ] Quarantine implementation
- [ ] Sudo integration for privileged operations

### Phase 3: Advanced Scanners
- [ ] TreeMap scanner and visualization
- [ ] Duplicate finder (SHA-256 hashing)
- [ ] Large/old file scanner
- [ ] Performance monitoring details

### Phase 4: Security & Maintenance
- [ ] Security scanner with signatures
- [ ] Maintenance task implementations
- [ ] Error recovery
- [ ] Logging system

### Phase 5: Polish
- [ ] Cross-platform testing
- [ ] Performance optimization
- [ ] Package for Homebrew/AUR
- [ ] Complete documentation

## Differences from v1.0 (Swift)

**Removed:**
- XPC client-server architecture
- Privileged helper daemon
- Code signature validation
- SwiftUI interface

**Added:**
- Cross-platform support (macOS + Linux)
- Terminal-based interactive UI
- Simpler privilege model (sudo for one-shot ops)
- Async scanning with Tokio
- Rust safety guarantees

**Preserved:**
- Path sanitization logic (ported from `InputSanitizer.swift`)
- Age-based protection (7-day rule)
- Blacklist/whitelist system
- All 7 major features
- Security-first approach

## Resources

- **Rust Book**: https://doc.rust-lang.org/book/
- **Ratatui Docs**: https://docs.rs/ratatui/
- **Crossterm Docs**: https://docs.rs/crossterm/
- **Tokio Tutorial**: https://tokio.rs/tokio/tutorial
- **Cargo Book**: https://doc.rust-lang.org/cargo/

---

**Note:** This is a complete rewrite from Swift to Rust. When porting features from v1.0, preserve the security logic but adapt to Rust idioms.
