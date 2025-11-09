# Backend Improvements Implementation Guide

## Overview
This document provides detailed implementation instructions for improving the Xamrock Backend API based on real-world integration experience with the CLI. The improvements focus on better error handling, resource discovery, and developer experience.

## Current Issues Discovered
1. HTTP 500 errors with empty messages for validation failures
2. No way to query existing organizations/projects
3. Bundle identifier validation rejects hyphens but doesn't explain rules
4. Duplicate organization names cause 500 errors instead of proper conflicts
5. No idempotency support for resource creation

## Implementation Changes

### 1. Enhanced Error Response Structure

#### File: `Sources/App/Models/ErrorResponse.swift` (NEW FILE)
Create this new file for standardized error responses:

```swift
import Foundation
import Hummingbird

/// Standardized error response structure
struct ErrorResponse: ResponseCodable {
    let error: ErrorDetail

    struct ErrorDetail: Codable {
        let code: String
        let message: String
        let field: String?
        let suggestion: String?
        let validationRule: String?
    }

    init(code: String, message: String, field: String? = nil,
         suggestion: String? = nil, validationRule: String? = nil) {
        self.error = ErrorDetail(
            code: code,
            message: message,
            field: field,
            suggestion: suggestion,
            validationRule: validationRule
        )
    }
}

/// Enhanced HTTP errors with better messages
enum APIError: Error {
    case duplicateResource(resource: String, field: String, value: String)
    case validationFailed(field: String, rule: String, suggestion: String)
    case resourceNotFound(resource: String, id: String)
    case quotaExceeded(resource: String, limit: Int)

    var httpError: HTTPError {
        switch self {
        case .duplicateResource(let resource, let field, let value):
            return HTTPError(.conflict, message: "\(resource) with \(field) '\(value)' already exists")
        case .validationFailed(let field, let rule, _):
            return HTTPError(.unprocessableEntity, message: "Validation failed for \(field): \(rule)")
        case .resourceNotFound(let resource, let id):
            return HTTPError(.notFound, message: "\(resource) with ID '\(id)' not found")
        case .quotaExceeded(let resource, let limit):
            return HTTPError(.paymentRequired, message: "Quota exceeded for \(resource). Limit: \(limit)")
        }
    }

    var errorResponse: ErrorResponse {
        switch self {
        case .duplicateResource(let resource, let field, let value):
            return ErrorResponse(
                code: "DUPLICATE_\(resource.uppercased())",
                message: "\(resource) with \(field) '\(value)' already exists",
                field: field,
                suggestion: "Use a different \(field) or retrieve the existing \(resource)"
            )
        case .validationFailed(let field, let rule, let suggestion):
            return ErrorResponse(
                code: "VALIDATION_FAILED",
                message: "Validation failed for field '\(field)'",
                field: field,
                suggestion: suggestion,
                validationRule: rule
            )
        case .resourceNotFound(let resource, let id):
            return ErrorResponse(
                code: "\(resource.uppercased())_NOT_FOUND",
                message: "\(resource) not found",
                field: "id",
                suggestion: "Check the ID and try again"
            )
        case .quotaExceeded(let resource, let limit):
            return ErrorResponse(
                code: "QUOTA_EXCEEDED",
                message: "Quota exceeded for \(resource)",
                suggestion: "Upgrade your subscription or delete existing \(resource)s. Current limit: \(limit)"
            )
        }
    }
}
```

### 2. Update Organization Controller

#### File: `Sources/App/Controllers/OrganizationController.swift`

**ADD** query parameter support to the `list` function (line 26):

```swift
/// GET /api/v1/organizations
/// List all organizations with optional filters
@Sendable func list(_ request: Request, context: Context) async throws -> [Organization] {
    var query = Organization.query(on: self.fluent.db())

    // Filter by name if provided
    if let name = request.uri.queryParameters.get("name") {
        query = query.filter(\.$name == name)
    }

    // Filter by subscription tier if provided
    if let tierString = request.uri.queryParameters.get("tier"),
       let tier = Organization.SubscriptionTier(rawValue: tierString) {
        query = query.filter(\.$subscriptionTier == tier)
    }

    // Add pagination
    let page = request.uri.queryParameters.get("page").flatMap(Int.init) ?? 1
    let perPage = request.uri.queryParameters.get("per_page").flatMap(Int.init) ?? 20
    let offset = (page - 1) * perPage

    query = query.limit(perPage).offset(offset)

    return try await query.all()
}
```

