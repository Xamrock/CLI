import Foundation

/// Client for communicating with Xamrock Backend API
public struct BackendClient {
    let baseURL: String

    public init(baseURL: String) {
        self.baseURL = baseURL
    }

    /// Check if the backend is healthy and reachable
    public func healthCheck() async -> Bool {
        guard let url = URL(string: "\(baseURL)/health") else {
            return false
        }

        do {
            let (_, response) = try await URLSession.shared.data(from: url)
            if let httpResponse = response as? HTTPURLResponse {
                return httpResponse.statusCode == 200
            }
            return false
        } catch {
            return false
        }
    }

    // MARK: - Organizations

    /// Get or create an organization, reusing from config if available
    public func getOrCreateOrganization(
        name: String,
        configManager: ConfigManager
    ) async throws -> UUID {
        // Check config first
        if let config = try? configManager.load(),
           let existingOrgId = config.organizationId {
            return existingOrgId
        }

        // Create new organization
        let orgId = try await createOrganization(name: name, tier: "free")

        // Save to config
        var config = (try? configManager.load()) ?? XamrockConfig()
        config.organizationId = orgId
        try configManager.save(config)

        return orgId
    }

    /// Create a new organization
    private func createOrganization(name: String, tier: String) async throws -> UUID {
        guard let url = URL(string: "\(baseURL)/api/v1/organizations") else {
            throw BackendError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body = [
            "name": name,
            "subscriptionTier": tier
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw BackendError.invalidResponse
        }

        guard httpResponse.statusCode == 201 else {
            let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw BackendError.httpError(statusCode: httpResponse.statusCode, message: errorMessage)
        }

        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        guard let idString = json?["id"] as? String,
              let id = UUID(uuidString: idString) else {
            throw BackendError.invalidJSON
        }

        return id
    }

    // MARK: - Projects

    /// Get or create a project, reusing from config if available
    public func getOrCreateProject(
        organizationId: UUID,
        bundleId: String,
        name: String,
        configManager: ConfigManager
    ) async throws -> UUID {
        // Check config first
        if let config = try? configManager.load(),
           let existingProjectId = config.projects[bundleId] {
            return existingProjectId
        }

        // Create new project
        let projectId = try await createProject(
            organizationId: organizationId,
            name: name,
            bundleId: bundleId
        )

        // Save to config
        var config = (try? configManager.load()) ?? XamrockConfig()
        config.projects[bundleId] = projectId
        try configManager.save(config)

        return projectId
    }

    /// Create a new project
    private func createProject(
        organizationId: UUID,
        name: String,
        bundleId: String
    ) async throws -> UUID {
        guard let url = URL(string: "\(baseURL)/api/v1/projects") else {
            throw BackendError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body = [
            "organizationId": organizationId.uuidString,
            "name": name,
            "bundleIdentifier": bundleId,
            "platform": "ios"
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw BackendError.invalidResponse
        }

        guard httpResponse.statusCode == 201 else {
            let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw BackendError.httpError(statusCode: httpResponse.statusCode, message: errorMessage)
        }

        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        guard let idString = json?["id"] as? String,
              let id = UUID(uuidString: idString) else {
            throw BackendError.invalidJSON
        }

        return id
    }

    // MARK: - Sessions

    /// Create a new exploration session
    public func createSession(
        projectId: UUID,
        steps: Int,
        goal: String,
        temperature: Double = 0.7,
        enableVerification: Bool = true,
        maxRetries: Int = 3
    ) async throws -> UUID {
        guard let url = URL(string: "\(baseURL)/api/v1/sessions") else {
            throw BackendError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let config: [String: Any] = [
            "steps": steps,
            "goal": goal,
            "temperature": temperature,
            "enableVerification": enableVerification,
            "maxRetries": maxRetries
        ]

        let body = [
            "projectId": projectId.uuidString,
            "config": config
        ] as [String : Any]

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw BackendError.invalidResponse
        }

        guard httpResponse.statusCode == 201 else {
            let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw BackendError.httpError(statusCode: httpResponse.statusCode, message: errorMessage)
        }

        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        guard let idString = json?["id"] as? String,
              let id = UUID(uuidString: idString) else {
            throw BackendError.invalidJSON
        }

        return id
    }

    /// Update a session with status and/or metrics
    public func updateSession(
        sessionId: UUID,
        status: SessionStatus? = nil,
        metrics: SessionMetrics? = nil
    ) async throws {
        guard let url = URL(string: "\(baseURL)/api/v1/sessions/\(sessionId)") else {
            throw BackendError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        var body: [String: Any] = [:]

        if let status = status {
            body["status"] = status.rawValue
        }

        if let metrics = metrics {
            let encoder = JSONEncoder()
            let metricsData = try encoder.encode(metrics)
            let metricsDict = try JSONSerialization.jsonObject(with: metricsData) as? [String: Any]
            body["metrics"] = metricsDict
        }

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw BackendError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw BackendError.httpError(statusCode: httpResponse.statusCode, message: errorMessage)
        }
    }
}

// MARK: - Errors

public enum BackendError: LocalizedError {
    case invalidURL
    case invalidResponse
    case httpError(statusCode: Int, message: String? = nil)
    case invalidJSON

    public var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL"
        case .invalidResponse:
            return "Invalid response from backend"
        case .httpError(let statusCode, let message):
            if let message = message {
                return "HTTP \(statusCode): \(message)"
            }
            return "HTTP error: \(statusCode)"
        case .invalidJSON:
            return "Invalid JSON response from backend"
        }
    }
}