# Backend Integration Implementation Guide

## Objective
Add backend connectivity to Xamrock CLI to enable uploading exploration results to the Xamrock Backend API. This is the first step toward building a complete platform where exploration data can be stored, analyzed, and visualized.

## Current State
- **CLI**: Fully functional local exploration, saves results to disk
- **Backend**: Development API server with Organizations, Projects, and Sessions endpoints
- **Gap**: No connection between CLI and Backend

## Implementation Tasks

### Task 1: Create Backend Client
Create the HTTP client for communicating with the backend API.

#### 1.1 Backend Client Implementation
**File**: `Sources/XamrockCLI/Core/Backend/BackendClient.swift`

```swift
import Foundation

/// Client for communicating with Xamrock Backend API
struct BackendClient {
    let baseURL: String
    let session: URLSession
    let verbose: Bool

    init(baseURL: String, verbose: Bool = false) {
        self.baseURL = baseURL
        self.session = URLSession.shared
        self.verbose = verbose
    }

    // MARK: - Health Check

    func healthCheck() async -> Bool {
        guard let url = URL(string: "\(baseURL)/health") else { return false }

        do {
            let (_, response) = try await session.data(from: url)
            if let httpResponse = response as? HTTPURLResponse {
                return httpResponse.statusCode == 200
            }
        } catch {
            if verbose {
                print("Health check failed: \(error.localizedDescription)")
            }
        }
        return false
    }

    // MARK: - Organizations

    func createOrganization(name: String, tier: String = "free") async throws -> UUID {
        let url = URL(string: "\(baseURL)/api/v1/organizations")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body = [
            "name": name,
            "subscriptionTier": tier
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw BackendError.invalidResponse
        }

        if verbose {
            print("Create organization response: \(httpResponse.statusCode)")
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

    func createProject(organizationId: UUID, name: String, bundleId: String) async throws -> UUID {
        let url = URL(string: "\(baseURL)/api/v1/projects")!
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

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw BackendError.invalidResponse
        }

        if verbose {
            print("Create project response: \(httpResponse.statusCode)")
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

    func createSession(projectId: UUID, config: [String: Any]) async throws -> UUID {
        let url = URL(string: "\(baseURL)/api/v1/sessions")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body = [
            "projectId": projectId.uuidString,
            "config": config
        ] as [String : Any]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw BackendError.invalidResponse
        }

        if verbose {
            print("Create session response: \(httpResponse.statusCode)")
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

    func updateSession(sessionId: UUID, status: String? = nil, metrics: [String: Any]? = nil) async throws {
        let url = URL(string: "\(baseURL)/api/v1/sessions/\(sessionId)")!
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        var body: [String: Any] = [:]
        if let status = status {
            body["status"] = status
        }
        if let metrics = metrics {
            body["metrics"] = metrics
        }

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw BackendError.invalidResponse
        }

        if verbose {
            print("Update session response: \(httpResponse.statusCode)")
        }

        guard httpResponse.statusCode == 200 else {
            let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw BackendError.httpError(statusCode: httpResponse.statusCode, message: errorMessage)
        }
    }

    func getSession(sessionId: UUID) async throws -> [String: Any] {
        let url = URL(string: "\(baseURL)/api/v1/sessions/\(sessionId)")!

        let (data, response) = try await session.data(from: url)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw BackendError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            throw BackendError.httpError(statusCode: httpResponse.statusCode)
        }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw BackendError.invalidJSON
        }

        return json
    }
}

enum BackendError: LocalizedError {
    case invalidResponse
    case httpError(statusCode: Int, message: String? = nil)
    case invalidJSON
    case connectionFailed

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "Invalid response from backend"
        case .httpError(let statusCode, let message):
            if let message = message {
                return "HTTP \(statusCode): \(message)"
            }
            return "HTTP error: \(statusCode)"
        case .invalidJSON:
            return "Invalid JSON response from backend"
        case .connectionFailed:
            return "Could not connect to backend"
        }
    }
}
```

### Task 2: Add Upload Capability to Explore Command

#### 2.1 Update ExploreCommand
**File to modify**: `Sources/XamrockCLI/Commands/ExploreCommand.swift`

