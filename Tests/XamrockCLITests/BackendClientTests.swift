import XCTest
@testable import XamrockCLI
import Foundation

final class BackendClientTests: XCTestCase {

    func testHealthCheck() async throws {
        // Arrange
        let client = BackendClient(baseURL: "http://localhost:8080")

        // Act
        let isHealthy = await client.healthCheck()

        // Assert
        XCTAssertTrue(isHealthy, "Backend health check should return true when backend is running")
    }

    func testHealthCheckWithInvalidURL() async throws {
        // Arrange
        let client = BackendClient(baseURL: "http://invalid:9999")

        // Act
        let isHealthy = await client.healthCheck()

        // Assert
        XCTAssertFalse(isHealthy, "Health check should return false for invalid backend URL")
    }

    // MARK: - Dashboard URL Tests

    func testGetDashboardURL() throws {
        // Arrange
        let client = BackendClient(baseURL: "http://localhost:8080")
        let sessionId = UUID()

        // Act
        let dashboardURL = client.getDashboardURL(sessionId: sessionId)

        // Assert
        XCTAssertEqual(
            dashboardURL,
            "http://localhost:8080/dashboard/sessions/\(sessionId)",
            "Dashboard URL should be correctly formatted"
        )
    }

    func testGetDashboardURLWithCustomBaseURL() throws {
        // Arrange
        let client = BackendClient(baseURL: "https://xamrock.example.com")
        let sessionId = UUID()

        // Act
        let dashboardURL = client.getDashboardURL(sessionId: sessionId)

        // Assert
        XCTAssertEqual(
            dashboardURL,
            "https://xamrock.example.com/dashboard/sessions/\(sessionId)",
            "Dashboard URL should work with custom base URLs"
        )
    }

    // MARK: - Artifact Type Tests

    func testArtifactTypeRawValues() throws {
        // Assert
        XCTAssertEqual(ArtifactType.screenshot.rawValue, "screenshot")
        XCTAssertEqual(ArtifactType.testFile.rawValue, "testFile")
        XCTAssertEqual(ArtifactType.report.rawValue, "report")
        XCTAssertEqual(ArtifactType.dashboard.rawValue, "dashboard")
        XCTAssertEqual(ArtifactType.manifest.rawValue, "manifest")
    }

    // MARK: - Session Models Tests

    func testSessionStatusCodable() throws {
        // Arrange
        let statuses: [SessionStatus] = [.running, .completed, .failed, .crashed]

        for status in statuses {
            // Act
            let encoded = try JSONEncoder().encode(status)
            let decoded = try JSONDecoder().decode(SessionStatus.self, from: encoded)

            // Assert
            XCTAssertEqual(status, decoded, "Session status should be encodable and decodable")
        }
    }

    func testSessionMetricsCodable() throws {
        // Arrange
        let metrics = SessionMetrics(
            screensDiscovered: 10,
            transitions: 25,
            durationSeconds: 120,
            successfulActions: 20,
            failedActions: 2,
            crashesDetected: 0,
            verificationsPerformed: 15,
            verificationsPassed: 14,
            retryAttempts: 3,
            successRatePercent: 90.0,
            healthScore: 85.5
        )

        // Act
        let encoded = try JSONEncoder().encode(metrics)
        let decoded = try JSONDecoder().decode(SessionMetrics.self, from: encoded)

        // Assert
        XCTAssertEqual(metrics.screensDiscovered, decoded.screensDiscovered)
        XCTAssertEqual(metrics.transitions, decoded.transitions)
        XCTAssertEqual(metrics.durationSeconds, decoded.durationSeconds)
        XCTAssertEqual(metrics.successfulActions, decoded.successfulActions)
        XCTAssertEqual(metrics.failedActions, decoded.failedActions)
        XCTAssertEqual(metrics.crashesDetected, decoded.crashesDetected)
        XCTAssertEqual(metrics.verificationsPerformed, decoded.verificationsPerformed)
        XCTAssertEqual(metrics.verificationsPassed, decoded.verificationsPassed)
        XCTAssertEqual(metrics.retryAttempts, decoded.retryAttempts)
        XCTAssertEqual(metrics.successRatePercent, decoded.successRatePercent)
        XCTAssertEqual(metrics.healthScore, decoded.healthScore)
    }

