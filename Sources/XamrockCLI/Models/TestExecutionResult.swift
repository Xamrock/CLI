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

    /// Initialize test execution result
    public init(
        exitCode: Int,
        outputDirectory: URL,
        duration: TimeInterval,
        screensDiscovered: Int,
        failuresFound: Int
    ) {
        self.exitCode = exitCode
        self.outputDirectory = outputDirectory
        self.duration = duration
        self.screensDiscovered = screensDiscovered
        self.failuresFound = failuresFound
    }

    /// Whether the test execution was successful
    public var wasSuccessful: Bool {
        exitCode == 0
    }
}
