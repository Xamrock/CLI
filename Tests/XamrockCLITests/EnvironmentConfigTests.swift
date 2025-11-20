import XCTest
@testable import XamrockCLI
import Foundation

/// Tests for environment-based configuration
final class EnvironmentConfigTests: XCTestCase {

    override func tearDown() {
        // Clean up environment variables after each test
        let keysToRemove = [
            "XAMROCK_BACKEND_URL",
            "XAMROCK_ORG_NAME",
            "GIT_BRANCH",
            "GIT_COMMIT",
            "PR_NUMBER",
            "CI"
        ]
        for key in keysToRemove {
            unsetenv(key)
        }
        super.tearDown()
    }

    // MARK: - Backend URL Tests

    func testBackendURLWhenNotSet() throws {
        // Arrange
        unsetenv("XAMROCK_BACKEND_URL")

        // Act
        let backendURL = EnvironmentConfig.backendURL

        // Assert
        XCTAssertNil(backendURL, "Backend URL should be nil when not set")
    }

    func testBackendURLWhenSet() throws {
        // Arrange
        setenv("XAMROCK_BACKEND_URL", "http://localhost:8080", 1)

        // Act
        let backendURL = EnvironmentConfig.backendURL

        // Assert
        XCTAssertEqual(backendURL, "http://localhost:8080")
    }

    func testBackendURLWithHTTPS() throws {
        // Arrange
        setenv("XAMROCK_BACKEND_URL", "https://xamrock.example.com", 1)

        // Act
        let backendURL = EnvironmentConfig.backendURL

        // Assert
        XCTAssertEqual(backendURL, "https://xamrock.example.com")
    }

    // MARK: - Organization Name Tests

    func testOrganizationNameDefaultValue() throws {
        // Arrange
        unsetenv("XAMROCK_ORG_NAME")

        // Act
        let orgName = EnvironmentConfig.organizationName

        // Assert
        XCTAssertEqual(orgName, "Default Organization")
    }

    func testOrganizationNameCustomValue() throws {
        // Arrange
        setenv("XAMROCK_ORG_NAME", "My Team", 1)

        // Act
        let orgName = EnvironmentConfig.organizationName

        // Assert
        XCTAssertEqual(orgName, "My Team")
    }

    // MARK: - Git Branch Tests

    func testGitBranchWhenNotSet() throws {
        // Arrange
        unsetenv("GIT_BRANCH")

        // Act
        let gitBranch = EnvironmentConfig.gitBranch

        // Assert
        XCTAssertNil(gitBranch)
    }

    func testGitBranchWhenSet() throws {
        // Arrange
        setenv("GIT_BRANCH", "feature/dashboard-integration", 1)

        // Act
        let gitBranch = EnvironmentConfig.gitBranch

        // Assert
        XCTAssertEqual(gitBranch, "feature/dashboard-integration")
    }

    // MARK: - Git Commit Tests

    func testGitCommitWhenNotSet() throws {
        // Arrange
        unsetenv("GIT_COMMIT")

        // Act
        let gitCommit = EnvironmentConfig.gitCommit

        // Assert
        XCTAssertNil(gitCommit)
    }

    func testGitCommitWhenSet() throws {
        // Arrange
        setenv("GIT_COMMIT", "abc123def456", 1)

        // Act
        let gitCommit = EnvironmentConfig.gitCommit

        // Assert
        XCTAssertEqual(gitCommit, "abc123def456")
    }

    // MARK: - Pull Request Number Tests

    func testPullRequestNumberWhenNotSet() throws {
        // Arrange
        unsetenv("PR_NUMBER")

        // Act
        let prNumber = EnvironmentConfig.pullRequestNumber

        // Assert
        XCTAssertNil(prNumber)
    }

    func testPullRequestNumberWhenSet() throws {
        // Arrange
        setenv("PR_NUMBER", "123", 1)

        // Act
        let prNumber = EnvironmentConfig.pullRequestNumber

        // Assert
        XCTAssertEqual(prNumber, "123")
    }

    // MARK: - CI Mode Tests

    func testCIModeWhenNotSet() throws {
        // Arrange
        unsetenv("CI")

        // Act
        let ciMode = EnvironmentConfig.ciMode

        // Assert
        XCTAssertFalse(ciMode, "CI mode should be false when not set")
    }

    func testCIModeWhenSetToTrue() throws {
        // Arrange
        setenv("CI", "true", 1)

        // Act
        let ciMode = EnvironmentConfig.ciMode

        // Assert
        XCTAssertTrue(ciMode)
    }

