import XCTest
import Foundation
import ArgumentParser
@testable import XamrockCLI

final class ExploreCommandTests: XCTestCase {

    var tempDirectory: URL!

    override func setUp() {
        super.setUp()
        tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("ExploreCommandTests-\(UUID().uuidString)")
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
        let args = ["--app", "com.example.MyApp"]

        // When: Parsing command
        var command = try ExploreCommand.parse(args)

        // Then: Should use defaults for optional arguments
        XCTAssertEqual(command.appIdentifier, "com.example.MyApp")
        XCTAssertEqual(command.steps, 20) // Default
        XCTAssertEqual(command.goal, "Explore the app systematically") // Default
        XCTAssertNil(command.platformString)
        XCTAssertFalse(command.ciMode)
        XCTAssertTrue(command.generateDashboard)
    }

    func testParseFullArguments() throws {
        // Given: All command line arguments
        let args = [
            "--app", "com.example.TestApp",
            "--platform", "ios",
            "--steps", "30",
            "--goal", "Test checkout flow",
            "--ci-mode",
            "--output", tempDirectory.path,
            "--no-generate-dashboard",
            "--fail-on-issues",
            "--verbose"
        ]

        // When: Parsing command
        var command = try ExploreCommand.parse(args)

        // Then: Should parse all arguments correctly
        XCTAssertEqual(command.appIdentifier, "com.example.TestApp")
        XCTAssertEqual(command.platformString, "ios")
        XCTAssertEqual(command.steps, 30)
        XCTAssertEqual(command.goal, "Test checkout flow")
        XCTAssertTrue(command.ciMode)
        XCTAssertEqual(command.outputPath, tempDirectory.path)
        XCTAssertFalse(command.generateDashboard)
        XCTAssertTrue(command.failOnIssues)
        XCTAssertTrue(command.verbose)
    }

    func testParsePlatformFlag() throws {
        // Given: Platform flags
        let iosArgs = ["--app", "com.example.App", "--platform", "ios"]
        let androidArgs = ["--app", "com.example.app", "--platform", "android"]

        // When: Parsing commands
        var iosCommand = try ExploreCommand.parse(iosArgs)
        var androidCommand = try ExploreCommand.parse(androidArgs)

        // Then: Should parse platform correctly
        XCTAssertEqual(iosCommand.platformString, "ios")
        XCTAssertEqual(androidCommand.platformString, "android")
    }

    func testParseInvalidPlatformThrows() throws {
        // Given: Invalid platform
        let args = ["--app", "com.example.App", "--platform", "invalid"]

        // When: Parsing succeeds but building configuration should throw
        var command = try ExploreCommand.parse(args)

        // Then: Should throw validation error when building configuration
        XCTAssertThrowsError(try command.buildConfiguration(projectDirectory: tempDirectory)) { error in
            guard let configError = error as? ConfigurationError else {
                XCTFail("Expected ConfigurationError")
                return
            }
            if case .invalidConfiguration = configError {
                // Expected
            } else {
                XCTFail("Expected invalidConfiguration error")
            }
        }
    }

    // MARK: - Configuration Building Tests

    func testBuildConfigurationFromArguments() throws {
        // Given: Parsed command with explicit platform
        let args = [
            "--app", "com.example.MyApp",
            "--platform", "ios",
            "--steps", "25",
            "--goal", "Test login flow",
            "--ci-mode",
            "--output", tempDirectory.path
        ]
        var command = try ExploreCommand.parse(args)

        // When: Building configuration
        let config = try command.buildConfiguration(projectDirectory: tempDirectory)

        // Then: Configuration should match arguments
        XCTAssertEqual(config.appIdentifier, "com.example.MyApp")
        XCTAssertEqual(config.steps, 25)
        XCTAssertEqual(config.goal, "Test login flow")
        XCTAssertTrue(config.ciMode)
        XCTAssertEqual(config.outputDirectory.path, tempDirectory.path)
    }

    func testBuildConfigurationDetectsPlatform() throws {
        // Given: iOS project directory with Xcode project
        let projectDir = tempDirectory.appendingPathComponent("MyiOSApp")
        try FileManager.default.createDirectory(at: projectDir, withIntermediateDirectories: true)
        let xcodeProj = projectDir.appendingPathComponent("MyApp.xcodeproj")
        try FileManager.default.createDirectory(at: xcodeProj, withIntermediateDirectories: true)

        let args = ["--app", "com.example.MyApp"]
        var command = try ExploreCommand.parse(args)

        // When: Building configuration without explicit platform
        let config = try command.buildConfiguration(projectDirectory: projectDir)

        // Then: Should auto-detect iOS
        XCTAssertEqual(config.platform, .iOS)
    }

    func testBuildConfigurationUsesExplicitPlatform() throws {
        // Given: Android project directory but explicit iOS platform
        let args = ["--app", "com.example.App", "--platform", "ios"]
        var command = try ExploreCommand.parse(args)

        // When: Building configuration
        let config = try command.buildConfiguration(projectDirectory: tempDirectory)

        // Then: Should use explicit platform
        XCTAssertEqual(config.platform, .iOS)
    }

    func testBuildConfigurationThrowsWhenPlatformAmbiguous() throws {
        // Given: Empty directory with no platform indicators
        let args = ["--app", "com.example.App"]
        var command = try ExploreCommand.parse(args)

        // When/Then: Should throw error about ambiguous platform
        XCTAssertThrowsError(try command.buildConfiguration(projectDirectory: tempDirectory)) { error in
            guard let configError = error as? ConfigurationError else {
                XCTFail("Expected ConfigurationError")
                return
            }
            if case .invalidConfiguration = configError {
                // Expected
            } else {
                XCTFail("Expected invalidConfiguration error")
            }
        }
    }

    // MARK: - Default Values Tests

    func testDefaultOutputDirectory() throws {
        // Given: Command without output path but with explicit platform
        let args = ["--app", "com.example.App", "--platform", "ios"]
        var command = try ExploreCommand.parse(args)

        // When: Building configuration
        let currentDir = FileManager.default.currentDirectoryPath
        let config = try command.buildConfiguration(projectDirectory: URL(fileURLWithPath: currentDir))

        // Then: Should use default output directory
        XCTAssertTrue(config.outputDirectory.path.contains("scout-results"))
    }

    func testDefaultGoal() throws {
        // Given: Command without goal but with explicit platform
        let args = ["--app", "com.example.App", "--platform", "ios"]
        var command = try ExploreCommand.parse(args)

        // When: Building configuration
        let config = try command.buildConfiguration(projectDirectory: tempDirectory)

        // Then: Should use default goal
        XCTAssertEqual(config.goal, "Explore the app systematically")
    }

    func testDefaultStepsCount() throws {
        // Given: Command without steps
        let args = ["--app", "com.example.App"]
        var command = try ExploreCommand.parse(args)

        // Then: Should use default steps
        XCTAssertEqual(command.steps, 20)
    }

    // MARK: - Validation Tests

    func testValidateRequiresAppIdentifier() {
        // Given: Command without app identifier
        let args: [String] = []

        // When/Then: Should throw missing argument error
        XCTAssertThrowsError(try ExploreCommand.parse(args))
    }

    func testValidateAcceptsValidStepsRange() throws {
        // Given: Valid step counts
        let validSteps = [1, 10, 20, 50, 100]

        for stepCount in validSteps {
            let args = ["--app", "com.example.App", "--steps", "\(stepCount)"]
            var command = try ExploreCommand.parse(args)

            // When/Then: Should parse successfully
            XCTAssertEqual(command.steps, stepCount)
        }
    }
}
