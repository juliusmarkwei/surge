# Architecture Documentation

## Overview

SURGE follows a client-server architecture where the main application runs in user space and communicates with a privileged helper daemon running as root via XPC (Inter-Process Communication).

## Components

### 1. Main Application (User Space)

The main application is a SwiftUI-based macOS app that provides:

- **Menu Bar Integration**: Always-visible monitoring and quick access
- **Main Window**: Full-featured UI for all cleaning and optimization features
- **Settings**: User preferences and helper management

**Key Files:**
- `SURGEApp.swift`: App entry point with MenuBarExtra
- `AppState.swift`: Global application state
- `XPCClient.swift`: Client-side XPC communication

#### Architecture Pattern: MVVM

```
View (SwiftUI) ← ViewModel ← Service ← XPC Client → Helper
```

**Responsibilities:**
- UI rendering and user interaction
- State management
- Async operation handling
- XPC client management

### 2. Privileged Helper (Root Daemon)

The privileged helper is a long-running daemon that:

- Runs with root privileges
- Performs system operations requiring elevation
- Validates all requests for security
- Communicates via XPC

**Key Files:**
- `main.swift`: Helper entry point
- `XPCServer.swift`: Server-side XPC implementation
- `ClientValidator.swift`: Security validation
- `InputSanitizer.swift`: Input sanitization
- Various operation handlers (SystemMonitor, SystemCleaner, etc.)

#### Security Model

```
Client Request → Code Signature Validation → Input Sanitization → Operation → Response
```

**Security Layers:**
1. **Connection Validation**: Verify client code signature
2. **Input Sanitization**: Validate and sanitize all inputs
3. **Path Validation**: Whitelist/blacklist path checking
4. **Operation Logging**: Audit trail of all operations

### 3. Shared Code

Common code used by both app and helper:

- `XPCProtocol.swift`: Communication protocol definition
- Data Transfer Objects (DTOs)
- Constants

## Communication Flow

### XPC Communication

```
┌─────────────┐                           ┌──────────────┐
│  Main App   │                           │    Helper    │
│ (User Space)│                           │ (Root Daemon)│
└──────┬──────┘                           └──────┬───────┘
       │                                         │
       │  1. Create XPC Connection              │
       │─────────────────────────────────────────>│
       │                                         │
       │  2. Validate Client Code Signature     │
       │<─────────────────────────────────────────│
       │                                         │
       │  3. Call Method (e.g., getSystemStats) │
       │─────────────────────────────────────────>│
       │                                         │
       │                 4. Sanitize Input       │
       │                       ┌─────────────────┤
       │                       │ InputSanitizer  │
       │                       └─────────────────┤
       │                                         │
       │                 5. Perform Operation    │
       │                       ┌─────────────────┤
       │                       │ SystemMonitor   │
       │                       └─────────────────┤
       │                                         │
       │  6. Return Result                       │
       │<─────────────────────────────────────────│
       │                                         │
```

### Request/Response Pattern

All XPC methods follow this pattern:

```swift
func operation(parameters, reply: @escaping (Result<Success, XPCError>) -> Void)
```

**Async/Await Wrapper:**

```swift
// Client side
let result = try await xpcClient.operation(parameters)

// Internally uses withCheckedThrowingContinuation
```

## Data Flow

### System Monitoring Example

```
MenuBarView
    ↓ (every 3s)
AppState.refreshSystemStats()
    ↓
XPCClient.getSystemStats()
    ↓ XPC
HelperXPCService.getSystemStats()
    ↓
SystemMonitor.shared.getSystemStats()
    ↓ Darwin APIs
host_statistics64(), host_processor_info()
    ↓
SystemStats struct
    ↓ XPC reply
MenuBarView (update UI)
```

### File Cleanup Example

```
User clicks "Clean"
    ↓
ViewModel.performCleanup()
    ↓
CleanupCoordinator.cleanup(categories)
    ↓
XPCClient.scanCleanableFiles(categories)
    ↓ XPC
HelperXPCService.scanCleanableFiles()
    ↓
InputSanitizer.validateCategories()
    ↓
SystemCleaner.scanCleanableFiles()
    ↓ FileManager
Scan directories, filter by age/size
    ↓
[CleanableItem] array
    ↓ XPC reply
ViewModel (show preview)
    ↓ User confirms
XPCClient.deleteFiles(paths)
    ↓ XPC
HelperXPCService.deleteFiles()
    ↓
InputSanitizer.sanitizePaths()
    ↓
SystemCleaner.deleteFiles()
    ↓ FileManager
Move to quarantine or delete
    ↓
CleanupResult
    ↓ XPC reply
ViewModel (show success)
```

## Security Architecture

### Threat Model

**Threats:**
1. Malicious app attempting to exploit helper
2. Path traversal to delete system files
3. Command injection
4. Privilege escalation
5. Data exfiltration

**Mitigations:**

#### 1. Code Signature Validation

