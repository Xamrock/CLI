import Foundation

/// Analyzes exploration results to suggest fixture entries
public struct FixtureAnalyzer {

    public init() {}

    /// Analyze exploration results and suggest fixture entries
    /// - Parameters:
    ///   - resultsDirectory: Directory containing exploration results
    ///   - minConfidence: Minimum confidence threshold (0.0-1.0)
    /// - Returns: Array of fixture suggestions
    public func analyze(resultsDirectory: URL, minConfidence: Double) throws -> [FixtureSuggestion] {
        var suggestions: [FixtureSuggestion] = []

        // Find exploration result files
        let fileManager = FileManager.default
        guard fileManager.fileExists(atPath: resultsDirectory.path) else {
            return []
        }

        let files = try fileManager.contentsOfDirectory(
            at: resultsDirectory,
            includingPropertiesForKeys: nil
        )

        let explorationFiles = files.filter { $0.lastPathComponent.contains("exploration-result") && $0.pathExtension == "json" }

        for file in explorationFiles {
            let fileSuggestions = try analyzeExplorationFile(file, minConfidence: minConfidence)
            suggestions.append(contentsOf: fileSuggestions)
        }

        // Merge duplicate field suggestions and calculate frequency
        let merged = mergeSuggestions(suggestions)

        // Sort by priority and frequency
        return merged.sorted { (lhs, rhs) in
            if lhs.priority != rhs.priority {
                return lhs.priority.rawValue > rhs.priority.rawValue
            }
            return lhs.frequency > rhs.frequency
        }
    }

    // MARK: - Private Methods

    private func analyzeExplorationFile(_ file: URL, minConfidence: Double) throws -> [FixtureSuggestion] {
        let data = try Data(contentsOf: file)
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return []
        }

        guard let steps = json["steps"] as? [[String: Any]] else {
            return []
        }

        var suggestions: [FixtureSuggestion] = []

        for step in steps {
            guard let action = step["action"] as? [String: Any],
                  let actionType = action["type"] as? String,
                  actionType == "type",
                  let elementId = action["elementId"] as? String,
                  let value = action["value"] as? String,
                  let valueSource = action["valueSource"] as? [String: Any],
                  let sourceType = valueSource["type"] as? String else {
                continue
            }

            let confidence = confidenceForSource(sourceType)

            // Only suggest if below confidence threshold
            if confidence < minConfidence {
                let screenType = step["screenType"] as? String
                let priority = priorityForSource(sourceType)

                let suggestion = FixtureSuggestion(
                    fieldId: elementId,
                    value: value,
                    patternSuggestion: suggestPattern(for: elementId, value: value),
                    priority: priority,
                    source: sourceType,
                    screenType: screenType,
                    frequency: 1
                )

                suggestions.append(suggestion)
            }
        }

        return suggestions
    }

    private func confidenceForSource(_ sourceType: String) -> Double {
        switch sourceType {
        case "fixtureExact", "environmentVariable":
            return 1.0
        case "fixturePattern", "fixtureContext":
            return 0.9
        case "fixtureSemantic":
            return 0.8
        case "fixtureDefault":
            return 0.7
        case "aiGenerated":
            return 0.6
        case "fallback":
            return 0.4
        default:
            return 0.5
        }
    }

    private func priorityForSource(_ sourceType: String) -> FixturePriority {
        switch sourceType {
        case "fallback":
            return .high
        case "aiGenerated":
            return .medium
        case "fixtureDefault":
            return .low
        default:
            return .low
        }
    }

    func suggestPattern(for fieldId: String, value: String) -> String {
        let lowercasedId = fieldId.lowercased()

        // Check for semantic types
        let semanticTypes = [
            "email": "semantic:email",
            "password": "semantic:password",
            "phone": "semantic:phone",
            "url": "semantic:url",
            "card": "semantic:creditCard",
            "credit": "semantic:creditCard",
            "zip": "semantic:zipCode",
            "postal": "semantic:zipCode",
            "name": "semantic:name",
            "address": "semantic:address",
            "city": "semantic:city",
            "state": "semantic:state",
            "country": "semantic:country",
            "username": "semantic:username",
            "search": "semantic:search",
            "date": "semantic:date",
            "number": "semantic:number"
        ]

        for (keyword, semanticPattern) in semanticTypes {
            if lowercasedId.contains(keyword) {
                return semanticPattern
            }
        }

        // Check for common patterns
        if lowercasedId.contains("confirm") || lowercasedId.contains("repeat") {
            // Use exact identifier for confirmation fields
            return fieldId
        }

        // Default to exact identifier
        return fieldId
    }

    private func mergeSuggestions(_ suggestions: [FixtureSuggestion]) -> [FixtureSuggestion] {
        var merged: [String: FixtureSuggestion] = [:]

        for suggestion in suggestions {
            let key = suggestion.fieldId

            if let existing = merged[key] {
                // Merge: increase frequency, keep highest priority
                let newFrequency = existing.frequency + suggestion.frequency
                let newPriority = existing.priority.rawValue > suggestion.priority.rawValue ? existing.priority : suggestion.priority

                merged[key] = FixtureSuggestion(
                    fieldId: existing.fieldId,
                    value: existing.value,
                    patternSuggestion: existing.patternSuggestion,
                    priority: newPriority,
                    source: existing.source,
                    screenType: existing.screenType ?? suggestion.screenType,
                    frequency: newFrequency
                )
            } else {
                merged[key] = suggestion
            }
        }

        return Array(merged.values)
    }
}

// MARK: - Fixture Suggestion

public struct FixtureSuggestion {
    public let fieldId: String
    public let value: String
    public let patternSuggestion: String
    public let priority: FixturePriority
    public let source: String
    public let screenType: String?
    public let frequency: Int
}

public enum FixturePriority: Int {
    case high = 3
    case medium = 2
    case low = 1
}
