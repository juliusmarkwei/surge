# SURGE v2.0 - UI Design Guide

## New UI Features ✨

The SURGE UI has been completely redesigned with a modern, professional terminal interface.

### What's New

1. **ASCII Art Banner** - Large SURGE logo at the top
2. **Dual-Panel Layout** - Features menu on left, quick guide on right
3. **Color-Coded Features** - Each feature has its own color
4. **Arrow Key Navigation** - Navigate menu with ↑↓ or j/k
5. **Visual Highlighting** - Selected menu item is highlighted
6. **System Status Bar** - Color-coded CPU/RAM/Disk usage
7. **Black Background Theme** - Professional dark theme
8. **Rounded Borders** - Modern border styling

## UI Layout

```
┌────────────────────────────────────────────────────────────────┐
│                      ASCII BANNER                              │
│     Version │ Release Date │ Creator                           │
└────────────────────────────────────────────────────────────────┘
┌──────────────────────────┬─────────────────────────────────────┐
│      Features            │         Quick Guide                 │
│  ▶ [1] Smart Care        │   Navigation                        │
│    [2] Storage Cleanup   │   ↑↓ or j/k  Navigate menu         │
│    [3] Disk TreeMap      │   1-8        Jump to feature        │
│    [4] Duplicate Finder  │   Enter      Select feature         │
│    [5] Large Files       │                                     │
│    [6] Performance       │   Actions                           │
│    [7] Security Scan     │   Space      Toggle selection       │
│    [8] Maintenance       │   a          Select all             │
│                          │                                     │
│                          │   Global                            │
│                          │   h or ?     Show help              │
│                          │   Esc        Go back                │
│                          │   q          Quit app               │
└──────────────────────────┴─────────────────────────────────────┘
┌────────────────────────────────────────────────────────────────┐
│ System Status: CPU │ RAM │ Disk (color-coded by usage)        │
└────────────────────────────────────────────────────────────────┘
```

## Navigation Methods

### Home Screen

**Number Keys (1-8)**: Jump directly to feature
- Press `1` → Smart Care
- Press `2` → Storage Cleanup
- Press `3` → Disk TreeMap
- ...and so on

**Arrow Keys**: Navigate menu
- Press `↑` or `k` → Move selection up
- Press `↓` or `j` → Move selection down
- Press `Enter` → Go to selected feature

**Visual Indicator**: `▶` shows current selection

### Other Screens

**Storage Cleanup**:
- `↑↓` or `j/k` - Navigate file list
- `Space` - Toggle file selection
- `Enter` - Start scan (if empty) or confirm cleanup

## Color Scheme

### Feature Colors
- **Green** - Smart Care
- **Yellow** - Storage Cleanup
- **Blue** - Disk TreeMap
- **Magenta** - Duplicate Finder
- **Red** - Large Files
- **Cyan** - Performance
- **Light Red** - Security Scan
- **Light Blue** - Maintenance

### System Status Colors
- **Green** - Normal (< 50%)
- **Yellow** - Warning (50-80%)
- **Red** - Critical (> 80%)

### UI Elements
- **Cyan** - Titles and headers
- **White** - Main text
- **Gray** - Descriptions
- **Black** - Background

## Banner Information

The top banner displays:
- **SURGE** - ASCII art logo (cyan, bold)
  ```
  ####   #   #  ####    ####   ####
 #      #   #  #   #  #      #
  ###   #   #  ####   # ###  ###
     #  #   #  #   #  #   #  #
 ####    ###   #   #   ###   ####
  ```
- **Version** - 2.0.0 (green, bold)
- **Released** - 2026-02-04 (yellow)
- **Created by** - SURGE Contributors (magenta, italic)

## Border Styles

- **Rounded** - Modern rounded corners for all panels
- **Color-coded** - Borders match panel purpose (cyan for banner, blue for features, green for status)

## Interactive Elements

### Highlighted Items
When you navigate with arrow keys:
- Selected item gets `▶` prefix
- Item background changes to feature color
- Text becomes black (high contrast on colored background)

### Status Indicators
System status shows real-time:
- CPU usage percentage
- RAM usage (percentage and GB)
- Disk usage (percentage and GB)
Colors automatically adjust based on usage levels.

## Running the New UI

```bash
cargo run
```

Then:
1. Use `↑↓` to navigate menu
2. Press `Enter` to select
3. Or press `1-8` to jump directly

The interface is fully keyboard-driven with vim-style navigation!

## Comparison: Old vs New

### Old UI
- Simple list
- No colors
- No navigation highlighting
- Single panel
- Plain borders

### New UI ✨
- ASCII art banner
- Color-coded features
- Visual selection indicator
- Dual-panel layout
- System status with color indicators
- Rounded borders
- Professional dark theme

---

**The UI is now ready for production use with a professional, polished appearance!**