Add these new options:
```swift
@Flag(help: "Upload exploration results to backend")
var upload = false

@Option(help: "Backend API URL (defaults to XAMROCK_API_URL env var)")
var apiURL: String?

@Flag(help: "Verify backend connectivity without running exploration")
var verifyBackend = false

@Flag(help: "Upload only summary, not detailed steps")
var uploadSummaryOnly = false
```

Add backend verification and upload logic:
```swift
public func run() async throws {
    // Verify or check backend if needed
    if verifyBackend || upload {
        let backendURL = apiURL ?? ProcessInfo.processInfo.environment["XAMROCK_API_URL"] ?? "http://localhost:8080"

        print("🔍 Checking backend at \(backendURL)...")
        let client = BackendClient(baseURL: backendURL, verbose: verbose)
        let isHealthy = await client.healthCheck()

        if !isHealthy {
            print("❌ Backend is not reachable at \(backendURL)")
            if verifyBackend {
                print("\n💡 Troubleshooting tips:")
                print("   1. Ensure backend is running: cd Backend && swift run")
                print("   2. Check the URL is correct")
                print("   3. Try: curl \(backendURL)/health")
                throw ExitCode.failure
            } else if upload {
                print("⚠️  Continuing without upload...")
                // Disable upload if backend is down
                upload = false
            }
        } else {
            print("✅ Backend is healthy")
            if verifyBackend {
                // Just verifying, exit early
                print("\n📊 Backend API available at: \(backendURL)")
                return
            }
        }
    }

    // ... existing exploration code ...

    // After exploration completes successfully
    if upload {
        try await uploadResults(result: explorationResult)
    }
}

private func uploadResults(result: ExplorationResult) async throws {
    let backendURL = apiURL ?? ProcessInfo.processInfo.environment["XAMROCK_API_URL"] ?? "http://localhost:8080"

    print("\n📤 Uploading results to backend...")

    let client = BackendClient(baseURL: backendURL, verbose: verbose)

    // Create or get organization (for now, create a test one)
    // TODO: In future, reuse existing org from config
    let orgId = try await client.createOrganization(
        name: "CLI User - \(Date().ISO8601Format())",
        tier: "free"
    )

    // Create project
    let projectId = try await client.createProject(
        organizationId: orgId,
        name: appBundleIdentifier,
        bundleId: appBundleIdentifier
    )

    // Create session with config
    let sessionConfig: [String: Any] = [
        "steps": steps,
        "goal": goal ?? "General exploration",
        "temperature": 0.7,
        "enableVerification": true,
        "maxRetries": 3
    ]

    let sessionId = try await client.createSession(
        projectId: projectId,
        config: sessionConfig
    )

    if verbose {
        print("Created session: \(sessionId)")
    }

    // Calculate health score (simple formula for now)
    let healthScore = Double(result.successRatePercent) * 0.6 +
                     Double(min(result.screensDiscovered * 5, 100)) * 0.4

    // Update session with metrics
    let metrics: [String: Any] = [
        "screensDiscovered": result.screensDiscovered,
        "transitions": result.transitions,
        "durationSeconds": Int(result.duration),
        "successfulActions": result.successfulActions,
        "failedActions": result.failedActions,
        "crashesDetected": result.crashesDetected,
        "verificationsPerformed": result.verificationsPerformed,
        "verificationsPassed": result.verificationsPassed,
        "retryAttempts": result.retryAttempts,
        "successRatePercent": result.successRatePercent,
        "healthScore": healthScore
    ]

    try await client.updateSession(
        sessionId: sessionId,
        status: "completed",
        metrics: metrics
    )

    print("✅ Results uploaded successfully!")
    print("📊 View session: \(backendURL)/api/v1/sessions/\(sessionId)")

    // Save session ID for future reference
    let manifestPath = outputDirectory.appendingPathComponent("backend_session.json")
    let backendInfo = [
        "sessionId": sessionId.uuidString,
        "apiURL": backendURL,
        "timestamp": ISO8601DateFormatter().string(from: Date())
    ]
    let backendData = try JSONSerialization.data(withJSONObject: backendInfo, options: .prettyPrinted)
    try backendData.write(to: manifestPath)

    if verbose {
        print("💾 Session info saved to: \(manifestPath.path)")
    }
}
```

