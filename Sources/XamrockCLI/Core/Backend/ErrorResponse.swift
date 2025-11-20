import Foundation

/// Structured error response from the Xamrock Backend API
public struct ErrorResponse: Codable, Equatable, Sendable {
    /// Machine-readable error code
    public let code: String

    /// Human-readable title/message
    public let message: String

    /// Specific error details
    public let details: String?

    /// Field that caused the error (optional)
    public let field: String?

    /// Actionable suggestions for fixing the error
    public let suggestions: [String]

    public init(
        code: String,
        message: String,
        details: String? = nil,
        field: String? = nil,
        suggestions: [String] = []
    ) {
        self.code = code
        self.message = message
        self.details = details
        self.field = field
        self.suggestions = suggestions
    }
}

// MARK: - Error Code Enum

/// Strongly-typed error codes from the backend
public enum ErrorCode: String, CaseIterable {
    case validationError = "VALIDATION_ERROR"
    case duplicateResource = "DUPLICATE_RESOURCE"
    case notFound = "NOT_FOUND"
    case quotaExceeded = "QUOTA_EXCEEDED"
    case unauthorized = "UNAUTHORIZED"
    case badRequest = "BAD_REQUEST"
    case internalServerError = "INTERNAL_SERVER_ERROR"

    /// Map HTTP status code to error code
    public static func fromStatusCode(_ statusCode: Int) -> ErrorCode {
        switch statusCode {
        case 400:
            return .badRequest
        case 401:
            return .unauthorized
        case 403:
            return .quotaExceeded
        case 404:
            return .notFound
        case 409:
            return .duplicateResource
        case 422:
            return .validationError
        case 500...:
            return .internalServerError
        default:
            return .internalServerError
        }
    }
}

// MARK: - Formatting

extension ErrorResponse {
    /// Formatted description for console output
    public var formattedDescription: String {
        var output = "❌ \(message)"

        if let details = details {
            output += "\n   \(details)"
        }

        if let field = field {
            output += "\n   Field: \(field)"
        }

        if !suggestions.isEmpty {
            output += "\n\n💡 Suggestions:"
            for suggestion in suggestions {
                output += "\n   • \(suggestion)"
            }
        }

        return output
    }
}

// MARK: - BackendError Extension

extension BackendError {
    /// Create a BackendError from an ErrorResponse
    public static func from(_ errorResponse: ErrorResponse, statusCode: Int) -> BackendError {
        return .structuredError(
            statusCode: statusCode,
            errorResponse: errorResponse
        )
    }

    /// Try to parse ErrorResponse from data
    public static func parseErrorResponse(from data: Data, statusCode: Int) -> BackendError {
        if let errorResponse = try? JSONDecoder().decode(ErrorResponse.self, from: data) {
            return .from(errorResponse, statusCode: statusCode)
        } else {
            // Fallback to old error format
            if data.isEmpty {
                return .httpError(statusCode: statusCode, message: "Unknown error")
            }
            let message = String(data: data, encoding: .utf8) ?? "Unknown error"
            return .httpError(statusCode: statusCode, message: message)
        }
    }
}