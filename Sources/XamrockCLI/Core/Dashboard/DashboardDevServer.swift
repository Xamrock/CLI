import Foundation

/// Development server for XamrockDashboard with hot reload
public class DashboardDevServer {

    // MARK: - Properties

    private let dashboardPath: URL
    private let host: String
    private let port: Int
    private let verbose: Bool
    private var serverProcess: Process?
    private var watchProcess: Process?

    // MARK: - Initialization

    public init(
        dashboardPath: URL,
        host: String = "localhost",
        port: Int = 8000,
        verbose: Bool = false
    ) {
        self.dashboardPath = dashboardPath
        self.host = host
        self.port = port
        self.verbose = verbose
    }

    // MARK: - Server Operations

    /// Perform initial build
    public func performInitialBuild() async throws {
        let outputPath = dashboardPath.appendingPathComponent("Public")

        let builder = DashboardBuilder(
            dashboardPath: dashboardPath,
            outputPath: outputPath,
            production: true, // Use release builds (matches docker-compose.yml)
            verbose: verbose
        )

        try await builder.buildWASM()
        try builder.copyAssets()
    }

    /// Start the development server
    public func start() async throws {
        // Check if port is available
        if isPortInUse(port) {
            throw DashboardError.portInUse(port)
        }

        // Start HTTP server using Python
        let publicPath = dashboardPath.appendingPathComponent("Public")

        guard FileManager.default.fileExists(atPath: publicPath.path) else {
            throw DashboardError.invalidConfiguration("Public directory not found at \(publicPath.path)")
        }

        let process = Process()
        process.currentDirectoryURL = publicPath
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = ["python3", "-m", "http.server", String(port)]

        if verbose {
            process.standardOutput = FileHandle.standardOutput
            process.standardError = FileHandle.standardError
        } else {
            // Suppress server logs unless verbose
            let pipe = Pipe()
            process.standardOutput = pipe
            process.standardError = pipe
        }

        try process.run()
        self.serverProcess = process

        // Give server a moment to start
        try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
    }

    /// Keep the server alive
    public func keepAlive() async throws {
        // Wait for Ctrl+C or process termination
        guard let process = serverProcess else {
            return
        }

        // Install signal handler for graceful shutdown
        signal(SIGINT) { _ in
            print("\n\nShutting down dev server...")
            exit(0)
        }

        // Wait for process to exit
        process.waitUntilExit()

        if process.terminationStatus != 0 {
            throw DashboardError.serverStartFailed("Server exited with code \(process.terminationStatus)")
        }
    }

    /// Stop the server
    public func stop() {
        serverProcess?.terminate()
        watchProcess?.terminate()
    }

    // MARK: - Port Checking

    private func isPortInUse(_ port: Int) -> Bool {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = ["lsof", "-ti:\(port)"]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = nil

        do {
            try process.run()
            process.waitUntilExit()

            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            return !data.isEmpty
        } catch {
            return false
        }
    }
}
