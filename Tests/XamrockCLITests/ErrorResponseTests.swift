import XCTest
@testable import XamrockCLI

final class ErrorResponseTests: XCTestCase {

    // MARK: - Test JSON Parsing

    func testParseValidationError() throws {
        // Arrange
        let json = """
        {
            "code": "VALIDATION_ERROR",
            "message": "Validation Error",
            "details": "Organization name cannot be empty",
            "field": "name",
            "suggestions": [
                "Check the field requirements",
                "Ensure the data format is correct",
                "Review the API documentation for this field"
            ]
        }
        """.data(using: .utf8)!

        // Act
        let errorResponse = try JSONDecoder().decode(ErrorResponse.self, from: json)

        // Assert
        XCTAssertEqual(errorResponse.code, "VALIDATION_ERROR")
        XCTAssertEqual(errorResponse.message, "Validation Error")
        XCTAssertEqual(errorResponse.details, "Organization name cannot be empty")
        XCTAssertEqual(errorResponse.field, "name")
        XCTAssertEqual(errorResponse.suggestions.count, 3)
        XCTAssertEqual(errorResponse.suggestions.first, "Check the field requirements")
    }

    func testParseNotFoundError() throws {
        // Arrange
        let json = """
        {
            "code": "NOT_FOUND",
            "message": "Organization not found",
            "details": "No organization found with ID: 00000000-0000-0000-0000-000000000000",
            "suggestions": [
                "Verify the organization ID",
                "List all organizations to find the correct ID"
            ]
        }
        """.data(using: .utf8)!

        // Act
        let errorResponse = try JSONDecoder().decode(ErrorResponse.self, from: json)

        // Assert
        XCTAssertEqual(errorResponse.code, "NOT_FOUND")
        XCTAssertEqual(errorResponse.message, "Organization not found")
        XCTAssertNil(errorResponse.field)
        XCTAssertEqual(errorResponse.suggestions.count, 2)
    }

    func testParseMinimalError() throws {
        // Arrange
        let json = """
        {
            "code": "INTERNAL_SERVER_ERROR",
            "message": "Internal Server Error",
            "suggestions": []
        }
        """.data(using: .utf8)!

        // Act
        let errorResponse = try JSONDecoder().decode(ErrorResponse.self, from: json)

        // Assert
        XCTAssertEqual(errorResponse.code, "INTERNAL_SERVER_ERROR")
        XCTAssertEqual(errorResponse.message, "Internal Server Error")
        XCTAssertNil(errorResponse.details)
        XCTAssertNil(errorResponse.field)
        XCTAssertTrue(errorResponse.suggestions.isEmpty)
    }

    // MARK: - Test Error Code Enum

    func testErrorCodeEnum() {
        // Test that we can create strongly typed error codes
        XCTAssertEqual(ErrorCode.validationError.rawValue, "VALIDATION_ERROR")
        XCTAssertEqual(ErrorCode.duplicateResource.rawValue, "DUPLICATE_RESOURCE")
        XCTAssertEqual(ErrorCode.notFound.rawValue, "NOT_FOUND")
        XCTAssertEqual(ErrorCode.quotaExceeded.rawValue, "QUOTA_EXCEEDED")
        XCTAssertEqual(ErrorCode.unauthorized.rawValue, "UNAUTHORIZED")
        XCTAssertEqual(ErrorCode.badRequest.rawValue, "BAD_REQUEST")
        XCTAssertEqual(ErrorCode.internalServerError.rawValue, "INTERNAL_SERVER_ERROR")
    }

    func testErrorCodeFromString() {
        // Test that we can parse error codes from strings
        XCTAssertEqual(ErrorCode(rawValue: "VALIDATION_ERROR"), .validationError)
        XCTAssertEqual(ErrorCode(rawValue: "NOT_FOUND"), .notFound)
        XCTAssertNil(ErrorCode(rawValue: "UNKNOWN_CODE"))
    }

    // MARK: - Test Display Formatting

    func testFormattedErrorOutput() {
        // Arrange
        let errorResponse = ErrorResponse(
            code: "VALIDATION_ERROR",
            message: "Validation Error",
            details: "Organization name cannot be empty",
            field: "name",
            suggestions: [
                "Provide a non-empty organization name",
                "Use alphanumeric characters and spaces"
            ]
        )

        // Act
        let formatted = errorResponse.formattedDescription

        // Assert
        XCTAssertTrue(formatted.contains("❌ Validation Error"))
        XCTAssertTrue(formatted.contains("Organization name cannot be empty"))
        XCTAssertTrue(formatted.contains("Field: name"))
        XCTAssertTrue(formatted.contains("💡 Suggestions:"))
        XCTAssertTrue(formatted.contains("• Provide a non-empty organization name"))
    }

    func testFormattedErrorWithoutOptionalFields() {
        // Arrange
        let errorResponse = ErrorResponse(
            code: "INTERNAL_SERVER_ERROR",
            message: "Internal Server Error",
            details: nil,
            field: nil,
            suggestions: []
        )

        // Act
        let formatted = errorResponse.formattedDescription

        // Assert
        XCTAssertTrue(formatted.contains("❌ Internal Server Error"))
        XCTAssertFalse(formatted.contains("Field:"))
        XCTAssertFalse(formatted.contains("💡 Suggestions:"))
    }

    // MARK: - Test HTTP Status Code Mapping

    func testStatusCodeToErrorCode() {
        XCTAssertEqual(ErrorCode.fromStatusCode(400), .badRequest)
        XCTAssertEqual(ErrorCode.fromStatusCode(401), .unauthorized)
        XCTAssertEqual(ErrorCode.fromStatusCode(403), .quotaExceeded)
        XCTAssertEqual(ErrorCode.fromStatusCode(404), .notFound)
        XCTAssertEqual(ErrorCode.fromStatusCode(409), .duplicateResource)
        XCTAssertEqual(ErrorCode.fromStatusCode(422), .validationError)
        XCTAssertEqual(ErrorCode.fromStatusCode(500), .internalServerError)
        XCTAssertEqual(ErrorCode.fromStatusCode(502), .internalServerError)
    }
}