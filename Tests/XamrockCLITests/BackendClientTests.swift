import XCTest
@testable import XamrockCLI

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
}