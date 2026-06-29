import SwiftUI

/// Main entry point for the SeggWat Feedback SDK.
///
/// Usage:
/// ```swift
/// // Configure in App.init
/// SeggWat.configure(projectKey: "your-uuid", options: SeggWatOptions(
///     buttonColor: .green,
///     screenshotsEnabled: true
/// ))
///
/// // Set user identity (optional) — email makes the submitter contactable
/// SeggWat.setUser("user-123", email: "jane@example.com")
///
/// // Add floating button to a view
/// ContentView()
///     .seggwatFeedbackButton()
/// ```
@MainActor
public final class SeggWat: ObservableObject {

    /// Shared singleton instance.
    public static let shared = SeggWat()

    /// Whether the SDK has been configured.
    @Published public private(set) var isConfigured = false

    /// Whether the feedback sheet is currently presented.
    @Published public var isPresented = false

    /// When `true`, the floating feedback button is hidden even though the SDK
    /// is configured. Host apps can toggle this per-screen to avoid overlapping
    /// a screen's own bottom input bar (e.g. a chat composer). The feedback
    /// sheet can still be presented programmatically via `presentFeedback()`.
    @Published public var isButtonHidden = false

    private(set) var projectKey: String = ""
    private(set) var options = SeggWatOptions()
    private(set) var userId: String?
    private(set) var userEmail: String?
    private var apiClient: APIClient?
    let rateLimiter = RateLimiter()

    private init() {}

    // MARK: - Configuration

    /// Configure the SDK with a project key and options.
    /// Call this once, typically in your App's initializer.
    public static func configure(projectKey: String, options: SeggWatOptions = SeggWatOptions()) {
        let instance = shared
        instance.projectKey = projectKey
        instance.options = options
        instance.apiClient = APIClient(baseURL: options.apiURL)
        instance.isConfigured = true
    }

    /// Set the current user for attribution.
    ///
    /// - Parameters:
    ///   - userId: Stable identifier for the user (e.g. your auth subject id).
    ///     Sent as `submitted_by` so feedback is no longer anonymous.
    ///   - email: Optional email address. Sent as `submitted_by_email` so your
    ///     team can see who submitted and reply directly from the dashboard.
    public static func setUser(_ userId: String?, email: String? = nil) {
        shared.userId = userId
        shared.userEmail = email
    }

    /// Present the feedback sheet programmatically.
    public static func presentFeedback() {
        shared.isPresented = true
    }

    /// Dismiss the feedback sheet programmatically.
    public static func dismiss() {
        shared.isPresented = false
    }

    // MARK: - Submission

    /// Submit feedback programmatically.
    ///
    /// - Parameters:
    ///   - message: The feedback message (3-1000 characters).
    ///   - screenName: Optional screen/path identifier.
    ///   - screenshotData: Optional JPEG screenshot data.
    public func submitFeedback(
        message: String,
        screenName: String? = nil,
        screenshotData: Data? = nil
    ) async throws {
        guard isConfigured, let apiClient else {
            throw SeggWatError.notConfigured
        }

        // Validate
        if let error = Validator.validateProjectKey(projectKey) {
            throw error
        }
        if let error = Validator.validateMessage(message) {
            throw error
        }
        if let error = Validator.validateVersion(options.appVersion) {
            throw error
        }
        if let error = Validator.validateUserId(userId) {
            throw error
        }
        if let error = Validator.validateEmail(userEmail) {
            throw error
        }

        // Rate limit
        if let remaining = rateLimiter.check() {
            throw SeggWatError.rateLimited(secondsRemaining: remaining)
        }

        let payload = FeedbackPayload(
            projectKey: projectKey,
            message: message.trimmingCharacters(in: .whitespacesAndNewlines),
            screenName: screenName,
            version: options.appVersion,
            userId: userId,
            userEmail: userEmail
        )

        if let screenshotData {
            if let error = Validator.validateScreenshotSize(screenshotData, maxSizeMB: options.maxScreenshotSizeMB) {
                throw error
            }
            try await apiClient.submitFeedbackWithScreenshot(payload, screenshotData: screenshotData)
        } else {
            try await apiClient.submitFeedback(payload)
        }

        rateLimiter.recordSubmission()

        // Notify callback
        options.onSubmit?(.success(()))
    }

    // MARK: - Rating Submission

    /// Submit a rating programmatically.
    ///
    /// - Parameters:
    ///   - rating: The rating value (`.helpful`, `.star`, or `.nps`).
    ///   - screenName: Optional screen/path identifier.
    /// - Returns: The created rating response with its server-assigned ID.
    @discardableResult
    public func submitRating(
        _ rating: RatingValue,
        screenName: String? = nil
    ) async throws -> RatingCreatedResponse {
        guard isConfigured, let apiClient else {
            throw SeggWatError.notConfigured
        }

        // Validate
        if let error = Validator.validateProjectKey(projectKey) {
            throw error
        }
        if let error = Validator.validateVersion(options.appVersion) {
            throw error
        }
        if let error = Validator.validateUserId(userId) {
            throw error
        }

        // Validate rating value
        switch rating {
        case .helpful:
            break
        case .star(let value, let maxStars):
            if let error = Validator.validateStarRating(value: value, maxStars: maxStars) {
                throw error
            }
        case .nps(let value):
            if let error = Validator.validateNpsRating(value: value) {
                throw error
            }
        }

        // Rate limit
        if let remaining = rateLimiter.check() {
            throw SeggWatError.rateLimited(secondsRemaining: remaining)
        }

        let context = RatingContextPayload(
            path: screenName,
            version: options.appVersion,
            submittedBy: userId
        )

        let payload = UnifiedRatingPayload(
            projectKey: projectKey,
            rating: rating,
            context: context
        )

        let response = try await apiClient.submitRating(payload)

        rateLimiter.recordSubmission()

        // Notify callback
        options.onSubmit?(.success(()))

        return response
    }

    // MARK: - Localization Helper

    func localizedString(_ key: String) -> String {
        Localizer.string(key, language: options.language)
    }

    func localizedString(_ key: String, _ args: CVarArg...) -> String {
        let format = Localizer.string(key, language: options.language)
        return String(format: format, arguments: args)
    }
}
