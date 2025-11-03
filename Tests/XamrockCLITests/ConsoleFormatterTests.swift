import XCTest
import Foundation
@testable import XamrockCLI

final class ConsoleFormatterTests: XCTestCase {

    var formatter: ConsoleFormatter!

    override func setUp() {
        super.setUp()
        formatter = ConsoleFormatter()
    }

    // MARK: - Header/Banner Tests

    func testFormatStartBanner() {
        // Given: Configuration
        let config = CLIConfiguration(
            platform: .iOS,
            appIdentifier: "com.example.MyApp",
            projectPath: URL(fileURLWithPath: "/path/to/project"),
            steps: 30,
            goal: "Test checkout flow",
            outputDirectory: URL(fileURLWithPath: "/output")
        )

        // When: Formatting start banner
        let output = formatter.formatStartBanner(config: config)

        // Then: Should include key details
        XCTAssertTrue(output.contains("Xamrock"))
        XCTAssertTrue(output.contains("com.example.MyApp"))
        XCTAssertTrue(output.contains("30"))
        XCTAssertTrue(output.contains("Test checkout flow"))
    }

    func testFormatCompletionBanner() {
        // Given: Successful result
        let result = TestExecutionResult(
            exitCode: 0,
            outputDirectory: URL(fileURLWithPath: "/output"),
            duration: 125.5,
            screensDiscovered: 15,
            failuresFound: 0
        )

        // When: Formatting completion banner
        let output = formatter.formatCompletionBanner(result: result)

        // Then: Should show success message
        XCTAssertTrue(output.contains("✅") || output.contains("SUCCESS") || output.contains("Complete"))
        XCTAssertTrue(output.contains("15")) // screens
        XCTAssertTrue(output.contains("125") || output.contains("2:05")) // duration
    }

    func testFormatCompletionBannerWithFailures() {
        // Given: Result with failures
        let result = TestExecutionResult(
            exitCode: 1,
            outputDirectory: URL(fileURLWithPath: "/output"),
            duration: 85.2,
            screensDiscovered: 10,
            failuresFound: 3
        )

        // When: Formatting completion banner
        let output = formatter.formatCompletionBanner(result: result)

        // Then: Should show failure indicators
        XCTAssertTrue(output.contains("❌") || output.contains("FAILED") || output.contains("failures"))
        XCTAssertTrue(output.contains("3")) // failures
    }

    // MARK: - Progress Indicator Tests

    func testFormatProgressStep() {
        // When: Formatting progress steps
        let step1 = formatter.formatProgress(step: "Validating configuration", isDone: true)
        let step2 = formatter.formatProgress(step: "Generating test file", isDone: false)

        // Then: Should show completion status
        XCTAssertTrue(step1.contains("✓") || step1.contains("✅") || step1.contains("DONE"))
        XCTAssertTrue(step2.contains("⏳") || step2.contains("▶") || step2.contains("..."))
    }

    // MARK: - Error Formatting Tests

    func testFormatError() {
        // When: Formatting error
        let error = ConfigurationError.missingDependency("Xcode")
        let output = formatter.formatError(error)

        // Then: Should highlight error clearly
        XCTAssertTrue(output.contains("❌") || output.contains("ERROR"))
        XCTAssertTrue(output.contains("Xcode"))
    }

    func testFormatErrorWithMessage() {
        // When: Formatting plain error message
        let output = formatter.formatError("Something went wrong")

        // Then: Should format as error
        XCTAssertTrue(output.contains("❌") || output.contains("ERROR"))
        XCTAssertTrue(output.contains("Something went wrong"))
    }

    // MARK: - Metrics Display Tests

    func testFormatMetrics() {
        // Given: Test result with metrics
        let result = TestExecutionResult(
            exitCode: 0,
            outputDirectory: URL(fileURLWithPath: "/output"),
            duration: 125.8,
            screensDiscovered: 18,
            failuresFound: 0
        )

        // When: Formatting metrics
        let output = formatter.formatMetrics(result: result)

        // Then: Should display all metrics
        XCTAssertTrue(output.contains("18")) // screens
        XCTAssertTrue(output.contains("125") || output.contains("2:05")) // duration in seconds or mm:ss
    }

    // MARK: - Artifact Display Tests

    func testFormatArtifactList() {
        // Given: List of artifacts
        let artifacts = [
            URL(fileURLWithPath: "/output/GeneratedTests.swift"),
            URL(fileURLWithPath: "/output/FailureReport.md"),
            URL(fileURLWithPath: "/output/dashboard.html")
        ]

        // When: Formatting artifact list
        let output = formatter.formatArtifactList(artifacts: artifacts)

        // Then: Should list all artifacts
        XCTAssertTrue(output.contains("GeneratedTests.swift"))
        XCTAssertTrue(output.contains("FailureReport.md"))
        XCTAssertTrue(output.contains("dashboard.html"))
    }

