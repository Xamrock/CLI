import Foundation

/// Manifest file describing exploration results and artifacts
public struct ExplorationManifest: Codable, Equatable {
    public let version: String
    public let timestamp: Date
    public let appIdentifier: String
    public let platform: String
    public let steps: Int
    public let goal: String
    public let exitCode: Int
    public let duration: TimeInterval
    public let screensDiscovered: Int
    public let failuresFound: Int
    public let artifacts: [String]

    public init(
        version: String = "1.0",
        timestamp: Date = Date(),
        appIdentifier: String,
        platform: String,
        steps: Int,
        goal: String,
        exitCode: Int,
        duration: TimeInterval,
        screensDiscovered: Int,
        failuresFound: Int,
        artifacts: [String]
    ) {
        self.version = version
        self.timestamp = timestamp
        self.appIdentifier = appIdentifier
        self.platform = platform
        self.steps = steps
        self.goal = goal
        self.exitCode = exitCode
        self.duration = duration
        self.screensDiscovered = screensDiscovered
        self.failuresFound = failuresFound
        self.artifacts = artifacts
    }
}
