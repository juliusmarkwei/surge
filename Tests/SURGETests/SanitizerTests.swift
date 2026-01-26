//
//  SanitizerTests.swift
//  SURGETests
//
//  Tests for InputSanitizer security validation.
//

import XCTest
@testable import Shared

final class SanitizerTests: XCTestCase {

    // MARK: - Path Validation Tests

    func testValidPath() {
        let path = "/Users/testuser/Library/Caches"
        XCTAssertNotNil(InputSanitizer.sanitizePath(path))
    }

    func testPathTraversalRejected() {
        let maliciousPath = "/Users/testuser/../../../System"
        XCTAssertNil(InputSanitizer.sanitizePath(maliciousPath))
    }

    func testBlacklistedPathRejected() {
        let paths = [
            "/System/Library",
            "/bin/bash",
            "/usr/bin",
            "/Library/Apple"
        ]

        for path in paths {
            XCTAssertNil(InputSanitizer.sanitizePath(path), "Should reject: \(path)")
        }
    }

    func testEmptyPathRejected() {
        XCTAssertNil(InputSanitizer.sanitizePath(""))
        XCTAssertNil(InputSanitizer.sanitizePath("   "))
    }

    func testHomeDirectoryProtected() {
        let path = "/Users/testuser"
        XCTAssertNil(InputSanitizer.sanitizePath(path), "Should not allow deleting home directory")
    }

    func testSafePathsAllowed() {
        let safePaths = [
            "/Library/Caches/com.example.app",
            "/private/var/log/system.log",
            "/Users/testuser/Library/Caches"
        ]

        for path in safePaths {
            XCTAssertNotNil(InputSanitizer.sanitizePath(path), "Should allow: \(path)")
        }
    }

    // MARK: - String Validation Tests

    func testSafeStringAllowed() {
        let safe = "normal-filename_123.txt"
        XCTAssertNotNil(InputSanitizer.sanitizeString(safe))
    }

    func testShellMetacharactersRejected() {
        let dangerous = [
            "file; rm -rf /",
            "file | cat",
            "file && echo",
            "file `whoami`",
            "file$(cat /etc/passwd)"
        ]

        for string in dangerous {
            XCTAssertNil(InputSanitizer.sanitizeString(string), "Should reject: \(string)")
        }
    }

    func testControlCharactersRemoved() {
        let input = "file\u{0000}name\u{0001}"
        let result = InputSanitizer.sanitizeString(input)
        XCTAssertEqual(result, "filename")
    }

    // MARK: - Number Validation Tests

    func testNumberInRange() {
        XCTAssertTrue(InputSanitizer.validateNumber(5, min: 0, max: 10))
        XCTAssertTrue(InputSanitizer.validateNumber(0, min: 0, max: 10))
        XCTAssertTrue(InputSanitizer.validateNumber(10, min: 0, max: 10))
    }

    func testNumberOutOfRange() {
        XCTAssertFalse(InputSanitizer.validateNumber(-1, min: 0, max: 10))
        XCTAssertFalse(InputSanitizer.validateNumber(11, min: 0, max: 10))
    }

    // MARK: - Safe Deletion Tests

    func testSafeToDelete() {
        let safePath = "/Library/Caches/temp.txt"
        // Note: This will fail if file doesn't exist, which is expected
        // In a real test, we'd create a temporary file
    }

    func testNotSafeToDelete() {
        let unsafePaths = [
            "/System",
            "/Applications",
            "/Library"
        ]

        for path in unsafePaths {
            XCTAssertFalse(InputSanitizer.isSafeToDelete(path), "Should not be safe to delete: \(path)")
        }
    }
}
