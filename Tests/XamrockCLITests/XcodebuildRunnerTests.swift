import XCTest
import Foundation
@testable import XamrockCLI

final class XcodebuildRunnerTests: XCTestCase {

    var tempDirectory: URL!

    override func setUp() {
        super.setUp()
        tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("XcodebuildRunnerTests-\(UUID().uuidString)")
        try! FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
    }

    override func tearDown() {
        if FileManager.default.fileExists(atPath: tempDirectory.path) {
            try? FileManager.default.removeItem(at: tempDirectory)
        }
        super.tearDown()
    }

    // MARK: - Command Building Tests

    func testBuildXcodebuildCommandWithMinimalConfig() throws {
        // Given: Configuration with minimal options
        let config = CLIConfiguration(
            platform: .iOS,
            appIdentifier: "com.example.MyApp",
            projectPath: URL(fileURLWithPath: "/path/to/MyApp.xcodeproj"),
            steps: 20,
            goal: "Test",
            outputDirectory: tempDirectory
        )
        let testFile = tempDirectory.appendingPathComponent("Test.swift")

        // When: Building xcodebuild command
        let runner = XcodebuildRunner()
        let command = runner.buildCommand(config: config, testFile: testFile)

        // Then: Should include essential xcodebuild arguments
        XCTAssertTrue(command.contains("xcodebuild"))
        XCTAssertTrue(command.contains("test"))
        XCTAssertTrue(command.contains("-project"))
        XCTAssertTrue(command.contains("MyApp.xcodeproj"))
        XCTAssertTrue(command.contains("-scheme"))
        XCTAssertTrue(command.contains("-destination"))
    }

    func testBuildCommandWithExplicitDevice() throws {
        // Given: Configuration with explicit device
        let config = CLIConfiguration(
            platform: .iOS,
            appIdentifier: "com.example.MyApp",
            projectPath: URL(fileURLWithPath: "/path/to/MyApp.xcodeproj"),
            targetDevice: "iPhone 15 Pro",
            steps: 20,
            goal: "Test",
            outputDirectory: tempDirectory
        )
        let testFile = tempDirectory.appendingPathComponent("Test.swift")

        // When: Building command
        let runner = XcodebuildRunner()
        let command = runner.buildCommand(config: config, testFile: testFile)

        // Then: Should include device in destination
        XCTAssertTrue(command.contains("iPhone 15 Pro"))
    }

    func testBuildCommandWithOSVersion() throws {
        // Given: Configuration with OS version
        let config = CLIConfiguration(
            platform: .iOS,
            appIdentifier: "com.example.MyApp",
            projectPath: URL(fileURLWithPath: "/path/to/MyApp.xcodeproj"),
            osVersion: "26.0",
            steps: 20,
            goal: "Test",
            outputDirectory: tempDirectory
        )
        let testFile = tempDirectory.appendingPathComponent("Test.swift")

        // When: Building command
        let runner = XcodebuildRunner()
        let command = runner.buildCommand(config: config, testFile: testFile)

        // Then: Should include OS version in destination
        XCTAssertTrue(command.contains("OS=26.0"))
    }

    func testBuildCommandIncludesTestTarget() throws {
        // Given: Configuration
        let config = CLIConfiguration(
            platform: .iOS,
            appIdentifier: "com.example.MyApp",
            projectPath: URL(fileURLWithPath: "/path/to/MyApp.xcodeproj"),
            steps: 20,
            goal: "Test",
            outputDirectory: tempDirectory
        )
        let testFile = tempDirectory.appendingPathComponent("ScoutCLIExploration.swift")

        // When: Building command
        let runner = XcodebuildRunner()
        let command = runner.buildCommand(config: config, testFile: testFile)

        // Then: Should include only-testing for our specific test
        XCTAssertTrue(command.contains("-only-testing:"))
    }

    // MARK: - Scheme Detection Tests

    func testDetectSchemeFromXcodeProject() throws {
        // Given: Mock Xcode project
        let projectDir = tempDirectory.appendingPathComponent("MyApp.xcodeproj")
        try FileManager.default.createDirectory(at: projectDir, withIntermediateDirectories: true)

        let config = CLIConfiguration(
            platform: .iOS,
            appIdentifier: "com.example.MyApp",
            projectPath: projectDir,
            steps: 20,
            goal: "Test",
            outputDirectory: tempDirectory
        )

        // When: Detecting scheme
        let runner = XcodebuildRunner()
        let scheme = runner.detectScheme(from: config)

        // Then: Should derive scheme from project name
        XCTAssertNotNil(scheme)
        XCTAssertEqual(scheme, "MyApp")
    }

    func testDetectSchemeFromWorkspace() throws {
        // Given: Mock Xcode workspace
        let workspaceDir = tempDirectory.appendingPathComponent("MyApp.xcworkspace")
        try FileManager.default.createDirectory(at: workspaceDir, withIntermediateDirectories: true)

        let config = CLIConfiguration(
            platform: .iOS,
            appIdentifier: "com.example.MyApp",
            projectPath: workspaceDir,
            steps: 20,
            goal: "Test",
            outputDirectory: tempDirectory
        )

        // When: Detecting scheme
        let runner = XcodebuildRunner()
        let scheme = runner.detectScheme(from: config)

        // Then: Should derive scheme from workspace name
        XCTAssertNotNil(scheme)
        XCTAssertEqual(scheme, "MyApp")
    }