### Task 3: Create Unit Tests

#### 3.1 Backend Integration Tests
**File**: `Tests/XamrockCLITests/BackendIntegrationTests.swift`

```swift
import XCTest
@testable import XamrockCLI

final class BackendIntegrationTests: XCTestCase {
    let testBackendURL = "http://localhost:8080"
    var client: BackendClient!

    override func setUp() async throws {
        client = BackendClient(baseURL: testBackendURL, verbose: true)

        // Check if backend is running
        let isHealthy = await client.healthCheck()
        if !isHealthy {
            throw XCTSkip("Backend is not running at \(testBackendURL)")
        }
    }

    func testHealthCheck() async throws {
        let isHealthy = await client.healthCheck()
        XCTAssertTrue(isHealthy, "Backend should be healthy")
    }

    func testCreateOrganization() async throws {
        let orgId = try await client.createOrganization(
            name: "Test Org \(UUID())",
            tier: "free"
        )
        XCTAssertNotNil(orgId)
    }

    func testCreateProject() async throws {
        // First create an organization
        let orgId = try await client.createOrganization(
            name: "Test Org \(UUID())",
            tier: "free"
        )

        // Then create a project
        let projectId = try await client.createProject(
            organizationId: orgId,
            name: "Test App",
            bundleId: "com.test.app.\(UUID().uuidString.prefix(8))"
        )
        XCTAssertNotNil(projectId)
    }

    func testCreateAndUpdateSession() async throws {
        // Setup: create org and project
        let orgId = try await client.createOrganization(
            name: "Test Org \(UUID())",
            tier: "free"
        )
        let projectId = try await client.createProject(
            organizationId: orgId,
            name: "Test App",
            bundleId: "com.test.app.\(UUID().uuidString.prefix(8))"
        )

        // Create session
        let config: [String: Any] = [
            "steps": 10,
            "goal": "Test exploration",
            "temperature": 0.7,
            "enableVerification": true,
            "maxRetries": 3
        ]
        let sessionId = try await client.createSession(
            projectId: projectId,
            config: config
        )
        XCTAssertNotNil(sessionId)

        // Update session with metrics
        let metrics: [String: Any] = [
            "screensDiscovered": 5,
            "transitions": 10,
            "durationSeconds": 30,
            "successfulActions": 8,
            "failedActions": 2,
            "successRatePercent": 80,
            "healthScore": 75.5
        ]

        try await client.updateSession(
            sessionId: sessionId,
            status: "completed",
            metrics: metrics
        )

        // Verify by fetching
        let session = try await client.getSession(sessionId: sessionId)
        XCTAssertEqual(session["status"] as? String, "completed")
        XCTAssertNotNil(session["metrics"])
    }

    func testUploadExplorationResult() async throws {
        // Mock exploration result
        let mockResult = ExplorationResult(
            screensDiscovered: 10,
            transitions: 25,
            duration: 60,
            navigationGraph: NavigationGraph(), // Mock graph
            successfulActions: 20,
            failedActions: 5,
            verificationsPerformed: 15,
            verificationsPassed: 12,
            verificationsFailed: 3,
            retryAttempts: 2,
            crashesDetected: 0
        )

        // Test the upload flow
        let orgId = try await client.createOrganization(
            name: "Test Upload Org",
            tier: "free"
        )

        let projectId = try await client.createProject(
            organizationId: orgId,
            name: "com.test.upload",
            bundleId: "com.test.upload"
        )

        let sessionId = try await client.createSession(
            projectId: projectId,
            config: ["steps": 25, "goal": "Test"]
        )

        // Calculate health score
        let healthScore = Double(mockResult.successRatePercent) * 0.6 +
                         Double(min(mockResult.screensDiscovered * 5, 100)) * 0.4

        let metrics: [String: Any] = [
            "screensDiscovered": mockResult.screensDiscovered,
            "transitions": mockResult.transitions,
            "durationSeconds": Int(mockResult.duration),
            "successfulActions": mockResult.successfulActions,
            "failedActions": mockResult.failedActions,
            "successRatePercent": mockResult.successRatePercent,
            "healthScore": healthScore
        ]

        try await client.updateSession(
            sessionId: sessionId,
            status: "completed",
            metrics: metrics
        )

        // Verify upload
        let session = try await client.getSession(sessionId: sessionId)
        XCTAssertEqual(session["status"] as? String, "completed")

        if let metrics = session["metrics"] as? [String: Any] {
            XCTAssertEqual(metrics["screensDiscovered"] as? Int, 10)
            XCTAssertEqual(metrics["transitions"] as? Int, 25)
        } else {
            XCTFail("Metrics not found in session")
        }
    }
}
```

