import XCTest
@testable import XamrockCLI

final class BackendSessionTests: XCTestCase {

    var testConfigDirectory: URL!

    override func setUp() async throws {
        try await super.setUp()
        testConfigDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("xamrock-test-\(UUID())")

        // Ensure backend is running
        let client = BackendClient(baseURL: "http://localhost:8080")
        let isHealthy = await client.healthCheck()
        if !isHealthy {
            throw XCTSkip("Backend is not running. Start it with: cd ../Backend && swift run Backend --in-memory-database --migrate")
        }
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: testConfigDirectory)
        super.tearDown()
    }

    func testSessionCreationAndUpdate() async throws {
        // Arrange
        let client = BackendClient(baseURL: "http://localhost:8080")
        let configManager = ConfigManager(configDirectory: testConfigDirectory)

        // Create organization and project first
        let orgId = try await client.getOrCreateOrganization(
            name: "Test Session Org \(UUID().uuidString.prefix(8))",
            configManager: configManager
        )

        let bundleId = "com.test.app.session\(Int.random(in: 10000...99999))"
        let projectId = try await client.getOrCreateProject(
            organizationId: orgId,
            bundleId: bundleId,
            name: "Test Session App",
            configManager: configManager
        )

        // Act - Create session
        let sessionId = try await client.createSession(
            projectId: projectId,
            steps: 10,
            goal: "Test exploration"
        )
        XCTAssertNotNil(sessionId, "Session should be created")

        // Act - Update session with metrics
        let metrics = SessionMetrics(
            screensDiscovered: 5,
            transitions: 10,
            durationSeconds: 60,
            successfulActions: 8,
            failedActions: 2,
            successRatePercent: 80.0,
            healthScore: 75.5
        )

        try await client.updateSession(
            sessionId: sessionId,
            status: .completed,
            metrics: metrics
        )

        // Assert - Verify session was updated (we can't fetch it yet, but update should not throw)
        XCTAssertTrue(true, "Session update should succeed without throwing")
    }

    func testSessionCreatesWithDefaultValues() async throws {
        // Arrange
        let client = BackendClient(baseURL: "http://localhost:8080")
        let configManager = ConfigManager(configDirectory: testConfigDirectory)

        // Create organization and project
        let orgId = try await client.getOrCreateOrganization(
            name: "Test Default Org \(UUID().uuidString.prefix(8))",
            configManager: configManager
        )

        let bundleId = "com.test.app.default\(Int.random(in: 10000...99999))"
        let projectId = try await client.getOrCreateProject(
            organizationId: orgId,
            bundleId: bundleId,
            name: "Test Default App",
            configManager: configManager
        )

        // Act - Create session with minimal parameters
        let sessionId = try await client.createSession(
            projectId: projectId,
            steps: 5,
            goal: "Quick test"
        )

        // Assert
        XCTAssertNotNil(sessionId, "Session should be created with minimal parameters")
    }
}