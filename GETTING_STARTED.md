# Getting Started with SURGE

## Quick Start (5 Minutes)

### 1. Build the Project

```bash
cd /Users/mac/Develop/cleanmymac

# Run the setup script
./Scripts/setup.sh

# This will:
# - Check for Swift installation
# - Resolve dependencies (swift-log, Sparkle, etc.)
# - Build the project
```

### 2. Run the App

```bash
# Run from command line
.build/debug/SURGE

# Or open in Xcode
open Package.swift
# Then press Cmd+R to build and run
```

### 3. Install the Privileged Helper

When you first run the app:

1. You'll see a menu bar icon appear (📊 with CPU percentage)
2. Click "Open SURGE" from the menu bar dropdown
3. The main window will prompt you to install the helper
4. Click "Install Helper"
5. System Settings will open automatically
6. Navigate to: **General → Login Items**
7. Under "Allow in the Background", enable **SURGE Helper**
8. Return to the app - it will connect automatically

### 4. Verify Everything Works

Once connected, you should see:
- ✅ Menu bar icon showing live CPU stats
- ✅ Stats updating every 3 seconds
- ✅ Main window accessible with 4 tabs
- ✅ Settings panel showing helper as "Connected"

## Project Structure Overview

```
SURGE/
│
├── Sources/
│   ├── SURGE/                   ← Main app (SwiftUI)
│   ├── PrivilegedHelper/        ← Root daemon (system operations)
│   └── Shared/                  ← XPC protocol (communication)
│
├── Documentation/               ← Technical docs
├── Tests/                       ← Unit tests
└── Scripts/                     ← Build scripts
```

## Key Files to Understand

### 1. Main App Entry Point
**File**: `Sources/SURGE/App/SURGEApp.swift`

This is the app's entry point with:
- MenuBarExtra for menu bar integration
- Main window setup
- Settings window

### 2. XPC Protocol
**File**: `Sources/Shared/XPCProtocol.swift`

Defines the communication contract between app and helper:
- Method signatures
- Data Transfer Objects (DTOs)
- Error types

### 3. XPC Client (App Side)
**File**: `Sources/SURGE/Services/XPC/XPCClient.swift`

Client-side XPC communication with async/await wrappers.

### 4. XPC Server (Helper Side)
**File**: `Sources/PrivilegedHelper/XPCServer.swift`

Server-side implementation that handles requests from the app.

### 5. Security Validation
**Files**:
- `Sources/PrivilegedHelper/Security/ClientValidator.swift`
- `Sources/PrivilegedHelper/Security/InputSanitizer.swift`

Critical security layer that validates all client requests.

## Development Workflow

### Making Changes

```bash
# 1. Create a feature branch
git checkout -b feature/my-feature

# 2. Make your changes

# 3. Build and test
swift build
swift test

# 4. Run the app to verify
.build/debug/SURGE

# 5. Commit and push
git add .
git commit -m "feat: add amazing feature"
git push origin feature/my-feature
```

### Adding a New XPC Method

Let's say you want to add a method to get battery info:

**Step 1**: Add to XPC Protocol (`Sources/Shared/XPCProtocol.swift`)

```swift
// Add DTO
public struct BatteryInfo: Codable, Sendable {
    public let percentage: Int
    public let isCharging: Bool
    public let timeRemaining: Int?
}

// Add to protocol
public protocol PrivilegedHelperProtocol {
    // ... existing methods ...

    func getBatteryInfo(reply: @escaping (Result<BatteryInfo, XPCError>) -> Void)
}
```

**Step 2**: Implement in Helper (`Sources/PrivilegedHelper/XPCServer.swift`)

```swift
class HelperXPCService: NSObject, PrivilegedHelperProtocol {
    // ... existing methods ...

    func getBatteryInfo(reply: @escaping (Result<BatteryInfo, XPCError>) -> Void) {
        do {
            let info = try SystemMonitor.shared.getBatteryInfo()
            reply(.success(info))
        } catch {
            reply(.failure(.operationFailed(error.localizedDescription)))
        }
    }
}
```

**Step 3**: Add to XPC Client (`Sources/SURGE/Services/XPC/XPCClient.swift`)

```swift
actor XPCClient {
    // ... existing methods ...

    func getBatteryInfo() async throws -> BatteryInfo {
        let proxy = try getProxy()

        return try await withCheckedThrowingContinuation { continuation in
            proxy.getBatteryInfo { result in
                continuation.resume(with: result)
            }
        }
    }
}
```

**Step 4**: Use in UI

```swift
Button("Check Battery") {
    Task {
        let battery = try await XPCClient.shared.getBatteryInfo()
        print("Battery: \(battery.percentage)%")
    }
}
```

### Adding a New View

**Step 1**: Create the view file

```bash
touch Sources/SURGE/Views/BatteryView.swift
```

**Step 2**: Implement SwiftUI view

