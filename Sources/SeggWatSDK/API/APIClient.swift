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
