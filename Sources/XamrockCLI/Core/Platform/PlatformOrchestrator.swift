import Foundation

/// Protocol defining platform-specific orchestration for exploration
///
/// Each platform (iOS, Android) implements this protocol to provide
/// platform-specific behavior for validation, test generation, execution, and artifact collection.
public protocol PlatformOrchestrator {

    /// Check if this platform is available in the current environment
    ///
    /// For iOS: Checks for Xcode installation
    /// For Android: Checks for Android SDK and tools
    ///
    /// - Returns: true if platform tools are available
    func isAvailable() -> Bool

    /// Validate the configuration for this platform
    ///
    /// Performs platform-specific validation such as:
    /// - Checking for required tools (Xcode, Android Studio, etc.)
    /// - Validating app identifier format
    /// - Checking project structure
    /// - Verifying device/simulator availability
    ///
    /// - Parameter config: The CLI configuration to validate
    /// - Throws: ConfigurationError if configuration is invalid
    func validate(config: CLIConfiguration) throws

    /// Generate a platform-specific test file
    ///
    /// Creates a temporary test file that will be executed by the platform's test runner.
    /// For iOS: Generates Swift XCUITest file
    /// For Android: Generates Kotlin/Java Espresso test file
    ///
    /// - Parameter config: The CLI configuration
    /// - Returns: URL to the generated test file
    /// - Throws: Error if test file generation fails
    func generateTestFile(config: CLIConfiguration) throws -> URL

    /// Run the exploration test
    ///
    /// Executes the platform-specific test runner:
    /// For iOS: Runs xcodebuild test
    /// For Android: Runs gradle connectedAndroidTest
    ///
    /// - Parameter config: The CLI configuration
    /// - Returns: Test execution result with metrics
    /// - Throws: Error if test execution fails
    func runExploration(config: CLIConfiguration) throws -> TestExecutionResult

    /// Collect artifacts generated during exploration
    ///
    /// Finds and collects all artifacts from the platform-specific output locations:
    /// - Generated test files
    /// - Failure reports
    /// - HTML dashboards
    /// - JSON exports
    ///
    /// - Parameter outputDirectory: Directory to search for artifacts
    /// - Returns: Array of artifact file URLs
    /// - Throws: Error if artifact collection fails
    func collectArtifacts(from outputDirectory: URL) throws -> [URL]
}
