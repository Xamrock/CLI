import Foundation

/// Validates fixture files for correctness
public struct FixtureValidator {

    public init() {}

    /// Validate a fixture file
    /// - Parameters:
    ///   - path: Path to fixture file
    ///   - strict: If true, treat warnings as errors
    /// - Returns: Validation result with errors and warnings
    public func validate(fixtureAt path: URL, strict: Bool = false) throws -> ValidationResult {
        var errors: [String] = []
        var warnings: [String] = []

        // Check file exists
        guard FileManager.default.fileExists(atPath: path.path) else {
            errors.append("Fixture file not found at: \(path.path)")
            return ValidationResult(isValid: false, errors: errors, warnings: warnings)
        }

        // Load and parse JSON
        let data: Data
        do {
            data = try Data(contentsOf: path)
        } catch {
            errors.append("Failed to read fixture file: \(error.localizedDescription)")
            return ValidationResult(isValid: false, errors: errors, warnings: warnings)
        }

        let json: [String: Any]
        do {
            guard let parsed = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                errors.append("Invalid JSON: Root must be an object")
                return ValidationResult(isValid: false, errors: errors, warnings: warnings)
            }
            json = parsed
        } catch {
            errors.append("Invalid JSON format: \(error.localizedDescription)")
            return ValidationResult(isValid: false, errors: errors, warnings: warnings)
        }

        // Validate schema
        validateSchema(json: json, errors: &errors, warnings: &warnings)

        // Validate patterns
        if let patterns = json["patterns"] as? [String: String] {
            validatePatterns(patterns: patterns, errors: &errors, warnings: &warnings)
        }

        // Validate defaults
        if let defaults = json["defaults"] as? [String: String] {
            validateDefaults(defaults: defaults, errors: &errors, warnings: &warnings)
        }

        // Validate fallback mode
        if let fallbackMode = json["fallbackMode"] as? String {
            validateFallbackMode(fallbackMode: fallbackMode, errors: &errors, warnings: &warnings)
        }

        // Determine if valid
        let isValid = errors.isEmpty && (!strict || warnings.isEmpty)

        return ValidationResult(isValid: isValid, errors: errors, warnings: warnings)
    }

    // MARK: - Schema Validation

    private func validateSchema(json: [String: Any], errors: inout [String], warnings: inout [String]) {
        // Check required fields
        if json["version"] == nil {
            warnings.append("Missing 'version' field - recommended to include version")
        }

        if json["patterns"] == nil {
            errors.append("Missing required 'patterns' field")
        } else if let patterns = json["patterns"] as? [String: String], patterns.isEmpty {
            warnings.append("Empty 'patterns' dictionary - fixture has no effect")
        }

        if json["defaults"] == nil {
            warnings.append("Missing 'defaults' field - consider adding semantic defaults")
        }

        if json["fallbackMode"] == nil {
            warnings.append("Missing 'fallbackMode' field - will default to 'aiGenerated'")
        }
    }

    // MARK: - Pattern Validation

    private func validatePatterns(patterns: [String: String], errors: inout [String], warnings: inout [String]) {
        let validSemanticTypes = [
            "email", "password", "phone", "url", "creditCard", "zipCode",
            "name", "address", "city", "state", "country", "username",
            "search", "date", "number"
        ]

        for (pattern, value) in patterns {
            if pattern.hasPrefix("pattern:regex:") {
                // Validate regex compilation
                let regexPattern = String(pattern.dropFirst("pattern:regex:".count))
                do {
                    _ = try NSRegularExpression(pattern: regexPattern, options: [])
                } catch {
                    errors.append("Invalid regex pattern '\(regexPattern)': \(error.localizedDescription)")
                }
            } else if pattern.hasPrefix("semantic:") {
                // Validate semantic type
                let semanticType = String(pattern.dropFirst("semantic:".count))
                if !validSemanticTypes.contains(semanticType) {
                    errors.append("Invalid semantic type '\(semanticType)'. Valid types: \(validSemanticTypes.joined(separator: ", "))")
                }
            } else if pattern.hasPrefix("screen:") {
                // Validate screen context format
                if !pattern.contains("|field:") {
                    errors.append("Invalid screen context pattern '\(pattern)'. Expected format: 'screen:SCREEN_TYPE|field:FIELD_NAME'")
                }
            } else if pattern.hasPrefix("pattern:") {
                // Validate pattern type
                let components = pattern.split(separator: ":", maxSplits: 2)
                if components.count >= 2 {
                    let patternType = String(components[1])
                    let validPatternTypes = ["contains", "regex", "placeholder", "label"]
                    if !validPatternTypes.contains(patternType) {
                        errors.append("Invalid pattern type '\(patternType)'. Valid types: \(validPatternTypes.joined(separator: ", "))")
                    }
                }
            }

            // Check for environment variable references
            if value.contains("${") {
                let varPattern = "\\$\\{([A-Z_][A-Z0-9_]*)\\}"
                if let regex = try? NSRegularExpression(pattern: varPattern, options: []) {
                    let matches = regex.matches(in: value, options: [], range: NSRange(value.startIndex..., in: value))
                    for match in matches {
                        if let varNameRange = Range(match.range(at: 1), in: value) {
                            let varName = String(value[varNameRange])
                            if ProcessInfo.processInfo.environment[varName] == nil {
                                warnings.append("Environment variable '\(varName)' is not set")
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: - Defaults Validation

    private func validateDefaults(defaults: [String: String], errors: inout [String], warnings: inout [String]) {
        let validSemanticTypes = [
            "email", "password", "phone", "url", "creditCard", "zipCode",
            "name", "address", "city", "state", "country", "username",
            "search", "date", "number"
        ]

        for (fieldType, _) in defaults {
            if !validSemanticTypes.contains(fieldType) {
                warnings.append("Unknown semantic field type in defaults: '\(fieldType)'")
            }
        }
    }

    // MARK: - Fallback Mode Validation

    private func validateFallbackMode(fallbackMode: String, errors: inout [String], warnings: inout [String]) {
        let validModes = ["aiGenerated", "semanticDefaults", "generic", "strict"]
        if !validModes.contains(fallbackMode) {
            errors.append("Invalid fallback mode '\(fallbackMode)'. Valid modes: \(validModes.joined(separator: ", "))")
        }
    }
}

// MARK: - Validation Result

public struct ValidationResult {
    public let isValid: Bool
    public let errors: [String]
    public let warnings: [String]

    public var summary: String {
        var parts: [String] = []

        if errors.isEmpty && warnings.isEmpty {
            return "✅ Fixture is valid"
        }

        if !errors.isEmpty {
            parts.append("\(errors.count) error\(errors.count == 1 ? "" : "s")")
        }

        if !warnings.isEmpty {
            parts.append("\(warnings.count) warning\(warnings.count == 1 ? "" : "s")")
        }

        let prefix = isValid ? "⚠️ " : "❌ "
        return prefix + parts.joined(separator: ", ")
    }
}
