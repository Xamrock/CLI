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