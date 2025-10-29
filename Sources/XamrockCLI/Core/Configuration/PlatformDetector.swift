import Foundation

/// Supported mobile platforms
public enum Platform: String, Codable, Equatable, Sendable {
    case iOS
    case android
}

/// Detects the target platform from project structure and identifiers
public struct PlatformDetector {

    /// Detect platform from a project directory
    /// - Parameter directory: The directory to search for platform indicators
    /// - Returns: The detected platform, or nil if ambiguous
    public static func detectPlatform(in directory: URL) -> Platform? {
        let fileManager = FileManager.default

        // Check for iOS indicators
        if hasXcodeProject(in: directory, fileManager: fileManager) {
            return .iOS
        }

        // Check for Android indicators
        if hasGradleProject(in: directory, fileManager: fileManager) {
            return .android
        }

        if hasAndroidManifest(in: directory, fileManager: fileManager) {
            return .android
        }

        // No clear indicators found
        return nil
    }

    /// Detect platform from an app identifier (bundle ID or package name)
    /// - Parameter appIdentifier: Bundle ID (e.g., "com.example.MyApp") or package name (e.g., "com.example.myapp")
    /// - Returns: The detected platform, or nil if ambiguous
    public static func detectPlatform(fromAppIdentifier appIdentifier: String) -> Platform? {
        // iOS bundle IDs typically have capital letters (e.g., com.example.MyApp)
        // Android package names are typically all lowercase (e.g., com.example.myapp)

        // Split by dots to get segments
        let segments = appIdentifier.split(separator: ".")

        // Check if any segment after the first two (com.example) has uppercase
        let appSegments = segments.dropFirst(2)

        for segment in appSegments {
            // If segment has uppercase letters, likely iOS
            if segment.contains(where: { $0.isUppercase }) {
                return .iOS
            }
            // If segment is all lowercase and contains underscore, likely Android
            if segment.contains("_") {
                return .android
            }
        }

        // Ambiguous - could be either platform
        return nil
    }

    /// Resolve platform with explicit override
    /// - Parameters:
    ///   - explicit: Explicit platform specified by user (overrides detection)
    ///   - projectDirectory: Directory to auto-detect from
    /// - Returns: The resolved platform (explicit takes precedence)
    public static func resolvePlatform(
        explicit: Platform?,
        projectDirectory: URL
    ) -> Platform? {
        // Explicit platform always wins
        if let explicit = explicit {
            return explicit
        }

        // Fall back to auto-detection
        return detectPlatform(in: projectDirectory)
    }

    // MARK: - Private Helpers

    private static func hasXcodeProject(in directory: URL, fileManager: FileManager) -> Bool {
        guard let contents = try? fileManager.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: nil
        ) else {
            return false
        }

        return contents.contains { url in
            url.pathExtension == "xcodeproj" || url.pathExtension == "xcworkspace"
        }
    }

    private static func hasGradleProject(in directory: URL, fileManager: FileManager) -> Bool {
        let gradleFiles = [
            "build.gradle",
            "build.gradle.kts",
            "settings.gradle",
            "settings.gradle.kts"
        ]

        for file in gradleFiles {
            let filePath = directory.appendingPathComponent(file)
            if fileManager.fileExists(atPath: filePath.path) {
                return true
            }
        }

        return false
    }

    private static func hasAndroidManifest(in directory: URL, fileManager: FileManager) -> Bool {
        // Common Android manifest locations
        let manifestPaths = [
            "app/src/main/AndroidManifest.xml",
            "src/main/AndroidManifest.xml",
            "AndroidManifest.xml"
        ]

        for path in manifestPaths {
            let fullPath = directory.appendingPathComponent(path)
            if fileManager.fileExists(atPath: fullPath.path) {
                return true
            }
        }

        return false
    }
}
