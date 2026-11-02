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
    /// Chat needs an end-user identity. Call `SeggWat.setChatToken(_:)` or
    /// `SeggWat.enableAnonymousChat()` first.
    case chatTokenMissing
    /// Server returned 401 - the chat token is invalid or expired.
    case chatTokenInvalid
    /// Server returned 428 - the project requires App Attest for anonymous chat.
    case attestationRequired
    /// App Attest is unavailable on this device (e.g. the iOS Simulator).
    case attestationUnsupported
    /// App Attest failed on the device or was rejected by the server.
    case attestationFailed(String)
    /// Server returned 400 or 429 for a chat message, with its reason
    /// (e.g. too long, or sending too quickly), fit to show the user.
    case chatMessageRejected(String)

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
        case .chatTokenMissing:
            return "Chat needs an end-user identity. Call SeggWat.setChatToken(_:) or SeggWat.enableAnonymousChat() first."
        case .chatTokenInvalid:
            return "The chat token is invalid or expired. Mint a new one on your backend."
        case .attestationRequired:
            return "This project requires App Attest for anonymous chat."
        case .attestationUnsupported:
            return "App Attest is not available on this device, e.g. the iOS Simulator."
        case .attestationFailed(let reason):
            return "App Attest failed: \(reason)"
        case .chatMessageRejected(let reason):
            return reason
        }
    }

    /// Map an HTTP status code to a SeggWatError.
    static func fromHTTPStatus(_ statusCode: Int, message: String? = nil) -> SeggWatError {
        switch statusCode {
        case 400: return .serverValidationFailed
        case 401: return .chatTokenInvalid
        case 428: return .attestationRequired
        case 403: return .originNotAllowed
        case 404: return .projectNotFound
        case 413: return .screenshotTooLarge
        case 409: return .duplicateRating
        case 415: return .unsupportedMediaType
        default: return .serverError(statusCode: statusCode, message: message)
        }
    }

    /// The server's reason for rejecting a chat message (400 or 429), if it gave one.
    static func chatRejection(statusCode: Int, data: Data) -> SeggWatError? {
        guard statusCode == 400 || statusCode == 429,
              let reason = try? JSONDecoder().decode(ChatErrorResponse.self, from: data).error
        else { return nil }
        return .chatMessageRejected(reason)
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
             (.duplicateRating, .duplicateRating),
             (.chatTokenMissing, .chatTokenMissing),
             (.chatTokenInvalid, .chatTokenInvalid),
             (.attestationRequired, .attestationRequired),
             (.attestationUnsupported, .attestationUnsupported):
            return true
        case (.invalidRatingValue(let a), .invalidRatingValue(let b)):
            return a == b
        case (.validationFailed(let a), .validationFailed(let b)):
            return a == b
        case (.rateLimited(let a), .rateLimited(let b)):
            return a == b
        case (.attestationFailed(let a), .attestationFailed(let b)):
            return a == b
        case (.chatMessageRejected(let a), .chatMessageRejected(let b)):
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
