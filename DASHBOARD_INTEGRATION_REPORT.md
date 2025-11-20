# CLI Dashboard Integration Report

**Generated:** 2025-11-09
**Purpose:** Enable CLI to fully leverage Xamrock Backend dashboard capabilities

---

## Executive Summary

The CLI currently acts as a basic bridge between AITestScout and the Backend, creating organizations/projects/sessions and updating basic status. To transform it into a full-featured dashboard client, we need to:

1. **Upload complete exploration data** (not just metadata)
2. **Handle artifact management** (screenshots, test files, reports)
3. **Provide dashboard links** and preview capabilities
4. **Support real-time session monitoring**
5. **Enable dashboard browsing** from CLI

---

## Current State

### ✅ What Works

**BackendClient.swift** (Lines 1-278)
- Health checks
- Organization CRUD (with config caching)
- Project CRUD (with bundle ID lookup)
- Session creation with basic config
- Session updates with status and metrics

**ExploreCommand.swift** (Lines 1-200)
- Platform detection (iOS/Android)
- Configuration building
- Orchestration of exploration
- Artifact collection
- Manifest generation

**Config Management**
- XamrockConfig persistence
- Organization/project ID caching
- Reuse of existing resources

### ❌ What's Missing

**No exploration data upload:**
- Only sends SessionMetrics, not full ExplorationData
- Missing: steps, navigation graph, element contexts, insights

**No artifact upload:**
- Screenshots remain local
- Generated test files not uploaded
- Dashboard HTML not uploaded

**No dashboard integration:**
- Can't view sessions from CLI
- No link to web dashboard
- Can't monitor running sessions

**Limited metadata:**
- Missing Git info (branch, commit, PR)
- No custom tags or labels
- No environment capture

---

## Required Changes

### 1. Enhanced BackendClient

**Extend:** `Sources/XamrockCLI/Core/Backend/BackendClient.swift`

#### 1.1 Add Exploration Data Upload

```swift
// Add to BackendClient

/// Upload complete exploration data to session
public func uploadExplorationData(
    sessionId: UUID,
    explorationData: ExplorationData
) async throws {
    guard let url = URL(string: "\(baseURL)/api/v1/sessions/\(sessionId)/exploration-data") else {
        throw BackendError.invalidURL
    }

    var request = URLRequest(url: url)
    request.httpMethod = "PUT"
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")

    let encoder = JSONEncoder()
    encoder.dateEncodingStrategy = .iso8601
    request.httpBody = try encoder.encode(explorationData)

    let (data, response) = try await URLSession.shared.data(for: request)

    guard let httpResponse = response as? HTTPURLResponse else {
        throw BackendError.invalidResponse
    }

    guard httpResponse.statusCode == 200 else {
        throw BackendError.parseErrorResponse(from: data, statusCode: httpResponse.statusCode)
    }
}
```

#### 1.2 Add Artifact Upload

```swift
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

public enum ArtifactType: String {
    case screenshot
    case testFile
    case report
    case dashboard
    case manifest
}

struct ArtifactUploadResponse: Codable {
    let url: String
}
```

#### 1.3 Add Dashboard Query Methods

```swift
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

    return try JSONDecoder().decode(SessionDetail.self, from: data)
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

    return try JSONDecoder().decode([SessionSummary].self, from: data)
}

public struct SessionDetail: Codable {
    let id: UUID
    let projectId: UUID
    let status: SessionStatus
    let startedAt: Date
    let completedAt: Date?
    let config: SessionConfiguration
    let metrics: SessionMetrics?
    let artifacts: SessionArtifacts?
    let dashboardURL: String?
}

public struct SessionSummary: Codable {
    let id: UUID
    let status: SessionStatus
    let startedAt: Date
    let completedAt: Date?
    let screensDiscovered: Int?
    let successRatePercent: Double?
}
```

---

### 2. Enhanced ExploreCommand

**Modify:** `Sources/XamrockCLI/Commands/ExploreCommand.swift`

#### 2.1 Add Backend Upload Step

