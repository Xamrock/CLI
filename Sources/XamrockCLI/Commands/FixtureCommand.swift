import Foundation
import ArgumentParser

/// Fixture management commands
public struct FixtureCommand: ParsableCommand {

    public static let configuration = CommandConfiguration(
        commandName: "fixture",
        abstract: "Manage test data fixtures for exploration",
        discussion: """
        Fixture commands help you create, validate, and analyze test data for UI exploration.

        Common workflows:
          1. Create fixture: xamrock fixture init --name "My Flow"
          2. Validate it: xamrock fixture validate --fixture fixtures/my-flow.json
          3. Use in exploration: xamrock explore --fixture fixtures/my-flow.json
          4. Analyze results: xamrock fixture analyze

        Learn more about fixtures at the AITestScout documentation.
        """,
        subcommands: [
            FixtureInitCommand.self,
            FixtureValidateCommand.self,
            FixtureAnalyzeCommand.self
        ]
    )

    public init() {}
}
