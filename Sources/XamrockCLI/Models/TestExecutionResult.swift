import Foundation

/// Result from running an exploration test
public struct TestExecutionResult: Equatable {
    /// Exit code from test execution (0 = success, non-zero = failure)
    public let exitCode: Int

    /// Directory where artifacts were output
    public let outputDirectory: URL

    /// Duration of exploration in seconds
    public let duration: TimeInterval

    /// Number of unique screens discovered
    public let screensDiscovered: Int

    /// Number of failures found during exploration
    public let failuresFound: Int

    /// Error message extracted from xcodebuild output (if any)
    public let errorMessage: String?

    /// Suggested fix based on the error type
    public let errorSuggestion: String?

    /// Initialize test execution result
    public init(
        exitCode: Int,
        outputDirectory: URL,
        duration: TimeInterval,
        screensDiscovered: Int,
        failuresFound: Int,
        errorMessage: String? = nil,
        errorSuggestion: String? = nil
    ) {
        self.exitCode = exitCode
        self.outputDirectory = outputDirectory
        self.duration = duration
        self.screensDiscovered = screensDiscovered
        self.failuresFound = failuresFound
        self.errorMessage = errorMessage
        self.errorSuggestion = errorSuggestion
    }

    /// Whether the test execution was successful
    public var wasSuccessful: Bool {
        exitCode == 0
    }
}
