import Foundation

/// Manages Xamrock configuration persistence
public class ConfigManager {
    private let configDirectory: URL
    private let configFileName = "config.json"

    private var configFileURL: URL {
        configDirectory.appendingPathComponent(configFileName)
    }

    public init(configDirectory: URL? = nil) {
        if let directory = configDirectory {
            self.configDirectory = directory
        } else {
            // Default to ~/.xamrock/
            let homeDirectory = FileManager.default.homeDirectoryForCurrentUser
            self.configDirectory = homeDirectory.appendingPathComponent(".xamrock")
        }
    }

    /// Save configuration to disk
    public func save(_ config: XamrockConfig) throws {
        // Create directory if it doesn't exist
        try FileManager.default.createDirectory(
            at: configDirectory,
            withIntermediateDirectories: true,
            attributes: nil
        )

        // Encode and save
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(config)
        try data.write(to: configFileURL)
    }

    /// Load configuration from disk
    public func load() throws -> XamrockConfig? {
        guard FileManager.default.fileExists(atPath: configFileURL.path) else {
            return nil
        }

        let data = try Data(contentsOf: configFileURL)
        let decoder = JSONDecoder()
        return try decoder.decode(XamrockConfig.self, from: data)
    }

    /// Delete configuration
    public func delete() throws {
        if FileManager.default.fileExists(atPath: configFileURL.path) {
            try FileManager.default.removeItem(at: configFileURL)
        }
    }

    /// Check if configuration exists
    public var configExists: Bool {
        FileManager.default.fileExists(atPath: configFileURL.path)
    }
}