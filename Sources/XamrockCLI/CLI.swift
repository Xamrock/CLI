import Foundation
import ArgumentParser

/// Main CLI entry point for Xamrock
@main
struct Xamrock: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "xamrock",
        abstract: "AI-powered mobile app testing CLI",
        discussion: """
        Xamrock CLI provides AI-powered UI exploration and testing for iOS and Android apps.

        Currently supports iOS via AITestScout framework. Android support coming soon.
        """,
        version: "1.0.0",
        subcommands: [ExploreCommand.self],
        defaultSubcommand: ExploreCommand.self
    )
}
