import Foundation

/// Terminal color codes
public enum ConsoleColor: String {
    case red = "\u{001B}[0;31m"
    case green = "\u{001B}[0;32m"
    case yellow = "\u{001B}[0;33m"
    case blue = "\u{001B}[0;34m"
    case magenta = "\u{001B}[0;35m"
    case cyan = "\u{001B}[0;36m"
    case reset = "\u{001B}[0;0m"
    case bold = "\u{001B}[1m"
}

/// Formats console output with colors and structure
public class ConsoleFormatter {

    private let verbose: Bool
    private let useColors: Bool

    public init(verbose: Bool = false, useColors: Bool = true) {
        self.verbose = verbose
        self.useColors = useColors
    }

    // MARK: - Banners

    /// Format the start banner
    public func formatStartBanner(config: CLIConfiguration) -> String {
        var lines: [String] = []

        lines.append("")
        lines.append(formatColored("╔═══════════════════════════════════════════════════════════════╗", color: .cyan))
        lines.append(formatColored("║              🤖 Xamrock CLI - AI Test Explorer              ║", color: .cyan))
        lines.append(formatColored("╚═══════════════════════════════════════════════════════════════╝", color: .cyan))
        lines.append("")
        lines.append("  " + formatColored("App:", color: .bold) + " \(config.appIdentifier)")
        lines.append("  " + formatColored("Platform:", color: .bold) + " \(config.platform?.rawValue ?? "auto-detect")")
        lines.append("  " + formatColored("Steps:", color: .bold) + " \(config.steps)")
        lines.append("  " + formatColored("Goal:", color: .bold) + " \(config.goal)")

        if verbose {
            lines.append("  " + formatColored("Output:", color: .bold) + " \(config.outputDirectory.path)")
            lines.append("  " + formatColored("CI Mode:", color: .bold) + " \(config.ciMode)")
            lines.append("  " + formatColored("Generate Dashboard:", color: .bold) + " \(config.generateDashboard)")
        }

        lines.append("")

        return lines.joined(separator: "\n")
    }

    /// Format the completion banner
    public func formatCompletionBanner(result: TestExecutionResult) -> String {
        var lines: [String] = []

        lines.append("")

        if result.wasSuccessful {
            lines.append(formatColored("╔═══════════════════════════════════════════════════════════════╗", color: .green))
            lines.append(formatColored("║                  ✅ Exploration Complete!                     ║", color: .green))
            lines.append(formatColored("╚═══════════════════════════════════════════════════════════════╝", color: .green))
        } else {
            let exitCodeText = result.exitCode != 0 ? " (Exit Code: \(result.exitCode))" : ""
            lines.append(formatColored("╔═══════════════════════════════════════════════════════════════╗", color: .red))
            lines.append(formatColored("║                  ❌ Exploration Failed\(exitCodeText.padding(toLength: 24 - exitCodeText.count, withPad: " ", startingAt: 0))║", color: .red))
            lines.append(formatColored("╚═══════════════════════════════════════════════════════════════╝", color: .red))
        }

        lines.append("")
        lines.append(formatMetrics(result: result))

        // Add error details if present
        if let errorMessage = result.errorMessage {
            lines.append("")
            lines.append(formatColored("Error:", color: .red))
            lines.append("  \(errorMessage)")
        }

        // Add suggestion if present
        if let suggestion = result.errorSuggestion {
            lines.append("")
            lines.append(formatColored("💡 Suggestion:", color: .yellow))
            // Indent each line of the suggestion
            let suggestionLines = suggestion.components(separatedBy: .newlines)
            for line in suggestionLines {
                lines.append("  \(line)")
            }
        }

        return lines.joined(separator: "\n")
    }

    // MARK: - Progress

    /// Format a progress step
    public func formatProgress(step: String, isDone: Bool) -> String {
        let icon = isDone ? "✅" : "⏳"
        return "\(icon) \(step)"
    }

    // MARK: - Errors

    /// Format an error
    public func formatError(_ error: Error) -> String {
        let errorMessage: String
        if let configError = error as? ConfigurationError {
            errorMessage = configError.localizedDescription
        } else {
            errorMessage = error.localizedDescription
        }

        return formatError(errorMessage)
    }

    /// Format an error message
    public func formatError(_ message: String) -> String {
        return formatColored("❌ ERROR: ", color: .red) + message
    }

    // MARK: - Metrics

    /// Format test execution metrics
    public func formatMetrics(result: TestExecutionResult) -> String {
        var lines: [String] = []

        lines.append("  " + formatColored("Duration:", color: .bold) + " \(formatDuration(result.duration))")
        lines.append("  " + formatColored("Screens Discovered:", color: .bold) + " \(result.screensDiscovered)")

        if result.failuresFound > 0 {
            lines.append("  " + formatColored("Failures Found:", color: .red) + " \(result.failuresFound)")
        } else {
            lines.append("  " + formatColored("Failures Found:", color: .green) + " 0")
        }

        return lines.joined(separator: "\n")
    }

    // MARK: - Artifacts

    /// Format artifact list
    public func formatArtifactList(artifacts: [URL]) -> String {
        guard !artifacts.isEmpty else {
            return "  No artifacts generated"
        }

        var lines: [String] = []
        lines.append(formatColored("Artifacts Generated:", color: .bold))

        for artifact in artifacts {
            let fileName = artifact.lastPathComponent
            let icon = getFileIcon(for: fileName)
            lines.append("  \(icon) \(fileName)")
        }

        return lines.joined(separator: "\n")
    }

    // MARK: - Utilities

    /// Format duration in a human-readable way
    public func formatDuration(_ seconds: TimeInterval) -> String {
        let totalSeconds = Int(seconds)

        if totalSeconds < 60 {
            return "\(totalSeconds)s"
        } else if totalSeconds < 3600 {
            let minutes = totalSeconds / 60
            let remainingSeconds = totalSeconds % 60
            return "\(minutes):\(String(format: "%02d", remainingSeconds))"
        } else {
            let hours = totalSeconds / 3600
            let minutes = (totalSeconds % 3600) / 60
            let remainingSeconds = totalSeconds % 60
            return "\(hours):\(String(format: "%02d", minutes)):\(String(format: "%02d", remainingSeconds))"
        }
    }

    /// Apply color to text
    public func formatColored(_ text: String, color: ConsoleColor) -> String {
        guard useColors else { return text }
        return color.rawValue + text + ConsoleColor.reset.rawValue
    }

    /// Format a clickable link (underlined cyan)
    public func formatLink(_ url: String) -> String {
        guard useColors else { return url }
        return "   \u{001B}[4;36m\(url)\u{001B}[0m"
    }

    /// Format an informational message
    public func formatInfo(_ message: String) -> String {
        guard useColors else { return message }
        return "   \u{001B}[36mℹ\u{001B}[0m \(message)"
    }

    /// Format a success message
    public func formatSuccess(_ message: String) -> String {
        guard useColors else { return message }
        return "   \u{001B}[32m✓\u{001B}[0m \(message)"
    }

    // MARK: - Private Helpers

    private func getFileIcon(for fileName: String) -> String {
        if fileName.hasSuffix(".swift") {
            return "📝"
        } else if fileName.hasSuffix(".md") {
            return "📄"
        } else if fileName.hasSuffix(".html") {
            return "🌐"
        } else if fileName.hasSuffix(".json") {
            return "📊"
        } else {
            return "📁"
        }
    }
}
