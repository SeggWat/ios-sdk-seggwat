import Foundation

/// A message in the end-user's support conversation.
public struct ChatMessage: Decodable, Identifiable, Equatable, Sendable {
    public enum Sender: String, Decodable, Sendable {
        /// Sent by the end-user on this device.
        case you
        /// A reply from the project's support team.
        case team
    }

    public let id: String
    public let sender: Sender
    public let body: String
    /// RFC 3339 timestamp, as sent by the server.
    public let createdAt: String

    enum CodingKeys: String, CodingKey {
        case id, sender, body
        case createdAt = "created_at"
    }

    init(id: String, sender: Sender, body: String, createdAt: String) {
        self.id = id
        self.sender = sender
        self.body = body
        self.createdAt = createdAt
    }
}

struct ChatHistoryResponse: Decodable {
    let messages: [ChatMessage]
}

struct SendChatPayload: Encodable {
    let projectKey: String
    let token: String
    let body: String

    enum CodingKeys: String, CodingKey {
        case projectKey = "project_key"
        case token, body
    }
}

struct SendChatResponse: Decodable {
    let messageId: String

    enum CodingKeys: String, CodingKey {
        case messageId = "message_id"
    }
}

struct ChatUnreadResponse: Decodable {
    let unread: Int
}

/// One parsed line of the chat SSE stream.
enum ChatStreamEvent: Equatable {
    /// A team reply delivered live.
    case message(ChatMessage)
    /// The server dropped events; reload history.
    case resync
}

/// Parses the chat stream line by line. Team replies arrive as unnamed
/// `data:` events carrying a message JSON; a `resync` event asks the client to
/// reload history. Keep-alive comments are ignored. Every server event carries
/// exactly one `data:` line, so the event name resets there rather than at the
/// blank separator line, which `AsyncBytes.lines` never yields.
struct ChatStreamParser {
    private var eventName: String?

    mutating func consume(_ line: String) -> ChatStreamEvent? {
        if line.hasPrefix("event:") {
            eventName = line.dropFirst("event:".count).trimmingCharacters(in: .whitespaces)
            return nil
        }
        guard line.hasPrefix("data:") else { return nil }
        let data = line.dropFirst("data:".count).trimmingCharacters(in: .whitespaces)
        defer { eventName = nil }
        if eventName == "resync" {
            return .resync
        }
        guard let message = try? JSONDecoder().decode(ChatMessage.self, from: Data(data.utf8)) else {
            return nil
        }
        return .message(message)
    }
}
