import XCTest
import Foundation
@testable import XamrockCLI

final class PlatformOrchestratorTests: XCTestCase {

    // MARK: - Mock Orchestrator for Testing

    class MockOrchestrator: PlatformOrchestrator {
        var isAvailableValue = true
        var validateCalled = false
        var generateTestFileCalled = false
        var runExplorationCalled = false
        var collectArtifactsCalled = false

        var validateThrows: ConfigurationError?
        var generatedTestFileURL: URL?
        var explorationResult: TestExecutionResult?
        var artifacts: [URL] = []

        func isAvailable() -> Bool {
            return isAvailableValue
        }

        func validate(config: CLIConfiguration) throws {
            validateCalled = true
            if let error = validateThrows {
                throw error
            }
        }

        func generateTestFile(config: CLIConfiguration) throws -> URL {
            generateTestFileCalled = true
            return generatedTestFileURL ?? URL(fileURLWithPath: "/tmp/test.swift")
        }

        func runExploration(config: CLIConfiguration) throws -> TestExecutionResult {
            runExplorationCalled = true
            return explorationResult ?? TestExecutionResult(
                exitCode: 0,
                outputDirectory: URL(fileURLWithPath: "/tmp/output"),
                duration: 100,
                screensDiscovered: 10,
                failuresFound: 0
            )
        }

        func collectArtifacts(from outputDirectory: URL) throws -> [URL] {
            collectArtifactsCalled = true
            return artifacts
        }
    }

    // MARK: - Protocol Requirement Tests

    func testOrchestratorImplementsAllRequiredMethods() {
        // Given: A mock orchestrator
        let orchestrator = MockOrchestrator()
        let config = CLIConfiguration(
            platform: .iOS,
            appIdentifier: "com.example.App",
            projectPath: URL(fileURLWithPath: "/tmp/project"),
            steps: 20,
            goal: "Test",
            ciMode: false,
            outputDirectory: URL(fileURLWithPath: "/tmp/output"),
            generateDashboard: true,
            failOnIssues: false
        )

        // When/Then: All protocol methods should be callable
        XCTAssertTrue(orchestrator.isAvailable())
        XCTAssertNoThrow(try orchestrator.validate(config: config))
        XCTAssertNoThrow(try orchestrator.generateTestFile(config: config))
        XCTAssertNoThrow(try orchestrator.runExploration(config: config))
        XCTAssertNoThrow(try orchestrator.collectArtifacts(from: config.outputDirectory))

        // Verify all methods were called
        XCTAssertTrue(orchestrator.validateCalled)
        XCTAssertTrue(orchestrator.generateTestFileCalled)
        XCTAssertTrue(orchestrator.runExplorationCalled)
        XCTAssertTrue(orchestrator.collectArtifactsCalled)
    }

    func testOrchestratorCanReportAvailability() {
        // Given: Orchestrators with different availability
        let available = MockOrchestrator()
        available.isAvailableValue = true

        let unavailable = MockOrchestrator()
        unavailable.isAvailableValue = false

        // When/Then: Should accurately report availability
        XCTAssertTrue(available.isAvailable())
        XCTAssertFalse(unavailable.isAvailable())
    }

    func testOrchestratorValidationCanThrow() {
        // Given: An orchestrator that throws on validation
        let orchestrator = MockOrchestrator()
        orchestrator.validateThrows = ConfigurationError.missingDependency("Xcode")

        let config = CLIConfiguration(
            platform: .iOS,
            appIdentifier: "com.example.App",
            projectPath: URL(fileURLWithPath: "/tmp/project"),
            steps: 20,
            goal: "Test",
            ciMode: false,
            outputDirectory: URL(fileURLWithPath: "/tmp/output"),
            generateDashboard: true,
            failOnIssues: false
        )

        // When/Then: Should propagate validation errors
        XCTAssertThrowsError(try orchestrator.validate(config: config)) { error in
            guard let configError = error as? ConfigurationError else {
                XCTFail("Expected ConfigurationError")
                return
            }
            if case .missingDependency(let dep) = configError {
                XCTAssertEqual(dep, "Xcode")
            } else {
                XCTFail("Wrong validation error type")
            }
        }
    }

    func testOrchestratorGeneratesTestFile() throws {
        // Given: An orchestrator with a test file path
        let orchestrator = MockOrchestrator()
        let expectedPath = URL(fileURLWithPath: "/tmp/GeneratedTest.swift")
        orchestrator.generatedTestFileURL = expectedPath

        let config = CLIConfiguration(
            platform: .iOS,
            appIdentifier: "com.example.App",
            projectPath: URL(fileURLWithPath: "/tmp/project"),
            steps: 20,
            goal: "Test",
            ciMode: false,
            outputDirectory: URL(fileURLWithPath: "/tmp/output"),
            generateDashboard: true,
            failOnIssues: false
        )

        // When: Generating test file
        let result = try orchestrator.generateTestFile(config: config)

        // Then: Should return expected path
        XCTAssertEqual(result, expectedPath)
        XCTAssertTrue(orchestrator.generateTestFileCalled)
    }

    func testOrchestratorRunsExploration() throws {
        // Given: An orchestrator with exploration results
        let orchestrator = MockOrchestrator()
        let expectedResult = TestExecutionResult(
            exitCode: 0,
            outputDirectory: URL(fileURLWithPath: "/tmp/scout-results"),
            duration: 250,
            screensDiscovered: 15,
            failuresFound: 2
        )
        orchestrator.explorationResult = expectedResult

        let config = CLIConfiguration(
            platform: .iOS,
            appIdentifier: "com.example.App",
            projectPath: URL(fileURLWithPath: "/tmp/project"),
            steps: 20,
            goal: "Test checkout flow",
            ciMode: false,
            outputDirectory: URL(fileURLWithPath: "/tmp/output"),
            generateDashboard: true,
            failOnIssues: false
        )

        // When: Running exploration
        let result = try orchestrator.runExploration(config: config)

        // Then: Should return expected results
        XCTAssertEqual(result.exitCode, 0)
        XCTAssertEqual(result.screensDiscovered, 15)
        XCTAssertEqual(result.failuresFound, 2)
        XCTAssertEqual(result.duration, 250)
        XCTAssertTrue(orchestrator.runExplorationCalled)
    }

    func testOrchestratorCollectsArtifacts() throws {
        // Given: An orchestrator with artifacts
        let orchestrator = MockOrchestrator()
        let artifact1 = URL(fileURLWithPath: "/tmp/output/GeneratedTests.swift")
        let artifact2 = URL(fileURLWithPath: "/tmp/output/dashboard.html")
        orchestrator.artifacts = [artifact1, artifact2]

        let outputDir = URL(fileURLWithPath: "/tmp/output")

        // When: Collecting artifacts
        let artifacts = try orchestrator.collectArtifacts(from: outputDir)

        // Then: Should return all artifacts
        XCTAssertEqual(artifacts.count, 2)
        XCTAssertTrue(artifacts.contains(artifact1))
        XCTAssertTrue(artifacts.contains(artifact2))
        XCTAssertTrue(orchestrator.collectArtifactsCalled)
    }
}
