import XCTest
import ArgumentParser
@testable import XamrockCLI

final class DashboardBuildCommandTests: XCTestCase {

    // MARK: - Path Resolution Tests

    func testResolveDashboardPath_ExplicitPath() throws {
        let command = try DashboardBuildCommand.parse(["--dashboard-path", "/Users/test/XamrockDashboard"])

        let resolved = try command.resolveDashboardPath()
        XCTAssertEqual(resolved.path, "/Users/test/XamrockDashboard")
    }

    func testResolveOutputPath_ExplicitPath() throws {
        let command = try DashboardBuildCommand.parse(["--output", "/Users/test/output"])

        let resolved = command.resolveOutputPath()
        XCTAssertEqual(resolved.path, "/Users/test/output")
    }

    func testResolveOutputPath_DefaultPath() throws {
        let command = try DashboardBuildCommand.parse([])

        let resolved = command.resolveOutputPath()
        XCTAssertTrue(resolved.path.hasSuffix("/dist"))
    }

    // MARK: - Default Values Tests

    func testDefaultValues() throws {
        let command = try DashboardBuildCommand.parse([])

        XCTAssertTrue(command.production)
        XCTAssertFalse(command.analyze)
        XCTAssertFalse(command.verbose)
        XCTAssertNil(command.outputPath)
        XCTAssertNil(command.dashboardPath)
    }

    // MARK: - Configuration Tests

    func testProductionFlag() throws {
        let command = try DashboardBuildCommand.parse(["--production"])

        XCTAssertTrue(command.production)
    }

    func testNoProductionFlag() throws {
        let command = try DashboardBuildCommand.parse(["--no-production"])

        XCTAssertFalse(command.production)
    }

    func testAnalyzeFlag() throws {
        let command = try DashboardBuildCommand.parse(["--analyze"])

        XCTAssertTrue(command.analyze)
    }

    func testVerboseFlag() throws {
        let command = try DashboardBuildCommand.parse(["--verbose"])

        XCTAssertTrue(command.verbose)
    }

    func testShortOutputFlag() throws {
        let command = try DashboardBuildCommand.parse(["-o", "/tmp/output"])

        XCTAssertEqual(command.outputPath, "/tmp/output")
    }

    func testShortVerboseFlag() throws {
        let command = try DashboardBuildCommand.parse(["-v"])

        XCTAssertTrue(command.verbose)
    }

    func testMultipleFlags() throws {
        let command = try DashboardBuildCommand.parse([
            "--output", "/tmp/dist",
            "--no-production",
            "--analyze",
            "--verbose"
        ])

        XCTAssertEqual(command.outputPath, "/tmp/dist")
        XCTAssertFalse(command.production)
        XCTAssertTrue(command.analyze)
        XCTAssertTrue(command.verbose)
    }

    // MARK: - File Size Formatting Tests

    func testFormatFileSize_KB() throws {
        let command = try DashboardBuildCommand.parse([])
        let formatted = command.formatFileSize(1024)

        XCTAssertEqual(formatted, "1.00 KB")
    }

    func testFormatFileSize_MB() throws {
        let command = try DashboardBuildCommand.parse([])
        let formatted = command.formatFileSize(1024 * 1024)

        XCTAssertEqual(formatted, "1.00 MB")
    }

    func testFormatFileSize_LargeMB() throws {
        let command = try DashboardBuildCommand.parse([])
        let formatted = command.formatFileSize(59 * 1024 * 1024)

        XCTAssertEqual(formatted, "59.00 MB")
    }
}
