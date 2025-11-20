import XCTest
@testable import XamrockCLI

final class BackendClientErrorTests: XCTestCase {

    // MARK: - Test Error Parsing from Response

    func testParseValidationErrorResponse() async throws {
        // This test validates that BackendClient correctly parses structured error responses
        // We'll test the actual error parsing logic

        // Given: A validation error response
        let errorData = """
        {
            "code": "VALIDATION_ERROR",
            "message": "Validation Error",
            "details": "Organization name cannot be empty",
            "field": "name",
            "suggestions": [
                "Provide a non-empty organization name",
                "Use only alphanumeric characters and spaces"
            ]
        }
        """.data(using: .utf8)!

        // When: Parsing the error
        let error = BackendError.parseErrorResponse(from: errorData, statusCode: 422)

        // Then: Should create a structured error
        switch error {
        case .structuredError(let statusCode, let errorResponse):
            XCTAssertEqual(statusCode, 422)
            XCTAssertEqual(errorResponse.code, "VALIDATION_ERROR")
            XCTAssertEqual(errorResponse.message, "Validation Error")
            XCTAssertEqual(errorResponse.details, "Organization name cannot be empty")
            XCTAssertEqual(errorResponse.field, "name")
            XCTAssertEqual(errorResponse.suggestions.count, 2)
        default:
            XCTFail("Expected structured error, got: \(error)")
        }
    }

    func testParseNotFoundErrorResponse() async throws {
        // Given: A not found error response
        let errorData = """
        {
            "code": "NOT_FOUND",
            "message": "Resource not found",
            "details": "Organization with ID 12345 not found",
            "suggestions": ["Check the organization ID", "List all organizations"]
        }
        """.data(using: .utf8)!

        // When: Parsing the error
        let error = BackendError.parseErrorResponse(from: errorData, statusCode: 404)

        // Then: Should create a structured error
        switch error {
        case .structuredError(let statusCode, let errorResponse):
            XCTAssertEqual(statusCode, 404)
            XCTAssertEqual(errorResponse.code, "NOT_FOUND")
            XCTAssertNil(errorResponse.field)
            XCTAssertEqual(errorResponse.suggestions.count, 2)
        default:
            XCTFail("Expected structured error, got: \(error)")
        }
    }

    func testParseDuplicateResourceError() async throws {
        // Given: A duplicate resource error response
        let errorData = """
        {
            "code": "DUPLICATE_RESOURCE",
            "message": "Resource already exists",
            "details": "An organization with this name already exists",
            "field": "name",
            "suggestions": ["Use a different organization name", "Check existing organizations"]
        }
        """.data(using: .utf8)!

        // When: Parsing the error
        let error = BackendError.parseErrorResponse(from: errorData, statusCode: 409)

        // Then: Should create a structured error
        switch error {
        case .structuredError(let statusCode, let errorResponse):
            XCTAssertEqual(statusCode, 409)
            XCTAssertEqual(errorResponse.code, "DUPLICATE_RESOURCE")
            XCTAssertEqual(errorResponse.field, "name")
        default:
            XCTFail("Expected structured error, got: \(error)")
        }
    }

    func testParseQuotaExceededError() async throws {
        // Given: A quota exceeded error response
        let errorData = """
        {
            "code": "QUOTA_EXCEEDED",
            "message": "Organization limit reached",
            "details": "Your subscription tier allows a maximum of 3 organizations",
            "suggestions": ["Upgrade your subscription", "Delete unused organizations"]
        }
        """.data(using: .utf8)!

        // When: Parsing the error
        let error = BackendError.parseErrorResponse(from: errorData, statusCode: 403)

        // Then: Should create a structured error
        switch error {
        case .structuredError(let statusCode, let errorResponse):
            XCTAssertEqual(statusCode, 403)
            XCTAssertEqual(errorResponse.code, "QUOTA_EXCEEDED")
            XCTAssertTrue(errorResponse.suggestions.contains("Upgrade your subscription"))
        default:
            XCTFail("Expected structured error, got: \(error)")
        }
    }

    func testParseNonJsonErrorResponse() async throws {
        // Given: A non-JSON error response (e.g., HTML error page)
        let errorData = "<html><body>Internal Server Error</body></html>".data(using: .utf8)!

        // When: Parsing the error (should fallback to httpError)
        let error = BackendError.parseErrorResponse(from: errorData, statusCode: 500)

        // Then: Should fallback to httpError
        switch error {
        case .httpError(let statusCode, let message):
            XCTAssertEqual(statusCode, 500)
            XCTAssertEqual(message, "<html><body>Internal Server Error</body></html>")
        default:
            XCTFail("Expected httpError fallback, got: \(error)")
        }
    }

    func testParseEmptyErrorResponse() async throws {
        // Given: An empty error response
        let errorData = Data()

        // When: Parsing the error
        let error = BackendError.parseErrorResponse(from: errorData, statusCode: 500)

        // Then: Should fallback to httpError with "Unknown error"
        switch error {
        case .httpError(let statusCode, let message):
            XCTAssertEqual(statusCode, 500)
            XCTAssertEqual(message, "Unknown error")
        default:
            XCTFail("Expected httpError fallback, got: \(error)")
        }
    }

    // MARK: - Test Error Description Formatting

    func testStructuredErrorDescription() {
        // Given: A structured error
        let errorResponse = ErrorResponse(
            code: "VALIDATION_ERROR",
            message: "Validation Error",
            details: "Invalid bundle identifier format",
            field: "bundleIdentifier",
            suggestions: ["Use format: com.company.appname"]
        )
        let error = BackendError.structuredError(statusCode: 422, errorResponse: errorResponse)

        // When: Getting error description
        let description = error.errorDescription!

        // Then: Should format properly
        XCTAssertTrue(description.contains("❌ Validation Error"))
        XCTAssertTrue(description.contains("Invalid bundle identifier format"))
        XCTAssertTrue(description.contains("Field: bundleIdentifier"))
        XCTAssertTrue(description.contains("💡 Suggestions:"))
        XCTAssertTrue(description.contains("Use format: com.company.appname"))
    }

    func testHttpErrorDescription() {
        // Given: An HTTP error
        let error = BackendError.httpError(statusCode: 500, message: "Internal Server Error")

        // When: Getting error description
        let description = error.errorDescription!

        // Then: Should format as before
        XCTAssertEqual(description, "HTTP 500: Internal Server Error")
    }

    func testHttpErrorDescriptionWithoutMessage() {
        // Given: An HTTP error without message
        let error = BackendError.httpError(statusCode: 503)

        // When: Getting error description
        let description = error.errorDescription!

        // Then: Should show just status code
        XCTAssertEqual(description, "HTTP error: 503")
    }
}