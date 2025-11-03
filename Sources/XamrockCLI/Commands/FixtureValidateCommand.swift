import Foundation
import ArgumentParser

/// Validate a fixture file
public struct FixtureValidateCommand: ParsableCommand {

    public static let configuration = CommandConfiguration(
        commandName: "validate",
        abstract: "Validate fixture file format and patterns",
        discussion: """
        Checks fixture JSON structure, pattern syntax, and semantic types.

        Examples:
          xamrock fixture validate --fixture fixtures/login.json
          xamrock fixture validate --fixture fixtures/login.json --strict
        """
    )

    // MARK: - Arguments

    @Option(name: [.short, .customLong("fixture")], help: "Path to fixture file")
    public var fixturePath: String

    @Flag(name: .long, help: "Treat warnings as errors")
    public var strict: Bool = false

    // MARK: - Initialization

    public init() {}

    // MARK: - Command Execution

    public func run() throws {
        let fixtureURL = URL(fileURLWithPath: fixturePath)

        print("🔍 Validating fixture: \(fixtureURL.lastPathComponent)")
        print("")

        // Validate fixture
        let validator = FixtureValidator()
        let result = try validator.validate(fixtureAt: fixtureURL, strict: strict)

        // Print results
        printValidationResult(result)

        // Exit with appropriate code
        if !result.isValid {
            throw ExitCode(1)
        }
    }

    // MARK: - Output Formatting

    private func printValidationResult(_ result: ValidationResult) {
        // Print summary
        print(result.summary)
        print("")

        // Print errors
        if !result.errors.isEmpty {
            print("Errors:")
            for (index, error) in result.errors.enumerated() {
                print("  \(index + 1). ❌ \(error)")
            }
            print("")
        }

        // Print warnings
        if !result.warnings.isEmpty {
            print("Warnings:")
            for (index, warning) in result.warnings.enumerated() {
                print("  \(index + 1). ⚠️  \(warning)")
            }
            print("")
        }

        // Print success message
        if result.isValid && result.warnings.isEmpty {
            print("All checks passed! ✨")
            print("")
        }
    }
}
