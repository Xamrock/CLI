import Foundation

/// Generates JSON manifest files for exploration results
public class ManifestGenerator {

    public init() {}

    /// Generate manifest from exploration results
    public func generateManifest(
        config: CLIConfiguration,
        result: TestExecutionResult,
        artifacts: [URL]
    ) throws -> ExplorationManifest {
        // Extract artifact file names
        let artifactNames = artifacts.map { $0.lastPathComponent }

        return ExplorationManifest(
            version: "1.0",
            timestamp: Date(),
            appIdentifier: config.appIdentifier,
            platform: config.platform?.rawValue ?? "unknown",
            steps: config.steps,
            goal: config.goal,
            exitCode: result.exitCode,
            duration: result.duration,
            screensDiscovered: result.screensDiscovered,
            failuresFound: result.failuresFound,
            artifacts: artifactNames
        )
    }

    /// Save manifest to file
    public func saveManifest(_ manifest: ExplorationManifest, to fileURL: URL) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601

        let jsonData = try encoder.encode(manifest)
        try jsonData.write(to: fileURL)
    }
}
