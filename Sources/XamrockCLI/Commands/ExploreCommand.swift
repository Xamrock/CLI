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

    // MARK: - Fixture Options

    @Option(name: .customLong("fixture"), help: "Path to fixture file for test data")
    public var fixturePath: String?

    // MARK: - Initialization

    public init() {}

    // MARK: - Command Execution

    public mutating func run() async throws {
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

        // Upload to backend if configured
        if EnvironmentConfig.isBackendEnabled {
            print(formatter.formatProgress(step: "Uploading to backend", isDone: false))
            do {
                try await uploadToBackend(
                    config: config,
                    result: result,
                    artifacts: artifacts + [manifestFile],
                    formatter: formatter
                )
                print(formatter.formatProgress(step: "Uploading to backend", isDone: true))
            } catch {
                print("")
                print("⚠️  Backend upload failed: \(error.localizedDescription)")
                print("   Results saved locally in \(config.outputDirectory.path)")
                print("")
            }
        }

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
            verbose: verbose,
            fixturePath: fixturePath
        )
    }

    // MARK: - Backend Upload

    /// Upload exploration results to the backend
    private func uploadToBackend(
        config: CLIConfiguration,
        result: TestExecutionResult,
        artifacts: [URL],
        formatter: ConsoleFormatter
    ) async throws {
        guard let backendURL = EnvironmentConfig.backendURL else {
            return
        }

        let backendClient = BackendClient(baseURL: backendURL)
        let configManager = ConfigManager()

        // 1. Get/Create Organization
        let orgName = EnvironmentConfig.organizationName
        let orgId = try await backendClient.getOrCreateOrganization(
            name: orgName,
            configManager: configManager
        )

        // 2. Get/Create Project
        let projectId = try await backendClient.getOrCreateProject(
            organizationId: orgId,
            bundleId: config.appIdentifier,
            name: config.appIdentifier,
            configManager: configManager
        )

        // 3. Create Session
        let sessionId = try await backendClient.createSession(
            projectId: projectId,
            steps: config.steps,
            goal: config.goal,
            temperature: config.ciMode ? 0.0 : 0.7,
            enableVerification: true,
            maxRetries: 3
        )

        print(formatter.formatInfo("Session created: \(sessionId)"))

        // 4. Upload Exploration Data (if available)
        if let explorationDataFile = artifacts.first(where: { $0.lastPathComponent == "exploration.json" }) {
            do {
                let data = try Data(contentsOf: explorationDataFile)
                try await backendClient.uploadExplorationData(
                    sessionId: sessionId,
                    explorationData: data
                )
                print(formatter.formatInfo("Exploration data uploaded"))
            } catch {
                print("   ⚠️  Could not upload exploration data: \(error.localizedDescription)")
            }
        }

        // 5. Upload Screenshots
        let screenshots = artifacts.filter { $0.pathExtension == "png" }
        if !screenshots.isEmpty {
            print(formatter.formatInfo("Uploading \(screenshots.count) screenshots..."))
            do {
                _ = try await backendClient.uploadScreenshots(
                    sessionId: sessionId,
                    screenshots: screenshots
                ) { current, total in
                    // Progress callback - could enhance with progress bar
                }
                print(formatter.formatInfo("Screenshots uploaded"))
            } catch {
                print("   ⚠️  Could not upload screenshots: \(error.localizedDescription)")
            }
        }

        // 6. Upload Test File
        if let testFile = artifacts.first(where: { $0.pathExtension == "swift" }) {
            do {
                _ = try await backendClient.uploadArtifact(
                    sessionId: sessionId,
                    file: testFile,
                    artifactType: .testFile
                )
                print(formatter.formatInfo("Test file uploaded"))
            } catch {
                print("   ⚠️  Could not upload test file: \(error.localizedDescription)")
            }
        }

        // 7. Upload Dashboard HTML
        if config.generateDashboard,
           let dashboardFile = artifacts.first(where: { $0.lastPathComponent == "dashboard.html" }) {
            do {
                _ = try await backendClient.uploadArtifact(
                    sessionId: sessionId,
                    file: dashboardFile,
                    artifactType: .dashboard
                )
                print(formatter.formatInfo("Dashboard uploaded"))
            } catch {
                print("   ⚠️  Could not upload dashboard: \(error.localizedDescription)")
            }
        }

        // 8. Upload Manifest
        if let manifestFile = artifacts.first(where: { $0.lastPathComponent == "manifest.json" }) {
            do {
                _ = try await backendClient.uploadArtifact(
                    sessionId: sessionId,
                    file: manifestFile,
                    artifactType: .manifest
                )
                print(formatter.formatInfo("Manifest uploaded"))
            } catch {
                print("   ⚠️  Could not upload manifest: \(error.localizedDescription)")
            }
        }

        // 9. Update Session with Final Metrics
        let metrics = buildSessionMetrics(from: result)
        let status = determineStatus(from: result)

        try await backendClient.updateSession(
            sessionId: sessionId,
            status: status,
            metrics: metrics
        )

        // 10. Print Dashboard Link
        let dashboardURL = backendClient.getDashboardURL(sessionId: sessionId)
        print("")
        print(formatter.formatSuccess("Dashboard available at:"))
        print(formatter.formatLink(dashboardURL))
        print("")
    }

    /// Build session metrics from test execution result
    private func buildSessionMetrics(from result: TestExecutionResult) -> SessionMetrics {
        return SessionMetrics(
            screensDiscovered: result.screensDiscovered,
            transitions: nil,  // Not available in TestExecutionResult
            durationSeconds: Int(result.duration),
            successfulActions: nil,  // Not available in TestExecutionResult
            failedActions: result.failuresFound,
            crashesDetected: result.exitCode != 0 ? 1 : 0,
            verificationsPerformed: nil,  // Not available in TestExecutionResult
            verificationsPassed: nil,  // Not available in TestExecutionResult
            retryAttempts: nil,  // Not available in TestExecutionResult
            successRatePercent: result.wasSuccessful ? 100.0 : 0.0,
            healthScore: calculateHealthScore(result: result)
        )
    }

    /// Determine session status from test execution result
    private func determineStatus(from result: TestExecutionResult) -> SessionStatus {
        if result.exitCode != 0 {
            return .crashed
        } else if result.failuresFound > 0 {
            return .failed
        } else {
            return .completed
        }
    }

    /// Calculate health score based on result
    private func calculateHealthScore(result: TestExecutionResult) -> Double {
        var score = result.wasSuccessful ? 100.0 : 50.0

        // Bonus for screens discovered
        if result.screensDiscovered >= 5 {
            score = min(100, score + 10)
        }

        // Penalty for failures
        if result.failuresFound > 0 {
            score = max(0, score - Double(result.failuresFound * 10))
        }

        // Penalty for crashes
        if result.exitCode != 0 {
            score = max(0, score - 20)
        }

        return score
    }
}
