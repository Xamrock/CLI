import Foundation

/// iOS-specific platform orchestrator
public class iOSOrchestrator: PlatformOrchestrator {

    private let xcodeAvailable: Bool

    /// Initialize iOS orchestrator
    /// - Parameter xcodeAvailable: Override for Xcode availability (for testing)
    public init(xcodeAvailable: Bool? = nil) {
        if let override = xcodeAvailable {
            self.xcodeAvailable = override
        } else {
            self.xcodeAvailable = Self.checkXcodeAvailability()
        }
    }

    // MARK: - PlatformOrchestrator Protocol

    public func isAvailable() -> Bool {
        return xcodeAvailable
    }

    public func validate(config: CLIConfiguration) throws {
        // Check Xcode availability
        guard xcodeAvailable else {
            throw ConfigurationError.missingDependency("Xcode")
        }

        // Validate bundle ID format
        try validateBundleID(config.appIdentifier)

        // Validate project path if provided
        if let projectPath = config.projectPath {
            guard FileManager.default.fileExists(atPath: projectPath.path) else {
                throw ConfigurationError.projectNotFound(projectPath)
            }
        }
    }

    public func generateTestFile(config: CLIConfiguration) throws -> URL {
        // Generate temporary directory for test file
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("XamrockCLI")
            .appendingPathComponent(UUID().uuidString)

        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

        // Generate test file
        let testFileName = "ScoutCLIExploration.swift"
        let testFileURL = tempDir.appendingPathComponent(testFileName)

        let testFileContent = generateTestFileContent(config: config)
        try testFileContent.write(to: testFileURL, atomically: true, encoding: .utf8)

        return testFileURL
    }

    public func runExploration(config: CLIConfiguration) throws -> TestExecutionResult {
        // Generate test file
        let testFile = try generateTestFile(config: config)

        // Run xcodebuild test
        let runner = XcodebuildRunner()
        let result = try runner.runTest(config: config, testFile: testFile)

        return result
    }

    public func collectArtifacts(from outputDirectory: URL) throws -> [URL] {
        // Check if directory exists
        guard FileManager.default.fileExists(atPath: outputDirectory.path) else {
            return []
        }

        var artifacts: [URL] = []

        // Known AITestScout artifact file names
        let artifactNames = [
            "GeneratedTests.swift",
            "FailureReport.md",
            "dashboard.html",
            "exploration.json",
            "manifest.json"
        ]

        // Check for each artifact
        for fileName in artifactNames {
            let fileURL = outputDirectory.appendingPathComponent(fileName)
            if FileManager.default.fileExists(atPath: fileURL.path) {
                artifacts.append(fileURL)
            }
        }

        // Also search subdirectories for AITestScout outputs
        if let enumerator = FileManager.default.enumerator(at: outputDirectory,
                                                            includingPropertiesForKeys: [.isRegularFileKey],
                                                            options: [.skipsHiddenFiles]) {
            for case let fileURL as URL in enumerator {
                if let resourceValues = try? fileURL.resourceValues(forKeys: [.isRegularFileKey]),
                   resourceValues.isRegularFile == true {
                    let fileName = fileURL.lastPathComponent
                    // Add additional artifacts not in the main list
                    if !artifacts.contains(fileURL) &&
                       (fileName.hasSuffix(".swift") ||
                        fileName.hasSuffix(".md") ||
                        fileName.hasSuffix(".html") ||
                        fileName.hasSuffix(".json")) {
                        artifacts.append(fileURL)
                    }
                }
            }
        }

        return artifacts
    }

    // MARK: - Private Helpers

    private static func checkXcodeAvailability() -> Bool {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/xcode-select")
        process.arguments = ["-p"]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe

        do {
            try process.run()
            process.waitUntilExit()
            return process.terminationStatus == 0
        } catch {
            return false
        }
    }

    private func validateBundleID(_ bundleID: String) throws {
        // Bundle ID should match pattern: com.example.App
        // - Only alphanumeric, dots, and hyphens
        // - At least one dot
        // - No consecutive dots
        // - No leading/trailing dots

        let bundleIDPattern = "^[a-zA-Z0-9]([a-zA-Z0-9-]*[a-zA-Z0-9])?(\\.[a-zA-Z0-9]([a-zA-Z0-9-]*[a-zA-Z0-9])?)+$"

        guard let regex = try? NSRegularExpression(pattern: bundleIDPattern),
              regex.firstMatch(in: bundleID, range: NSRange(bundleID.startIndex..., in: bundleID)) != nil else {
            throw ConfigurationError.invalidAppIdentifier(bundleID)
        }
    }

    private func generateTestFileContent(config: CLIConfiguration) -> String {
        let outputPath = config.outputDirectory.path

        // Build ExplorationConfig initialization
        var configLines: [String] = [
            "        let config = ExplorationConfig(",
            "            steps: \(config.steps),",
            "            goal: \"\(config.goal.replacingOccurrences(of: "\"", with: "\\\""))\",",
            "            outputDirectory: URL(fileURLWithPath: \"\(outputPath)\"),",
            "            generateTests: true,",
            "            generateDashboard: \(config.generateDashboard),",
            "            failOnCriticalIssues: \(config.failOnIssues),",
            "            verboseOutput: \(config.verbose)"
        ]

        // Add CI mode settings if enabled
        if config.ciMode {
            configLines.append("            temperature: 0.3,")
            configLines.append("            seed: 42")
        }

        configLines.append("        )")

        let configBlock = configLines.joined(separator: "\n")

        let failOnIssuesCheck = config.failOnIssues ? """

        // Fail test if critical issues found
        try result.assertNoCriticalIssues()
""" : ""

        return """
import XCTest
import AITestScout

/// Auto-generated test file by XamrockCLI
/// App: \(config.appIdentifier)
/// Goal: \(config.goal)
@available(iOS 26.0, *)
final class ScoutCLIExploration: XCTestCase {
    func testExploration() throws {
        let app = XCUIApplication()
        app.launch()

\(configBlock)

        let result = try Scout.explore(app, config: config)\(failOnIssuesCheck)

        print("✅ Exploration complete")
        print("   Screens: \\(result.screensDiscovered)")
        print("   Transitions: \\(result.transitions)")
        print("   Duration: \\(Int(result.duration))s")
        print("   Success Rate: \\(result.successRatePercent)%")
    }
}
"""
    }
}