```swift
import SwiftUI

struct BatteryView: View {
    @StateObject private var viewModel = BatteryViewModel()

    var body: some View {
        VStack {
            Text("Battery: \(viewModel.percentage)%")
            Button("Refresh") {
                Task {
                    await viewModel.refresh()
                }
            }
        }
    }
}
```

**Step 3**: Add to main window tabs (in `MainWindowView.swift`)

## Testing

### Run Unit Tests

```bash
swift test
```

### Run Specific Test

```bash
swift test --filter SanitizerTests
```

### Add New Test

Create a new file in `Tests/SURGETests/`:

```swift
import XCTest
@testable import YourTarget

final class MyTests: XCTestCase {
    func testSomething() {
        XCTAssertTrue(true)
    }
}
```

### Manual Testing Checklist

Before committing changes:

- [ ] App builds without warnings
- [ ] Menu bar displays correctly
- [ ] Helper connects successfully
- [ ] No console errors
- [ ] Memory usage reasonable (check Activity Monitor)
- [ ] No crashes during 5-minute runtime

## Debugging

### Enable Verbose Logging

The helper uses `swift-log`. To see debug logs:

```bash
# Set log level to debug
export LOG_LEVEL=debug
.build/debug/SURGE
```

### Debug XPC Communication

Add logging in `XPCClient.swift`:

```swift
func getSystemStats() async throws -> SystemStats {
    print("🔵 Calling getSystemStats")
    let result = try await ...
    print("✅ Got result: \(result)")
    return result
}
```

### Check Helper Status

```bash
# List running helpers
launchctl list | grep surge

# Check helper logs
log show --predicate 'subsystem == "com.surge.helper"' --last 5m
```

### Common Issues

**Issue**: Helper not connecting
**Solution**:
1. Check System Settings → General → Login Items
2. Uninstall and reinstall the helper
3. Check Console.app for errors

**Issue**: Build errors about missing modules
**Solution**:
```bash
swift package clean
swift package resolve
swift build
```

**Issue**: XPC connection failed
**Solution**: Ensure helper is approved in System Settings

## Performance Profiling

### Memory Leaks

```bash
# Run with Instruments
open -a Instruments .build/debug/SURGE

# Or use leaks command
leaks --atExit -- .build/debug/SURGE
```

### CPU Usage

```bash
# Monitor CPU usage
top -pid $(pgrep -f SURGE)
```

## Code Style Guide

### Swift Naming

```swift
// ✅ Good
func getSystemStats() -> SystemStats
let maxRetryCount = 3
class SystemCleaner

// ❌ Bad
func GetStats() -> SystemStats
let MAX_RETRY_COUNT = 3
class systemCleaner
```

### Error Handling

```swift
// ✅ Good - Typed errors
enum MyError: Error {
    case notFound
    case invalidInput(String)
}

func myFunction() throws {
    guard condition else {
        throw MyError.notFound
    }
}

// ❌ Bad - Generic errors
func myFunction() throws {
    guard condition else {
        throw NSError(domain: "", code: -1)
    }
}
```

### Async/Await

```swift
// ✅ Good - Use async/await
func fetchData() async throws -> Data {
    try await URLSession.shared.data(from: url)
}

// ❌ Bad - Completion handlers for new code
func fetchData(completion: @escaping (Data?) -> Void) {
    URLSession.shared.dataTask(with: url) { data, _, _ in
        completion(data)
    }
}
```

## Resources

### Documentation
- `README.md` - Project overview
- `ARCHITECTURE.md` - Technical architecture
- `CONTRIBUTING.md` - Contribution guidelines
- `PROJECT_SUMMARY.md` - Implementation summary

### External Resources
- [Swift API Design Guidelines](https://swift.org/documentation/api-design-guidelines/)
- [SwiftUI Documentation](https://developer.apple.com/documentation/swiftui)
- [XPC Documentation](https://developer.apple.com/documentation/xpc)
- [SMAppService](https://developer.apple.com/documentation/servicemanagement/smappservice)

### Similar Projects
- [Stats](https://github.com/exelban/stats) - Menu bar system monitor
- [Pearcleaner](https://github.com/alienator88/Pearcleaner) - App uninstaller
- [GrandPerspective](http://grandperspectiv.sourceforge.net/) - Disk visualizer

## Next Steps

### For Development

1. **Read the Architecture Docs**: `Documentation/ARCHITECTURE.md`
2. **Review XPC Protocol**: `Sources/Shared/XPCProtocol.swift`
3. **Explore the Codebase**: Start with `SURGEApp.swift`
4. **Run Tests**: `swift test`
5. **Pick a Phase 2 Task**: See README.md for upcoming features

### For Contributing

1. **Read CONTRIBUTING.md**
2. **Check GitHub Issues** (when repository is live)
3. **Join Discussions**
4. **Submit PRs**

## Questions?

- **GitHub Issues**: For bugs and feature requests
- **GitHub Discussions**: For questions and ideas
- **Code Comments**: Well-documented throughout

---

**Happy Coding! 🚀**

Let's build an amazing free system utility together.
