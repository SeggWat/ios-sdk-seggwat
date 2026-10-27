import Foundation

/// Handles HTTP communication with the SeggWat API.
final class APIClient: Sendable {
    private let baseURL: URL
    private let session: URLSession
    private let bundleID: String?

    init(baseURL: URL, session: URLSession = .shared) {
        self.baseURL = baseURL
        self.session = session
        self.bundleID = Bundle.main.bundleIdentifier
    }

    /// Submit feedback as JSON (no screenshot).
    func submitFeedback(_ payload: FeedbackPayload) async throws -> Void {
        let url = baseURL.appendingPathComponent("api/v1/feedback/submit")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        applyPlatformHeaders(&request)

        let encoder = JSONEncoder()
        request.httpBody = try encoder.encode(payload)

        let (data, response) = try await performRequest(request)
        try validateResponse(response, data: data)
    }

    /// Submit feedback with a screenshot as multipart/form-data.
    func submitFeedbackWithScreenshot(_ payload: FeedbackPayload, screenshotData: Data) async throws -> Void {
        let url = baseURL.appendingPathComponent("api/v1/feedback/submit-with-screenshot")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        applyPlatformHeaders(&request)

        let encoder = JSONEncoder()
        let jsonData = try encoder.encode(payload)

        var multipart = MultipartFormData()
        multipart.addField(name: "data", value: jsonData)
        multipart.addFile(name: "screenshot", filename: "screenshot.jpg", contentType: "image/jpeg", data: screenshotData)

        request.setValue(multipart.contentType, forHTTPHeaderField: "Content-Type")
        request.httpBody = multipart.encode()

        let (data, response) = try await performRequest(request)
        try validateResponse(response, data: data)
    }

    /// Submit a rating.
    func submitRating(_ payload: UnifiedRatingPayload) async throws -> RatingCreatedResponse {
        let url = baseURL.appendingPathComponent("api/v1/ratings")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        applyPlatformHeaders(&request)

        let encoder = JSONEncoder()
        request.httpBody = try encoder.encode(payload)

        let (data, response) = try await performRequest(request)
        try validateResponse(response, data: data)

        let decoder = JSONDecoder()
        return try decoder.decode(RatingCreatedResponse.self, from: data)
    }

    // MARK: - Chat

    /// Load the end-user's conversation. Marks team replies read.
    func chatHistory(projectKey: String, token: String) async throws -> [ChatMessage] {
        let request = chatRequest("api/v1/chat/history", projectKey: projectKey, token: token)
        let (data, response) = try await performRequest(request)
        try validateResponse(response, data: data)
        return try JSONDecoder().decode(ChatHistoryResponse.self, from: data).messages
    }

    /// Send an end-user message. Returns the server-assigned message id.
    func sendChatMessage(_ payload: SendChatPayload) async throws -> String {
        let url = baseURL.appendingPathComponent("api/v1/chat/messages")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        applyPlatformHeaders(&request)
        request.httpBody = try JSONEncoder().encode(payload)

        let (data, response) = try await performRequest(request)
        try validateResponse(response, data: data)
        return try JSONDecoder().decode(SendChatResponse.self, from: data).messageId
    }

    /// Count unread team replies. Passive: marks nothing read.
    func chatUnread(projectKey: String, token: String) async throws -> Int {
        let request = chatRequest("api/v1/chat/unread", projectKey: projectKey, token: token)
        let (data, response) = try await performRequest(request)
        try validateResponse(response, data: data)
        return try JSONDecoder().decode(ChatUnreadResponse.self, from: data).unread
    }

    /// Open the SSE stream of live team replies.
    func chatStream(projectKey: String, token: String) async throws -> URLSession.AsyncBytes {
        var request = chatRequest("api/v1/chat/stream", projectKey: projectKey, token: token)
        request.setValue("text/event-stream", forHTTPHeaderField: "Accept")
        request.timeoutInterval = .infinity
        let (bytes, response) = try await session.bytes(for: request)
        try validateResponse(response, data: Data())
        return bytes
    }

    /// Fetch a single-use App Attest challenge.
    func attestChallenge(projectKey: String) async throws -> String {
        var request = URLRequest(url: baseURL.appendingPathComponent("api/v1/chat/attest/challenge"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        applyPlatformHeaders(&request)
        request.httpBody = try JSONEncoder().encode(["project_key": projectKey])

        let (data, response) = try await performRequest(request)
        try validateResponse(response, data: data)
        return try JSONDecoder().decode(AttestChallengeResponse.self, from: data).challenge
    }

    /// Submit an App Attest attestation for an anonymous identity.
    func submitAttestation(_ payload: AttestPayload) async throws {
        var request = URLRequest(url: baseURL.appendingPathComponent("api/v1/chat/attest"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        applyPlatformHeaders(&request)
        request.httpBody = try JSONEncoder().encode(payload)

        let (data, response) = try await performRequest(request)
        try validateResponse(response, data: data)
    }

    /// Register this device for push notifications of team replies.
    func registerPush(_ payload: PushTokenPayload) async throws {
        try await postNoContent("api/v1/chat/push/register", payload)
    }

    /// Stop push notifications on this device.
    func unregisterPush(_ payload: PushUnregisterPayload) async throws {
        try await postNoContent("api/v1/chat/push/unregister", payload)
    }

    private func postNoContent(_ path: String, _ body: some Encodable) async throws {
        var request = URLRequest(url: baseURL.appendingPathComponent(path))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        applyPlatformHeaders(&request)
        request.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await performRequest(request)
        try validateResponse(response, data: data)
    }

    private func chatRequest(_ path: String, projectKey: String, token: String) -> URLRequest {
        var components = URLComponents(url: baseURL.appendingPathComponent(path), resolvingAgainstBaseURL: false)!
        components.queryItems = [
            URLQueryItem(name: "project_key", value: projectKey),
            URLQueryItem(name: "token", value: token),
        ]
        var request = URLRequest(url: components.url!)
        applyPlatformHeaders(&request)
        return request
    }

    // MARK: - Private

    private func applyPlatformHeaders(_ request: inout URLRequest) {
        request.setValue("iOS", forHTTPHeaderField: "X-SeggWat-Platform")
        if let bundleID {
            request.setValue(bundleID, forHTTPHeaderField: "X-SeggWat-BundleID")
        }
    }

    private func performRequest(_ request: URLRequest) async throws -> (Data, URLResponse) {
        do {
            return try await session.data(for: request)
        } catch {
            throw SeggWatError.networkError(error.localizedDescription)
        }
    }

    private func validateResponse(_ response: URLResponse, data: Data) throws {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw SeggWatError.networkError("Invalid response")
        }

        let statusCode = httpResponse.statusCode
        guard (200...299).contains(statusCode) else {
            let message = String(data: data, encoding: .utf8)
            throw SeggWatError.fromHTTPStatus(statusCode, message: message)
        }
    }
}
