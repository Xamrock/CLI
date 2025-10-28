import Foundation

/// Errors that can occur during configuration validation
public enum ConfigurationError: Error, Equatable, LocalizedError {
    case missingDependency(String)
    case invalidConfiguration(String)
    case platformNotAvailable(Platform)
    case invalidAppIdentifier(String)
    case projectNotFound(URL)

    public var errorDescription: String? {
        switch self {
        case .missingDependency(let dependency):
            return "Missing required dependency: \(dependency)"
        case .invalidConfiguration(let reason):
            return "Invalid configuration: \(reason)"
        case .platformNotAvailable(let platform):
            return "Platform not available: \(platform.rawValue)"
        case .invalidAppIdentifier(let identifier):
            return "Invalid app identifier: \(identifier)"
        case .projectNotFound(let path):
            return "Project not found at path: \(path.path)"
        }
    }
}
