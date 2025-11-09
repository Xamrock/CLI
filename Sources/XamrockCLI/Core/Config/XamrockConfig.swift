import Foundation

/// Configuration for Xamrock CLI
public struct XamrockConfig: Codable, Equatable {
    /// Backend API URL
    public var apiURL: String?

    /// Organization ID (reused across sessions)
    public var organizationId: UUID?

    /// Project IDs mapped by bundle identifier
    public var projects: [String: UUID]

    public init(
        apiURL: String? = nil,
        organizationId: UUID? = nil,
        projects: [String: UUID] = [:]
    ) {
        self.apiURL = apiURL
        self.organizationId = organizationId
        self.projects = projects
    }
}