Run tests with:
```bash
# Run all backend integration tests
swift test --filter BackendIntegration

# Run with verbose output
swift test --filter BackendIntegration --verbose
```

### Task 4: Create Development Scripts

#### 4.1 Backend Integration Test Script
**File**: `Scripts/test-backend-integration.sh`

```bash
#!/bin/bash
# Development script for testing backend integration
# NOT included in the compiled CLI binary

set -e

echo "🚀 Xamrock Backend Integration Test"
echo "===================================="

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check if backend is running
check_backend() {
    if curl -f -s http://localhost:8080/health > /dev/null; then
        return 0
    else
        return 1
    fi
}

# Step 1: Check backend
echo -e "\n${YELLOW}Step 1: Checking backend status...${NC}"
if check_backend; then
    echo -e "${GREEN}✅ Backend is running${NC}"
else
    echo -e "${YELLOW}⚠️  Backend not running. Starting it...${NC}"
    cd ../Backend
    swift run App &
    BACKEND_PID=$!
    sleep 3

    if check_backend; then
        echo -e "${GREEN}✅ Backend started successfully${NC}"
    else
        echo -e "${RED}❌ Failed to start backend${NC}"
        exit 1
    fi
    cd ../CLI
fi

# Step 2: Verify backend connectivity
echo -e "\n${YELLOW}Step 2: Verifying backend connectivity...${NC}"
swift run xamrock explore --verify-backend --api-url http://localhost:8080
if [ $? -eq 0 ]; then
    echo -e "${GREEN}✅ Backend connectivity verified${NC}"
else
    echo -e "${RED}❌ Backend connectivity check failed${NC}"
    exit 1
fi

# Step 3: Run unit tests
echo -e "\n${YELLOW}Step 3: Running backend integration tests...${NC}"
swift test --filter BackendIntegration
if [ $? -eq 0 ]; then
    echo -e "${GREEN}✅ Integration tests passed${NC}"
else
    echo -e "${RED}❌ Integration tests failed${NC}"
    exit 1
fi

# Step 4: Run exploration with upload
echo -e "\n${YELLOW}Step 4: Running exploration with upload...${NC}"
swift run xamrock explore \
    --app com.apple.Preferences \
    --steps 5 \
    --upload \
    --api-url http://localhost:8080 \
    --verbose

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✅ Exploration and upload successful${NC}"
else
    echo -e "${RED}❌ Exploration or upload failed${NC}"
    exit 1
fi

# Step 5: Verify data in backend
echo -e "\n${YELLOW}Step 5: Verifying uploaded data...${NC}"
RESPONSE=$(curl -s http://localhost:8080/api/v1/sessions)
SESSIONS=$(echo $RESPONSE | jq length 2>/dev/null || echo "0")

if [ "$SESSIONS" -gt 0 ]; then
    echo -e "${GREEN}✅ Found $SESSIONS sessions in backend${NC}"

    # Show last session summary
    echo -e "\n${YELLOW}Latest session summary:${NC}"
    echo $RESPONSE | jq '.[0] | {id, status, startedAt, metrics: .metrics | {screensDiscovered, transitions, healthScore}}' 2>/dev/null || echo "Could not parse sessions"
else
    echo -e "${RED}❌ No sessions found in backend${NC}"
    exit 1
fi

echo -e "\n${GREEN}🎉 All integration tests passed!${NC}"

# Cleanup if we started backend
if [ ! -z "$BACKEND_PID" ]; then
    echo -e "\n${YELLOW}Stopping backend...${NC}"
    kill $BACKEND_PID 2>/dev/null || true
fi
```

