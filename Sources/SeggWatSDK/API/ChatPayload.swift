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
    /// The message this one replies to, if any.
    public let replyTo: ChatReplyTo?

    enum CodingKeys: String, CodingKey {
        case id, sender, body
        case createdAt = "created_at"
        case replyTo = "reply_to"
    }

    init(id: String, sender: Sender, body: String, createdAt: String, replyTo: ChatReplyTo? = nil) {
        self.id = id
        self.sender = sender
        self.body = body
        self.createdAt = createdAt
        self.replyTo = replyTo
    }

    /// `createdAt` parsed, with or without fractional seconds.
    var createdDate: Date? {
        Self.fractionalFormatter.date(from: createdAt) ?? Self.formatter.date(from: createdAt)
    }

    private static let formatter = ISO8601DateFormatter()
    private static let fractionalFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()
}

/// The quoted message a chat message replies to.
public struct ChatReplyTo: Decodable, Equatable, Sendable {
    public let messageId: String
    public let sender: ChatMessage.Sender
    /// A one-line preview of the quoted message.
    public let snippet: String

    enum CodingKeys: String, CodingKey {
        case messageId = "message_id"
        case sender, snippet
    }

    init(messageId: String, sender: ChatMessage.Sender, snippet: String) {
        self.messageId = messageId
        self.sender = sender
        self.snippet = snippet
    }

    /// Quote `message`: its body collapsed to one line, cut at 140 characters.
    init(quoting message: ChatMessage) {
        let line = message.body.split(whereSeparator: \.isWhitespace).joined(separator: " ")
        self.init(
            messageId: message.id,
            sender: message.sender,
            snippet: line.count > 140 ? String(line.prefix(140)) + "…" : line
        )
    }
}

/// The server's limit on a message body, in Unicode scalars (Rust `chars()`).
enum ChatBody {
    static let maxLength = 5000

    static func length(_ body: String) -> Int {
        body.trimmingCharacters(in: .whitespacesAndNewlines).unicodeScalars.count
    }
}

struct ChatHistoryResponse: Decodable {
    let messages: [ChatMessage]
}

struct SendChatPayload: Encodable {
    let projectKey: String
    let token: String
    let body: String
    var replyToId: String? = nil
    var context: ChatClientContext? = nil

    enum CodingKeys: String, CodingKey {
        case projectKey = "project_key"
        case token, body
        case replyToId = "reply_to_id"
        case context
    }
}

/// The app and device a chat message comes from, shown to the team in the
/// SeggWat inbox so they don't have to ask which version the user is on.
struct ChatClientContext: Encodable, Equatable {
    var platform = "ios"
    var appVersion: String?
    var build: String?
    var osVersion: String?
    var deviceModel: String?
    var locale: String?

    enum CodingKeys: String, CodingKey {
        case platform
        case appVersion = "app_version"
        case build
        case osVersion = "os_version"
        case deviceModel = "device_model"
        case locale
    }

    /// The running app and device. `appVersion` is the configured version,
    /// which defaults to the bundle's.
    static func current(appVersion: String?) -> ChatClientContext {
        let os = ProcessInfo.processInfo.operatingSystemVersion
        let osVersion = os.patchVersion > 0
            ? "\(os.majorVersion).\(os.minorVersion).\(os.patchVersion)"
            : "\(os.majorVersion).\(os.minorVersion)"
        return ChatClientContext(
            appVersion: appVersion,
            build: Bundle.main.infoDictionary?["CFBundleVersion"] as? String,
            osVersion: osVersion,
            deviceModel: deviceModel(),
            locale: Locale.current.identifier
        )
    }

    /// Hardware identifier such as `iPhone16,2`; the simulated device's on a simulator.
    private static func deviceModel() -> String? {
        if let simulated = ProcessInfo.processInfo.environment["SIMULATOR_MODEL_IDENTIFIER"] {
            return simulated
        }
        var info = utsname()
        uname(&info)
        let model = withUnsafeBytes(of: &info.machine) { buffer in
            String(decoding: buffer.prefix(while: { $0 != 0 }), as: UTF8.self)
        }
        return model.isEmpty ? nil : model
    }
}

struct SendChatResponse: Decodable {
    let messageId: String

    enum CodingKeys: String, CodingKey {
        case messageId = "message_id"
    }
}

struct ChatErrorResponse: Decodable {
    let error: String
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

struct PushTokenPayload: Encodable {
    let projectKey: String
    let token: String
    let deviceToken: String
    let environment: String

    enum CodingKeys: String, CodingKey {
        case projectKey = "project_key"
        case token
        case deviceToken = "device_token"
        case environment
    }
}

/// Removes a device from push. The device token alone authorizes it, so a
/// sign-out still goes through after the chat token expired.
struct PushUnregisterPayload: Encodable {
    let projectKey: String
    let deviceToken: String

    enum CodingKeys: String, CodingKey {
        case projectKey = "project_key"
        case deviceToken = "device_token"
    }
}
