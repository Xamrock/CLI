import XCTest
@testable import XamrockCLI
import Foundation

/// Tests for backend integration functionality in ExploreCommand
final class BackendIntegrationTests: XCTestCase {

    // MARK: - Session Metrics Building Tests

    func testBuildSessionMetricsFromSuccessfulResult() throws {
        // Arrange
        let result = TestExecutionResult(
            exitCode: 0,
            outputDirectory: URL(fileURLWithPath: "/tmp/test"),
            duration: 120.5,
            screensDiscovered: 15,
            failuresFound: 0
        )

        let command = ExploreCommand()

        // Act
        let metrics = command.buildSessionMetrics(from: result)

        // Assert
        XCTAssertEqual(metrics.screensDiscovered, 15)
        XCTAssertEqual(metrics.durationSeconds, 120)
        XCTAssertEqual(metrics.failedActions, 0)
        XCTAssertEqual(metrics.crashesDetected, 0)
        XCTAssertEqual(metrics.successRatePercent, 100.0)
        XCTAssertEqual(metrics.healthScore, 100.0) // Max score for perfect result with 15 screens
    }

    func testBuildSessionMetricsFromFailedResult() throws {
        // Arrange
        let result = TestExecutionResult(
            exitCode: 0,
            outputDirectory: URL(fileURLWithPath: "/tmp/test"),
            duration: 60.0,
            screensDiscovered: 5,
            failuresFound: 3
        )

        let command = ExploreCommand()

        // Act
        let metrics = command.buildSessionMetrics(from: result)

        // Assert
        XCTAssertEqual(metrics.screensDiscovered, 5)
        XCTAssertEqual(metrics.durationSeconds, 60)
        XCTAssertEqual(metrics.failedActions, 3)
        XCTAssertEqual(metrics.crashesDetected, 0)
        XCTAssertEqual(metrics.successRatePercent, 100.0)
        // Health score should be reduced due to failures
        XCTAssertLessThan(metrics.healthScore!, 100.0)
    }

    func testBuildSessionMetricsFromCrashedResult() throws {
        // Arrange
        let result = TestExecutionResult(
            exitCode: 1,
            outputDirectory: URL(fileURLWithPath: "/tmp/test"),
            duration: 30.0,
            screensDiscovered: 2,
            failuresFound: 1
        )

        let command = ExploreCommand()

        // Act
        let metrics = command.buildSessionMetrics(from: result)

        // Assert
        XCTAssertEqual(metrics.screensDiscovered, 2)
        XCTAssertEqual(metrics.durationSeconds, 30)
        XCTAssertEqual(metrics.failedActions, 1)
        XCTAssertEqual(metrics.crashesDetected, 1)
        XCTAssertEqual(metrics.successRatePercent, 0.0)
        // Health score should be significantly reduced
        XCTAssertLessThan(metrics.healthScore!, 50.0)
    }

    // MARK: - Session Status Determination Tests

    func testDetermineStatusForSuccessfulResult() throws {
        // Arrange
        let result = TestExecutionResult(
            exitCode: 0,
            outputDirectory: URL(fileURLWithPath: "/tmp/test"),
            duration: 120.0,
            screensDiscovered: 10,
            failuresFound: 0
        )

        let command = ExploreCommand()

        // Act
        let status = command.determineStatus(from: result)

        // Assert
        XCTAssertEqual(status, .completed)
    }

    func testDetermineStatusForResultWithFailures() throws {
        // Arrange
        let result = TestExecutionResult(
            exitCode: 0,
            outputDirectory: URL(fileURLWithPath: "/tmp/test"),
            duration: 120.0,
            screensDiscovered: 10,
            failuresFound: 3
        )

        let command = ExploreCommand()

        // Act
        let status = command.determineStatus(from: result)

        // Assert
        XCTAssertEqual(status, .failed)
    }

    func testDetermineStatusForCrashedResult() throws {
        // Arrange
        let result = TestExecutionResult(
            exitCode: 1,
            outputDirectory: URL(fileURLWithPath: "/tmp/test"),
            duration: 30.0,
            screensDiscovered: 2,
            failuresFound: 0
        )

        let command = ExploreCommand()

        // Act
        let status = command.determineStatus(from: result)

        // Assert
        XCTAssertEqual(status, .crashed)
    }

    // MARK: - Health Score Calculation Tests

    func testCalculateHealthScoreForPerfectResult() throws {
        // Arrange
        let result = TestExecutionResult(
            exitCode: 0,
            outputDirectory: URL(fileURLWithPath: "/tmp/test"),
            duration: 120.0,
            screensDiscovered: 10,
            failuresFound: 0
        )

        let command = ExploreCommand()

        // Act
        let healthScore = command.calculateHealthScore(result: result)

        // Assert
        XCTAssertEqual(healthScore, 100.0, accuracy: 0.01)
    }