    // MARK: - Verbose Mode Tests

    func testVerboseModeShowsAdditionalDetails() {
        // Given: Formatter in verbose mode
        let verboseFormatter = ConsoleFormatter(verbose: true)
        let config = CLIConfiguration(
            platform: .iOS,
            appIdentifier: "com.example.MyApp",
            projectPath: URL(fileURLWithPath: "/path/to/project"),
            steps: 20,
            goal: "Test",
            outputDirectory: URL(fileURLWithPath: "/output")
        )

        // When: Formatting start banner
        let output = verboseFormatter.formatStartBanner(config: config)

        // Then: Should include verbose details
        XCTAssertTrue(output.count > 100) // More detailed output
    }

    // MARK: - Utility Tests

    func testFormatDuration() {
        // When: Formatting various durations
        let short = formatter.formatDuration(45.5)
        let medium = formatter.formatDuration(125.8)
        let long = formatter.formatDuration(3665.2)

        // Then: Should format appropriately
        XCTAssertTrue(short.contains("45") || short.contains("0:45"))
        XCTAssertTrue(medium.contains("125") || medium.contains("2:05"))
        XCTAssertTrue(long.contains("3665") || long.contains("61:05") || long.contains("1:01:05"))
    }

    func testColoredOutput() {
        // When: Formatting with colors (if supported)
        let success = formatter.formatColored("Success", color: .green)
        let error = formatter.formatColored("Error", color: .red)

        // Then: Should include text (colors may not be visible in tests)
        XCTAssertTrue(success.contains("Success"))
        XCTAssertTrue(error.contains("Error"))
    }

    // MARK: - Enhanced Error Display Tests

    func testFormatCompletionBannerWithErrorMessage() {
        // Given: Result with error message
        let result = TestExecutionResult(
            exitCode: 65,
            outputDirectory: URL(fileURLWithPath: "/output"),
            duration: 5.2,
            screensDiscovered: 0,
            failuresFound: 0,
            errorMessage: "Unable to find a destination matching the provided destination specifier",
            errorSuggestion: nil
        )

        // When: Formatting completion banner
        let output = formatter.formatCompletionBanner(result: result)

        // Then: Should display error message
        XCTAssertTrue(output.contains("❌") || output.contains("FAILED"))
        XCTAssertTrue(output.contains("destination"))
    }

    func testFormatCompletionBannerWithErrorSuggestion() {
        // Given: Result with error and suggestion
        let result = TestExecutionResult(
            exitCode: 65,
            outputDirectory: URL(fileURLWithPath: "/output"),
            duration: 3.1,
            screensDiscovered: 0,
            failuresFound: 0,
            errorMessage: "Scheme not found",
            errorSuggestion: """
            Try:
              1. Open your project in Xcode
              2. Verify the scheme exists
            """
        )

        // When: Formatting completion banner
        let output = formatter.formatCompletionBanner(result: result)

        // Then: Should display both error and suggestion
        XCTAssertTrue(output.contains("Scheme"))
        XCTAssertTrue(output.contains("Try:") || output.contains("1."))
    }

    func testFormatCompletionBannerWithExitCode() {
        // Given: Result with non-zero exit code
        let result = TestExecutionResult(
            exitCode: 65,
            outputDirectory: URL(fileURLWithPath: "/output"),
            duration: 2.0,
            screensDiscovered: 0,
            failuresFound: 0,
            errorMessage: "Build failed",
            errorSuggestion: nil
        )

        // When: Formatting completion banner
        let output = formatter.formatCompletionBanner(result: result)

        // Then: Should display exit code
        XCTAssertTrue(output.contains("65") || output.contains("Exit"))
    }

    func testFormatCompletionBannerSuccessHidesErrorFields() {
        // Given: Successful result (no error fields should be shown)
        let result = TestExecutionResult(
            exitCode: 0,
            outputDirectory: URL(fileURLWithPath: "/output"),
            duration: 120.0,
            screensDiscovered: 15,
            failuresFound: 0,
            errorMessage: nil,
            errorSuggestion: nil
        )

        // When: Formatting completion banner
        let output = formatter.formatCompletionBanner(result: result)

        // Then: Should not contain error-related text
        XCTAssertTrue(output.contains("✅") || output.contains("Complete"))
        XCTAssertFalse(output.contains("Error") || output.contains("ERROR"))
    }
}