Make it executable:
```bash
chmod +x Scripts/test-backend-integration.sh
```

#### 4.2 Quick Test Script
**File**: `Scripts/quick-test.sh`

```bash
#!/bin/bash
# Quick test for development

# Just verify connectivity
swift run xamrock explore --verify-backend

# Run a minimal exploration with upload
swift run xamrock explore --app com.apple.Maps --steps 2 --upload --verbose
```

## Testing Instructions

### Prerequisites
1. Backend must be running: `cd ../Backend && swift run App`
2. CLI must build: `cd ../CLI && swift build`

### Testing Sequence

#### Test 1: Verify Backend Connectivity
```bash
# Quick connectivity check
swift run xamrock explore --verify-backend --api-url http://localhost:8080

# Expected output:
# 🔍 Checking backend at http://localhost:8080...
# ✅ Backend is healthy
# 📊 Backend API available at: http://localhost:8080
```

#### Test 2: Run Unit Tests
```bash
# Run backend integration tests
swift test --filter BackendIntegration

# Expected: All tests pass (some may skip if backend not running)
```

#### Test 3: Exploration with Upload
```bash
# Run exploration and upload results
swift run xamrock explore --app com.apple.Maps --steps 3 --upload --verbose

# Expected output:
# 🔍 Checking backend at http://localhost:8080...
# ✅ Backend is healthy
# 🤖 Starting AI exploration...
# [... exploration output ...]
# 📤 Uploading results to backend...
# ✅ Results uploaded successfully!
# 📊 View session: http://localhost:8080/api/v1/sessions/[UUID]
```

#### Test 4: Backend Down Handling
```bash
# Stop backend, then try upload
swift run xamrock explore --app com.apple.Maps --steps 2 --upload

# Expected output:
# 🔍 Checking backend at http://localhost:8080...
# ❌ Backend is not reachable at http://localhost:8080
# ⚠️  Continuing without upload...
# [... normal exploration continues ...]
```

#### Test 5: Environment Variable Configuration
```bash
# Use environment variable for API URL
export XAMROCK_API_URL=http://localhost:8080
swift run xamrock explore --app com.apple.Maps --upload

# Should use the environment variable URL
```

## Success Criteria

- [ ] `--verify-backend` flag successfully checks connectivity
- [ ] `--upload` flag uploads summary metrics after exploration
- [ ] Session ID is saved locally for reference
- [ ] Error messages are clear when backend is unavailable
- [ ] Backend validation errors are properly displayed
- [ ] Unit tests pass when backend is running
- [ ] Exploration continues even if upload fails

## Implementation Notes

- Use async/await for all network calls
- Handle network errors gracefully
- Don't hardcode credentials
- Make upload optional (flag-based)
- Save session IDs locally for traceability
- Use environment variables for configuration
- Include verbose logging for debugging

## Future Enhancements (Not Part of This Task)

1. **Authentication**: Add API key support
2. **Batch Upload**: Upload exploration steps in batches
3. **Media Upload**: Upload screenshots to backend
4. **Progress Streaming**: WebSocket support for live monitoring
5. **Configuration File**: Store API settings in ~/.xamrock/config
6. **Organization Reuse**: Reuse existing orgs instead of creating new ones

## Questions to Resolve

1. Should upload be default behavior or opt-in? (Currently opt-in)
2. How to handle organization reuse? (Currently creates new)
3. Should we compress data before upload? (Not yet)
4. What timeout values for network requests? (Using defaults)
5. Should we retry failed uploads? (Not yet)

## Deliverables

1. ✅ BackendClient implementation
2. ✅ Updated ExploreCommand with `--upload` and `--verify-backend` flags
3. ✅ Backend integration unit tests
4. ✅ Development test scripts
5. ✅ Updated documentation

---

**Priority**: Start with the BackendClient and unit tests to verify the approach, then add the upload capability to ExploreCommand.

**Estimated Time**: 4-6 hours for full implementation