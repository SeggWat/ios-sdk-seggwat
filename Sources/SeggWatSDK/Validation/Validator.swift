import Foundation

/// Validates feedback input, mirroring the rules in seggwat-core.js.
enum Validator {
    static let messageMinLength = 3
    static let messageMaxLength = 1000
    static let versionMaxLength = 50
    static let userIdMaxLength = 255
    static let emailMaxLength = 320

    private static func matches(_ string: String, pattern: String) -> Bool {
        string.range(of: pattern, options: .regularExpression) != nil
    }

    /// Validate a project key (UUID format).
    static func validateProjectKey(_ key: String) -> SeggWatError? {
        let pattern = "^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$"
        guard matches(key, pattern: pattern) else {
            return .invalidProjectKey
        }
        return nil
    }

    /// Validate a feedback message.
    static func validateMessage(_ message: String) -> SeggWatError? {
        let trimmed = message.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            return .validationFailed("Message cannot be empty.")
        }
        if trimmed.count < messageMinLength {
            return .validationFailed("Message must be at least \(messageMinLength) characters.")
        }
        if trimmed.count > messageMaxLength {
            return .validationFailed("Message must be at most \(messageMaxLength) characters.")
        }
        return nil
    }

    /// Validate a version string (optional).
    static func validateVersion(_ version: String?) -> SeggWatError? {
        guard let version, !version.isEmpty else { return nil }
        if version.count > versionMaxLength {
            return .validationFailed("Version must be at most \(versionMaxLength) characters.")
        }
        let pattern = "^[a-zA-Z0-9._\\-]+$"
        guard matches(version, pattern: pattern) else {
            return .validationFailed("Version contains invalid characters. Use only letters, numbers, dots, hyphens, and underscores.")
        }
        return nil
    }

    /// Validate a user ID (optional).
    static func validateUserId(_ userId: String?) -> SeggWatError? {
        guard let userId, !userId.isEmpty else { return nil }
        if userId.count > userIdMaxLength {
            return .validationFailed("User ID must be at most \(userIdMaxLength) characters.")
        }
        let pattern = "^[a-zA-Z0-9_\\-]+$"
        guard matches(userId, pattern: pattern) else {
            return .validationFailed("User ID contains invalid characters. Use only letters, numbers, underscores, and hyphens.")
        }
        return nil
    }

    /// Validate a submitter email address (optional).
    static func validateEmail(_ email: String?) -> SeggWatError? {
        guard let email, !email.isEmpty else { return nil }
        if email.count > emailMaxLength {
            return .validationFailed("Email must be at most \(emailMaxLength) characters.")
        }
        let pattern = "^[^@\\s]+@[^@\\s]+\\.[^@\\s]+$"
        guard matches(email, pattern: pattern) else {
            return .validationFailed("Email is not a valid address.")
        }
        return nil
    }

    /// Validate a star rating value.
    static func validateStarRating(value: UInt8, maxStars: UInt8) -> SeggWatError? {
        guard (1...10).contains(maxStars) else {
            return .invalidRatingValue("maxStars must be between 1 and 10.")
        }
        guard (1...maxStars).contains(value) else {
            return .invalidRatingValue("Star rating must be between 1 and \(maxStars).")
        }
        return nil
    }

    /// Validate an NPS rating value.
    static func validateNpsRating(value: UInt8) -> SeggWatError? {
        guard value <= 10 else {
            return .invalidRatingValue("NPS rating must be between 0 and 10.")
        }
        return nil
    }

    /// Validate screenshot data size.
    static func validateScreenshotSize(_ data: Data, maxSizeMB: Int) -> SeggWatError? {
        let maxBytes = maxSizeMB * 1024 * 1024
        if data.count > maxBytes {
            return .validationFailed("Screenshot exceeds maximum size of \(maxSizeMB)MB.")
        }
        return nil
    }
}