    // MARK: - Destination Building Tests

    func testBuildDestinationStringDefault() {
        // Given: Configuration without explicit device
        let config = CLIConfiguration(
            platform: .iOS,
            appIdentifier: "com.example.MyApp",
            projectPath: URL(fileURLWithPath: "/path/to/project"),
            steps: 20,
            goal: "Test",
            outputDirectory: tempDirectory
        )

        // When: Building destination
        let runner = XcodebuildRunner()
        let destination = runner.buildDestination(from: config)

        // Then: Should use default simulator
        XCTAssertTrue(destination.contains("platform=iOS Simulator"))
    }

    func testBuildDestinationWithDevice() {
        // Given: Configuration with device
        let config = CLIConfiguration(
            platform: .iOS,
            appIdentifier: "com.example.MyApp",
            projectPath: URL(fileURLWithPath: "/path/to/project"),
            targetDevice: "iPhone 15",
            steps: 20,
            goal: "Test",
            outputDirectory: tempDirectory
        )

        // When: Building destination
        let runner = XcodebuildRunner()
        let destination = runner.buildDestination(from: config)

        // Then: Should include device name
        XCTAssertTrue(destination.contains("name=iPhone 15"))
    }

    func testBuildDestinationWithOSVersion() {
        // Given: Configuration with OS version
        let config = CLIConfiguration(
            platform: .iOS,
            appIdentifier: "com.example.MyApp",
            projectPath: URL(fileURLWithPath: "/path/to/project"),
            osVersion: "26.0",
            steps: 20,
            goal: "Test",
            outputDirectory: tempDirectory
        )

        // When: Building destination
        let runner = XcodebuildRunner()
        let destination = runner.buildDestination(from: config)

        // Then: Should include OS version
        XCTAssertTrue(destination.contains("OS=26.0"))
    }

    // MARK: - Result Parsing Tests

    func testParseSuccessfulTestOutput() throws {
        // Given: Successful xcodebuild output
        let output = """
        Test Suite 'All tests' passed at 2025-10-27 12:00:00.000.
             Executed 1 tests, with 0 failures (0 unexpected) in 125.5 (125.8) seconds
        ** TEST SUCCEEDED **
        """
        let exitCode = 0

        // When: Parsing result
        let runner = XcodebuildRunner()
        let result = runner.parseResult(
            output: output,
            exitCode: exitCode,
            startTime: Date(),
            config: CLIConfiguration(
                platform: .iOS,
                appIdentifier: "com.example.MyApp",
                projectPath: URL(fileURLWithPath: "/path/to/project"),
                steps: 20,
                goal: "Test",
                outputDirectory: tempDirectory
            )
        )

        // Then: Should indicate success
        XCTAssertEqual(result.exitCode, 0)
        XCTAssertTrue(result.wasSuccessful)
    }

    func testParseFailedTestOutput() throws {
        // Given: Failed xcodebuild output
        let output = """
        Test Suite 'All tests' failed at 2025-10-27 12:00:00.000.
             Executed 1 tests, with 3 failures (3 unexpected) in 125.5 (125.8) seconds
        ** TEST FAILED **
        """
        let exitCode = 1

        // When: Parsing result
        let runner = XcodebuildRunner()
        let result = runner.parseResult(
            output: output,
            exitCode: exitCode,
            startTime: Date(),
            config: CLIConfiguration(
                platform: .iOS,
                appIdentifier: "com.example.MyApp",
                projectPath: URL(fileURLWithPath: "/path/to/project"),
                steps: 20,
                goal: "Test",
                outputDirectory: tempDirectory
            )
        )

        // Then: Should indicate failure
        XCTAssertEqual(result.exitCode, 1)
        XCTAssertFalse(result.wasSuccessful)
    }

    func testParseOutputExtractsMetrics() throws {
        // Given: Output with AITestScout metrics
        let output = """
        ✅ Exploration complete
           Screens: 15
           Transitions: 42
           Duration: 125s
           Success Rate: 85%
        ** TEST SUCCEEDED **
        """

        // When: Parsing result
        let runner = XcodebuildRunner()
        let result = runner.parseResult(
            output: output,
            exitCode: 0,
            startTime: Date(),
            config: CLIConfiguration(
                platform: .iOS,
                appIdentifier: "com.example.MyApp",
                projectPath: URL(fileURLWithPath: "/path/to/project"),
                steps: 20,
                goal: "Test",
                outputDirectory: tempDirectory
            )
        )

        // Then: Should extract metrics
        XCTAssertEqual(result.screensDiscovered, 15)
        // Failures would be 0 for a successful test
        XCTAssertEqual(result.failuresFound, 0)
    }
}
