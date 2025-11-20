import XCTest
@testable import XamrockCLI

final class ErrorHandlerTests: XCTestCase {

    // MARK: - Test Error Type Detection

    func testIsDuplicateResource() {
        // Test structured error
        let structuredError = BackendError.structuredError(
            statusCode: 409,
            errorResponse: ErrorResponse(
                code: "DUPLICATE_RESOURCE",
                message: "Resource already exists"
            )
        )
        XCTAssertTrue(ErrorHandler.isDuplicateResource(structuredError))

        // Test HTTP error with 409 status
        let httpError = BackendError.httpError(statusCode: 409, message: "Duplicate")
        XCTAssertTrue(ErrorHandler.isDuplicateResource(httpError))

        // Test non-duplicate errors
        let validationError = BackendError.structuredError(
            statusCode: 422,
            errorResponse: ErrorResponse(
                code: "VALIDATION_ERROR",
                message: "Validation failed"
            )
        )
        XCTAssertFalse(ErrorHandler.isDuplicateResource(validationError))
    }

    func testIsNotFound() {
        // Test structured error
        let structuredError = BackendError.structuredError(
            statusCode: 404,
            errorResponse: ErrorResponse(
                code: "NOT_FOUND",
                message: "Resource not found"
            )
        )
        XCTAssertTrue(ErrorHandler.isNotFound(structuredError))

        // Test HTTP error with 404 status
        let httpError = BackendError.httpError(statusCode: 404, message: "Not found")
        XCTAssertTrue(ErrorHandler.isNotFound(httpError))

        // Test non-not-found errors
        let serverError = BackendError.httpError(statusCode: 500, message: "Server error")
        XCTAssertFalse(ErrorHandler.isNotFound(serverError))
    }

    func testIsValidationError() {
        // Test structured error
        let structuredError = BackendError.structuredError(
            statusCode: 422,
            errorResponse: ErrorResponse(
                code: "VALIDATION_ERROR",
                message: "Validation failed",
                field: "email"
            )
        )
        XCTAssertTrue(ErrorHandler.isValidationError(structuredError))

        // Test HTTP error with 422 status
        let httpError = BackendError.httpError(statusCode: 422, message: "Validation failed")
        XCTAssertTrue(ErrorHandler.isValidationError(httpError))

        // Test non-validation errors
        let authError = BackendError.structuredError(
            statusCode: 401,
            errorResponse: ErrorResponse(
                code: "UNAUTHORIZED",
                message: "Not authenticated"
            )
        )
        XCTAssertFalse(ErrorHandler.isValidationError(authError))
    }

    // MARK: - Test Data Extraction

    func testValidationFieldExtraction() {
        // Test with field present
        let errorWithField = BackendError.structuredError(
            statusCode: 422,
            errorResponse: ErrorResponse(
                code: "VALIDATION_ERROR",
                message: "Validation failed",
                field: "bundleIdentifier"
            )
        )
        XCTAssertEqual(ErrorHandler.validationField(from: errorWithField), "bundleIdentifier")

        // Test without field
        let errorWithoutField = BackendError.structuredError(
            statusCode: 422,
            errorResponse: ErrorResponse(
                code: "VALIDATION_ERROR",
                message: "Validation failed"
            )
        )
        XCTAssertNil(ErrorHandler.validationField(from: errorWithoutField))

        // Test with HTTP error (no field)
        let httpError = BackendError.httpError(statusCode: 422, message: "Validation failed")
        XCTAssertNil(ErrorHandler.validationField(from: httpError))
    }

    func testSuggestionsExtraction() {
        // Test with suggestions
        let errorWithSuggestions = BackendError.structuredError(
            statusCode: 404,
            errorResponse: ErrorResponse(
                code: "NOT_FOUND",
                message: "Not found",
                suggestions: ["Check the ID", "List available resources"]
            )
        )
        let suggestions = ErrorHandler.suggestions(from: errorWithSuggestions)
        XCTAssertNotNil(suggestions)
        XCTAssertEqual(suggestions?.count, 2)
        XCTAssertTrue(suggestions?.contains("Check the ID") ?? false)

        // Test without suggestions
        let errorWithoutSuggestions = BackendError.structuredError(
            statusCode: 500,
            errorResponse: ErrorResponse(
                code: "INTERNAL_SERVER_ERROR",
                message: "Server error",
                suggestions: []
            )
        )
        XCTAssertNil(ErrorHandler.suggestions(from: errorWithoutSuggestions))

        // Test with HTTP error (no suggestions)
        let httpError = BackendError.httpError(statusCode: 404, message: "Not found")
        XCTAssertNil(ErrorHandler.suggestions(from: httpError))
    }

    // MARK: - Test Error Handling Output

    func testHandleValidationError() {
        // Create a validation error
        let error = BackendError.structuredError(
            statusCode: 422,
            errorResponse: ErrorResponse(
                code: "VALIDATION_ERROR",
                message: "Validation Error",
                details: "Bundle identifier format is invalid",
                field: "bundleIdentifier",
                suggestions: [
                    "Use format: com.company.appname",
                    "Avoid special characters"
                ]
            )
        )

        // Capture output (in a real scenario, we'd redirect stdout)
        // For now, we just verify the error can be handled without crashing
        ErrorHandler.handle(error)

        // Test passes if no crash occurs
        XCTAssertTrue(true)
    }

    func testHandleDuplicateResourceError() {
        let error = BackendError.structuredError(
            statusCode: 409,
            errorResponse: ErrorResponse(
                code: "DUPLICATE_RESOURCE",
                message: "Resource already exists",
                details: "An organization with this name already exists",
                field: "name",
                suggestions: ["Use a different name", "Check existing organizations"]
            )
        )

        ErrorHandler.handle(error)
        XCTAssertTrue(true)
    }

    func testHandleNotFoundError() {
        let error = BackendError.structuredError(
            statusCode: 404,
            errorResponse: ErrorResponse(
                code: "NOT_FOUND",
                message: "Organization not found",
                details: "No organization found with the specified ID",
                suggestions: ["Verify the organization ID", "List all organizations"]
            )
        )

        ErrorHandler.handle(error)
        XCTAssertTrue(true)
    }

    func testHandleQuotaExceededError() {
        let error = BackendError.structuredError(
            statusCode: 403,
            errorResponse: ErrorResponse(
                code: "QUOTA_EXCEEDED",
                message: "Quota exceeded",
                details: "Maximum number of projects reached for your subscription",
                suggestions: ["Upgrade your subscription", "Delete unused projects"]
            )
        )

        ErrorHandler.handle(error)
        XCTAssertTrue(true)
    }

    func testHandleUnauthorizedError() {
        let error = BackendError.structuredError(
            statusCode: 401,
            errorResponse: ErrorResponse(
                code: "UNAUTHORIZED",
                message: "Authentication required",
                suggestions: ["Use 'xamrock login' to authenticate"]
            )
        )

        ErrorHandler.handle(error)
        XCTAssertTrue(true)
    }

    func testHandleLegacyHttpError() {
        // Test handling of old-style HTTP errors
        let error = BackendError.httpError(statusCode: 500, message: "Internal Server Error")

        ErrorHandler.handle(error)
        XCTAssertTrue(true)
    }

    func testHandleGenericError() {
        // Test handling of non-backend errors
        struct CustomError: LocalizedError {
            var errorDescription: String? { "Custom error occurred" }
        }

        let error = CustomError()
        ErrorHandler.handle(error)
        XCTAssertTrue(true)
    }
}