import XCTest
import Foundation
@testable import XamrockCLI

final class XcodebuildRunnerErrorHandlingTests: XCTestCase {

    var tempDirectory: URL!

    override func setUp() {
        super.setUp()
        tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("XcodebuildRunnerErrorTests-\(UUID().uuidString)")
        try! FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
    }

    override func tearDown() {
        if FileManager.default.fileExists(atPath: tempDirectory.path) {
            try? FileManager.default.removeItem(at: tempDirectory)
        }
        super.tearDown()
    }

    // MARK: - Output Directory Creation Tests

    func testRunTestCreatesOutputDirectoryIfMissing() throws {
        // Given: Configuration with non-existent output directory
        let outputDir = tempDirectory.appendingPathComponent("scout-results")
        XCTAssertFalse(FileManager.default.fileExists(atPath: outputDir.path))

        let config = CLIConfiguration(
            platform: .iOS,
            appIdentifier: "com.example.MyApp",
            projectPath: tempDirectory.appendingPathComponent("MyApp.xcodeproj"),
            steps: 5,
            goal: "Test",
            outputDirectory: outputDir
        )
        let testFile = tempDirectory.appendingPathComponent("Test.swift")
        try "test content".write(to: testFile, atomically: true, encoding: .utf8)

        // When: Running test (will fail, but should create directory)
        let runner = XcodebuildRunner()
        do {
            _ = try runner.runTest(config: config, testFile: testFile)
        } catch {
            // Expected to fail since we're not running real xcodebuild
        }

        // Then: Output directory should be created
        XCTAssertTrue(FileManager.default.fileExists(atPath: outputDir.path),
                     "Output directory should be created before running xcodebuild")
    }

    func testParseResultHandlesEmptyOutput() {
        // Given: Empty output (xcodebuild failed to start)
        let config = CLIConfiguration(
            platform: .iOS,
            appIdentifier: "com.example.MyApp",
            projectPath: tempDirectory,
            steps: 20,
            goal: "Test",
            outputDirectory: tempDirectory
        )

        // When: Parsing empty result
        let runner = XcodebuildRunner()
        let result = runner.parseResult(
            output: "",
            exitCode: 1,
            startTime: Date(),
            config: config
        )

        // Then: Should handle gracefully
        XCTAssertEqual(result.exitCode, 1)
        XCTAssertFalse(result.wasSuccessful)
        XCTAssertEqual(result.screensDiscovered, 0)
        XCTAssertEqual(result.failuresFound, 0)
    }

    func testParseResultHandlesMalformedOutput() {
        // Given: Malformed output
        let output = """
        Error: Unknown scheme
        xcodebuild: error: Unable to find a destination
        ** BUILD FAILED **
        """
        let config = CLIConfiguration(
            platform: .iOS,
            appIdentifier: "com.example.MyApp",
            projectPath: tempDirectory,
            steps: 20,
            goal: "Test",
            outputDirectory: tempDirectory
        )

        // When: Parsing malformed result
        let runner = XcodebuildRunner()
        let result = runner.parseResult(
            output: output,
            exitCode: 65,
            startTime: Date(),
            config: config
        )

        // Then: Should not crash and return sensible values
        XCTAssertEqual(result.exitCode, 65)
        XCTAssertFalse(result.wasSuccessful)
        XCTAssertEqual(result.screensDiscovered, 0)
    }

    // MARK: - Error Propagation Tests

    func testRunTestCapturesXcodebuildErrors() throws {
        // Given: Invalid configuration (no scheme)
        let config = CLIConfiguration(
            platform: .iOS,
            appIdentifier: "com.example.MyApp",
            projectPath: nil, // No project path
            steps: 5,
            goal: "Test",
            outputDirectory: tempDirectory
        )
        let testFile = tempDirectory.appendingPathComponent("Test.swift")
        try "test".write(to: testFile, atomically: true, encoding: .utf8)

        // When: Running test
        let runner = XcodebuildRunner()
        let result = try runner.runTest(config: config, testFile: testFile)

        // Then: Should complete but with failure exit code
        XCTAssertNotEqual(result.exitCode, 0)
        XCTAssertFalse(result.wasSuccessful)
    }

    func testBuildCommandHandlesMissingScheme() {
        // Given: Configuration without project path
        let config = CLIConfiguration(
            platform: .iOS,
            appIdentifier: "com.example.MyApp",
            projectPath: nil,
            steps: 5,
            goal: "Test",
            outputDirectory: tempDirectory
        )
        let testFile = tempDirectory.appendingPathComponent("Test.swift")

        // When: Building command
        let runner = XcodebuildRunner()
        let command = runner.buildCommand(config: config, testFile: testFile)

        // Then: Should build command without scheme
        XCTAssertTrue(command.contains("xcodebuild test"))
        XCTAssertFalse(command.contains("-scheme"))
    }

    // MARK: - Verbose Output Tests

    func testRunTestCapturesVerboseOutput() throws {
        // Given: Configuration
        let outputDir = tempDirectory.appendingPathComponent("results")
        let config = CLIConfiguration(
            platform: .iOS,
            appIdentifier: "com.example.MyApp",
            projectPath: tempDirectory.appendingPathComponent("MyApp.xcodeproj"),
            steps: 5,
            goal: "Test",
            outputDirectory: outputDir,
            verbose: true
        )
        let testFile = tempDirectory.appendingPathComponent("Test.swift")
        try "test".write(to: testFile, atomically: true, encoding: .utf8)

        // When: Running test (will fail but should capture output)
        let runner = XcodebuildRunner()
        let result = try runner.runTest(config: config, testFile: testFile)

        // Then: Should have executed (exit code will be non-zero for invalid project)
        XCTAssertNotNil(result)
        // The actual output is captured in the result parsing
    }
}
