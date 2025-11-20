import Foundation
import ArgumentParser

/// Dashboard management commands
public struct DashboardCommand: ParsableCommand {

    public static let configuration = CommandConfiguration(
        commandName: "dashboard",
        abstract: "Manage XamrockDashboard development and deployment",
        discussion: """
        Dashboard commands help you develop, build, and deploy the XamrockDashboard web application.

        Common workflows:
          1. Start dev server: xamrock dashboard dev
          2. Build for production: xamrock dashboard build
          3. Custom port: xamrock dashboard dev --port 3000

        The dashboard is built with Swift + WebAssembly using the Gossamer framework.
        """,
        subcommands: [
            DashboardDevCommand.self,
            DashboardBuildCommand.self
        ]
    )

    public init() {}
}
