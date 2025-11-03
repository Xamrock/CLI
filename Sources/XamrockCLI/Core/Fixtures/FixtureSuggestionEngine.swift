import Foundation

/// Generates fixture JSON from suggestions
public struct FixtureSuggestionEngine {

    public init() {}

    /// Generate fixture structure from suggestions
    /// - Parameters:
    ///   - suggestions: Array of fixture suggestions
    ///   - name: Name for the fixture
    /// - Returns: Dictionary representing fixture JSON
    public func generateFixture(from suggestions: [FixtureSuggestion], name: String) -> [String: Any] {
        var patterns: [String: String] = [:]
        var defaults: [String: String] = [:]

        for suggestion in suggestions {
            // Add to patterns
            patterns[suggestion.patternSuggestion] = suggestion.value

            // If semantic type, also add to defaults
            if suggestion.patternSuggestion.hasPrefix("semantic:") {
                let semanticType = String(suggestion.patternSuggestion.dropFirst("semantic:".count))
                defaults[semanticType] = suggestion.value
            }
        }

        return [
            "version": "1.0",
            "name": name,
            "description": "Auto-generated fixture from exploration analysis",
            "patterns": patterns,
            "defaults": defaults,
            "fallbackMode": "aiGenerated"
        ]
    }

    /// Merge suggestions with existing fixture
    /// - Parameters:
    ///   - suggestions: New suggestions to add
    ///   - fixturePath: Path to existing fixture
    /// - Returns: Merged fixture structure
    public func merge(suggestions: [FixtureSuggestion], with fixturePath: URL) throws -> [String: Any] {
        // Load existing fixture
        let data = try Data(contentsOf: fixturePath)
        guard var fixture = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw FixtureError.invalidFormat
        }

        // Get existing patterns and defaults
        var patterns = (fixture["patterns"] as? [String: String]) ?? [:]
        var defaults = (fixture["defaults"] as? [String: String]) ?? [:]

        // Add new suggestions
        for suggestion in suggestions {
            // Only add if not already present
            if patterns[suggestion.patternSuggestion] == nil {
                patterns[suggestion.patternSuggestion] = suggestion.value
            }

            // Add to defaults if semantic
            if suggestion.patternSuggestion.hasPrefix("semantic:") {
                let semanticType = String(suggestion.patternSuggestion.dropFirst("semantic:".count))
                if defaults[semanticType] == nil {
                    defaults[semanticType] = suggestion.value
                }
            }
        }

        // Update fixture
        fixture["patterns"] = patterns
        fixture["defaults"] = defaults

        return fixture
    }
}

// MARK: - Suggestion Formatter

public struct SuggestionFormatter {

    public init() {}

    /// Format suggestions as interactive summary
    /// - Parameter suggestions: Array of suggestions
    /// - Returns: Formatted string for console output
    public func formatInteractiveSummary(suggestions: [FixtureSuggestion]) -> String {
        guard !suggestions.isEmpty else {
            return "✅ All fields using high-confidence fixture values!"
        }

        var output = """
        🔍 Found \(suggestions.count) field\(suggestions.count == 1 ? "" : "s") that could benefit from fixture entries:


        """

        // Group by priority
        let highPriority = suggestions.filter { $0.priority == .high }
        let mediumPriority = suggestions.filter { $0.priority == .medium }
        let lowPriority = suggestions.filter { $0.priority == .low }

        if !highPriority.isEmpty {
            output += "High Priority (fallback values used):\n"
            for suggestion in highPriority.prefix(10) {
                output += formatSuggestion(suggestion)
            }
            output += "\n"
        }

        if !mediumPriority.isEmpty {
            output += "Medium Priority (AI-generated values):\n"
            for suggestion in mediumPriority.prefix(10) {
                output += formatSuggestion(suggestion)
            }
            output += "\n"
        }

        if !lowPriority.isEmpty {
            output += "Low Priority:\n"
            for suggestion in lowPriority.prefix(5) {
                output += formatSuggestion(suggestion)
            }
            output += "\n"
        }

        return output
    }

    private func formatSuggestion(_ suggestion: FixtureSuggestion) -> String {
        var line = "  • \(suggestion.fieldId)"

        if let screenType = suggestion.screenType {
            line += " (on \(screenType) screen)"
        }

        line += "\n    Suggest: \(suggestion.patternSuggestion)"

        if suggestion.frequency > 1 {
            line += " (used \(suggestion.frequency)x)"
        }

        line += "\n"

        return line
    }

    /// Format as JSON for file output
    /// - Parameter suggestions: Array of suggestions
    /// - Returns: JSON data
    public func formatAsJSON(suggestions: [FixtureSuggestion]) throws -> Data {
        let suggestionsData = suggestions.map { suggestion in
            return [
                "fieldId": suggestion.fieldId,
                "value": suggestion.value,
                "patternSuggestion": suggestion.patternSuggestion,
                "priority": suggestion.priority == .high ? "high" : (suggestion.priority == .medium ? "medium" : "low"),
                "source": suggestion.source,
                "screenType": suggestion.screenType ?? "",
                "frequency": suggestion.frequency
            ] as [String: Any]
        }

        return try JSONSerialization.data(
            withJSONObject: ["suggestions": suggestionsData],
            options: [.prettyPrinted, .sortedKeys]
        )
    }
}

// MARK: - Errors

enum FixtureError: Error {
    case invalidFormat
}
