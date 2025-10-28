import XCTest
import Foundation
@testable import XamrockCLI

final class TestFileOutputTests: XCTestCase {

    var tempDirectory: URL!

    override func setUp() {
        super.setUp()
        tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("TestFileOutputTests-\(UUID().uuidString)")
        try! FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
    }

    override func tearDown() {
        if FileManager.default.fileExists(atPath: tempDirectory.path) {
            try? FileManager.default.removeItem(at: tempDirectory)
        }
        super.tearDown()
    }

    // MARK: - Test File Save Location Tests

    func testGenerateTestFileSavesToOutputDirectory() throws {
        // Given: Configuration with output directory
        let outputDir = tempDirectory.appendingPathComponent("scout-results")
        let config = CLIConfiguration(
            platform: .iOS,
            appIdentifier: "com.example.MyApp",
            projectPath: tempDirectory.appendingPathComponent("MyApp.xcodeproj"),
            steps: 20,
            goal: "Test",
            outputDirectory: outputDir
        )

        // When: Generating test file
        let orchestrator = iOSOrchestrator()
        let testFileURL = try orchestrator.generateTestFile(config: config)

        // Then: Test file should be in output directory
        XCTAssertTrue(FileManager.default.fileExists(atPath: testFileURL.path))
        XCTAssertTrue(testFileURL.path.contains(outputDir.path),
                     "Test file should be saved in output directory")
    }

    func testGeneratedTestFileSavedWithPredictableName() throws {
        // Given: Configuration
        let outputDir = tempDirectory.appendingPathComponent("output")
        let config = CLIConfiguration(
            platform: .iOS,
            appIdentifier: "com.example.MyApp",
            projectPath: tempDirectory,
            steps: 20,
            goal: "Test",
            outputDirectory: outputDir
        )

        // When: Generating test file
        let orchestrator = iOSOrchestrator()
        let testFileURL = try orchestrator.generateTestFile(config: config)

        // Then: File should have predictable name
        XCTAssertTrue(testFileURL.lastPathComponent.hasSuffix(".swift"))
        XCTAssertTrue(testFileURL.lastPathComponent.contains("Scout") ||
                     testFileURL.lastPathComponent.contains("Exploration"))
    }
}