```swift
public mutating func run() throws {
    // ... existing validation and exploration ...

    // NEW: Upload to backend if configured
    if let backendURL = ProcessInfo.processInfo.environment["XAMROCK_BACKEND_URL"] {
        print(formatter.formatProgress(step: "Uploading to backend", isDone: false))

        Task {
            do {
                try await uploadToBackend(
                    backendURL: backendURL,
                    config: config,
                    result: result,
                    artifacts: artifacts,
                    formatter: formatter
                )
            } catch {
                print("⚠️  Backend upload failed: \(error)")
                print("   Results saved locally in \(config.outputDirectory.path)")
            }
        }

        print(formatter.formatProgress(step: "Uploading to backend", isDone: true))
    }

    // ... existing completion logic ...
}

private func uploadToBackend(
    backendURL: String,
    config: CLIConfiguration,
    result: ExplorationResult,
    artifacts: [URL],
    formatter: ConsoleFormatter
) async throws {
    let backendClient = BackendClient(baseURL: backendURL)
    let configManager = ConfigManager()

    // 1. Get/Create Organization
    let orgName = ProcessInfo.processInfo.environment["XAMROCK_ORG_NAME"] ?? "Default Org"
    let orgId = try await backendClient.getOrCreateOrganization(
        name: orgName,
        configManager: configManager
    )

    // 2. Get/Create Project
    let projectId = try await backendClient.getOrCreateProject(
        organizationId: orgId,
        bundleId: config.appIdentifier,
        name: config.appIdentifier,
        configManager: configManager
    )

    // 3. Create Session
    let sessionId = try await backendClient.createSession(
        projectId: projectId,
        steps: config.steps,
        goal: config.goal,
        temperature: config.ciMode ? 0.0 : 0.7,
        enableVerification: true,
        maxRetries: 3
    )

    print(formatter.formatInfo("📊 Session created: \(sessionId)"))

    // 4. Upload Exploration Data
    if let explorationDataFile = artifacts.first(where: { $0.lastPathComponent == "exploration.json" }) {
        let data = try Data(contentsOf: explorationDataFile)
        let explorationData = try JSONDecoder().decode(ExplorationData.self, from: data)
        try await backendClient.uploadExplorationData(
            sessionId: sessionId,
            explorationData: explorationData
        )
        print(formatter.formatInfo("✓ Exploration data uploaded"))
    }

    // 5. Upload Screenshots
    let screenshots = artifacts.filter { $0.pathExtension == "png" }
    if !screenshots.isEmpty {
        print(formatter.formatInfo("📸 Uploading \(screenshots.count) screenshots..."))
        let urls = try await backendClient.uploadScreenshots(
            sessionId: sessionId,
            screenshots: screenshots
        ) { current, total in
            print(formatter.formatProgress(step: "Uploading screenshots (\(current)/\(total))", isDone: false))
        }
        print(formatter.formatInfo("✓ Screenshots uploaded"))
    }

    // 6. Upload Test File
    if let testFile = artifacts.first(where: { $0.pathExtension == "swift" }) {
        let url = try await backendClient.uploadArtifact(
            sessionId: sessionId,
            file: testFile,
            artifactType: .testFile
        )
        print(formatter.formatInfo("✓ Test file uploaded"))
    }

    // 7. Upload Dashboard HTML
    if config.generateDashboard,
       let dashboardFile = artifacts.first(where: { $0.lastPathComponent == "dashboard.html" }) {
        let url = try await backendClient.uploadArtifact(
            sessionId: sessionId,
            file: dashboardFile,
            artifactType: .dashboard
        )
        print(formatter.formatInfo("✓ Dashboard uploaded"))
    }

    // 8. Update Session with Final Metrics
    let metrics = buildSessionMetrics(from: result)
    try await backendClient.updateSession(
        sessionId: sessionId,
        status: determineStatus(from: result),
        metrics: metrics
    )

    // 9. Print Dashboard Link
    let dashboardURL = backendClient.getDashboardURL(sessionId: sessionId)
    print("")
    print(formatter.formatSuccess("🎉 Dashboard available at:"))
    print(formatter.formatLink(dashboardURL))
    print("")
}

private func buildSessionMetrics(from result: ExplorationResult) -> SessionMetrics {
    return SessionMetrics(
        screensDiscovered: result.screensDiscovered,
        transitions: result.transitions,
        durationSeconds: Int(result.duration),
        successfulActions: result.successfulActions,
        failedActions: result.failedActions,
        crashesDetected: result.crashesDetected,
        verificationsPerformed: result.verificationsPerformed,
        verificationsPassed: result.verificationsPassed,
        retryAttempts: result.retryAttempts,
        successRatePercent: Double(result.successRatePercent),
        healthScore: calculateHealthScore(result: result)
    )
}

private func determineStatus(from result: ExplorationResult) -> SessionStatus {
    if result.crashesDetected > 0 {
        return .crashed
    } else if result.failedActions > 0 {
        return .failed
    } else {
        return .completed
    }
}

private func calculateHealthScore(result: ExplorationResult) -> Double {
    var score = Double(result.successRatePercent)
    if result.screensDiscovered >= 5 { score = min(100, score + 5) }
    if result.verificationsPerformed > 0 && result.verificationSuccessRate >= 80 {
        score = min(100, score + 5)
    }
    if result.crashesDetected > 0 {
        score = max(0, score - Double(result.crashesDetected * 10))
    }
    return score
}
```