    func testArtifactUploadResponseCodable() throws {
        // Arrange
        let json = """
        {
            "url": "https://example.com/artifacts/123.png"
        }
        """.data(using: .utf8)!

        // Act
        let response = try JSONDecoder().decode(ArtifactUploadResponse.self, from: json)

        // Assert
        XCTAssertEqual(response.url, "https://example.com/artifacts/123.png")
    }

    func testSessionDetailCodable() throws {
        // Arrange
        let json = """
        {
            "id": "123e4567-e89b-12d3-a456-426614174000",
            "projectId": "223e4567-e89b-12d3-a456-426614174000",
            "status": "completed",
            "startedAt": "2025-01-01T12:00:00Z",
            "completedAt": "2025-01-01T12:05:00Z",
            "config": {
                "steps": 30,
                "goal": "Test exploration",
                "temperature": 0.7,
                "enableVerification": true,
                "maxRetries": 3
            },
            "metrics": {
                "screensDiscovered": 10,
                "transitions": 25,
                "durationSeconds": 300,
                "successfulActions": 20,
                "failedActions": 2,
                "crashesDetected": 0,
                "verificationsPerformed": 15,
                "verificationsPassed": 14,
                "retryAttempts": 3,
                "successRatePercent": 90.0,
                "healthScore": 85.5
            },
            "artifacts": {
                "screenshots": ["https://example.com/1.png", "https://example.com/2.png"],
                "testFiles": ["https://example.com/test.swift"],
                "reports": ["https://example.com/report.html"],
                "dashboardURL": "https://example.com/dashboard.html",
                "manifestURL": "https://example.com/manifest.json"
            },
            "dashboardURL": "https://example.com/dashboard/sessions/123"
        }
        """.data(using: .utf8)!

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        // Act
        let detail = try decoder.decode(SessionDetail.self, from: json)

        // Assert
        XCTAssertEqual(detail.id.uuidString.lowercased(), "123e4567-e89b-12d3-a456-426614174000")
        XCTAssertEqual(detail.projectId.uuidString.lowercased(), "223e4567-e89b-12d3-a456-426614174000")
        XCTAssertEqual(detail.status, .completed)
        XCTAssertNotNil(detail.config)
        XCTAssertEqual(detail.config?.steps, 30)
        XCTAssertEqual(detail.config?.goal, "Test exploration")
        XCTAssertNotNil(detail.metrics)
        XCTAssertEqual(detail.metrics?.screensDiscovered, 10)
        XCTAssertNotNil(detail.artifacts)
        XCTAssertEqual(detail.artifacts?.screenshots?.count, 2)
        XCTAssertEqual(detail.dashboardURL, "https://example.com/dashboard/sessions/123")
    }

    func testSessionSummaryCodable() throws {
        // Arrange
        let json = """
        {
            "id": "123e4567-e89b-12d3-a456-426614174000",
            "status": "completed",
            "startedAt": "2025-01-01T12:00:00Z",
            "completedAt": "2025-01-01T12:05:00Z",
            "screensDiscovered": 10,
            "successRatePercent": 90.0
        }
        """.data(using: .utf8)!

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        // Act
        let summary = try decoder.decode(SessionSummary.self, from: json)

        // Assert
        XCTAssertEqual(summary.id.uuidString.lowercased(), "123e4567-e89b-12d3-a456-426614174000")
        XCTAssertEqual(summary.status, .completed)
        XCTAssertEqual(summary.screensDiscovered, 10)
        XCTAssertEqual(summary.successRatePercent, 90.0)
    }

    // MARK: - Error Tests

    func testNewBackendErrors() throws {
        // Test uploadFailed error
        let uploadError = BackendError.uploadFailed
        XCTAssertEqual(uploadError.errorDescription, "Failed to upload artifact")

        // Test sessionNotFound error
        let notFoundError = BackendError.sessionNotFound
        XCTAssertEqual(notFoundError.errorDescription, "Session not found")

        // Test requestFailed error
        let requestError = BackendError.requestFailed
        XCTAssertEqual(requestError.errorDescription, "Request failed")
    }
}