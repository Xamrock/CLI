import Foundation
import ArgumentParser

/// Explore command - runs AITestScout exploration
public struct ExploreCommand: ParsableCommand {

    public static let configuration = CommandConfiguration(
        commandName: "explore",
        abstract: "Explore an iOS or Android app with AI-powered testing",
        discussion: """
        Runs AITestScout exploration on your mobile app, generating tests and reports.

        Examples:
          scout explore --app com.example.MyApp
          scout explore --app com.example.MyApp --steps 30 --ci-mode
          scout explore --app com.example.MyApp --platform ios --output ./results
        """
    )

    // MARK: - Required Arguments

    @Option(name: [.short, .long, .customLong("app")], help: "App identifier (bundle ID for iOS, package name for Android)")
    public var appIdentifier: String

    // MARK: - Platform Detection

    @Option(name: [.short, .customLong("platform")], help: "Platform: ios or android (auto-detected if omitted)")
    public var platformString: String?

    @Option(name: .customLong("project-path"), help: "Project directory path (default: current directory)")
    public var projectPath: String?

    // MARK: - Exploration Options

    @Option(name: [.short, .customLong("steps")], help: "Number of exploration steps (default: 20)")
    public var steps: Int = 20

    @Option(name: [.short, .customLong("goal")], help: "Exploration goal (default: systematic exploration)")
    public var goal: String = "Explore the app systematically"

    @Flag(name: .customLong("ci-mode"), help: "Enable CI-friendly mode (deterministic, low temperature, fixed seed)")
    public var ciMode: Bool = false

    // MARK: - Device Options

    @Option(name: [.short, .customLong("device")], help: "Target device or simulator name")
    public var device: String?

    @Option(name: .customLong("os-version"), help: "OS version to target")
    public var osVersion: String?

    // MARK: - Output Options

    @Option(name: [.short, .customLong("output")], help: "Output directory for artifacts (default: ./scout-results)")
    public var outputPath: String?

    @Flag(name: .customLong("generate-dashboard"), inversion: .prefixedNo, help: "Generate HTML dashboard (default: true)")
    public var generateDashboard: Bool = true

    @Flag(name: .customLong("fail-on-issues"), help: "Exit with code 1 if failures are detected")
    public var failOnIssues: Bool = false

    @Flag(name: [.short, .customLong("verbose")], help: "Verbose console output")
    public var verbose: Bool = false

    // MARK: - Initialization

    public init() {}

    // MARK: - Command Execution

    public mutating func run() throws {
        // Initialize console formatter
        let formatter = ConsoleFormatter(verbose: verbose)

        // Build configuration
        let projectDir = URL(fileURLWithPath: projectPath ?? FileManager.default.currentDirectoryPath)
        let config = try buildConfiguration(projectDirectory: projectDir)

        // Print start banner
        print(formatter.formatStartBanner(config: config))

        // Determine platform orchestrator
        guard let platform = config.platform else {
            throw ConfigurationError.invalidConfiguration("Could not determine platform")
        }

        let orchestrator: PlatformOrchestrator
        switch platform {
        case .iOS:
            orchestrator = iOSOrchestrator()
        case .android:
            throw ConfigurationError.platformNotAvailable(.android)
        }

        // Validate configuration
        print(formatter.formatProgress(step: "Validating configuration", isDone: false))
        try orchestrator.validate(config: config)
        print(formatter.formatProgress(step: "Validating configuration", isDone: true))

        // Run exploration
        print(formatter.formatProgress(step: "Running exploration", isDone: false))
        let result = try orchestrator.runExploration(config: config)
        print(formatter.formatProgress(step: "Running exploration", isDone: true))

        // Collect artifacts
        print(formatter.formatProgress(step: "Collecting artifacts", isDone: false))
        let artifacts = try orchestrator.collectArtifacts(from: config.outputDirectory)
        print(formatter.formatProgress(step: "Collecting artifacts", isDone: true))

        // Generate manifest
        print(formatter.formatProgress(step: "Generating manifest", isDone: false))
        let manifestGenerator = ManifestGenerator()
        let manifest = try manifestGenerator.generateManifest(
            config: config,
            result: result,
            artifacts: artifacts
        )
        let manifestFile = config.outputDirectory.appendingPathComponent("manifest.json")
        try manifestGenerator.saveManifest(manifest, to: manifestFile)
        print(formatter.formatProgress(step: "Generating manifest", isDone: true))

        // Print completion banner
        print(formatter.formatCompletionBanner(result: result))

        // Print artifacts
        print(formatter.formatArtifactList(artifacts: artifacts + [manifestFile]))
        print("")

        // Exit with appropriate code
        if failOnIssues && result.failuresFound > 0 {
            throw ExitCode(Int32(result.exitCode))
        } else if result.exitCode != 0 {
            throw ExitCode(Int32(result.exitCode))
        }
    }

    // MARK: - Configuration Building

    /// Build CLIConfiguration from command arguments
    public func buildConfiguration(projectDirectory: URL) throws -> CLIConfiguration {
        // Parse platform if provided
        var platform: Platform? = nil
        if let platformStr = platformString {
            switch platformStr.lowercased() {
            case "ios":
                platform = .iOS
            case "android":
                platform = .android
            default:
                throw ConfigurationError.invalidConfiguration("Invalid platform: \(platformStr). Must be 'ios' or 'android'")
            }
        }

        // Resolve platform (explicit or auto-detect)
        let resolvedPlatform = PlatformDetector.resolvePlatform(
            explicit: platform,
            projectDirectory: projectDirectory
        )

        // Require platform to be determined
        guard let finalPlatform = resolvedPlatform else {
            throw ConfigurationError.invalidConfiguration(
                "Could not determine platform. Please specify --platform ios or --platform android"
            )
        }

        // Determine output directory
        let outputDirectory: URL
        if let outputPath = outputPath {
            outputDirectory = URL(fileURLWithPath: outputPath)
        } else {
            // Default to ./scout-results
            outputDirectory = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
                .appendingPathComponent("scout-results")
        }

        return CLIConfiguration(
            platform: finalPlatform,
            appIdentifier: appIdentifier,
            projectPath: projectDirectory,
            targetDevice: device,
            osVersion: osVersion,
            steps: steps,
            goal: goal,
            ciMode: ciMode,
            outputDirectory: outputDirectory,
            generateDashboard: generateDashboard,
            failOnIssues: failOnIssues,
            verbose: verbose
        )
    }
}