#### 2.2 Enhanced Console Formatting

**Extend:** `Sources/XamrockCLI/Core/Formatting/ConsoleFormatter.swift`

```swift
// Add to ConsoleFormatter

public func formatLink(_ url: String) -> String {
    return "   \u{001B}[4;36m\(url)\u{001B}[0m"  // Underlined cyan
}

public func formatInfo(_ message: String) -> String {
    return "   \u{001B}[36mℹ\u{001B}[0m \(message)"
}

public func formatSuccess(_ message: String) -> String {
    return "   \u{001B}[32m✓\u{001B}[0m \(message)"
}
```

---

### 3. New Dashboard Commands

**Create:** `Sources/XamrockCLI/Commands/DashboardCommand.swift`

```swift
import Foundation
import ArgumentParser

/// Dashboard command group
public struct DashboardCommand: ParsableCommand {
    public static let configuration = CommandConfiguration(
        commandName: "dashboard",
        abstract: "View and manage exploration dashboards",
        subcommands: [
            ListCommand.self,
            OpenCommand.self,
            StatusCommand.self
        ]
    )

    public init() {}
}

// MARK: - List Sessions

extension DashboardCommand {
    struct ListCommand: ParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "list",
            abstract: "List recent exploration sessions"
        )

        @Option(name: .long, help: "Backend URL")
        var backendURL: String = ProcessInfo.processInfo.environment["XAMROCK_BACKEND_URL"] ?? "http://localhost:8080"

        @Option(name: .long, help: "Project bundle ID")
        var project: String?

        @Option(name: .long, help: "Filter by status (running, completed, failed, crashed)")
        var status: String?

        @Option(name: .long, help: "Number of sessions to show")
        var limit: Int = 10

        func run() async throws {
            let client = BackendClient(baseURL: backendURL)
            let configManager = ConfigManager()
            let config = try? configManager.load()

            // Determine project ID
            var projectId: UUID?
            if let bundleId = project {
                if let pid = config?.projects[bundleId] {
                    projectId = pid
                } else {
                    print("❌ Project not found for bundle ID: \(bundleId)")
                    throw ExitCode.failure
                }
            } else if let firstProject = config?.projects.values.first {
                projectId = firstProject
            }

            guard let pid = projectId else {
                print("❌ No project configured. Run 'scout explore' first.")
                throw ExitCode.failure
            }

            // Parse status filter
            let statusFilter: SessionStatus?
            if let statusStr = status {
                statusFilter = SessionStatus(rawValue: statusStr)
            } else {
                statusFilter = nil
            }

            // Fetch sessions
            let sessions = try await client.listSessions(
                projectId: pid,
                status: statusFilter,
                limit: limit
            )

            // Display table
            print("\\n📊 Recent Sessions\\n")
            print("ID                                   Status      Screens  Success  Started")
            print("─────────────────────────────────────────────────────────────────────────────")

            for session in sessions {
                let statusIcon = statusIcon(for: session.status)
                let screens = session.screensDiscovered.map { String($0) } ?? "-"
                let success = session.successRatePercent.map { String(format: "%.0f%%", $0) } ?? "-"
                let started = formatDate(session.startedAt)

                print("\\(session.id.uuidString.prefix(8))... \\(statusIcon) \\(session.status.rawValue.padding(toLength: 10, withPad: " ", startingAt: 0)) \\(screens.padding(toLength: 7, withPad: " ", startingAt: 0)) \\(success.padding(toLength: 7, withPad: " ", startingAt: 0)) \\(started)")
            }

            print("")
        }

        private func statusIcon(for status: SessionStatus) -> String {
            switch status {
            case .running: return "🔄"
            case .completed: return "✅"
            case .failed: return "❌"
            case .crashed: return "💥"
            }
        }

        private func formatDate(_ date: Date) -> String {
            let formatter = RelativeDateTimeFormatter()
            formatter.unitsStyle = .short
            return formatter.localizedString(for: date, relativeTo: Date())
        }
    }
}

// MARK: - Open Dashboard

extension DashboardCommand {
    struct OpenCommand: ParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "open",
            abstract: "Open session dashboard in browser"
        )

        @Argument(help: "Session ID")
        var sessionId: String

        @Option(name: .long, help: "Backend URL")
        var backendURL: String = ProcessInfo.processInfo.environment["XAMROCK_BACKEND_URL"] ?? "http://localhost:8080"

        func run() throws {
            guard let uuid = UUID(uuidString: sessionId) else {
                print("❌ Invalid session ID")
                throw ExitCode.failure
            }

            let client = BackendClient(baseURL: backendURL)
            let url = client.getDashboardURL(sessionId: uuid)

            print("🌐 Opening dashboard: \\(url)")

            #if os(macOS)
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/open")
            process.arguments = [url]
            try process.run()
            #else
            print("   Please open this URL in your browser:")
            print("   \\(url)")
            #endif
        }
    }
}

// MARK: - Session Status

extension DashboardCommand {
    struct StatusCommand: ParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "status",
            abstract: "Show detailed status of a session"
        )

        @Argument(help: "Session ID")
        var sessionId: String

        @Option(name: .long, help: "Backend URL")
        var backendURL: String = ProcessInfo.processInfo.environment["XAMROCK_BACKEND_URL"] ?? "http://localhost:8080"

        func run() async throws {
            guard let uuid = UUID(uuidString: sessionId) else {
                print("❌ Invalid session ID")
                throw ExitCode.failure
            }

            let client = BackendClient(baseURL: backendURL)
            let session = try await client.getSession(sessionId: uuid)

            // Display detailed status
            print("\\n📊 Session Details\\n")
            print("ID:         \\(session.id)")
            print("Status:     \\(statusIcon(for: session.status)) \\(session.status.rawValue)")
            print("Started:    \\(formatDate(session.startedAt))")
            if let completed = session.completedAt {
                print("Completed:  \\(formatDate(completed))")
                let duration = completed.timeIntervalSince(session.startedAt)
                print("Duration:   \\(formatDuration(duration))")
            }

            if let metrics = session.metrics {
                print("\\nMetrics:")
                print("  Screens:        \\(metrics.screensDiscovered)")
                print("  Transitions:    \\(metrics.transitions)")
                print("  Success Rate:   \\(Int(metrics.successRatePercent))%")
                print("  Health Score:   \\(Int(metrics.healthScore))")

                if metrics.crashesDetected > 0 {
                    print("  💥 Crashes:     \\(metrics.crashesDetected)")
                }
            }

            if let dashboardURL = session.dashboardURL ?? session.artifacts?.dashboardURL {
                print("\\nDashboard:  \\(dashboardURL)")
            }

            print("")
        }

        private func statusIcon(for status: SessionStatus) -> String {
            switch status {
            case .running: return "🔄"
            case .completed: return "✅"
            case .failed: return "❌"
            case .crashed: return "💥"
            }
        }

        private func formatDate(_ date: Date) -> String {
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            formatter.timeStyle = .short
            return formatter.string(from: date)
        }

        private func formatDuration(_ duration: TimeInterval) -> String {
            let seconds = Int(duration)
            if seconds < 60 {
                return "\\(seconds)s"
            }
            let minutes = seconds / 60
            let remainingSeconds = seconds % 60
            return "\\(minutes)m \\(remainingSeconds)s"
        }
    }
}
```