```swift
func validateClient(_ connection: NSXPCConnection) -> Bool {
    // Get audit token
    // Create SecCode from PID
    // Create SecRequirement
    // Validate code signature matches requirement
    return SecCodeCheckValidity(code, [], requirement) == errSecSuccess
}
```

**Prevents:** Unauthorized apps from connecting to helper

#### 2. Input Sanitization

```swift
func sanitizePath(_ path: String) -> String? {
    // Standardize path (resolve .. and symlinks)
    // Check for path traversal
    // Validate against blacklist (system paths)
    // Validate against whitelist (allowed paths)
    return sanitizedPath
}
```

**Prevents:** Path traversal, accessing protected system files

#### 3. Whitelisting/Blacklisting

**Blacklist (Never Touch):**
- /System
- /bin, /sbin
- /usr/bin, /usr/sbin
- /Library/Apple
- Critical system directories

**Whitelist (Safe with Validation):**
- /Library/Caches
- ~/Library/Caches
- /private/var/log
- User-specific paths

#### 4. Age-Based Protection

Files modified in the last 7 days are automatically skipped to prevent deleting actively used files.

#### 5. Quarantine System

Instead of immediate deletion:
1. Move files to `/tmp/.SURGE-Quarantine`
2. Add timestamp to filename
3. Automatically clean items older than 30 days
4. User can manually restore if needed

### Secure Coding Practices

1. **Never Trust Client Input**: All data from XPC is untrusted
2. **Fail Secure**: On validation failure, reject operation
3. **Least Privilege**: Helper only runs when needed
4. **Audit Logging**: All operations logged for review
5. **Defense in Depth**: Multiple validation layers

## Performance Considerations

### 1. Menu Bar Updates

**Challenge:** 24/7 operation without battery drain

**Solution:**
- 3-second update interval (not per-frame)
- Lazy initialization of views
- Efficient Darwin API usage
- Proper memory management (@weak self)

### 2. Disk Scanning

**Challenge:** Scanning 100GB+ without UI freeze

**Solution:**
- Streaming results via XPC (no large arrays)
- Incremental updates to UI
- Background threads for heavy computation
- Level-of-detail rendering (cull small items)

### 3. XPC Communication

**Challenge:** Minimize latency and overhead

**Solution:**
- Batch operations where possible
- Use `async`/`await` for clean async code
- Connection pooling (single persistent connection)
- Efficient serialization (Codable)

## Error Handling

### Error Propagation

```
Helper Operation Error
    ↓ XPCError
XPC Reply with .failure(XPCError)
    ↓ Swift Result
Client throws XPCError
    ↓ try/catch
ViewModel handles error
    ↓ @Published
View displays error to user
```

### Error Categories

1. **Connection Errors**: Helper not installed/running
2. **Validation Errors**: Invalid input rejected
3. **Permission Errors**: Insufficient privileges
4. **Operation Errors**: File I/O failures, etc.

### User-Facing Errors

All errors are transformed into user-friendly messages:

```swift
enum XPCError: LocalizedError {
    case connectionFailed
    case unauthorized
    case invalidInput(String)
    case operationFailed(String)

    var errorDescription: String? {
        // User-friendly message
    }
}
```

## State Management

### AppState (Singleton, ObservableObject)

**Responsibilities:**
- Global app state
- XPC connection management
- System monitoring coordination
- Window management

**Published Properties:**
- `systemStats`: Latest system statistics
- `isHelperConnected`: Connection status
- `error`: Latest error message

### ViewModels (ObservableObject)

Each major feature has its own ViewModel:
- `SmartCareViewModel`
- `StorageViewModel`
- `PerformanceViewModel`
- `SecurityViewModel`

**Pattern:**
```swift
@MainActor
class FeatureViewModel: ObservableObject {
    @Published var state: State
    @Published var error: String?

    private let xpcClient: XPCClient

    func performAction() async {
        // Update state, call XPC, handle result
    }
}
```

## Testing Strategy

### Unit Tests

- ViewModels (business logic)
- Services (without XPC)
- Utilities (formatters, sanitizers)

### Integration Tests

- XPC communication
- Helper operations (with mock FileManager)

### UI Tests

- Critical user flows
- Settings management
- Error states

### Manual Testing

- Install on clean macOS installations
- 24-hour runtime tests
- Memory leak detection (Instruments)
- Security validation

## Future Architecture Considerations

### Phase 2+

1. **Database**: Core Data for scan results caching
2. **Notifications**: User notifications for completed tasks
3. **Scheduled Tasks**: Background cleanup scheduling
4. **Updates**: Sparkle integration for auto-updates
5. **Analytics**: Privacy-respecting telemetry (opt-in)

## References

- [XPC Services - Apple Developer](https://developer.apple.com/documentation/xpc)
- [SMAppService - Apple Developer](https://developer.apple.com/documentation/servicemanagement/smappservice)
- [Secure Coding Guide - Apple](https://developer.apple.com/library/archive/documentation/Security/Conceptual/SecureCodingGuide/)