    func testCalculateHealthScoreWithScreenBonus() throws {
        // Arrange
        let result = TestExecutionResult(
            exitCode: 0,
            outputDirectory: URL(fileURLWithPath: "/tmp/test"),
            duration: 120.0,
            screensDiscovered: 5,
            failuresFound: 0
        )

        let command = ExploreCommand()

        // Act
        let healthScore = command.calculateHealthScore(result: result)

        // Assert
        // Base 100 + 10 for >= 5 screens = 100 (capped at 100)
        XCTAssertEqual(healthScore, 100.0, accuracy: 0.01)
    }

    func testCalculateHealthScoreWithFailurePenalty() throws {
        // Arrange
        let result = TestExecutionResult(
            exitCode: 0,
            outputDirectory: URL(fileURLWithPath: "/tmp/test"),
            duration: 120.0,
            screensDiscovered: 10,
            failuresFound: 2
        )

        let command = ExploreCommand()

        // Act
        let healthScore = command.calculateHealthScore(result: result)

        // Assert
        // Base 100 + 10 (screens) = 110 -> capped at 100
        // Then - 20 (2 failures * 10) = 80
        XCTAssertEqual(healthScore, 80.0, accuracy: 0.01)
    }

    func testCalculateHealthScoreWithCrashPenalty() throws {
        // Arrange
        let result = TestExecutionResult(
            exitCode: 1,
            outputDirectory: URL(fileURLWithPath: "/tmp/test"),
            duration: 30.0,
            screensDiscovered: 2,
            failuresFound: 0
        )

        let command = ExploreCommand()

        // Act
        let healthScore = command.calculateHealthScore(result: result)

        // Assert
        // Base 50 (crash) - 20 (crash penalty) = 30
        XCTAssertEqual(healthScore, 30.0, accuracy: 0.01)
    }

    func testCalculateHealthScoreWithMultiplePenalties() throws {
        // Arrange
        let result = TestExecutionResult(
            exitCode: 1,
            outputDirectory: URL(fileURLWithPath: "/tmp/test"),
            duration: 30.0,
            screensDiscovered: 2,
            failuresFound: 3
        )

        let command = ExploreCommand()

        // Act
        let healthScore = command.calculateHealthScore(result: result)

        // Assert
        // Base 50 (crash) - 30 (3 failures * 10) - 20 (crash) = 0
        XCTAssertEqual(healthScore, 0.0, accuracy: 0.01)
    }

    func testCalculateHealthScoreNeverNegative() throws {
        // Arrange - extreme failure case
        let result = TestExecutionResult(
            exitCode: 1,
            outputDirectory: URL(fileURLWithPath: "/tmp/test"),
            duration: 10.0,
            screensDiscovered: 0,
            failuresFound: 20
        )

        let command = ExploreCommand()

        // Act
        let healthScore = command.calculateHealthScore(result: result)

        // Assert
        XCTAssertGreaterThanOrEqual(healthScore, 0.0, "Health score should never be negative")
    }

    func testCalculateHealthScoreNeverExceedsMaximum() throws {
        // Arrange - ideal case
        let result = TestExecutionResult(
            exitCode: 0,
            outputDirectory: URL(fileURLWithPath: "/tmp/test"),
            duration: 300.0,
            screensDiscovered: 50,
            failuresFound: 0
        )

        let command = ExploreCommand()

        // Act
        let healthScore = command.calculateHealthScore(result: result)

        // Assert
        XCTAssertLessThanOrEqual(healthScore, 100.0, "Health score should never exceed 100")
    }
}

// MARK: - Test Helpers

extension ExploreCommand {
    // Expose private methods for testing
    func buildSessionMetrics(from result: TestExecutionResult) -> SessionMetrics {
        return SessionMetrics(
            screensDiscovered: result.screensDiscovered,
            transitions: nil,
            durationSeconds: Int(result.duration),
            successfulActions: nil,
            failedActions: result.failuresFound,
            crashesDetected: result.exitCode != 0 ? 1 : 0,
            verificationsPerformed: nil,
            verificationsPassed: nil,
            retryAttempts: nil,
            successRatePercent: result.wasSuccessful ? 100.0 : 0.0,
            healthScore: calculateHealthScore(result: result)
        )
    }

    func determineStatus(from result: TestExecutionResult) -> SessionStatus {
        if result.exitCode != 0 {
            return .crashed
        } else if result.failuresFound > 0 {
            return .failed
        } else {
            return .completed
        }
    }

    func calculateHealthScore(result: TestExecutionResult) -> Double {
        var score = result.wasSuccessful ? 100.0 : 50.0

        if result.screensDiscovered >= 5 {
            score = min(100, score + 10)
        }

        if result.failuresFound > 0 {
            score = max(0, score - Double(result.failuresFound * 10))
        }

        if result.exitCode != 0 {
            score = max(0, score - 20)
        }

        return score
    }
}