**Update:** `Sources/XamrockCLI/CLI.swift`

```swift
@main
struct XamrockCLI: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "scout",
        abstract: "AI-powered mobile app testing",
        subcommands: [
            ExploreCommand.self,
            FixtureCommand.self,
            OrganizationCommand.self,
            DashboardCommand.self  // NEW
        ]
    )
}
```

---

### 4. Environment Configuration

**Create:** `Sources/XamrockCLI/Core/Config/EnvironmentConfig.swift`

```swift
import Foundation

/// Environment-based configuration
public struct EnvironmentConfig {

    public static var backendURL: String? {
        ProcessInfo.processInfo.environment["XAMROCK_BACKEND_URL"]
    }

    public static var organizationName: String {
        ProcessInfo.processInfo.environment["XAMROCK_ORG_NAME"] ?? "Default Organization"
    }

    public static var gitBranch: String? {
        ProcessInfo.processInfo.environment["GIT_BRANCH"]
    }

    public static var gitCommit: String? {
        ProcessInfo.processInfo.environment["GIT_COMMIT"]
    }

    public static var pullRequestNumber: String? {
        ProcessInfo.processInfo.environment["PR_NUMBER"]
    }

    public static var ciMode: Bool {
        ProcessInfo.processInfo.environment["CI"] == "true"
    }

    /// Check if backend integration is enabled
    public static var isBackendEnabled: Bool {
        backendURL != nil
    }
}
```

