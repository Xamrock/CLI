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

    // MARK: - Error Message Extraction Tests

    func testParseResultExtractsTestTargetNotFoundError() {
        // Given: xcodebuild output indicating test target not found (exit code 65)
        let output = """
        xcodebuild: error: Unable to find a destination matching the provided destination specifier:
                { platform:iOS Simulator }

        ** TEST FAILED **
        """
        let config = CLIConfiguration(
            platform: .iOS,
            appIdentifier: "com.example.MyApp",
            projectPath: tempDirectory,
            steps: 20,
            goal: "Test",
            outputDirectory: tempDirectory
        )

        // When: Parsing result with exit code 65
        let runner = XcodebuildRunner()
        let result = runner.parseResult(
            output: output,
            exitCode: 65,
            startTime: Date(),
            config: config
        )

        // Then: Should capture error details
        XCTAssertEqual(result.exitCode, 65)
        XCTAssertFalse(result.wasSuccessful)
        XCTAssertNotNil(result.errorMessage)
        XCTAssertTrue(result.errorMessage?.contains("destination") ?? false)
    }

    func testParseResultExtractsSchemeNotFoundError() {
        // Given: xcodebuild output indicating scheme not found
        let output = """
        xcodebuild: error: Scheme MyApp is not currently configured for the test action.
        ** TEST FAILED **
        """
        let config = CLIConfiguration(
            platform: .iOS,
            appIdentifier: "com.example.MyApp",
            projectPath: tempDirectory,
            steps: 20,
            goal: "Test",
            outputDirectory: tempDirectory
        )

        // When: Parsing result
        let runner = XcodebuildRunner()
        let result = runner.parseResult(
            output: output,
            exitCode: 70,
            startTime: Date(),
            config: config
        )

        // Then: Should capture scheme error
        XCTAssertNotNil(result.errorMessage)
        XCTAssertTrue(result.errorMessage?.contains("Scheme") ?? false)
    }

    func testParseResultExtractsBuildFailedError() {
        // Given: xcodebuild output indicating build failed
        let output = """
        The following build commands failed:
                CompileSwift normal arm64 Compiling TestFile.swift
        (1 failure)
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

        // When: Parsing result
        let runner = XcodebuildRunner()
        let result = runner.parseResult(
            output: output,
            exitCode: 65,
            startTime: Date(),
            config: config
        )

        // Then: Should capture build error
        XCTAssertNotNil(result.errorMessage)
        XCTAssertTrue(result.errorMessage?.contains("BUILD FAILED") ?? false)
    }

    func testParseResultProvidesSuggestionForExitCode65() {
        // Given: Exit code 65 (general build/test failure)
        let output = "** BUILD FAILED **"
        let config = CLIConfiguration(
            platform: .iOS,
            appIdentifier: "com.example.MyApp",
            projectPath: tempDirectory,
            steps: 20,
            goal: "Test",
            outputDirectory: tempDirectory
        )

        // When: Parsing result
        let runner = XcodebuildRunner()
        let result = runner.parseResult(
            output: output,
            exitCode: 65,
            startTime: Date(),
            config: config
        )

        // Then: Should provide suggestion
        XCTAssertNotNil(result.errorSuggestion)
        XCTAssertFalse(result.errorSuggestion?.isEmpty ?? true)
    }

    func testParseResultCapturesFullErrorOutput() {
        // Given: Multi-line error output
        let output = """
        xcodebuild: error: Unable to find a destination
        Error Domain=IDETestOperationsObserverErrorDomain Code=14
        Error: Test target not found
        ** TEST FAILED **
        """
        let config = CLIConfiguration(
            platform: .iOS,
            appIdentifier: "com.example.MyApp",
            projectPath: tempDirectory,
            steps: 20,
            goal: "Test",
            outputDirectory: tempDirectory
        )

        // When: Parsing result
        let runner = XcodebuildRunner()
        let result = runner.parseResult(
            output: output,
            exitCode: 65,
            startTime: Date(),
            config: config
        )

        // Then: Should preserve full error context
        XCTAssertNotNil(result.errorMessage)
        // Error message should be extractable from full output
    }
}
