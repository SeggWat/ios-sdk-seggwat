import Foundation

/// Errors that can occur when using the SeggWat SDK.
public enum SeggWatError: LocalizedError, Equatable {
    /// SDK has not been configured. Call `SeggWat.configure(projectKey:options:)` first.
    case notConfigured
    /// The project key is not a valid UUID.
    case invalidProjectKey
    /// Message validation failed (too short, too long, or empty).
    case validationFailed(String)
    /// Rate limited - user must wait before submitting again.
    case rateLimited(secondsRemaining: Int)
    /// Server returned 400 - request validation failed.
    case serverValidationFailed
    /// Server returned 403 - origin/bundle not allowed.
    case originNotAllowed
    /// Server returned 404 - project not found.
    case projectNotFound
    /// Server returned 413 - screenshot too large.
    case screenshotTooLarge
    /// Server returned 415 - unsupported media type.
    case unsupportedMediaType
    /// Network error (no connection, timeout, etc.).
    case networkError(String)
    /// Unexpected server error with HTTP status code.
    case serverError(statusCode: Int, message: String?)
    /// Screenshot capture failed.
    case screenshotCaptureFailed
    /// Invalid rating value (star out of range, NPS out of range, etc.).
    case invalidRatingValue(String)
    /// Server returned 409 - duplicate rating.
    case duplicateRating

    public var errorDescription: String? {
        switch self {
        case .notConfigured:
            return "SeggWat SDK is not configured. Call SeggWat.configure(projectKey:options:) first."
        case .invalidProjectKey:
            return "Invalid project key. Must be a valid UUID."
        case .validationFailed(let reason):
            return "Validation failed: \(reason)"
        case .rateLimited(let seconds):
            return "Please wait \(seconds) seconds before submitting again."
        case .serverValidationFailed:
            return "Server rejected the request due to validation errors."
        case .originNotAllowed:
            return "This app is not allowed to submit feedback to this project."
        case .projectNotFound:
            return "Project not found. Check your project key."
        case .screenshotTooLarge:
            return "Screenshot is too large. Try reducing the image size."
        case .unsupportedMediaType:
            return "Unsupported file format. Use JPEG or PNG."
        case .networkError(let message):
            return "Network error: \(message)"
        case .serverError(let code, let message):
            return "Server error (\(code)): \(message ?? "Unknown error")"
        case .screenshotCaptureFailed:
            return "Failed to capture screenshot."
        case .invalidRatingValue(let reason):
            return "Invalid rating value: \(reason)"
        case .duplicateRating:
            return "A rating has already been submitted for this path."
        }
    }

    /// Map an HTTP status code to a SeggWatError.
    static func fromHTTPStatus(_ statusCode: Int, message: String? = nil) -> SeggWatError {
        switch statusCode {
        case 400: return .serverValidationFailed
        case 403: return .originNotAllowed
        case 404: return .projectNotFound
        case 413: return .screenshotTooLarge
        case 409: return .duplicateRating
        case 415: return .unsupportedMediaType
        default: return .serverError(statusCode: statusCode, message: message)
        }
    }

    public static func == (lhs: SeggWatError, rhs: SeggWatError) -> Bool {
        switch (lhs, rhs) {
        case (.notConfigured, .notConfigured),
             (.invalidProjectKey, .invalidProjectKey),
             (.serverValidationFailed, .serverValidationFailed),
             (.originNotAllowed, .originNotAllowed),
             (.projectNotFound, .projectNotFound),
             (.screenshotTooLarge, .screenshotTooLarge),
             (.unsupportedMediaType, .unsupportedMediaType),
             (.screenshotCaptureFailed, .screenshotCaptureFailed),
             (.duplicateRating, .duplicateRating):
            return true
        case (.invalidRatingValue(let a), .invalidRatingValue(let b)):
            return a == b
        case (.validationFailed(let a), .validationFailed(let b)):
            return a == b
        case (.rateLimited(let a), .rateLimited(let b)):
            return a == b
        case (.networkError(let a), .networkError(let b)):
            return a == b
        case (.serverError(let codeA, let msgA), .serverError(let codeB, let msgB)):
            return codeA == codeB && msgA == msgB
        default:
            return false
        }
    }
}
