import XCTest
import Foundation
@testable import XamrockCLI

final class iOSOrchestratorTests: XCTestCase {

    var orchestrator: iOSOrchestrator!
    var tempDirectory: URL!

    override func setUp() {
        super.setUp()
        orchestrator = iOSOrchestrator()
        tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("iOSOrchestratorTests-\(UUID().uuidString)")
        try! FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
    }

    override func tearDown() {
        if FileManager.default.fileExists(atPath: tempDirectory.path) {
            try? FileManager.default.removeItem(at: tempDirectory)
        }
        super.tearDown()
    }

    // MARK: - Availability Tests

    func testIsAvailableReturnsTrueWhenXcodeInstalled() {
        // When: Checking availability on macOS with Xcode
        let available = orchestrator.isAvailable()

        // Then: Should detect Xcode (we're running tests, so Xcode must be installed)
        XCTAssertTrue(available, "Xcode should be available when running tests")
    }

    // MARK: - Validation Tests

    func testValidateSucceedsWithValidConfiguration() throws {
        // Given: A valid iOS configuration
        let config = CLIConfiguration(
            platform: .iOS,
            appIdentifier: "com.example.MyApp",
            projectPath: tempDirectory,
            steps: 20,
            goal: "Test app",
            outputDirectory: tempDirectory.appendingPathComponent("output")
        )

        // When/Then: Should validate successfully
        XCTAssertNoThrow(try orchestrator.validate(config: config))
    }

    func testValidateThrowsWhenXcodeMissing() throws {
        // Given: An orchestrator that reports Xcode as unavailable
        let unavailableOrchestrator = iOSOrchestrator(xcodeAvailable: false)
        let config = CLIConfiguration(
            platform: .iOS,
            appIdentifier: "com.example.MyApp",
            projectPath: tempDirectory,
            steps: 20,
            goal: "Test",
            outputDirectory: tempDirectory
        )

        // When/Then: Should throw missing dependency error
        XCTAssertThrowsError(try unavailableOrchestrator.validate(config: config)) { error in
            guard let configError = error as? ConfigurationError else {
                XCTFail("Expected ConfigurationError")
                return
            }
            if case .missingDependency(let dep) = configError {
                XCTAssertEqual(dep, "Xcode")
            } else {
                XCTFail("Expected missingDependency error")
            }
        }
    }

    func testValidateThrowsWhenBundleIDInvalid() {
        // Given: Configuration with invalid bundle ID
        let config = CLIConfiguration(
            platform: .iOS,
            appIdentifier: "invalid-bundle-id-!@#",
            projectPath: tempDirectory,
            steps: 20,
            goal: "Test",
            outputDirectory: tempDirectory
        )

        // When/Then: Should throw invalid app identifier error
        XCTAssertThrowsError(try orchestrator.validate(config: config)) { error in
            guard let configError = error as? ConfigurationError else {
                XCTFail("Expected ConfigurationError")
                return
            }
            if case .invalidAppIdentifier = configError {
                // Expected
            } else {
                XCTFail("Expected invalidAppIdentifier error")
            }
        }
    }

    func testValidateAcceptsValidBundleIDs() throws {
        // Given: Valid bundle ID patterns
        let validBundleIDs = [
            "com.example.App",
            "com.company.MyApp",
            "org.test.TestApp123",
            "com.example.app-name"
        ]

        for bundleID in validBundleIDs {
            let config = CLIConfiguration(
                platform: .iOS,
                appIdentifier: bundleID,
                projectPath: tempDirectory,
                steps: 20,
                goal: "Test",
                outputDirectory: tempDirectory
            )

            // When/Then: Should validate successfully
            XCTAssertNoThrow(try orchestrator.validate(config: config), "Failed for bundle ID: \(bundleID)")
        }
    }

    // MARK: - Test File Generation Tests

    func testGenerateTestFileCreatesSwiftFile() throws {
        // Given: A valid configuration
        let config = CLIConfiguration(
            platform: .iOS,
            appIdentifier: "com.example.MyApp",
            projectPath: tempDirectory,
            steps: 20,
            goal: "Explore systematically",
            outputDirectory: tempDirectory.appendingPathComponent("output")
        )

        // When: Generating test file
        let testFileURL = try orchestrator.generateTestFile(config: config)

        // Then: Should create a .swift file
        XCTAssertTrue(testFileURL.path.hasSuffix(".swift"), "Should generate Swift file")
        XCTAssertTrue(FileManager.default.fileExists(atPath: testFileURL.path), "Test file should exist")
    }

    func testGeneratedTestFileContainsCorrectConfiguration() throws {
        // Given: A configuration with specific values
        let config = CLIConfiguration(
            platform: .iOS,
            appIdentifier: "com.example.TestApp",
            projectPath: tempDirectory,
            steps: 30,
            goal: "Test the checkout flow",
            ciMode: true,
            outputDirectory: tempDirectory.appendingPathComponent("results")
        )

        // When: Generating test file
        let testFileURL = try orchestrator.generateTestFile(config: config)

        // Then: Test file should contain configuration values
        let content = try String(contentsOf: testFileURL, encoding: .utf8)
        XCTAssertTrue(content.contains("steps: 30"), "Should contain step count")
        XCTAssertTrue(content.contains("Test the checkout flow"), "Should contain goal")
        XCTAssertTrue(content.contains("import AITestScout"), "Should import AITestScout")
        XCTAssertTrue(content.contains("Scout.explore"), "Should call Scout.explore")
    }