**REPLACE** the create function error handling (lines 32-54):

```swift
/// POST /api/v1/organizations
/// Create a new organization
@Sendable func create(_ request: Request, context: Context) async throws -> EditedResponse<Organization> {
    let createRequest = try await request.decode(as: CreateOrganizationRequest.self, context: context)

    // Validate the request
    guard !createRequest.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
        throw APIError.validationFailed(
            field: "name",
            rule: "Name cannot be empty",
            suggestion: "Provide a non-empty organization name"
        ).httpError
    }

    // Check for duplicate name
    let existingOrg = try await Organization.query(on: self.fluent.db())
        .filter(\.$name == createRequest.name)
        .first()

    if existingOrg != nil {
        throw APIError.duplicateResource(
            resource: "Organization",
            field: "name",
            value: createRequest.name
        ).httpError
    }

    // Create the organization
    let organization = Organization(
        name: createRequest.name,
        subscriptionTier: createRequest.subscriptionTier,
        settings: createRequest.settings ?? OrganizationSettings.defaults(for: createRequest.subscriptionTier)
    )

    // Validate the model
    do {
        try organization.validate()
    } catch {
        throw APIError.validationFailed(
            field: "organization",
            rule: error.localizedDescription,
            suggestion: "Check organization data and try again"
        ).httpError
    }

    // Save to database
    try await organization.save(on: self.fluent.db())

    return .init(status: .created, response: organization)
}
```

### 3. Update Project Controller

#### File: `Sources/App/Controllers/ProjectController.swift`

**ADD** these query endpoints to the controller:

```swift
/// Add routes to the router group
func addRoutes(to group: RouterGroup<Context>) {
    group
        .get(use: self.list)
        .post(use: self.create)
        .get("search", use: self.searchByBundleId)  // NEW
        .group(":id")
        .add(middleware: UUIDParameterMiddleware())
        .get(use: self.get)
        .put(use: self.update)
        .delete(use: self.delete)
}

/// GET /api/v1/projects/search?bundleId=com.example.app
/// Search for project by bundle identifier
@Sendable func searchByBundleId(_ request: Request, context: Context) async throws -> Project? {
    guard let bundleId = request.uri.queryParameters.get("bundleId") else {
        throw HTTPError(.badRequest, message: "bundleId query parameter is required")
    }

    // Optionally filter by organization
    var query = Project.query(on: self.fluent.db())
        .filter(\.$bundleIdentifier == bundleId)

    if let orgIdString = request.uri.queryParameters.get("organizationId"),
       let orgId = UUID(uuidString: orgIdString) {
        query = query.filter(\.$organization.$id == orgId)
    }

    return try await query.first()
}
```

**UPDATE** the create function with better validation errors:

```swift
/// POST /api/v1/projects
/// Create a new project
@Sendable func create(_ request: Request, context: Context) async throws -> EditedResponse<Project> {
    let createRequest = try await request.decode(as: CreateProjectRequest.self, context: context)

    // Validate bundle identifier format
    let project = Project(
        organizationID: createRequest.organizationId,
        name: createRequest.name,
        bundleIdentifier: createRequest.bundleIdentifier,
        platform: createRequest.platform
    )

    // Check if bundle identifier is valid
    guard project.isValidBundleIdentifier else {
        throw APIError.validationFailed(
            field: "bundleIdentifier",
            rule: "Must follow format: lowercase letters, numbers, and dots only (e.g., com.example.app)",
            suggestion: "Remove hyphens and special characters. Use format like: com.example.app"
        ).httpError
    }

    // Check for duplicate within organization
    let existingProject = try await Project.findByBundleIdentifier(
        createRequest.bundleIdentifier,
        organizationID: createRequest.organizationId,
        on: self.fluent.db()
    )

    if existingProject != nil {
        throw APIError.duplicateResource(
            resource: "Project",
            field: "bundleIdentifier",
            value: createRequest.bundleIdentifier
        ).httpError
    }

    // Validate the model
    do {
        try project.validate()
    } catch {
        if error is ProjectError {
            switch error as! ProjectError {
            case .invalidBundleIdentifier:
                throw APIError.validationFailed(
                    field: "bundleIdentifier",
                    rule: "Format: [a-z0-9]+(\\.[a-z0-9]+)+",
                    suggestion: "Use lowercase letters, numbers, and dots. Example: com.company.app"
                ).httpError
            default:
                throw error
            }
        }
        throw error
    }

    // Save to database
    try await project.save(on: self.fluent.db())

    return .init(status: .created, response: project)
}
```

