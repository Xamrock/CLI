import XCTest
import Foundation
import ArgumentParser
@testable import XamrockCLI

final class FixtureValidateCommandTests: XCTestCase {

    var tempDirectory: URL!

    override func setUp() {
        super.setUp()
        tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("FixtureValidateCommandTests-\(UUID().uuidString)")
        try! FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
    }

    override func tearDown() {
        if FileManager.default.fileExists(atPath: tempDirectory.path) {
            try? FileManager.default.removeItem(at: tempDirectory)
        }
        super.tearDown()
    }

    // MARK: - Argument Parsing Tests

    func testParseFixturePath() throws {
        // Given: Fixture path argument
        let fixturePath = tempDirectory.appendingPathComponent("test.json").path
        let args = ["--fixture", fixturePath]

        // When: Parsing command
        let command = try FixtureValidateCommand.parse(args)

        // Then: Should parse path correctly
        XCTAssertEqual(command.fixturePath, fixturePath)
    }

    func testParseStrictMode() throws {
        // Given: Strict flag
        let args = ["--fixture", "test.json", "--strict"]

        // When: Parsing command
        let command = try FixtureValidateCommand.parse(args)

        // Then: Should enable strict mode
        XCTAssertTrue(command.strict)
    }

    // MARK: - Valid Fixture Tests

    func testValidateValidFixture() throws {
        // Given: Valid fixture file
        let fixturePath = tempDirectory.appendingPathComponent("valid.json")
        let validJSON = """
        {
          "version": "1.0",
          "name": "Test Fixture",
          "patterns": {
            "emailField": "test@example.com"
          },
          "defaults": {
            "email": "default@example.com"
          },
          "fallbackMode": "aiGenerated"
        }
        """
        try validJSON.write(to: fixturePath, atomically: true, encoding: .utf8)

        // When: Validating fixture
        let validator = FixtureValidator()
        let result = try validator.validate(fixtureAt: fixturePath)

        // Then: Should pass validation
        XCTAssertTrue(result.isValid)
        XCTAssertTrue(result.errors.isEmpty)
        XCTAssertTrue(result.warnings.isEmpty)
    }

    func testValidateFixtureWithAllPatternTypes() throws {
        // Given: Fixture with all pattern types
        let fixturePath = tempDirectory.appendingPathComponent("patterns.json")
        let patternsJSON = """
        {
          "version": "1.0",
          "patterns": {
            "emailField": "test@example.com",
            "pattern:contains:password": "SecurePass123",
            "pattern:regex:card.*number": "4242424242424242",
            "pattern:placeholder:Enter email": "user@test.com",
            "pattern:label:Phone": "555-0123",
            "semantic:email": "demo@test.com",
            "screen:login|field:email": "admin@app.com"
          },
          "defaults": {},
          "fallbackMode": "aiGenerated"
        }
        """
        try patternsJSON.write(to: fixturePath, atomically: true, encoding: .utf8)

        // When: Validating fixture
        let validator = FixtureValidator()
        let result = try validator.validate(fixtureAt: fixturePath)

        // Then: Should recognize all pattern types
        XCTAssertTrue(result.isValid)
        XCTAssertTrue(result.errors.isEmpty)
    }

    // MARK: - Invalid JSON Tests

    func testValidateInvalidJSON() throws {
        // Given: Invalid JSON file
        let fixturePath = tempDirectory.appendingPathComponent("invalid.json")
        try "{ invalid json }".write(to: fixturePath, atomically: true, encoding: .utf8)

        // When/Then: Should throw or return invalid result
        let validator = FixtureValidator()
        let result = try validator.validate(fixtureAt: fixturePath)

        XCTAssertFalse(result.isValid)
        XCTAssertFalse(result.errors.isEmpty)
        XCTAssertTrue(result.errors.contains { $0.contains("JSON") })
    }

    func testValidateMissingFile() throws {
        // Given: Non-existent file
        let fixturePath = tempDirectory.appendingPathComponent("missing.json")

        // When/Then: Should return error about missing file
        let validator = FixtureValidator()
        let result = try validator.validate(fixtureAt: fixturePath)

        XCTAssertFalse(result.isValid)
        XCTAssertTrue(result.errors.contains { $0.contains("not found") || $0.contains("exist") })
    }

    // MARK: - Schema Validation Tests

    func testValidateMissingVersion() throws {
        // Given: Fixture without version
        let fixturePath = tempDirectory.appendingPathComponent("no-version.json")
        let json = """
        {
          "patterns": {},
          "defaults": {}
        }
        """
        try json.write(to: fixturePath, atomically: true, encoding: .utf8)

        // When: Validating fixture
        let validator = FixtureValidator()
        let result = try validator.validate(fixtureAt: fixturePath)

        // Then: Should have warning about missing version
        XCTAssertFalse(result.warnings.isEmpty)
        XCTAssertTrue(result.warnings.contains { $0.contains("version") })
    }

    func testValidateInvalidSemanticType() throws {
        // Given: Fixture with invalid semantic type
        let fixturePath = tempDirectory.appendingPathComponent("bad-semantic.json")
        let json = """
        {
          "version": "1.0",
          "patterns": {
            "semantic:invalidType": "value"
          },
          "defaults": {},
          "fallbackMode": "aiGenerated"
        }
        """
        try json.write(to: fixturePath, atomically: true, encoding: .utf8)

        // When: Validating fixture
        let validator = FixtureValidator()
        let result = try validator.validate(fixtureAt: fixturePath)

        // Then: Should have error about invalid semantic type
        XCTAssertFalse(result.isValid)
        XCTAssertTrue(result.errors.contains { $0.contains("semantic") || $0.contains("invalidType") })
    }

