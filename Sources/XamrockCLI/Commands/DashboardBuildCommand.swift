import Foundation
import ArgumentParser

/// Build dashboard for production
public struct DashboardBuildCommand: AsyncParsableCommand {

    public static let configuration = CommandConfiguration(
        commandName: "build",
        abstract: "Build dashboard for production deployment",
        discussion: """
        Builds the XamrockDashboard for production with optimizations:
          - Full WASM optimization
          - Minified JavaScript
          - Bundle size analysis

        Examples:
          xamrock dashboard build
          xamrock dashboard build --output ./dist
          xamrock dashboard build --analyze
        """
    )

    // MARK: - Output Options

    @Option(name: [.short, .customLong("output")], help: "Output directory (default: ./dist)")
    public var outputPath: String?

    @Option(name: .customLong("dashboard-path"), help: "Path to XamrockDashboard directory")
    public var dashboardPath: String?

    // MARK: - Build Options

    @Flag(name: .customLong("production"), inversion: .prefixedNo, help: "Production build with full optimizations (default: true)")
    public var production: Bool = true

    @Flag(name: .customLong("analyze"), help: "Analyze bundle size")
    public var analyze: Bool = false

    @Flag(name: [.short, .customLong("verbose")], help: "Verbose output")
    public var verbose: Bool = false

    // MARK: - Initialization

    public init() {}

    // MARK: - Command Execution

    public func run() async throws {
        let formatter = ConsoleFormatter(verbose: verbose)

        // Print start banner
        print("")
        print(formatter.formatColored("🔨 Building XamrockDashboard for production", color: .bold))
        print("")

        // Resolve paths
        let dashboardURL = try resolveDashboardPath()
        let outputURL = resolveOutputPath()

        print("  " + formatter.formatColored("Dashboard:", color: .bold) + " \(dashboardURL.path)")
        print("  " + formatter.formatColored("Output:", color: .bold) + " \(outputURL.path)")
        print("")

        // Initialize builder
        let builder = DashboardBuilder(
            dashboardPath: dashboardURL,
            outputPath: outputURL,
            production: production,
            verbose: verbose
        )

        // Clean previous build
        print(formatter.formatProgress(step: "Cleaning previous build", isDone: false))
        do {
            try builder.clean()
            print(formatter.formatProgress(step: "Cleaning previous build", isDone: true))
        } catch {
            print("")
            print(formatter.formatError(error))
            throw error
        }

        // Build WASM
        print(formatter.formatProgress(step: "Building Swift → WASM", isDone: false))
        do {
            try await builder.buildWASM()
            print(formatter.formatProgress(step: "Building Swift → WASM", isDone: true))
        } catch {
            print("")
            print(formatter.formatError(error))

            if let dashboardError = error as? DashboardError {
                if let suggestion = dashboardError.recoverySuggestion {
                    print("")
                    print(formatter.formatColored("💡 Suggestion:", color: .yellow))
                    let suggestionLines = suggestion.components(separatedBy: .newlines)
                    for line in suggestionLines {
                        print("  \(line)")
                    }
                }
            }

            throw error
        }

        // Optimize (if production)
        if production {
            print(formatter.formatProgress(step: "Optimizing WASM", isDone: false))
            try await builder.optimizeWASM()
            print(formatter.formatProgress(step: "Optimizing WASM", isDone: true))
        }

        // Copy static assets
        print(formatter.formatProgress(step: "Copying static assets", isDone: false))
        do {
            try builder.copyAssets()
            print(formatter.formatProgress(step: "Copying static assets", isDone: true))
        } catch {
            print("")
            print(formatter.formatError(error))
            throw error
        }

        print("")
        print(formatter.formatSuccess("Build complete!"))
        print("")

        // Show bundle info
        do {
            let bundleSize = try builder.getBundleSize()
            print("  " + formatter.formatColored("WASM Size:", color: .bold) + " \(formatFileSize(bundleSize.wasm))")
            print("  " + formatter.formatColored("JS Size:", color: .bold) + " \(formatFileSize(bundleSize.js))")
            print("  " + formatter.formatColored("Total:", color: .bold) + " \(formatFileSize(bundleSize.total))")
            print("")

            // Analyze if requested
            if analyze {
                print(formatter.formatProgress(step: "Analyzing bundle", isDone: false))
                try builder.analyzeBundleSize()
                print(formatter.formatProgress(step: "Analyzing bundle", isDone: true))
            }
        } catch {
            print("  " + formatter.formatColored("Warning:", color: .yellow) + " Could not analyze bundle size")
        }
    }

    // MARK: - Internal Methods

    func resolveDashboardPath() throws -> URL {
        if let path = dashboardPath {
            return URL(fileURLWithPath: path)
        }

        // Auto-detect: look for XamrockDashboard in parent directory
        let currentDir = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)

        // Try ../XamrockDashboard
        let parentDashboard = currentDir
            .deletingLastPathComponent()
            .appendingPathComponent("XamrockDashboard")

        if FileManager.default.fileExists(atPath: parentDashboard.path) {
            return parentDashboard
        }

        // Try ./XamrockDashboard
        let localDashboard = currentDir.appendingPathComponent("XamrockDashboard")
        if FileManager.default.fileExists(atPath: localDashboard.path) {
            return localDashboard
        }

        throw DashboardError.dashboardNotFound(
            "Could not find XamrockDashboard directory. Use --dashboard-path to specify location."
        )
    }

    func resolveOutputPath() -> URL {
        if let path = outputPath {
            return URL(fileURLWithPath: path)
        }
        return URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
            .appendingPathComponent("dist")
    }

    func formatFileSize(_ bytes: Int) -> String {
        let kb = Double(bytes) / 1024.0
        let mb = kb / 1024.0

        if mb >= 1.0 {
            return String(format: "%.2f MB", mb)
        } else {
            return String(format: "%.2f KB", kb)
        }
    }
}
