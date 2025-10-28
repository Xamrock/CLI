import XCTest
import Foundation
@testable import XamrockCLI

final class ManifestGeneratorTests: XCTestCase {

    var tempDirectory: URL!

    override func setUp() {
        super.setUp()
        tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("ManifestGeneratorTests-\(UUID().uuidString)")
        try! FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
    }

    override func tearDown() {
        if FileManager.default.fileExists(atPath: tempDirectory.path) {
            try? FileManager.default.removeItem(at: tempDirectory)
        }
        super.tearDown()
    }

    // MARK: - Manifest Generation Tests

    func testGenerateManifestWithBasicInfo() throws {
        // Given: Test result and artifacts
        let result = TestExecutionResult(
            exitCode: 0,
            outputDirectory: tempDirectory,
            duration: 125.5,
            screensDiscovered: 15,
            failuresFound: 0
        )
        let artifacts = [
            tempDirectory.appendingPathComponent("GeneratedTests.swift"),
            tempDirectory.appendingPathComponent("dashboard.html")
        ]
        let config = CLIConfiguration(
            platform: .iOS,
            appIdentifier: "com.example.MyApp",
            projectPath: URL(fileURLWithPath: "/path/to/project"),
            steps: 30,
            goal: "Test checkout",
            outputDirectory: tempDirectory
        )

        // When: Generating manifest
        let generator = ManifestGenerator()
        let manifest = try generator.generateManifest(
            config: config,
            result: result,
            artifacts: artifacts
        )

        // Then: Should include basic info
        XCTAssertEqual(manifest.appIdentifier, "com.example.MyApp")
        XCTAssertEqual(manifest.platform, "iOS")
        XCTAssertEqual(manifest.steps, 30)
        XCTAssertEqual(manifest.exitCode, 0)
    }

    func testGenerateManifestWithMetrics() throws {
        // Given: Test result with metrics
        let result = TestExecutionResult(
            exitCode: 0,
            outputDirectory: tempDirectory,
            duration: 85.3,
            screensDiscovered: 12,
            failuresFound: 0
        )
        let config = CLIConfiguration(
            platform: .iOS,
            appIdentifier: "com.example.MyApp",
            projectPath: URL(fileURLWithPath: "/path/to/project"),
            steps: 20,
            goal: "Test",
            outputDirectory: tempDirectory
        )

        // When: Generating manifest
        let generator = ManifestGenerator()
        let manifest = try generator.generateManifest(
            config: config,
            result: result,
            artifacts: []
        )

        // Then: Should include metrics
        XCTAssertEqual(manifest.duration, 85.3, accuracy: 0.1)
        XCTAssertEqual(manifest.screensDiscovered, 12)
        XCTAssertEqual(manifest.failuresFound, 0)
    }

    func testGenerateManifestWithArtifactList() throws {
        // Given: Multiple artifacts
        let artifacts = [
            tempDirectory.appendingPathComponent("GeneratedTests.swift"),
            tempDirectory.appendingPathComponent("FailureReport.md"),
            tempDirectory.appendingPathComponent("dashboard.html"),
            tempDirectory.appendingPathComponent("exploration.json")
        ]
        let result = TestExecutionResult(
            exitCode: 0,
            outputDirectory: tempDirectory,
            duration: 100,
            screensDiscovered: 10,
            failuresFound: 0
        )
        let config = CLIConfiguration(
            platform: .iOS,
            appIdentifier: "com.example.MyApp",
            projectPath: URL(fileURLWithPath: "/path/to/project"),
            steps: 20,
            goal: "Test",
            outputDirectory: tempDirectory
        )

        // When: Generating manifest
        let generator = ManifestGenerator()
        let manifest = try generator.generateManifest(
            config: config,
            result: result,
            artifacts: artifacts
        )

        // Then: Should list all artifacts
        XCTAssertEqual(manifest.artifacts.count, 4)
        XCTAssertTrue(manifest.artifacts.contains("GeneratedTests.swift"))
        XCTAssertTrue(manifest.artifacts.contains("FailureReport.md"))
        XCTAssertTrue(manifest.artifacts.contains("dashboard.html"))
        XCTAssertTrue(manifest.artifacts.contains("exploration.json"))
    }

