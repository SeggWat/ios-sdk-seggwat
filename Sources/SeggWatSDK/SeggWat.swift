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

    /// Whether the support chat sheet is currently presented.
    @Published public var isChatPresented = false

    /// Unread support replies, refreshed by `refreshUnreadCount()`. Shown as a
    /// badge on the floating button.
    @Published public private(set) var unreadCount = 0

    /// Bumped whenever the chat identity changes, so views and requests of the
    /// previous user are dropped.
    @Published private(set) var chatIdentity = 0

    /// Whether chat is usable, i.e. an end-user token has been set.
    public var isChatAvailable: Bool { chatToken != nil }

    private(set) var projectKey: String = ""
    private(set) var options = SeggWatOptions()
    private(set) var userId: String?
    private(set) var userEmail: String?
    private(set) var chatToken: String?
    private var attestation: Task<Void, Error>?
    // Push notifications (see SeggWat+Push.swift).
    var pushEnabled = false
    var pushDeviceToken: String?
    /// The device token and chat identity last registered with the server.
    var registeredPush: PushRegistration?
    var pushSyncRunning = false
    var pushSyncNeeded = false
    /// A notification was tapped before the chat identity was set.
    var pendingChatOpen = false
    private(set) var apiClient: APIClient?
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

    /// Set the end-user token that enables the in-app support chat.
    ///
    /// Mint the token on **your backend** as an HS256 JWT signed with the
    /// project's end-user signing secret, with claims `sub` (your user id),
    /// `project_key`, `iat` and `exp`, plus optional `email` and `name` — see
    /// https://seggwat.com/docs/features/portal-authentication. Pass `nil` on
    /// sign-out.
    public static func setChatToken(_ token: String?) {
        let instance = shared
        // A refreshed token for the same user keeps the open chat.
        if token.map(chatSubject) != instance.chatToken.map(chatSubject) {
            instance.chatIdentity += 1
            instance.unreadCount = 0
            if token == nil {
                instance.isChatPresented = false
                instance.pendingChatOpen = false
            }
        }
        instance.chatToken = token
        if token != nil {
            Task { await instance.refreshUnreadCount() }
            if instance.pendingChatOpen {
                instance.pendingChatOpen = false
                instance.isChatPresented = true
            }
        }
        // Move push to the new identity, or stop it on sign-out.
        Task { await instance.syncPushRegistration() }
    }

    /// The user a chat token identifies: the JWT's `sub`, or the anonymous
    /// token itself.
    nonisolated static func chatSubject(_ token: String) -> String {
        let parts = token.split(separator: ".")
        guard parts.count == 3 else { return token }
        var base64 = parts[1].replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        base64 += String(repeating: "=", count: (4 - base64.count % 4) % 4)
        guard let data = Data(base64Encoded: base64),
              let claims = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let sub = claims["sub"] as? String else {
            return token
        }
        return sub
    }

    /// Enable the support chat for an anonymous user, for apps with no backend
    /// to mint end-user tokens. The SDK creates a random identity per install
    /// and keeps it in the Keychain. Requires "Anonymous chat in apps" to be
    /// on in the project's widget settings.
    ///
    /// The conversation belongs to this install: signing in later with
    /// `setChatToken(_:)` starts a separate conversation.
    public static func enableAnonymousChat() {
        setChatToken(DeviceToken.loadOrCreate())
    }

    /// Present the support chat sheet. Requires `setChatToken(_:)` or
    /// `enableAnonymousChat()`.
    public static func presentChat() {
        guard shared.isChatAvailable else { return }
        shared.isChatPresented = true
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
    /// With `SeggWatOptions.reviewPrompt` set, a high rating then requests an
    /// App Store review and a low one opens the feedback form.
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

        switch options.reviewPrompt?.action(for: rating) {
        case .requestReview: requestAppStoreReview()
        case .collectFeedback: isPresented = true
        case .noPrompt, nil: break
        }

        return response
    }

    // MARK: - Chat

    /// Refresh `unreadCount` from the server. Read-only: it does not mark
    /// replies read or count as the user being in the chat.
    public func refreshUnreadCount() async {
        let identity = chatIdentity
        if let count = try? await withChat({ api, token in
            try await api.chatUnread(projectKey: self.projectKey, token: token)
        }), identity == chatIdentity {
            unreadCount = count
        }
    }

    func chatHistory() async throws -> [ChatMessage] {
        let identity = chatIdentity
        let messages = try await withChat { api, token in
            try await api.chatHistory(projectKey: self.projectKey, token: token)
        }
        guard identity == chatIdentity else { throw CancellationError() }
        unreadCount = 0
        return messages
    }

    func sendChatMessage(_ body: String, replyTo: ChatReplyTo? = nil) async throws -> ChatMessage {
        let trimmed = body.trimmingCharacters(in: .whitespacesAndNewlines)
        let identity = chatIdentity
        let id = try await withChat { api, token in
            try await api.sendChatMessage(
                SendChatPayload(
                    projectKey: self.projectKey,
                    token: token,
                    body: trimmed,
                    replyToId: replyTo?.messageId
                )
            )
        }
        guard identity == chatIdentity else { throw CancellationError() }
        // Ask for notification permission once the user has something to wait for.
        Task { await requestPushPermissionIfNeeded() }
        return ChatMessage(
            id: id,
            sender: .you,
            body: trimmed,
            createdAt: ISO8601DateFormatter().string(from: Date()),
            replyTo: replyTo
        )
    }

    func chatStream() async throws -> URLSession.AsyncBytes {
        try await withChat { api, token in
            try await api.chatStream(projectKey: self.projectKey, token: token)
        }
    }

    /// Run a chat request. If the project requires App Attest and this
    /// anonymous identity isn't attested yet (428), attest once and retry.
    func withChat<T>(_ request: (APIClient, String) async throws -> T) async throws -> T {
        guard isConfigured, let apiClient else { throw SeggWatError.notConfigured }
        guard let chatToken else { throw SeggWatError.chatTokenMissing }
        do {
            return try await request(apiClient, chatToken)
        } catch SeggWatError.attestationRequired where chatToken.hasPrefix("dev_") {
            try await attestDevice(apiClient: apiClient, token: chatToken)
            return try await request(apiClient, chatToken)
        }
    }

    /// Attest this install's anonymous identity, sharing one attempt between
    /// concurrent requests (e.g. the unread poll and opening the chat).
    private func attestDevice(apiClient: APIClient, token: String) async throws {
        if let attestation {
            return try await attestation.value
        }
        let task = Task {
            try await AppAttest.attest(apiClient: apiClient, projectKey: projectKey, token: token)
        }
        attestation = task
        defer { attestation = nil }
        try await task.value
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