    func testGeneratedTestFileIncludesCIModeSettings() throws {
        // Given: Configuration with CI mode enabled
        let config = CLIConfiguration(
            platform: .iOS,
            appIdentifier: "com.example.App",
            projectPath: tempDirectory,
            steps: 20,
            goal: "CI test",
            ciMode: true,
            outputDirectory: tempDirectory
        )

        // When: Generating test file
        let testFileURL = try orchestrator.generateTestFile(config: config)

        // Then: Should include CI-friendly settings
        let content = try String(contentsOf: testFileURL, encoding: .utf8)
        XCTAssertTrue(content.contains("temperature:") || content.contains("seed:"),
                     "Should include deterministic settings for CI mode")
    }

    // MARK: - Artifact Collection Tests

    func testCollectArtifactsFindsGeneratedFiles() throws {
        // Given: An output directory with AITestScout artifacts
        let outputDir = tempDirectory.appendingPathComponent("scout-results")
        try FileManager.default.createDirectory(at: outputDir, withIntermediateDirectories: true)

        // Create mock artifacts
        let testFile = outputDir.appendingPathComponent("GeneratedTests.swift")
        let reportFile = outputDir.appendingPathComponent("FailureReport.md")
        let dashboardFile = outputDir.appendingPathComponent("dashboard.html")
        let exportFile = outputDir.appendingPathComponent("exploration.json")

        try "test content".write(to: testFile, atomically: true, encoding: .utf8)
        try "report content".write(to: reportFile, atomically: true, encoding: .utf8)
        try "dashboard content".write(to: dashboardFile, atomically: true, encoding: .utf8)
        try "{}".write(to: exportFile, atomically: true, encoding: .utf8)

        // When: Collecting artifacts
        let artifacts = try orchestrator.collectArtifacts(from: outputDir)

        // Then: Should find all artifacts
        XCTAssertTrue(artifacts.count >= 4, "Should find at least 4 artifacts")
        let paths = artifacts.map { $0.lastPathComponent }
        XCTAssertTrue(paths.contains("GeneratedTests.swift"))
        XCTAssertTrue(paths.contains("FailureReport.md"))
        XCTAssertTrue(paths.contains("dashboard.html"))
        XCTAssertTrue(paths.contains("exploration.json"))
    }

    func testCollectArtifactsReturnsEmptyArrayWhenNoArtifacts() throws {
        // Given: An empty output directory
        let outputDir = tempDirectory.appendingPathComponent("empty-results")
        try FileManager.default.createDirectory(at: outputDir, withIntermediateDirectories: true)

        // When: Collecting artifacts
        let artifacts = try orchestrator.collectArtifacts(from: outputDir)

        // Then: Should return empty array
        XCTAssertEqual(artifacts.count, 0, "Should return empty array for directory with no artifacts")
    }

    func testCollectArtifactsHandlesMissingDirectory() {
        // Given: A non-existent directory
        let missingDir = tempDirectory.appendingPathComponent("does-not-exist")

        // When/Then: Should handle gracefully (either throw or return empty)
        // Implementation can choose to throw or return empty array
        do {
            let artifacts = try orchestrator.collectArtifacts(from: missingDir)
            XCTAssertEqual(artifacts.count, 0, "Should return empty for missing directory")
        } catch {
            // Also acceptable to throw
            XCTAssertTrue(error is ConfigurationError || error is CocoaError)
        }
    }

    // MARK: - Integration Test (Validation Flow)

    func testFullValidationFlow() throws {
        // Given: A complete, valid configuration
        let projectDir = tempDirectory.appendingPathComponent("MyApp")
        try FileManager.default.createDirectory(at: projectDir, withIntermediateDirectories: true)

        // Create a mock Xcode project
        let xcodeProj = projectDir.appendingPathComponent("MyApp.xcodeproj")
        try FileManager.default.createDirectory(at: xcodeProj, withIntermediateDirectories: true)

        let config = CLIConfiguration(
            platform: .iOS,
            appIdentifier: "com.example.MyApp",
            projectPath: projectDir,
            targetDevice: "iPhone 15",
            steps: 25,
            goal: "Full integration test",
            ciMode: false,
            outputDirectory: tempDirectory.appendingPathComponent("output"),
            generateDashboard: true,
            failOnIssues: true
        )

        // When: Running full validation
        XCTAssertNoThrow(try orchestrator.validate(config: config))

        // And: Generating test file
        let testFile = try orchestrator.generateTestFile(config: config)
        XCTAssertTrue(FileManager.default.fileExists(atPath: testFile.path))

        // Then: Test file should be valid Swift with all configuration
        let content = try String(contentsOf: testFile, encoding: .utf8)
        XCTAssertTrue(content.contains("import XCTest"))
        XCTAssertTrue(content.contains("import AITestScout"))
        XCTAssertTrue(content.contains("steps: 25"))
        XCTAssertTrue(content.contains("Full integration test"))
    }
}
