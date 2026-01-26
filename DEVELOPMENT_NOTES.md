# Development Notes

## Running SURGE

### Quick Development (Current Method)

For development and testing the UI:

```bash
swift build
.build/debug/SURGE
```

**Note**: When running this way, the privileged helper **cannot be installed** because SMAppService requires a proper app bundle. You'll see "Helper Not Connected" in the menu bar, which is expected.

### Testing UI Without Helper

You can still test:
- ✅ Menu bar interface
- ✅ All UI views and navigation
- ✅ Smart Care and Storage views (UI only)
- ❌ Actual cleanup operations (requires helper)
- ❌ System stats (requires helper)

### Building Full App Bundle (With Helper Support)

To test the complete app with helper installation:

```bash
./Scripts/build-app-bundle.sh
open .build/debug/SURGE.app
```

**Current Issue**: The app bundle build is missing Sparkle framework. This needs to be fixed by either:
1. Copying Sparkle.framework to the bundle
2. Removing Sparkle dependency (not needed yet for Phase 2)
3. Using Xcode to build a proper signed bundle

### Installing the Helper (When Bundle Works)

Once the app bundle is fixed:

1. Open SURGE from the app bundle
2. Click "Open SURGE" from menu bar
3. Click "Install Helper"
4. System Settings will open
5. Navigate to: **General → Login Items & Extensions**
6. Enable **"SURGE Helper"** under "Allow in the Background"
7. Return to SURGE - should connect automatically

## Why Helper Installation Fails

SMAppService (used for helper installation) requires:
- A proper .app bundle structure
- Info.plist with SMPrivilegedExecutables key
- Helper binary and plist in correct locations
- Code signing (for distribution, not strictly required for dev)

When running `swift build` directly:
- Creates standalone executables, not app bundles
- SMAppService can't find the helper tool
- Helper installation will fail

## Current Development Status

**Phase 2 Complete**: ✅
- All code is implemented and builds successfully
- UI is fully functional
- Helper code is ready

**Limitation**: Helper installation requires proper app bundle packaging (Phase 8 task)

## Next Steps

### Option 1: Continue UI Development
Keep using `.build/debug/SURGE` for UI work on Phase 3 features (TreeMap, etc.)

### Option 2: Fix App Bundle
1. Remove or properly bundle Sparkle framework
2. Update build script to copy frameworks
3. Test helper installation

### Option 3: Use Xcode
Create an Xcode project for proper building and signing (planned for Phase 8)

## Workaround for Testing

To test cleanup operations without helper:
1. Add a "mock mode" that simulates cleanup without privileged access
2. Use it for UI testing and development
3. Real helper testing can wait until Phase 8 (Release Preparation)

---

**Current Recommendation**: Continue with `.build/debug/SURGE` for Phase 3 development. Helper installation can be fully tested in Phase 8 when we set up proper building and code signing.