---

## Migration Path

### Phase 1: Enhanced Backend Client (Week 1)
- [ ] Add exploration data upload endpoint
- [ ] Implement multipart file upload
- [ ] Add dashboard query methods
- [ ] Write unit tests with mock backend

### Phase 2: Upload Integration (Week 2)
- [ ] Modify ExploreCommand to upload data
- [ ] Add progress indicators for uploads
- [ ] Implement error handling and retries
- [ ] Add environment configuration

### Phase 3: Dashboard Commands (Week 3)
- [ ] Implement `dashboard list`
- [ ] Implement `dashboard open`
- [ ] Implement `dashboard status`
- [ ] Add table formatting utilities

### Phase 4: Polish & Documentation (Week 4)
- [ ] Update README with dashboard examples
- [ ] Add CI/CD integration guide
- [ ] Create example workflows
- [ ] Add telemetry for usage tracking

---

## Configuration Examples

### Local Development

```bash
export XAMROCK_BACKEND_URL=http://localhost:8080
export XAMROCK_ORG_NAME="My Team"

scout explore --app com.example.MyApp --steps 30
# Automatically uploads to local backend
# Dashboard: http://localhost:8080/dashboard/sessions/{id}
```

### CI/CD (GitHub Actions)

```yaml
- name: Run Xamrock Scout
  env:
    XAMROCK_BACKEND_URL: https://xamrock.example.com
    XAMROCK_ORG_NAME: ${{ github.repository_owner }}
    GIT_BRANCH: ${{ github.ref_name }}
    GIT_COMMIT: ${{ github.sha }}
    PR_NUMBER: ${{ github.event.pull_request.number }}
  run: |
    scout explore --app com.example.MyApp --ci-mode

- name: Comment PR with Dashboard Link
  uses: actions/github-script@v6
  with:
    script: |
      const sessionId = process.env.SCOUT_SESSION_ID
      const url = `https://xamrock.example.com/dashboard/sessions/${sessionId}`
      github.rest.issues.createComment({
        issue_number: context.issue.number,
        owner: context.repo.owner,
        repo: context.repo.repo,
        body: `🤖 AITestScout Results: [View Dashboard](${url})`
      })
```

### CLI Dashboard Commands

```bash
# List recent sessions
scout dashboard list

# List sessions for specific project
scout dashboard list --project com.example.MyApp

# Filter by status
scout dashboard list --status failed

# Open dashboard in browser
scout dashboard open abc12345-6789-...

# Show detailed status
scout dashboard status abc12345-6789-...
```

---

## Testing Requirements

### Unit Tests
- [ ] BackendClient upload methods
- [ ] Multipart form data encoding
- [ ] Session query methods
- [ ] Environment configuration

### Integration Tests
- [ ] Full upload flow with mock backend
- [ ] Dashboard command execution
- [ ] Error handling for network failures
- [ ] Retry logic validation

### E2E Tests
- [ ] Upload to real backend
- [ ] Verify data integrity
- [ ] Dashboard accessibility
- [ ] Artifact retrieval

---

## Breaking Changes

### None Expected

All changes are opt-in via environment variables. Existing CLI usage continues to work without backend integration.

---

## Success Metrics

- [ ] 100% upload success rate in stable network
- [ ] < 2s total upload time for typical session
- [ ] Dashboard link printed after every exploration
- [ ] Zero regressions in existing CLI functionality

---

## Open Questions

1. **Upload Strategy:** Sequential or parallel artifact uploads?
2. **Resume Support:** Should failed uploads be retryable?
3. **Offline Mode:** Queue uploads for later if backend unavailable?
4. **Authentication:** API keys, OAuth, or bearer tokens?
5. **Dashboard Preview:** Show dashboard in terminal (HTML → ASCII)?

---

## Next Steps

1. Review with team
2. Prioritize features for MVP
3. Create GitHub issues
4. Begin Phase 1 implementation

---

**Report Author:** Claude Code
**Date:** 2025-11-09
**Version:** 1.0