    func testValidateInvalidRegex() throws {
        // Given: Fixture with invalid regex pattern
        let fixturePath = tempDirectory.appendingPathComponent("bad-regex.json")
        let json = """
        {
          "version": "1.0",
          "patterns": {
            "pattern:regex:[invalid(regex": "value"
          },
          "defaults": {},
          "fallbackMode": "aiGenerated"
        }
        """
        try json.write(to: fixturePath, atomically: true, encoding: .utf8)

        // When: Validating fixture
        let validator = FixtureValidator()
        let result = try validator.validate(fixtureAt: fixturePath)

        // Then: Should have error about invalid regex
        XCTAssertFalse(result.isValid)
        XCTAssertTrue(result.errors.contains { $0.contains("regex") })
    }

    func testValidateInvalidFallbackMode() throws {
        // Given: Fixture with invalid fallback mode
        let fixturePath = tempDirectory.appendingPathComponent("bad-fallback.json")
        let json = """
        {
          "version": "1.0",
          "patterns": {},
          "defaults": {},
          "fallbackMode": "invalidMode"
        }
        """
        try json.write(to: fixturePath, atomically: true, encoding: .utf8)

        // When: Validating fixture
        let validator = FixtureValidator()
        let result = try validator.validate(fixtureAt: fixturePath)

        // Then: Should have error about invalid fallback mode
        XCTAssertFalse(result.isValid)
        XCTAssertTrue(result.errors.contains { $0.contains("fallback") })
    }

    // MARK: - Warning Tests

    func testValidateEmptyPatterns() throws {
        // Given: Fixture with no patterns
        let fixturePath = tempDirectory.appendingPathComponent("empty-patterns.json")
        let json = """
        {
          "version": "1.0",
          "patterns": {},
          "defaults": {},
          "fallbackMode": "aiGenerated"
        }
        """
        try json.write(to: fixturePath, atomically: true, encoding: .utf8)

        // When: Validating fixture
        let validator = FixtureValidator()
        let result = try validator.validate(fixtureAt: fixturePath)

        // Then: Should have warning about empty patterns
        XCTAssertTrue(result.isValid) // Still valid, just not useful
        XCTAssertFalse(result.warnings.isEmpty)
        XCTAssertTrue(result.warnings.contains { $0.contains("empty") || $0.contains("pattern") })
    }

    func testValidateDuplicatePatterns() throws {
        // Given: Fixture with potentially conflicting patterns
        let fixturePath = tempDirectory.appendingPathComponent("duplicate.json")
        let json = """
        {
          "version": "1.0",
          "patterns": {
            "emailField": "test1@example.com",
            "pattern:contains:email": "test2@example.com",
            "semantic:email": "test3@example.com"
          },
          "defaults": {},
          "fallbackMode": "aiGenerated"
        }
        """
        try json.write(to: fixturePath, atomically: true, encoding: .utf8)

        // When: Validating fixture
        let validator = FixtureValidator()
        let result = try validator.validate(fixtureAt: fixturePath)

        // Then: Should warn about potential overlaps
        XCTAssertTrue(result.isValid)
        // Note: This is informational, not necessarily a warning
    }

    func testValidateEnvironmentVariableReferences() throws {
        // Given: Fixture with environment variables
        let fixturePath = tempDirectory.appendingPathComponent("env-vars.json")
        let json = """
        {
          "version": "1.0",
          "patterns": {
            "passwordField": "${TEST_PASSWORD}",
            "apiKeyField": "${API_KEY}"
          },
          "defaults": {},
          "fallbackMode": "aiGenerated"
        }
        """
        try json.write(to: fixturePath, atomically: true, encoding: .utf8)

        // When: Validating fixture
        let validator = FixtureValidator()
        let result = try validator.validate(fixtureAt: fixturePath)

        // Then: Should recognize env vars and warn if not set
        XCTAssertTrue(result.isValid)
        // May have warnings about unset environment variables
    }

    // MARK: - Strict Mode Tests

    func testStrictModeFailsOnWarnings() throws {
        // Given: Fixture with warnings (empty patterns)
        let fixturePath = tempDirectory.appendingPathComponent("warnings.json")
        let json = """
        {
          "version": "1.0",
          "patterns": {},
          "defaults": {},
          "fallbackMode": "aiGenerated"
        }
        """
        try json.write(to: fixturePath, atomically: true, encoding: .utf8)

        // When: Validating in strict mode
        let validator = FixtureValidator()
        let result = try validator.validate(fixtureAt: fixturePath, strict: true)

        // Then: Should fail due to warnings in strict mode
        XCTAssertFalse(result.isValid)
    }

    func testValidationResultSummary() throws {
        // Given: Validation result with mixed issues
        let result = ValidationResult(
            isValid: false,
            errors: ["Error 1", "Error 2"],
            warnings: ["Warning 1"]
        )

        // When: Getting summary
        let summary = result.summary

        // Then: Should include counts
        XCTAssertTrue(summary.contains("2"))
        XCTAssertTrue(summary.contains("error"))
        XCTAssertTrue(summary.contains("1"))
        XCTAssertTrue(summary.contains("warning"))
    }
}
