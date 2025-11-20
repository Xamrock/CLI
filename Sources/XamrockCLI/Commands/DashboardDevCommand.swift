import Foundation
import ArgumentParser

/// Start dashboard development server with hot reload
public struct DashboardDevCommand: AsyncParsableCommand {

    public static let configuration = CommandConfiguration(
        commandName: "dev",
        abstract: "Start development server with hot reload",
        discussion: """
        Starts a local development server for XamrockDashboard with:
          - File watching for Swift sources
          - Automatic browser refresh
          - Fast incremental builds

        Examples:
          xamrock dashboard dev
          xamrock dashboard dev --port 3000
          xamrock dashboard dev --open
        """
    )

    // MARK: - Server Options

    @Option(name: [.short, .customLong("port")], help: "Dev server port (default: 8000)")
    public var port: Int = 8000

    @Option(name: .customLong("host"), help: "Dev server host (default: localhost)")
    public var host: String = "localhost"

    @Flag(name: .customLong("open"), help: "Open browser automatically")
    public var openBrowser: Bool = false

    // MARK: - Build Options

    @Flag(name: .customLong("skip-initial-build"), help: "Skip initial build and use existing artifacts")
    public var skipInitialBuild: Bool = false

    @Option(name: .customLong("dashboard-path"), help: "Path to XamrockDashboard directory")
    public var dashboardPath: String?

    @Flag(name: [.short, .customLong("verbose")], help: "Verbose output")
    public var verbose: Bool = false

    // MARK: - Initialization

    public init() {}

    // MARK: - Command Execution

    public func run() async throws {
        let formatter = ConsoleFormatter(verbose: verbose)

        // Print start banner
        print("")
        print(formatter.formatColored("╔═══════════════════════════════════════════════════════════════╗", color: .cyan))
        print(formatter.formatColored("║           🌐 XamrockDashboard Dev Server                    ║", color: .cyan))
        print(formatter.formatColored("╚═══════════════════════════════════════════════════════════════╝", color: .cyan))
        print("")

        // Resolve dashboard path
        let dashboardURL = try resolveDashboardPath()
        print("  " + formatter.formatColored("Dashboard:", color: .bold) + " \(dashboardURL.path)")
        print("  " + formatter.formatColored("Server:", color: .bold) + " http://\(host):\(port)")
        print("")

        // Initialize dev server
        let devServer = DashboardDevServer(
            dashboardPath: dashboardURL,
            host: host,
            port: port,
            verbose: verbose
        )

        // Perform initial build unless skipped
        if !skipInitialBuild {
            print(formatter.formatProgress(step: "Building dashboard", isDone: false))
            do {
                try await devServer.performInitialBuild()
                print(formatter.formatProgress(step: "Building dashboard", isDone: true))
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
        }

        // Start dev server
        print(formatter.formatProgress(step: "Starting dev server", isDone: false))
        do {
            try await devServer.start()
            print(formatter.formatProgress(step: "Starting dev server", isDone: true))
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

        print("")
        print(formatter.formatSuccess("Dev server running at:"))
        print(formatter.formatLink("http://\(host):\(port)"))
        print("")
        print(formatter.formatInfo("Press Ctrl+C to stop"))
        print("")

        // Open browser if requested
        if openBrowser {
            try openInBrowser(url: "http://\(host):\(port)")
        }

        // Keep running until interrupted
        try await devServer.keepAlive()
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

    func openInBrowser(url: String) throws {
        #if os(macOS)
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        process.arguments = [url]
        try process.run()
        #endif
    }
}
