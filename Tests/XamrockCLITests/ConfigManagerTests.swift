import XCTest
@testable import XamrockCLI

final class ConfigManagerTests: XCTestCase {

    var testConfigDirectory: URL!

    override func setUp() {
        super.setUp()
        // Use a temporary directory for testing
        testConfigDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("xamrock-test-\(UUID())")
    }

    override func tearDown() {
        // Clean up test directory
        try? FileManager.default.removeItem(at: testConfigDirectory)
        super.tearDown()
    }

    func testConfigSavesAndLoads() throws {
        // Arrange
        let config = XamrockConfig(
            apiURL: "http://localhost:8080",
            organizationId: UUID(),
            projects: ["com.test.app": UUID()]
        )
        let manager = ConfigManager(configDirectory: testConfigDirectory)

        // Act - Save
        try manager.save(config)

        // Act - Load
        let loadedConfig = try manager.load()

        // Assert
        XCTAssertNotNil(loadedConfig, "Loaded config should not be nil")
        XCTAssertEqual(loadedConfig?.apiURL, config.apiURL, "API URL should match")
        XCTAssertEqual(loadedConfig?.organizationId, config.organizationId, "Organization ID should match")
        XCTAssertEqual(loadedConfig?.projects, config.projects, "Projects should match")
    }

    func testLoadReturnsNilWhenConfigDoesNotExist() throws {
        // Arrange
        let manager = ConfigManager(configDirectory: testConfigDirectory)

        // Act
        let config = try? manager.load()

        // Assert
        XCTAssertNil(config, "Should return nil when config doesn't exist")
    }

    func testConfigUpdatesExistingFile() throws {
        // Arrange
        let manager = ConfigManager(configDirectory: testConfigDirectory)
        let initialConfig = XamrockConfig(apiURL: "http://localhost:8080")
        try manager.save(initialConfig)

        // Act - Update with new values
        let updatedConfig = XamrockConfig(
            apiURL: "http://localhost:9090",
            organizationId: UUID()
        )
        try manager.save(updatedConfig)

        // Act - Load
        let loadedConfig = try manager.load()

        // Assert
        XCTAssertEqual(loadedConfig?.apiURL, "http://localhost:9090", "Should have updated API URL")
        XCTAssertNotNil(loadedConfig?.organizationId, "Should have organization ID")
    }
}