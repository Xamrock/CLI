import Foundation

/// Errors specific to dashboard operations
public enum DashboardError: LocalizedError {
    case dashboardNotFound(String)
    case buildFailed(String)
    case serverStartFailed(String)
    case dockerNotRunning
    case portInUse(Int)
    case invalidConfiguration(String)

    public var errorDescription: String? {
        switch self {
        case .dashboardNotFound(let message):
            return "Dashboard not found: \(message)"
        case .buildFailed(let message):
            return "Build failed: \(message)"
        case .serverStartFailed(let message):
            return "Server failed to start: \(message)"
        case .dockerNotRunning:
            return "Docker is not running"
        case .portInUse(let port):
            return "Port \(port) is already in use"
        case .invalidConfiguration(let message):
            return "Invalid configuration: \(message)"
        }
    }

    public var recoverySuggestion: String? {
        switch self {
        case .dashboardNotFound:
            return """
            Could not locate XamrockDashboard directory.

            Try:
              1. Specify the path explicitly: --dashboard-path /path/to/XamrockDashboard
              2. Ensure XamrockDashboard is in the parent directory: ../XamrockDashboard
              3. Clone XamrockDashboard if not present
            """

        case .buildFailed(let message):
            return """
            Dashboard build failed: \(message)

            Try:
              1. Check that Docker is running: docker ps
              2. Ensure all dependencies are available
              3. Run with --verbose for detailed error messages
              4. Check the XamrockDashboard build logs
            """

        case .serverStartFailed:
            return """
            Development server failed to start.

            Try:
              1. Use a different port: --port 9000
              2. Check that the port is not in use: lsof -ti:8000
              3. Ensure build artifacts exist
            """

        case .dockerNotRunning:
            return """
            Docker Desktop is not running.

            Try:
              1. Start Docker Desktop: open -a Docker
              2. Wait for Docker to finish starting
              3. Verify: docker ps
            """

        case .portInUse(let port):
            return """
            Port \(port) is already in use.

            Try:
              1. Use a different port: --port 9000
              2. Find and kill the process: lsof -ti:\(port) | xargs kill
              3. Check what's using the port: lsof -i:\(port)
            """

        case .invalidConfiguration(let message):
            return """
            Configuration is invalid: \(message)

            Try:
              1. Check your command-line arguments
              2. Verify paths exist
              3. Run with --help to see valid options
            """
        }
    }
}
