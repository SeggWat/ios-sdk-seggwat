import Foundation

/// Feedback submission payload matching the server's expected JSON format.
/// Mirrors `POST /api/v1/feedback/submit`.
struct FeedbackPayload: Codable, Equatable {
    let projectKey: String
    let message: String
    let path: String
    let source: String
    let version: String?
    let submittedBy: String?

    enum CodingKeys: String, CodingKey {
        case projectKey = "project_key"
        case message
        case path
        case source
        case version
        case submittedBy = "submitted_by"
    }

    init(
        projectKey: String,
        message: String,
        screenName: String? = nil,
        version: String? = nil,
        userId: String? = nil
    ) {
        self.projectKey = projectKey
        self.message = message
        // The server requires a non-empty `path`. Native screens have no URL, so
        // fall back to "/" when no screen name is supplied.
        self.path = screenName ?? "/"
        self.source = "Widget"
        self.version = version
        self.submittedBy = userId
    }
}