    func testCIModeWhenSetToOtherValue() throws {
        // Arrange
        setenv("CI", "false", 1)

        // Act
        let ciMode = EnvironmentConfig.ciMode

        // Assert
        XCTAssertFalse(ciMode, "CI mode should only be true when explicitly set to 'true'")
    }

    func testCIModeWhenSetTo1() throws {
        // Arrange
        setenv("CI", "1", 1)

        // Act
        let ciMode = EnvironmentConfig.ciMode

        // Assert
        XCTAssertFalse(ciMode, "CI mode should only be true when set to 'true', not '1'")
    }

    // MARK: - Backend Enabled Tests

    func testIsBackendEnabledWhenURLNotSet() throws {
        // Arrange
        unsetenv("XAMROCK_BACKEND_URL")

        // Act
        let isEnabled = EnvironmentConfig.isBackendEnabled

        // Assert
        XCTAssertFalse(isEnabled)
    }

    func testIsBackendEnabledWhenURLSet() throws {
        // Arrange
        setenv("XAMROCK_BACKEND_URL", "http://localhost:8080", 1)

        // Act
        let isEnabled = EnvironmentConfig.isBackendEnabled

        // Assert
        XCTAssertTrue(isEnabled)
    }

    func testIsBackendEnabledWithEmptyURL() throws {
        // Arrange
        setenv("XAMROCK_BACKEND_URL", "", 1)

        // Act
        let isEnabled = EnvironmentConfig.isBackendEnabled

        // Assert
        // Empty string is still truthy in Swift, so this depends on implementation
        // The current implementation treats empty string as enabled
        XCTAssertFalse(isEnabled, "Empty URL should not enable backend")
    }

    // MARK: - Integration Tests

    func testFullCIEnvironmentConfiguration() throws {
        // Arrange - Simulate GitHub Actions environment
        setenv("XAMROCK_BACKEND_URL", "https://xamrock.example.com", 1)
        setenv("XAMROCK_ORG_NAME", "my-github-org", 1)
        setenv("GIT_BRANCH", "main", 1)
        setenv("GIT_COMMIT", "abc123", 1)
        setenv("PR_NUMBER", "456", 1)
        setenv("CI", "true", 1)

        // Act & Assert
        XCTAssertEqual(EnvironmentConfig.backendURL, "https://xamrock.example.com")
        XCTAssertEqual(EnvironmentConfig.organizationName, "my-github-org")
        XCTAssertEqual(EnvironmentConfig.gitBranch, "main")
        XCTAssertEqual(EnvironmentConfig.gitCommit, "abc123")
        XCTAssertEqual(EnvironmentConfig.pullRequestNumber, "456")
        XCTAssertTrue(EnvironmentConfig.ciMode)
        XCTAssertTrue(EnvironmentConfig.isBackendEnabled)
    }

    func testLocalDevelopmentConfiguration() throws {
        // Arrange - Simulate local development
        setenv("XAMROCK_BACKEND_URL", "http://localhost:8080", 1)
        unsetenv("XAMROCK_ORG_NAME")
        unsetenv("GIT_BRANCH")
        unsetenv("GIT_COMMIT")
        unsetenv("PR_NUMBER")
        unsetenv("CI")

        // Act & Assert
        XCTAssertEqual(EnvironmentConfig.backendURL, "http://localhost:8080")
        XCTAssertEqual(EnvironmentConfig.organizationName, "Default Organization")
        XCTAssertNil(EnvironmentConfig.gitBranch)
        XCTAssertNil(EnvironmentConfig.gitCommit)
        XCTAssertNil(EnvironmentConfig.pullRequestNumber)
        XCTAssertFalse(EnvironmentConfig.ciMode)
        XCTAssertTrue(EnvironmentConfig.isBackendEnabled)
    }

    func testNoBackendConfiguration() throws {
        // Arrange - No backend configured
        unsetenv("XAMROCK_BACKEND_URL")
        unsetenv("XAMROCK_ORG_NAME")
        unsetenv("GIT_BRANCH")
        unsetenv("GIT_COMMIT")
        unsetenv("PR_NUMBER")
        unsetenv("CI")

        // Act & Assert
        XCTAssertNil(EnvironmentConfig.backendURL)
        XCTAssertEqual(EnvironmentConfig.organizationName, "Default Organization")
        XCTAssertNil(EnvironmentConfig.gitBranch)
        XCTAssertNil(EnvironmentConfig.gitCommit)
        XCTAssertNil(EnvironmentConfig.pullRequestNumber)
        XCTAssertFalse(EnvironmentConfig.ciMode)
        XCTAssertFalse(EnvironmentConfig.isBackendEnabled)
    }
}
