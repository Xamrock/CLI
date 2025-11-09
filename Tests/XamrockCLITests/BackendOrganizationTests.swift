import XCTest
@testable import XamrockCLI

final class BackendOrganizationTests: XCTestCase {

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

    func testOrganizationReuse() async throws {
        // Arrange
        let client = BackendClient(baseURL: "http://localhost:8080")
        let configManager = ConfigManager(configDirectory: testConfigDirectory)

        // Act - First call should create organization
        let orgId1 = try await client.getOrCreateOrganization(
            name: "Test CLI Org \(UUID().uuidString.prefix(8))",
            configManager: configManager
        )
        XCTAssertNotNil(orgId1, "First call should create organization")

        // Verify it was saved to config
        let config1 = try configManager.load()
        XCTAssertEqual(config1?.organizationId, orgId1, "Organization ID should be saved to config")

        // Act - Second call should reuse
        let orgId2 = try await client.getOrCreateOrganization(
            name: "Different Name Should Not Matter",
            configManager: configManager
        )

        // Assert
        XCTAssertEqual(orgId1, orgId2, "Should reuse the same organization ID")
    }

    func testProjectReuse() async throws {
        // Arrange
        let client = BackendClient(baseURL: "http://localhost:8080")
        let configManager = ConfigManager(configDirectory: testConfigDirectory)
        // Generate valid bundle ID (no hyphens allowed)
        let bundleId = "com.test.app.test\(Int.random(in: 10000...99999))"

        // Get or create organization first
        let orgId = try await client.getOrCreateOrganization(
            name: "Test CLI Project Org \(UUID().uuidString.prefix(8))",
            configManager: configManager
        )

        // Act - First call should create project
        let projectId1 = try await client.getOrCreateProject(
            organizationId: orgId,
            bundleId: bundleId,
            name: "Test App",
            configManager: configManager
        )
        XCTAssertNotNil(projectId1, "First call should create project")

        // Verify it was saved to config
        let config1 = try configManager.load()
        XCTAssertEqual(config1?.projects[bundleId], projectId1, "Project ID should be saved to config")

        // Act - Second call should reuse
        let projectId2 = try await client.getOrCreateProject(
            organizationId: orgId,
            bundleId: bundleId,
            name: "Test App",
            configManager: configManager
        )

        // Assert
        XCTAssertEqual(projectId1, projectId2, "Should reuse the same project ID")
    }
}