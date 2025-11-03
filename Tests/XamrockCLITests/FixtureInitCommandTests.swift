import XCTest
import Foundation
import ArgumentParser
@testable import XamrockCLI

final class FixtureInitCommandTests: XCTestCase {

    var tempDirectory: URL!

    override func setUp() {
        super.setUp()
        tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("FixtureInitCommandTests-\(UUID().uuidString)")
        try! FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
    }

    override func tearDown() {
        if FileManager.default.fileExists(atPath: tempDirectory.path) {
            try? FileManager.default.removeItem(at: tempDirectory)
        }
        super.tearDown()
    }

    // MARK: - Argument Parsing Tests

    func testParseMinimalArguments() throws {
        // Given: Minimal command line arguments
        let args: [String] = []

        // When: Parsing command
        let command = try FixtureInitCommand.parse(args)

        // Then: Should use defaults
        XCTAssertNil(command.name)
        XCTAssertNil(command.outputPath)
        XCTAssertEqual(command.template, .standard)
    }

    func testParseFullArguments() throws {
        // Given: All command line arguments
        let outputPath = tempDirectory.appendingPathComponent("my-fixture.json").path
        let args = [
            "--name", "Login Flow",
            "--output", outputPath,
            "--template", "comprehensive"
        ]

        // When: Parsing command
        let command = try FixtureInitCommand.parse(args)

        // Then: Should parse all arguments correctly
        XCTAssertEqual(command.name, "Login Flow")
        XCTAssertEqual(command.outputPath, outputPath)
        XCTAssertEqual(command.template, .comprehensive)
    }

    func testParseTemplateOptions() throws {
        // Given: Different template options
        let templates = ["minimal", "standard", "comprehensive"]

        for templateName in templates {
            // When: Parsing command with template
            let args = ["--template", templateName]
            let command = try FixtureInitCommand.parse(args)

            // Then: Should parse template correctly
            XCTAssertEqual(command.template.rawValue, templateName)
        }
    }

    // MARK: - File Generation Tests

    func testGenerateMinimalFixture() throws {
        // Given: Init command with minimal template
        let outputPath = tempDirectory.appendingPathComponent("minimal.json")
        let args = [
            "--name", "Test Fixture",
            "--output", outputPath.path,
            "--template", "minimal"
        ]
        let command = try FixtureInitCommand.parse(args)

        // When: Generating fixture
        try command.generateFixture(at: outputPath)

        // Then: File should be created with valid JSON
        XCTAssertTrue(FileManager.default.fileExists(atPath: outputPath.path))

        let data = try Data(contentsOf: outputPath)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]

        XCTAssertNotNil(json)
        XCTAssertEqual(json?["version"] as? String, "1.0")
        XCTAssertEqual(json?["name"] as? String, "Test Fixture")
        XCTAssertNotNil(json?["patterns"])
        XCTAssertNotNil(json?["defaults"])
    }

    func testGenerateStandardFixture() throws {
        // Given: Init command with standard template
        let outputPath = tempDirectory.appendingPathComponent("standard.json")
        let args = [
            "--name", "Standard Fixture",
            "--output", outputPath.path,
            "--template", "standard"
        ]
        let command = try FixtureInitCommand.parse(args)

        // When: Generating fixture
        try command.generateFixture(at: outputPath)

        // Then: File should contain common patterns
        let data = try Data(contentsOf: outputPath)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]

        XCTAssertNotNil(json)

        let patterns = json?["patterns"] as? [String: String]
        XCTAssertNotNil(patterns)
        XCTAssertTrue((patterns?.count ?? 0) > 0, "Standard template should have patterns")

        let defaults = json?["defaults"] as? [String: String]
        XCTAssertNotNil(defaults)
        XCTAssertTrue((defaults?.count ?? 0) > 0, "Standard template should have defaults")
    }

    func testGenerateComprehensiveFixture() throws {
        // Given: Init command with comprehensive template
        let outputPath = tempDirectory.appendingPathComponent("comprehensive.json")
        let args = [
            "--name", "Comprehensive Fixture",
            "--output", outputPath.path,
            "--template", "comprehensive"
        ]
        let command = try FixtureInitCommand.parse(args)

        // When: Generating fixture
        try command.generateFixture(at: outputPath)

        // Then: File should contain extensive examples
        let data = try Data(contentsOf: outputPath)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]

        XCTAssertNotNil(json)

        let patterns = json?["patterns"] as? [String: String]
        let defaults = json?["defaults"] as? [String: String]

        // Comprehensive should have more entries than standard
        XCTAssertTrue((patterns?.count ?? 0) > 5, "Comprehensive template should have many patterns")
        XCTAssertTrue((defaults?.count ?? 0) > 5, "Comprehensive template should have many defaults")
    }

    func testDefaultOutputPath() throws {
        // Given: Init command without output path
        let args = ["--name", "Test"]
        let command = try FixtureInitCommand.parse(args)

        // When: Getting default output path
        let defaultPath = command.resolveOutputPath()

        // Then: Should default to fixtures/default.json
        XCTAssertTrue(defaultPath.path.contains("fixtures"))
        XCTAssertTrue(defaultPath.path.hasSuffix(".json"))
    }

    func testCreateDirectoryIfNeeded() throws {
        // Given: Output path in non-existent directory
        let nestedPath = tempDirectory
            .appendingPathComponent("nested")
            .appendingPathComponent("directories")
            .appendingPathComponent("fixture.json")

        let args = ["--output", nestedPath.path]
        let command = try FixtureInitCommand.parse(args)

        // When: Generating fixture
        try command.generateFixture(at: nestedPath)

        // Then: Directories should be created
        XCTAssertTrue(FileManager.default.fileExists(atPath: nestedPath.path))
    }

    func testOverwriteExistingFile() throws {
        // Given: Existing fixture file
        let outputPath = tempDirectory.appendingPathComponent("existing.json")
        try "old content".write(to: outputPath, atomically: true, encoding: .utf8)

        let args = [
            "--name", "New Fixture",
            "--output", outputPath.path,
            "--template", "minimal"
        ]
        let command = try FixtureInitCommand.parse(args)

        // When: Generating fixture (should overwrite)
        try command.generateFixture(at: outputPath)

        // Then: File should be updated with new content
        let data = try Data(contentsOf: outputPath)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]

        XCTAssertEqual(json?["name"] as? String, "New Fixture")
    }

    // MARK: - Validation Tests

    func testValidJSONStructure() throws {
        // Given: Generated fixture
        let outputPath = tempDirectory.appendingPathComponent("valid.json")
        let args = [
            "--name", "Valid Fixture",
            "--output", outputPath.path
        ]
        let command = try FixtureInitCommand.parse(args)

        // When: Generating fixture
        try command.generateFixture(at: outputPath)

        // Then: JSON should be valid and properly formatted
        let data = try Data(contentsOf: outputPath)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]

        XCTAssertNotNil(json?["version"])
        XCTAssertNotNil(json?["patterns"])
        XCTAssertNotNil(json?["defaults"])
        XCTAssertNotNil(json?["fallbackMode"])
    }

    func testGeneratedFixtureHasDescription() throws {
        // Given: Init command with name
        let outputPath = tempDirectory.appendingPathComponent("described.json")
        let args = [
            "--name", "Test Fixture",
            "--output", outputPath.path
        ]
        let command = try FixtureInitCommand.parse(args)

        // When: Generating fixture
        try command.generateFixture(at: outputPath)

        // Then: Should include description
        let data = try Data(contentsOf: outputPath)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]

        XCTAssertNotNil(json?["description"])
    }
}
