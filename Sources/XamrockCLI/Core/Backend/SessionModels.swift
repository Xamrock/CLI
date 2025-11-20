import Foundation

/// Session status enum
public enum SessionStatus: String, Codable {
    case running = "running"
    case completed = "completed"
    case failed = "failed"
    case crashed = "crashed"
}

/// Session metrics data
public struct SessionMetrics: Codable {
    public let screensDiscovered: Int?
    public let transitions: Int?
    public let durationSeconds: Int?
    public let successfulActions: Int?
    public let failedActions: Int?
    public let crashesDetected: Int?
    public let verificationsPerformed: Int?
    public let verificationsPassed: Int?
    public let retryAttempts: Int?
    public let successRatePercent: Double?
    public let healthScore: Double?

    public init(
        screensDiscovered: Int? = nil,
        transitions: Int? = nil,
        durationSeconds: Int? = nil,
        successfulActions: Int? = nil,
        failedActions: Int? = nil,
        crashesDetected: Int? = nil,
        verificationsPerformed: Int? = nil,
        verificationsPassed: Int? = nil,
        retryAttempts: Int? = nil,
        successRatePercent: Double? = nil,
        healthScore: Double? = nil
    ) {
        self.screensDiscovered = screensDiscovered
        self.transitions = transitions
        self.durationSeconds = durationSeconds
        self.successfulActions = successfulActions
        self.failedActions = failedActions
        self.crashesDetected = crashesDetected
        self.verificationsPerformed = verificationsPerformed
        self.verificationsPassed = verificationsPassed
        self.retryAttempts = retryAttempts
        self.successRatePercent = successRatePercent
        self.healthScore = healthScore
    }
}

// MARK: - Artifact Types

/// Types of artifacts that can be uploaded
public enum ArtifactType: String, Codable {
    case screenshot
    case testFile
    case report
    case dashboard
    case manifest
}

/// Response from artifact upload
public struct ArtifactUploadResponse: Codable {
    public let url: String
}

// MARK: - Session Details

/// Session configuration (for creation)
public struct SessionConfiguration: Codable {
    public let steps: Int
    public let goal: String
    public let temperature: Double
    public let enableVerification: Bool
    public let maxRetries: Int
}

/// Session artifacts
public struct SessionArtifacts: Codable {
    public let screenshots: [String]?
    public let testFiles: [String]?
    public let reports: [String]?
    public let dashboardURL: String?
    public let manifestURL: String?
}

/// Detailed session information
public struct SessionDetail: Codable {
    public let id: UUID
    public let projectId: UUID
    public let status: SessionStatus
    public let startedAt: Date
    public let completedAt: Date?
    public let config: SessionConfiguration?
    public let metrics: SessionMetrics?
    public let artifacts: SessionArtifacts?
    public let dashboardURL: String?
}

/// Session summary (for listing)
public struct SessionSummary: Codable {
    public let id: UUID
    public let status: SessionStatus
    public let startedAt: Date
    public let completedAt: Date?
    public let screensDiscovered: Int?
    public let successRatePercent: Double?
}