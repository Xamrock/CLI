import Foundation
import ArgumentParser

/// Initialize a new fixture file with templates
public struct FixtureInitCommand: ParsableCommand {

    public static let configuration = CommandConfiguration(
        commandName: "init",
        abstract: "Create a new fixture file with common defaults",
        discussion: """
        Generate a fixture file template with pre-populated patterns and defaults.

        Examples:
          xamrock fixture init
          xamrock fixture init --name "Login Flow" --output fixtures/login.json
          xamrock fixture init --template comprehensive
        """
    )

    // MARK: - Arguments

    @Option(name: [.short, .long], help: "Fixture name")
    public var name: String?

    @Option(name: [.short, .customLong("output")], help: "Output file path (default: fixtures/default.json)")
    public var outputPath: String?

    @Option(name: [.short, .long], help: "Template type: minimal, standard, comprehensive (default: standard)")
    public var template: FixtureTemplate = .standard

    // MARK: - Initialization

    public init() {}

    // MARK: - Command Execution

    public func run() throws {
        let outputURL = resolveOutputPath()

        print("📝 Creating fixture file...")
        print("   Template: \(template.rawValue)")
        print("   Output: \(outputURL.path)")

        // Generate fixture
        try generateFixture(at: outputURL)

        print("✅ Fixture created successfully!")
        print("")
        print("Next steps:")
        print("  1. Edit \(outputURL.path) to customize values")
        print("  2. Validate: xamrock fixture validate --fixture \(outputURL.path)")
        print("  3. Use in exploration: xamrock explore --fixture \(outputURL.path)")
    }

    // MARK: - Internal Methods

    func resolveOutputPath() -> URL {
        if let path = outputPath {
            return URL(fileURLWithPath: path)
        } else {
            // Default to fixtures/default.json
            let currentDir = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
            return currentDir
                .appendingPathComponent("fixtures")
                .appendingPathComponent("default.json")
        }
    }

    func generateFixture(at url: URL) throws {
        // Create parent directory if needed
        let parentDir = url.deletingLastPathComponent()
        if !FileManager.default.fileExists(atPath: parentDir.path) {
            try FileManager.default.createDirectory(
                at: parentDir,
                withIntermediateDirectories: true
            )
        }

        // Generate fixture based on template
        let fixture = template.generateFixture(name: name)

        // Encode to JSON with pretty printing
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(fixture)

        // Write to file
        try data.write(to: url)
    }
}

// MARK: - Fixture Template

public enum FixtureTemplate: String, ExpressibleByArgument, CaseIterable {
    case minimal
    case standard
    case comprehensive

    func generateFixture(name: String?) -> FixtureStructure {
        let fixtureName = name ?? "Test Fixture"

        switch self {
        case .minimal:
            return FixtureStructure(
                version: "1.0",
                name: fixtureName,
                description: "Minimal fixture template - add your patterns here",
                patterns: [:],
                defaults: [:],
                fallbackMode: "aiGenerated"
            )

        case .standard:
            return FixtureStructure(
                version: "1.0",
                name: fixtureName,
                description: "Standard fixture with common field types",
                patterns: [
                    "pattern:contains:email": "test@example.com",
                    "pattern:contains:password": "TestPassword123",
                    "pattern:contains:phone": "555-0100"
                ],
                defaults: [
                    "email": "default@example.com",
                    "password": "DefaultPass123",
                    "phone": "555-9999",
                    "name": "Test User",
                    "zipCode": "94103"
                ],
                fallbackMode: "aiGenerated"
            )

        case .comprehensive:
            return FixtureStructure(
                version: "1.0",
                name: fixtureName,
                description: "Comprehensive fixture with extensive examples",
                patterns: [
                    // Exact identifiers
                    "emailField": "exact@example.com",
                    "passwordField": "ExactPass123",

                    // Contains patterns
                    "pattern:contains:email": "test@example.com",
                    "pattern:contains:password": "SecurePass123!",
                    "pattern:contains:phone": "555-0123",
                    "pattern:contains:name": "Test User",

                    // Regex patterns
                    "pattern:regex:card.*[Nn]umber": "4242424242424242",
                    "pattern:regex:zip.*code": "94103",

                    // Semantic types
                    "semantic:email": "semantic@example.com",
                    "semantic:phone": "555-8888",
                    "semantic:url": "https://example.com",
                    "semantic:creditCard": "4242424242424242",
                    "semantic:zipCode": "94105",

                    // Screen context
                    "screen:login|field:email": "login@app.com",
                    "screen:login|field:password": "LoginPass123!",
                    "screen:checkout|field:email": "checkout@shop.com"
                ],
                defaults: [
                    "email": "default@example.com",
                    "password": "DefaultPass123",
                    "phone": "555-9999",
                    "name": "Test User",
                    "address": "123 Main St",
                    "city": "San Francisco",
                    "state": "CA",
                    "zipCode": "94103",
                    "country": "USA",
                    "url": "https://example.com",
                    "search": "test query",
                    "username": "testuser"
                ],
                fallbackMode: "aiGenerated"
            )
        }
    }
}

// MARK: - Fixture Structure

struct FixtureStructure: Codable {
    let version: String
    let name: String
    let description: String
    let patterns: [String: String]
    let defaults: [String: String]
    let fallbackMode: String
}
