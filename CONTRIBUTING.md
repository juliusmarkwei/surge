# Contributing to SURGE

Thank you for your interest in contributing to SURGE! This document provides guidelines and information for contributors.

## Code of Conduct

- Be respectful and inclusive
- Welcome newcomers and help them get started
- Focus on constructive feedback
- Prioritize user safety and data protection

## How to Contribute

### Reporting Issues

1. Check if the issue already exists
2. Use the issue template
3. Provide detailed reproduction steps
4. Include system information (macOS version, hardware)
5. Attach relevant logs if possible

### Suggesting Features

1. Open a Discussion first to gather feedback
2. Describe the use case and benefits
3. Consider implementation complexity
4. Be open to alternative solutions

### Submitting Code

1. **Fork the repository**
2. **Create a feature branch**: `git checkout -b feature/your-feature-name`
3. **Make your changes** following our coding standards
4. **Write tests** for new functionality
5. **Update documentation** as needed
6. **Test thoroughly** on macOS 13, 14, and 15 if possible
7. **Commit with clear messages**: Use conventional commits format
8. **Push to your fork**: `git push origin feature/your-feature-name`
9. **Open a Pull Request** with a detailed description

## Development Setup

### Prerequisites

- macOS 13.0 or later
- Xcode 15.0 or later
- Swift 5.9 or later

### Getting Started

```bash
# Clone the repository
git clone https://github.com/yourusername/surge.git
cd surge

# Run setup script
./Scripts/setup.sh

# Build and run
swift build
.build/debug/SURGE
```

### Development Workflow

1. Make changes in your branch
2. Run tests: `swift test`
3. Build: `swift build`
4. Test manually with the app
5. Check for memory leaks with Instruments
6. Commit and push

## Coding Standards

### Swift Style

- Follow [Swift API Design Guidelines](https://swift.org/documentation/api-design-guidelines/)
- Use SwiftLint (configuration coming soon)
- Prefer `async`/`await` over callbacks
- Use actors for shared mutable state
- Comprehensive error handling with typed errors

### Code Organization

```swift
// MARK: - Section Name

/// Documentation comment
/// - Parameter name: Description
/// - Returns: Description
func functionName(parameter: Type) -> ReturnType {
    // Implementation
}
```

### Naming Conventions

- **Types**: PascalCase (e.g., `SystemCleaner`)
- **Functions/Variables**: camelCase (e.g., `getSystemStats`)
- **Constants**: camelCase (e.g., `maxDepth`)
- **Private properties**: prefix with underscore optional

### Security Guidelines

**CRITICAL**: All code touching the privileged helper must follow these rules:

1. **Never trust client input** - sanitize everything
2. **Validate paths** - use InputSanitizer for all file paths
3. **Check permissions** - verify operations are allowed
4. **Log security events** - audit trail for privileged operations
5. **Fail secure** - reject on validation failure, don't try to fix
6. **Test edge cases** - path traversal, injection attacks, etc.

Example:

```swift
// ❌ BAD - No validation
func deleteFile(path: String) {
    try FileManager.default.removeItem(atPath: path)
}

// ✅ GOOD - Proper validation
func deleteFile(path: String) throws {
    guard let sanitized = InputSanitizer.sanitizePath(path) else {
        throw XPCError.invalidInput("Path validation failed")
    }

    guard InputSanitizer.isSafeToDelete(sanitized) else {
        throw XPCError.permissionDenied("Path is protected")
    }

    try FileManager.default.removeItem(atPath: sanitized)
    logger.info("Deleted file", metadata: ["path": .string(sanitized)])
}
```

## Testing Requirements

### Unit Tests

- Test business logic in ViewModels
- Test utility functions
- Test data transformations
- Aim for 80%+ code coverage

### Security Tests

- Test input sanitization
- Test path validation
- Test XPC client validation
- Test error handling

### Integration Tests

- Test XPC communication
- Test helper operations
- Test state management

### Manual Testing Checklist

Before submitting a PR, test:

- [ ] App launches without errors
- [ ] Menu bar displays correct stats
- [ ] Helper installs successfully
- [ ] XPC communication works
- [ ] No memory leaks (run in Instruments)
- [ ] No crashes during 1-hour runtime
- [ ] UI is responsive
- [ ] Errors are handled gracefully

## Documentation

### Code Documentation

- Add doc comments to all public APIs
- Explain "why" not just "what"
- Include usage examples for complex APIs
- Document security considerations

### Architecture Documentation

Update `Documentation/ARCHITECTURE.md` when making structural changes.

### User Documentation

Update `README.md` for user-facing changes.

## Git Workflow

### Commit Messages

Use [Conventional Commits](https://www.conventionalcommits.org/):

```
feat: add disk usage visualization
fix: correct memory leak in XPC client
docs: update installation instructions
test: add tests for path sanitization
refactor: simplify cleanup coordinator logic
perf: optimize directory scanning
security: validate all XPC inputs
```

### Branch Naming

- `feature/feature-name` - New features
- `fix/issue-description` - Bug fixes
- `docs/topic` - Documentation updates
- `refactor/component-name` - Code refactoring
- `test/test-description` - Test additions

### Pull Request Guidelines

**PR Title**: Clear, descriptive summary

**PR Description** should include:
- What changed and why
- How to test the changes
- Screenshots/videos for UI changes
- Security considerations (if applicable)
- Related issues (Fixes #123)

**Before Submitting:**
- [ ] Code compiles without warnings
- [ ] Tests pass (`swift test`)
- [ ] No new security issues
- [ ] Documentation updated
- [ ] CHANGELOG.md updated (for significant changes)

## Areas for Contribution

### High Priority

- [ ] Complete Phase 2: Storage Management Core
- [ ] Implement TreeMap visualization
- [ ] Add duplicate file detection
- [ ] Improve test coverage
- [ ] Add localization support

### Good First Issues

Look for issues labeled `good-first-issue`:
- Documentation improvements
- UI polish
- Test additions
- Bug fixes with reproduction steps

### Advanced Contributions

- Performance optimization
- New security signatures
- Advanced features (smart scheduling, etc.)
- Platform support (future iOS/iPadOS builds)

## Code Review Process

1. **Automated checks** run on PR (coming soon: CI/CD)
2. **Maintainer review** within 3-5 days
3. **Feedback** provided with specific suggestions
4. **Revisions** as needed
5. **Approval** and merge

## Security Vulnerability Reporting

**DO NOT** open public issues for security vulnerabilities.

Instead:
1. Email: security@example.com
2. Include: Detailed description, reproduction steps, impact
3. Response: Within 48 hours
4. Fix: Coordinated disclosure after patch

## Recognition

Contributors are recognized in:
- README.md Contributors section
- GitHub Contributors graph
- Release notes (for significant contributions)

## Questions?

- **General questions**: GitHub Discussions
- **Development questions**: Open an issue or discussion
- **Quick questions**: Comment on relevant issue/PR

## License

By contributing, you agree that your contributions will be licensed under the GPLv3 license.

---

Thank you for helping make SURGE better! 🎉
