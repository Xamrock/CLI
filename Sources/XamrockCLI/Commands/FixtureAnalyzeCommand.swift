import Foundation
import ArgumentParser

/// Analyze exploration results to suggest fixture entries
public struct FixtureAnalyzeCommand: ParsableCommand {

    public static let configuration = CommandConfiguration(
        commandName: "analyze",
        abstract: "Analyze exploration results and suggest fixture entries",
        discussion: """
        Scans previous exploration results to identify fields that used low-confidence
        values (fallback, AI-generated) and suggests fixture patterns.

        Examples:
          xamrock fixture analyze
          xamrock fixture analyze --results-dir ./scout-results --output fixtures/suggested.json
          xamrock fixture analyze --min-confidence 0.5
        """
    )

    // MARK: - Arguments

    @Option(name: .customLong("results-dir"), help: "Path to scout-results directory (default: ./scout-results)")
    public var resultsDir: String?

    @Option(name: [.short, .customLong("output")], help: "Output fixture path (optional)")
    public var outputPath: String?

    @Option(name: .customLong("min-confidence"), help: "Minimum confidence threshold (0.0-1.0, default: 0.7)")
    public var minConfidence: Double = 0.7

    @Option(name: .long, help: "Output format: interactive, json (default: interactive)")
    public var format: OutputFormat = .interactive

    // MARK: - Initialization

    public init() {}

    // MARK: - Command Execution

    public func run() throws {
        try runAnalysis()
    }

    func runAnalysis() throws {
        // Resolve results directory
        let resultsURL = resolveResultsDirectory()

        print("🔍 Analyzing exploration results...")
        print("   Results: \(resultsURL.path)")
        print("   Min confidence: \(minConfidence)")
        print("")

        // Analyze results
        let analyzer = FixtureAnalyzer()
        let suggestions = try analyzer.analyze(resultsDirectory: resultsURL, minConfidence: minConfidence)

        // Format output
        let formatter = SuggestionFormatter()

        switch format {
        case .interactive:
            // Print interactive summary
            let summary = formatter.formatInteractiveSummary(suggestions: suggestions)
            print(summary)

            // Optionally generate fixture
            if !suggestions.isEmpty {
                print("💡 Generate fixture from these suggestions?")
                print("")
                print("Run: xamrock fixture analyze --output fixtures/suggested.json --format json")
                print("")
            }

        case .json:
            // Generate fixture JSON
            if let outputPath = outputPath {
                let outputURL = URL(fileURLWithPath: outputPath)
                try generateAndSaveFixture(suggestions: suggestions, to: outputURL)
                print("✅ Fixture saved to: \(outputURL.path)")
                print("")
            } else {
                // Print JSON to stdout
                let jsonData = try formatter.formatAsJSON(suggestions: suggestions)
                if let jsonString = String(data: jsonData, encoding: .utf8) {
                    print(jsonString)
                }
            }
        }
    }

    // MARK: - Internal Methods

    private func resolveResultsDirectory() -> URL {
        if let path = resultsDir {
            return URL(fileURLWithPath: path)
        } else {
            // Default to ./scout-results
            let currentDir = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
            return currentDir.appendingPathComponent("scout-results")
        }
    }

    private func generateAndSaveFixture(suggestions: [FixtureSuggestion], to url: URL) throws {
        // Create parent directory if needed
        let parentDir = url.deletingLastPathComponent()
        if !FileManager.default.fileExists(atPath: parentDir.path) {
            try FileManager.default.createDirectory(
                at: parentDir,
                withIntermediateDirectories: true
            )
        }

        // Generate fixture
        let engine = FixtureSuggestionEngine()
        let fixture = engine.generateFixture(
            from: suggestions,
            name: "Suggested Fixture from Analysis"
        )

        // Encode to JSON
        let data = try JSONSerialization.data(
            withJSONObject: fixture,
            options: [.prettyPrinted, .sortedKeys]
        )

        // Write to file
        try data.write(to: url)
    }
}

// MARK: - Output Format

public enum OutputFormat: String, ExpressibleByArgument {
    case interactive
    case json
}
