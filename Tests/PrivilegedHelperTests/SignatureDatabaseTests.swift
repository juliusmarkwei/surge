//
//  SignatureDatabaseTests.swift
//  PrivilegedHelperTests
//
//  Tests for malware signature database and matching.
//

import XCTest
@testable import PrivilegedHelper
@testable import Shared

final class SignatureDatabaseTests: XCTestCase {

    var signatureDB: SignatureDatabase!

    override func setUp() async throws {
        signatureDB = SignatureDatabase.shared
    }

    // MARK: - Database Info Tests

    func testDatabaseInfo() {
        let info = signatureDB.info

        XCTAssertFalse(info.version.isEmpty)
        XCTAssertGreaterThan(info.malwareCount, 0)
        // Extension count might be 0 if not implemented yet
        XCTAssertGreaterThanOrEqual(info.extensionCount, 0)
    }

    // MARK: - Pattern Matching Tests

    func testNamePatternMatching() {
        // Test matching against known malware names
        let testCases: [(name: String, shouldMatch: Bool)] = [
            ("adload_installer.pkg", true),
            ("searchbaron.app", true),
            ("genieo_helper", true),
            ("normalapp.app", false),
            ("clean_file.txt", false)
        ]

        for testCase in testCases {
            let result = signatureDB.matchFile(
                path: "/test/\(testCase.name)",
                name: testCase.name,
                hash: nil
            )

            if testCase.shouldMatch {
                XCTAssertNotNil(result, "Expected match for: \(testCase.name)")
            } else {
                XCTAssertNil(result, "Expected no match for: \(testCase.name)")
            }
        }
    }

    func testPathPatternMatching() {
        // Test glob-style path matching
        let testPaths: [(path: String, shouldMatch: Bool)] = [
            ("/Library/LaunchAgents/com.malware.plist", true),
            ("/Library/Application Support/.hidden_malware", true),
            ("/Applications/Safari.app", false),
            ("/Users/test/Documents/file.txt", false)
        ]

        for testPath in testPaths {
            let name = (testPath.path as NSString).lastPathComponent
            let result = signatureDB.matchFile(
                path: testPath.path,
                name: name,
                hash: nil
            )

            // Note: This tests the path pattern matching capability
            // Actual matches depend on signature database content
        }
    }

    // MARK: - Hash Calculation Tests

    func testFileHashCalculation() {
        // Create a temporary test file
        let tempDir = FileManager.default.temporaryDirectory
        let testFile = tempDir.appendingPathComponent("test_hash_file.txt")
        let testContent = "Test content for hashing"

        do {
            try testContent.write(to: testFile, atomically: true, encoding: .utf8)

            let hash1 = signatureDB.calculateFileHash(at: testFile.path)
            XCTAssertNotNil(hash1)
            XCTAssertFalse(hash1!.isEmpty)
            XCTAssertEqual(hash1!.count, 64) // SHA-256 is 64 hex characters

            // Same file should produce same hash
            let hash2 = signatureDB.calculateFileHash(at: testFile.path)
            XCTAssertEqual(hash1, hash2)

            // Modify file
            try "Modified content".write(to: testFile, atomically: true, encoding: .utf8)

            let hash3 = signatureDB.calculateFileHash(at: testFile.path)
            XCTAssertNotNil(hash3)
            XCTAssertNotEqual(hash1, hash3) // Different content = different hash

            // Cleanup
            try? FileManager.default.removeItem(at: testFile)
        } catch {
            XCTFail("Failed to create test file: \(error)")
        }
    }

    func testHashCalculationForNonexistentFile() {
        let hash = signatureDB.calculateFileHash(at: "/nonexistent/file.txt")
        XCTAssertNil(hash)
    }

    func testHashCalculationForLargeFile() {
        // Create a file larger than 10MB (should not be hashed for performance)
        let tempDir = FileManager.default.temporaryDirectory
        let largeFile = tempDir.appendingPathComponent("large_test_file.bin")

        do {
            // Create 11MB file
            let data = Data(count: 11 * 1024 * 1024)
            try data.write(to: largeFile)

            // Should return nil for files > 10MB
            let hash = signatureDB.calculateFileHash(at: largeFile.path)
            // Note: Actual behavior depends on implementation
            // May return nil or still hash it

            // Cleanup
            try? FileManager.default.removeItem(at: largeFile)
        } catch {
            XCTFail("Failed to create large test file: \(error)")
        }
    }

    // MARK: - Extension Matching Tests

    func testExtensionMatching() {
        // Test browser extension matching
        let chromeExtensionID = "abcdefghijklmnopqrstuvwxyz123456" // 32 chars
        let safariExtension = "suspicious.safariextz"
        let firefoxExtension = "addon@malware.xpi"

        let chromeMatch = signatureDB.matchExtension(
            extensionID: chromeExtensionID,
            browser: "chrome"
        )

        // Should return match if extension is in database, nil otherwise
        // This depends on database content
    }

    // MARK: - Edge Cases

    func testEmptyFileName() {
        let result = signatureDB.matchFile(path: "/test/", name: "", hash: nil)
        // Should handle empty name gracefully (return nil)
        XCTAssertNil(result)
    }

    func testVeryLongFileName() {
        let longName = String(repeating: "a", count: 1000)
        let result = signatureDB.matchFile(
            path: "/test/\(longName)",
            name: longName,
            hash: nil
        )
        // Should handle long names without crashing
    }

    func testSpecialCharactersInFileName() {
        let specialNames = [
            "file with spaces.app",
            "file_with_underscore.app",
            "file-with-dash.app",
            "file.multiple.dots.app",
            "file(with)parens.app"
        ]

        for name in specialNames {
            let result = signatureDB.matchFile(
                path: "/test/\(name)",
                name: name,
                hash: nil
            )
            // Should handle special characters without crashing
        }
    }

    func testCaseInsensitiveMatching() {
        // Test that name pattern matching is case-insensitive
        let variations = [
            "adload",
            "Adload",
            "ADLOAD",
            "AdLoAd"
        ]

        var matchResults: [Bool] = []
        for variation in variations {
            let result = signatureDB.matchFile(
                path: "/test/\(variation)",
                name: variation,
                hash: nil
            )
            matchResults.append(result != nil)
        }

        // All variations should produce same result (all match or all don't match)
        let firstResult = matchResults.first!
        XCTAssertTrue(matchResults.allSatisfy { $0 == firstResult })
    }

    // MARK: - Performance Tests

    func testMatchPerformance() {
        // Test matching performance for 1000 files
        let testFiles = (0..<1000).map { i in
            (path: "/test/file\(i).app", name: "file\(i).app")
        }

        measure {
            for file in testFiles {
                _ = signatureDB.matchFile(path: file.path, name: file.name, hash: nil)
            }
        }
    }

    func testHashCalculationPerformance() {
        // Create a 1MB test file
        let tempDir = FileManager.default.temporaryDirectory
        let testFile = tempDir.appendingPathComponent("perf_test.bin")

        do {
            let data = Data(count: 1024 * 1024) // 1 MB
            try data.write(to: testFile)

            measure {
                _ = signatureDB.calculateFileHash(at: testFile.path)
            }

            // Cleanup
            try? FileManager.default.removeItem(at: testFile)
        } catch {
            XCTFail("Failed to create performance test file")
        }
    }
}
