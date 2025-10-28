import Foundation

/// Configuration for CLI exploration command
public struct CLIConfiguration {
    /// Target platform (iOS or Android)
    public var platform: Platform?

    /// App identifier (bundle ID for iOS, package name for Android)
    public var appIdentifier: String

    /// Path to the project root directory
    public var projectPath: URL?

    /// Target device or simulator name
    public var targetDevice: String?

    /// OS version to target
    public var osVersion: String?

    /// Number of exploration steps
    public var steps: Int

    /// Exploration goal description
    public var goal: String

    /// Enable CI-friendly mode (deterministic, low temperature, fixed seed)
    public var ciMode: Bool

    /// Output directory for artifacts
    public var outputDirectory: URL

    /// Whether to generate HTML dashboard
    public var generateDashboard: Bool

    /// Whether to fail with exit code 1 if issues are found
    public var failOnIssues: Bool

    /// Verbose console output
    public var verbose: Bool

    /// Initialize CLI configuration
    public init(
        platform: Platform?,
        appIdentifier: String,
        projectPath: URL?,
        targetDevice: String? = nil,
        osVersion: String? = nil,
        steps: Int = 20,
        goal: String = "Explore the app systematically",
        ciMode: Bool = false,
        outputDirectory: URL = URL(fileURLWithPath: "./scout-results"),
        generateDashboard: Bool = true,
        failOnIssues: Bool = false,
        verbose: Bool = false
    ) {
        self.platform = platform
        self.appIdentifier = appIdentifier
        self.projectPath = projectPath
        self.targetDevice = targetDevice
        self.osVersion = osVersion
        self.steps = steps
        self.goal = goal
        self.ciMode = ciMode
        self.outputDirectory = outputDirectory
        self.generateDashboard = generateDashboard
        self.failOnIssues = failOnIssues
        self.verbose = verbose
    }
}
