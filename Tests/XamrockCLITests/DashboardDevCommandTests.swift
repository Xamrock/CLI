import XCTest
import ArgumentParser
@testable import XamrockCLI

final class DashboardDevCommandTests: XCTestCase {

    // MARK: - Path Resolution Tests

    func testResolveDashboardPath_ExplicitPath() throws {
        let command = try DashboardDevCommand.parse(["--dashboard-path", "/Users/test/XamrockDashboard"])

        let resolved = try command.resolveDashboardPath()
        XCTAssertEqual(resolved.path, "/Users/test/XamrockDashboard")
    }

    // MARK: - Default Values Tests

    func testDefaultValues() throws {
        let command = try DashboardDevCommand.parse([])

        XCTAssertEqual(command.port, 8000)
        XCTAssertEqual(command.host, "localhost")
        XCTAssertFalse(command.openBrowser)
        XCTAssertFalse(command.skipInitialBuild)
        XCTAssertFalse(command.verbose)
        XCTAssertNil(command.dashboardPath)
    }

    // MARK: - Configuration Tests

    func testCustomPort() throws {
        let command = try DashboardDevCommand.parse(["--port", "3000"])

        XCTAssertEqual(command.port, 3000)
    }

    func testCustomHost() throws {
        let command = try DashboardDevCommand.parse(["--host", "0.0.0.0"])

        XCTAssertEqual(command.host, "0.0.0.0")
    }

    func testOpenBrowserFlag() throws {
        let command = try DashboardDevCommand.parse(["--open"])

        XCTAssertTrue(command.openBrowser)
    }

    func testSkipInitialBuildFlag() throws {
        let command = try DashboardDevCommand.parse(["--skip-initial-build"])

        XCTAssertTrue(command.skipInitialBuild)
    }

    func testVerboseFlag() throws {
        let command = try DashboardDevCommand.parse(["--verbose"])

        XCTAssertTrue(command.verbose)
    }

    func testShortPortFlag() throws {
        let command = try DashboardDevCommand.parse(["-p", "9000"])

        XCTAssertEqual(command.port, 9000)
    }

    func testShortVerboseFlag() throws {
        let command = try DashboardDevCommand.parse(["-v"])

        XCTAssertTrue(command.verbose)
    }

    func testMultipleFlags() throws {
        let command = try DashboardDevCommand.parse([
            "--port", "3000",
            "--host", "0.0.0.0",
            "--open",
            "--verbose"
        ])

        XCTAssertEqual(command.port, 3000)
        XCTAssertEqual(command.host, "0.0.0.0")
        XCTAssertTrue(command.openBrowser)
        XCTAssertTrue(command.verbose)
    }
}
