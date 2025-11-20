import Foundation

/// Utility for handling different types of backend errors
public struct ErrorHandler {

    /// Handle a backend error and print appropriate user-friendly messages
    public static func handle(_ error: Error) {
        if let backendError = error as? BackendError {
            handleBackendError(backendError)
        } else {
            // Generic error handling
            print("❌ Error: \(error.localizedDescription)")
        }
    }

    /// Handle backend-specific errors
    private static func handleBackendError(_ error: BackendError) {
        switch error {
        case .structuredError(let statusCode, let errorResponse):
            handleStructuredError(statusCode: statusCode, errorResponse: errorResponse)
        case .httpError(let statusCode, let message):
            handleHttpError(statusCode: statusCode, message: message)
        case .invalidURL:
            print("❌ Invalid URL configuration")
            print("💡 Check your backend URL in the configuration")
        case .invalidResponse:
            print("❌ Invalid response from backend")
            print("💡 The backend returned an unexpected response format")
        case .invalidJSON:
            print("❌ Invalid JSON response from backend")
            print("💡 The backend returned data that couldn't be parsed")
        case .uploadFailed:
            print("❌ Failed to upload artifact to backend")
            print("💡 Check your network connection and try again")
        case .sessionNotFound:
            print("❌ Session not found")
            print("💡 Verify the session ID or use 'dashboard list' to see available sessions")
        case .requestFailed:
            print("❌ Request failed")
            print("💡 Check your network connection and backend availability")
        }
    }

    /// Handle structured errors with specific logic per error code
    private static func handleStructuredError(statusCode: Int, errorResponse: ErrorResponse) {
        // Print the formatted error description
        print(errorResponse.formattedDescription)

        // Add specific handling based on error code
        if let errorCode = ErrorCode(rawValue: errorResponse.code) {
            switch errorCode {
            case .validationError:
                handleValidationError(errorResponse)
            case .duplicateResource:
                handleDuplicateResource(errorResponse)
            case .notFound:
                handleNotFound(errorResponse)
            case .quotaExceeded:
                handleQuotaExceeded(errorResponse)
            case .unauthorized:
                handleUnauthorized(errorResponse)
            case .badRequest:
                handleBadRequest(errorResponse)
            case .internalServerError:
                handleInternalServerError(errorResponse)
            }
        }
    }

    /// Handle legacy HTTP errors
    private static func handleHttpError(statusCode: Int, message: String?) {
        print("❌ HTTP Error \(statusCode)")
        if let message = message, !message.isEmpty {
            print("   \(message)")
        }

        // Provide generic suggestions based on status code
        switch statusCode {
        case 400:
            print("💡 Check your request parameters")
        case 401:
            print("💡 Authentication required - please log in")
        case 403:
            print("💡 You don't have permission for this operation")
        case 404:
            print("💡 The requested resource was not found")
        case 409:
            print("💡 A resource with this identifier already exists")
        case 422:
            print("💡 Validation failed - check your input data")
        case 500...:
            print("💡 Server error - please try again later")
        default:
            break
        }
    }

    // MARK: - Specific Error Handlers

    private static func handleValidationError(_ errorResponse: ErrorResponse) {
        // Additional context for validation errors
        if let field = errorResponse.field {
            print("\n🔍 Check the '\(field)' field specifically")
        }
    }

    private static func handleDuplicateResource(_ errorResponse: ErrorResponse) {
        // Additional context for duplicate resources
        print("\n🔍 Try using a different identifier or check existing resources")
    }

    private static func handleNotFound(_ errorResponse: ErrorResponse) {
        // Additional context for not found errors
        print("\n🔍 Verify the ID or use 'list' commands to see available resources")
    }

    private static func handleQuotaExceeded(_ errorResponse: ErrorResponse) {
        // Additional context for quota errors
        print("\n🔍 Consider upgrading your subscription or removing unused resources")
    }

    private static func handleUnauthorized(_ errorResponse: ErrorResponse) {
        // Additional context for auth errors
        print("\n🔍 Use 'xamrock login' to authenticate")
    }

    private static func handleBadRequest(_ errorResponse: ErrorResponse) {
        // Additional context for bad requests
        print("\n🔍 Review the command syntax and parameters")
    }

    private static func handleInternalServerError(_ errorResponse: ErrorResponse) {
        // Additional context for server errors
        print("\n🔍 If this persists, please contact support")
    }
}

// MARK: - Convenience Methods for Commands

public extension ErrorHandler {

    /// Check if an error indicates a resource already exists
    static func isDuplicateResource(_ error: Error) -> Bool {
        if let backendError = error as? BackendError {
            switch backendError {
            case .structuredError(_, let errorResponse):
                return errorResponse.code == ErrorCode.duplicateResource.rawValue
            case .httpError(let statusCode, _):
                return statusCode == 409
            default:
                return false
            }
        }
        return false
    }

    /// Check if an error indicates a resource was not found
    static func isNotFound(_ error: Error) -> Bool {
        if let backendError = error as? BackendError {
            switch backendError {
            case .structuredError(_, let errorResponse):
                return errorResponse.code == ErrorCode.notFound.rawValue
            case .httpError(let statusCode, _):
                return statusCode == 404
            default:
                return false
            }
        }
        return false
    }

    /// Check if an error is a validation error
    static func isValidationError(_ error: Error) -> Bool {
        if let backendError = error as? BackendError {
            switch backendError {
            case .structuredError(_, let errorResponse):
                return errorResponse.code == ErrorCode.validationError.rawValue
            case .httpError(let statusCode, _):
                return statusCode == 422
            default:
                return false
            }
        }
        return false
    }

    /// Extract field name from validation error if available
    static func validationField(from error: Error) -> String? {
        if let backendError = error as? BackendError {
            switch backendError {
            case .structuredError(_, let errorResponse):
                return errorResponse.field
            default:
                return nil
            }
        }
        return nil
    }

    /// Get suggestions from an error if available
    static func suggestions(from error: Error) -> [String]? {
        if let backendError = error as? BackendError {
            switch backendError {
            case .structuredError(_, let errorResponse):
                return errorResponse.suggestions.isEmpty ? nil : errorResponse.suggestions
            default:
                return nil
            }
        }
        return nil
    }
}