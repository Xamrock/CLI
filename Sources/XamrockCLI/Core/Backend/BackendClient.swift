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
            throw BackendError.parseErrorResponse(from: data, statusCode: httpResponse.statusCode)
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
            throw BackendError.parseErrorResponse(from: data, statusCode: httpResponse.statusCode)
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
            throw BackendError.parseErrorResponse(from: data, statusCode: httpResponse.statusCode)
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
            throw BackendError.parseErrorResponse(from: data, statusCode: httpResponse.statusCode)
        }
    }

    // MARK: - Exploration Data Upload

    /// Upload complete exploration data to session
    public func uploadExplorationData(
        sessionId: UUID,
        explorationData: Data
    ) async throws {
        guard let url = URL(string: "\(baseURL)/api/v1/sessions/\(sessionId)/exploration-data") else {
            throw BackendError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = explorationData

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw BackendError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            throw BackendError.parseErrorResponse(from: data, statusCode: httpResponse.statusCode)
        }
    }

    // MARK: - Artifact Upload

    /// Upload file artifact to session
    public func uploadArtifact(
        sessionId: UUID,
        file: URL,
        artifactType: ArtifactType
    ) async throws -> String {
        guard let url = URL(string: "\(baseURL)/api/v1/sessions/\(sessionId)/artifacts") else {
            throw BackendError.invalidURL
        }

        // Create multipart/form-data request
        let boundary = UUID().uuidString
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        var body = Data()

        // Add artifact type field
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"type\"\r\n\r\n".data(using: .utf8)!)
        body.append("\(artifactType.rawValue)\r\n".data(using: .utf8)!)

        // Add file field
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"\(file.lastPathComponent)\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: application/octet-stream\r\n\r\n".data(using: .utf8)!)
        body.append(try Data(contentsOf: file))
        body.append("\r\n".data(using: .utf8)!)
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)

        request.httpBody = body

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 201 else {
            throw BackendError.uploadFailed
        }

        let result = try JSONDecoder().decode(ArtifactUploadResponse.self, from: data)
        return result.url
    }

    /// Upload multiple screenshots in batch
    public func uploadScreenshots(
        sessionId: UUID,
        screenshots: [URL],
        onProgress: ((Int, Int) -> Void)? = nil
    ) async throws -> [String] {
        var uploadedURLs: [String] = []

        for (index, screenshot) in screenshots.enumerated() {
            let url = try await uploadArtifact(
                sessionId: sessionId,
                file: screenshot,
                artifactType: .screenshot
            )
            uploadedURLs.append(url)
            onProgress?(index + 1, screenshots.count)
        }

        return uploadedURLs
    }

    // MARK: - Dashboard Methods

    /// Get dashboard URL for a session
    public func getDashboardURL(sessionId: UUID) -> String {
        return "\(baseURL)/dashboard/sessions/\(sessionId)"
    }

    /// Fetch session details for display
    public func getSession(sessionId: UUID) async throws -> SessionDetail {
        guard let url = URL(string: "\(baseURL)/api/v1/sessions/\(sessionId)") else {
            throw BackendError.invalidURL
        }

        let (data, response) = try await URLSession.shared.data(from: url)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw BackendError.sessionNotFound
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(SessionDetail.self, from: data)
    }

    /// List all sessions for a project
    public func listSessions(
        projectId: UUID,
        status: SessionStatus? = nil,
        limit: Int = 20
    ) async throws -> [SessionSummary] {
        var components = URLComponents(string: "\(baseURL)/api/v1/sessions")!
        components.queryItems = [
            URLQueryItem(name: "projectId", value: projectId.uuidString),
            URLQueryItem(name: "limit", value: "\(limit)")
        ]
        if let status = status {
            components.queryItems?.append(URLQueryItem(name: "status", value: status.rawValue))
        }

        guard let url = components.url else {
            throw BackendError.invalidURL
        }

        let (data, response) = try await URLSession.shared.data(from: url)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw BackendError.requestFailed
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode([SessionSummary].self, from: data)
    }
}

// MARK: - Errors

public enum BackendError: LocalizedError {
    case invalidURL
    case invalidResponse
    case httpError(statusCode: Int, message: String? = nil)
    case structuredError(statusCode: Int, errorResponse: ErrorResponse)
    case invalidJSON
    case uploadFailed
    case sessionNotFound
    case requestFailed

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
        case .structuredError(_, let errorResponse):
            return errorResponse.formattedDescription
        case .invalidJSON:
            return "Invalid JSON response from backend"
        case .uploadFailed:
            return "Failed to upload artifact"
        case .sessionNotFound:
            return "Session not found"
        case .requestFailed:
            return "Request failed"
        }
    }
}