### 4. Update Bundle Identifier Validation

#### File: `Sources/App/Models/Project.swift`

**UPDATE** the validation regex (line 94) to be more explicit:

```swift
/// Validates that the bundle identifier follows Apple's format
var isValidBundleIdentifier: Bool {
    // Bundle identifier rules:
    // - Must contain at least one dot
    // - Can only contain lowercase letters, numbers, and dots
    // - Cannot contain hyphens, underscores, or special characters
    // - Cannot start or end with a dot
    // - Cannot have consecutive dots
    // Examples: com.company.app, org.team.product

    guard !bundleIdentifier.isEmpty else { return false }
    guard bundleIdentifier.contains(".") else { return false }
    guard !bundleIdentifier.hasPrefix(".") && !bundleIdentifier.hasSuffix(".") else { return false }
    guard !bundleIdentifier.contains("..") else { return false }

    // Only lowercase letters, numbers, and dots allowed
    let pattern = "^[a-z0-9]+(\\.[a-z0-9]+)+$"
    let regex = try? NSRegularExpression(pattern: pattern, options: [])
    let range = NSRange(location: 0, length: bundleIdentifier.utf16.count)
    return regex?.firstMatch(in: bundleIdentifier, options: [], range: range) != nil
}
```

**UPDATE** the error description (line 164):

```swift
case .invalidBundleIdentifier:
    return "Bundle identifier must use format: com.company.app (lowercase letters, numbers, dots only - no hyphens or underscores)"
```

### 5. Add Global Error Middleware

#### File: `Sources/App/App+build.swift`

**ADD** after line 95 (in router middleware):

```swift
// Add middleware
router.addMiddleware {
    // Logging middleware
    LogRequestsMiddleware(.info)

    // CORS middleware for API access
    CORSMiddleware(
        allowOrigin: .originBased,
        allowHeaders: [.contentType, .authorization, .accept],
        allowMethods: [.get, .post, .put, .delete, .patch, .options]
    )

    // Global error handler middleware (NEW)
    ErrorHandlingMiddleware()
}
```

#### File: `Sources/App/Middleware/ErrorHandlingMiddleware.swift` (NEW FILE)

```swift
import Hummingbird
import Logging

/// Global error handling middleware that provides consistent error responses
struct ErrorHandlingMiddleware<Context: RequestContext>: RouterMiddleware {
    func handle(_ request: Request, context: Context, next: (Request, Context) async throws -> Response) async throws -> Response {
        do {
            return try await next(request, context)
        } catch let error as APIError {
            // Handle our custom API errors with proper response
            let response = Response(
                status: error.httpError.status,
                headers: [.contentType: "application/json"],
                body: .init(byteBuffer: try JSONEncoder().encodeAsByteBuffer(
                    error.errorResponse,
                    allocator: context.allocator
                ))
            )
            return response
        } catch let error as HTTPError {
            // Handle existing HTTP errors
            throw error
        } catch {
            // Handle unexpected errors
            context.logger.error("Unexpected error: \(error)")
            let errorResponse = ErrorResponse(
                code: "INTERNAL_ERROR",
                message: "An unexpected error occurred",
                suggestion: "Please try again or contact support if the problem persists"
            )
            let response = Response(
                status: .internalServerError,
                headers: [.contentType: "application/json"],
                body: .init(byteBuffer: try JSONEncoder().encodeAsByteBuffer(
                    errorResponse,
                    allocator: context.allocator
                ))
            )
            return response
        }
    }
}
```

### 6. Add Idempotency Support (Optional but Recommended)

#### File: `Sources/App/Models/IdempotencyKey.swift` (NEW FILE)

