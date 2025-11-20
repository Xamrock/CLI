import Foundation

/// Environment-based configuration
public struct EnvironmentConfig {

    public static var backendURL: String? {
        guard let url = ProcessInfo.processInfo.environment["XAMROCK_BACKEND_URL"],
              !url.isEmpty else {
            return nil
        }
        return url
    }

    public static var organizationName: String {
        guard let name = ProcessInfo.processInfo.environment["XAMROCK_ORG_NAME"],
              !name.isEmpty else {
            return "Default Organization"
        }
        return name
    }

    public static var gitBranch: String? {
        guard let branch = ProcessInfo.processInfo.environment["GIT_BRANCH"],
              !branch.isEmpty else {
            return nil
        }
        return branch
    }

    public static var gitCommit: String? {
        guard let commit = ProcessInfo.processInfo.environment["GIT_COMMIT"],
              !commit.isEmpty else {
            return nil
        }
        return commit
    }

    public static var pullRequestNumber: String? {
        guard let prNumber = ProcessInfo.processInfo.environment["PR_NUMBER"],
              !prNumber.isEmpty else {
            return nil
        }
        return prNumber
    }

    public static var ciMode: Bool {
        ProcessInfo.processInfo.environment["CI"] == "true"
    }

    /// Check if backend integration is enabled
    public static var isBackendEnabled: Bool {
        backendURL != nil
    }
}