    func testGenerateManifestIncludesTimestamp() throws {
        // Given: Configuration and result
        let result = TestExecutionResult(
            exitCode: 0,
            outputDirectory: tempDirectory,
            duration: 50,
            screensDiscovered: 5,
            failuresFound: 0
        )
        let config = CLIConfiguration(
            platform: .iOS,
            appIdentifier: "com.example.MyApp",
            projectPath: URL(fileURLWithPath: "/path/to/project"),
            steps: 20,
            goal: "Test",
            outputDirectory: tempDirectory
        )

        // When: Generating manifest
        let generator = ManifestGenerator()
        let manifest = try generator.generateManifest(
            config: config,
            result: result,
            artifacts: []
        )

        // Then: Should include timestamp
        XCTAssertNotNil(manifest.timestamp)
        XCTAssertGreaterThan(manifest.timestamp.timeIntervalSinceNow, -5) // Within last 5 seconds
    }

    // MARK: - JSON Encoding Tests

    func testManifestEncodesToJSON() throws {
        // Given: Manifest
        let result = TestExecutionResult(
            exitCode: 0,
            outputDirectory: tempDirectory,
            duration: 100,
            screensDiscovered: 10,
            failuresFound: 0
        )
        let config = CLIConfiguration(
            platform: .iOS,
            appIdentifier: "com.example.MyApp",
            projectPath: URL(fileURLWithPath: "/path/to/project"),
            steps: 20,
            goal: "Test",
            outputDirectory: tempDirectory
        )
        let generator = ManifestGenerator()
        let manifest = try generator.generateManifest(
            config: config,
            result: result,
            artifacts: []
        )

        // When: Encoding to JSON
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let jsonData = try encoder.encode(manifest)

        // Then: Should produce valid JSON
        XCTAssertNotNil(jsonData)
        let jsonString = String(data: jsonData, encoding: .utf8)
        XCTAssertNotNil(jsonString)
        XCTAssertTrue(jsonString!.contains("com.example.MyApp"))
    }

    // MARK: - File Writing Tests

    func testSaveManifestToFile() throws {
        // Given: Manifest
        let result = TestExecutionResult(
            exitCode: 0,
            outputDirectory: tempDirectory,
            duration: 100,
            screensDiscovered: 10,
            failuresFound: 0
        )
        let config = CLIConfiguration(
            platform: .iOS,
            appIdentifier: "com.example.MyApp",
            projectPath: URL(fileURLWithPath: "/path/to/project"),
            steps: 20,
            goal: "Test",
            outputDirectory: tempDirectory
        )
        let generator = ManifestGenerator()
        let manifest = try generator.generateManifest(
            config: config,
            result: result,
            artifacts: []
        )

        // When: Saving to file
        let manifestFile = tempDirectory.appendingPathComponent("manifest.json")
        try generator.saveManifest(manifest, to: manifestFile)

        // Then: File should exist and be valid JSON
        XCTAssertTrue(FileManager.default.fileExists(atPath: manifestFile.path))
        let data = try Data(contentsOf: manifestFile)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(ExplorationManifest.self, from: data)
        XCTAssertEqual(decoded.appIdentifier, "com.example.MyApp")
    }

    func testManifestIncludesVersion() throws {
        // Given: Manifest
        let result = TestExecutionResult(
            exitCode: 0,
            outputDirectory: tempDirectory,
            duration: 100,
            screensDiscovered: 10,
            failuresFound: 0
        )
        let config = CLIConfiguration(
            platform: .iOS,
            appIdentifier: "com.example.MyApp",
            projectPath: URL(fileURLWithPath: "/path/to/project"),
            steps: 20,
            goal: "Test",
            outputDirectory: tempDirectory
        )

        // When: Generating manifest
        let generator = ManifestGenerator()
        let manifest = try generator.generateManifest(
            config: config,
            result: result,
            artifacts: []
        )

        // Then: Should include version
        XCTAssertNotNil(manifest.version)
        XCTAssertFalse(manifest.version.isEmpty)
    }
}