```swift
import FluentKit
import Foundation

/// Tracks idempotency keys to prevent duplicate resource creation
final class IdempotencyKey: Model, @unchecked Sendable {
    static let schema = "idempotency_keys"

    @ID(key: .id)
    var id: UUID?

    @Field(key: "key")
    var key: String

    @Field(key: "resource_type")
    var resourceType: String

    @Field(key: "resource_id")
    var resourceId: UUID

    @Field(key: "created_at")
    var createdAt: Date

    init() {}

    init(key: String, resourceType: String, resourceId: UUID) {
        self.key = key
        self.resourceType = resourceType
        self.resourceId = resourceId
        self.createdAt = Date()
    }
}
```

## Testing the Improvements

### Test 1: Duplicate Organization Name
```bash
# First request - should succeed
curl -X POST http://localhost:8080/api/v1/organizations \
  -H "Content-Type: application/json" \
  -d '{"name":"Acme Corp","subscriptionTier":"free"}'

# Second request - should return 409 Conflict with helpful message
curl -X POST http://localhost:8080/api/v1/organizations \
  -H "Content-Type: application/json" \
  -d '{"name":"Acme Corp","subscriptionTier":"free"}'

# Expected response:
{
  "error": {
    "code": "DUPLICATE_ORGANIZATION",
    "message": "Organization with name 'Acme Corp' already exists",
    "field": "name",
    "suggestion": "Use a different name or retrieve the existing Organization"
  }
}
```

### Test 2: Invalid Bundle Identifier
```bash
curl -X POST http://localhost:8080/api/v1/projects \
  -H "Content-Type: application/json" \
  -d '{
    "organizationId":"[UUID]",
    "name":"My App",
    "bundleIdentifier":"com.test-app.example",
    "platform":"ios"
  }'

# Expected response (422):
{
  "error": {
    "code": "VALIDATION_FAILED",
    "message": "Validation failed for field 'bundleIdentifier'",
    "field": "bundleIdentifier",
    "suggestion": "Remove hyphens and special characters. Use format like: com.example.app",
    "validationRule": "Must follow format: lowercase letters, numbers, and dots only (e.g., com.example.app)"
  }
}
```

### Test 3: Query Organizations
```bash
# Query by name
curl "http://localhost:8080/api/v1/organizations?name=Acme%20Corp"

# Query by tier with pagination
curl "http://localhost:8080/api/v1/organizations?tier=free&page=1&per_page=10"
```

### Test 4: Search Projects
```bash
# Search by bundle ID
curl "http://localhost:8080/api/v1/projects/search?bundleId=com.example.app"

# Search by bundle ID within organization
curl "http://localhost:8080/api/v1/projects/search?bundleId=com.example.app&organizationId=[UUID]"
```

## Migration Notes

### Database Migration Required
If using idempotency keys, create migration:

```swift
// Sources/App/Migrations/CreateIdempotencyKeys.swift
struct CreateIdempotencyKeys: AsyncMigration {
    func prepare(on database: Database) async throws {
        try await database.schema("idempotency_keys")
            .id()
            .field("key", .string, .required)
            .field("resource_type", .string, .required)
            .field("resource_id", .uuid, .required)
            .field("created_at", .datetime, .required)
            .unique(on: "key")
            .create()
    }

    func revert(on database: Database) async throws {
        try await database.schema("idempotency_keys").delete()
    }
}
```

## Success Criteria

After implementing these changes:

1. ✅ No more HTTP 500 errors with empty messages
2. ✅ Clear validation messages explaining what's wrong and how to fix it
3. ✅ Ability to query existing organizations and projects
4. ✅ Proper HTTP status codes (409 for conflicts, 422 for validation)
5. ✅ Bundle identifier validation clearly explains format requirements
6. ✅ CLI can check for existing resources before creating new ones
7. ✅ Better developer experience with actionable error messages

## CLI Benefits

With these backend improvements, the CLI can:
- Remove workaround code for organization/project reuse
- Show users exactly what went wrong with helpful error messages
- Query for existing resources instead of maintaining local state
- Provide better error messages to end users
- Retry operations safely with idempotency keys

## Rollout Strategy

1. Implement error handling improvements first (no breaking changes)
2. Add query endpoints (additive, no breaking changes)
3. Update validation messages (backward compatible)
4. Optional: Add idempotency support later

All changes are backward compatible and can be rolled out incrementally.