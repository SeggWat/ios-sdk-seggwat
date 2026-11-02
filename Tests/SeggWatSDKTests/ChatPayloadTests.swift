import XCTest
@testable import SeggWatSDK

final class ChatPayloadTests: XCTestCase {

    func testSendPayloadEncoding() throws {
        let payload = SendChatPayload(projectKey: "key", token: "jwt", body: "Hi")
        let json = try JSONSerialization.jsonObject(with: JSONEncoder().encode(payload)) as! [String: Any]

        XCTAssertEqual(json["project_key"] as? String, "key")
        XCTAssertEqual(json["token"] as? String, "jwt")
        XCTAssertEqual(json["body"] as? String, "Hi")
        XCTAssertNil(json["reply_to_id"])
    }

    func testSendPayloadEncodesReplyToId() throws {
        let payload = SendChatPayload(projectKey: "key", token: "jwt", body: "Hi", replyToId: "m1")
        let json = try JSONSerialization.jsonObject(with: JSONEncoder().encode(payload)) as! [String: Any]
        XCTAssertEqual(json["reply_to_id"] as? String, "m1")
    }

    func testHistoryDecodingReadsReplyTo() throws {
        let json = """
        {"conversation_id":"c1","messages":[
          {"id":"m1","sender":"you","body":"Hello","created_at":"2026-10-26T10:00:00+00:00"},
          {"id":"m2","sender":"team","body":"Hi!","created_at":"2026-10-26T10:01:00+00:00",
           "reply_to":{"message_id":"m1","sender":"you","snippet":"Hello"}}
        ]}
        """
        let response = try JSONDecoder().decode(ChatHistoryResponse.self, from: Data(json.utf8))

        XCTAssertEqual(response.messages.map(\.id), ["m1", "m2"])
        XCTAssertEqual(response.messages[0].sender, .you)
        XCTAssertEqual(response.messages[1].sender, .team)
        XCTAssertNil(response.messages[0].replyTo)
        XCTAssertEqual(response.messages[1].replyTo, ChatReplyTo(messageId: "m1", sender: .you, snippet: "Hello"))
    }

    func testStreamParserDecodesReplyTo() {
        var parser = ChatStreamParser()
        let event = parser.consume(#"data: {"id":"m5","sender":"team","body":"Yes","created_at":"t","reply_to":{"message_id":"m1","sender":"you","snippet":"Hello"}}"#)
        let quote = ChatReplyTo(messageId: "m1", sender: .you, snippet: "Hello")
        XCTAssertEqual(event, .message(ChatMessage(id: "m5", sender: .team, body: "Yes", createdAt: "t", replyTo: quote)))
    }

    func testCreatedDateParsesWithAndWithoutFractionalSeconds() {
        let plain = ChatMessage(id: "a", sender: .you, body: "", createdAt: "2026-10-26T10:00:00+00:00")
        let fractional = ChatMessage(id: "b", sender: .you, body: "", createdAt: "2026-10-26T10:00:00.123456789+00:00")
        XCTAssertEqual(plain.createdDate, Date(timeIntervalSince1970: 1_793_008_800))
        XCTAssertEqual(fractional.createdDate!.timeIntervalSince1970, 1_793_008_800.123, accuracy: 0.001)
        XCTAssertNil(ChatMessage(id: "c", sender: .you, body: "", createdAt: "t").createdDate)
    }

    func testQuoteCollapsesAndTruncatesBody() {
        let short = ChatReplyTo(quoting: ChatMessage(id: "m1", sender: .team, body: "  Hi\n\nthere  ", createdAt: "t"))
        XCTAssertEqual(short, ChatReplyTo(messageId: "m1", sender: .team, snippet: "Hi there"))
        let long = ChatReplyTo(quoting: ChatMessage(id: "m2", sender: .you, body: String(repeating: "a", count: 200), createdAt: "t"))
        XCTAssertEqual(long.snippet, String(repeating: "a", count: 140) + "…")
    }

    func testBodyLengthCountsUnicodeScalarsOfTrimmedText() {
        XCTAssertEqual(ChatBody.length("  hi \n"), 2)
        // One scalar each, though two UTF-16 units.
        XCTAssertEqual(ChatBody.length("😀😀"), 2)
        XCTAssertEqual(ChatBody.length(String(repeating: "x", count: 5001)), 5001)
    }

    func testRejectionCarriesServerMessage() {
        let data = Data(#"{"error":"You're sending messages too quickly. Please wait a moment."}"#.utf8)
        XCTAssertEqual(
            SeggWatError.chatRejection(statusCode: 429, data: data),
            .chatMessageRejected("You're sending messages too quickly. Please wait a moment.")
        )
        XCTAssertEqual(SeggWatError.chatRejection(statusCode: 400, data: Data(#"{"error":"Too long"}"#.utf8)), .chatMessageRejected("Too long"))
        XCTAssertNil(SeggWatError.chatRejection(statusCode: 500, data: data))
        XCTAssertNil(SeggWatError.chatRejection(statusCode: 400, data: Data("oops".utf8)))
    }

    func testStreamParserDeliversTeamMessage() {
        var parser = ChatStreamParser()
        let event = parser.consume(#"data: {"id":"m3","sender":"team","body":"Fixed","created_at":"2026-10-26T10:02:00+00:00"}"#)

        XCTAssertEqual(event, .message(ChatMessage(id: "m3", sender: .team, body: "Fixed", createdAt: "2026-10-26T10:02:00+00:00")))
    }

    func testStreamParserResyncThenMessage() {
        var parser = ChatStreamParser()
        XCTAssertNil(parser.consume("event: resync"))
        XCTAssertEqual(parser.consume("data: 1"), .resync)
        // The event name must not leak into the next event.
        let next = parser.consume(#"data: {"id":"m4","sender":"team","body":"x","created_at":"t"}"#)
        XCTAssertEqual(next, .message(ChatMessage(id: "m4", sender: .team, body: "x", createdAt: "t")))
    }

    func testStreamParserIgnoresKeepAlive() {
        var parser = ChatStreamParser()
        XCTAssertNil(parser.consume(": ping"))
        XCTAssertNil(parser.consume(""))
    }

    func testUnauthorizedMapsToInvalidToken() {
        XCTAssertEqual(SeggWatError.fromHTTPStatus(401), .chatTokenInvalid)
    }
}

final class ChatThreadTests: XCTestCase {

    private func message(_ id: String, _ sender: ChatMessage.Sender = .you) -> ChatMessage {
        ChatMessage(id: id, sender: sender, body: "body \(id)", createdAt: "t")
    }

    func testPendingSendSwapsToServerId() {
        var thread = ChatThread()
        let localId = thread.addPending(body: "Hi", replyTo: nil)
        XCTAssertEqual(thread.rows.map(\.state), [.pending])

        thread.markSent(localId, as: message("m1"))
        XCTAssertEqual(thread.rows.map(\.id), ["m1"])
        XCTAssertEqual(thread.rows.map(\.state), [.sent])
    }

    func testSendConfirmedAfterHistoryHasItKeepsOneRow() {
        var thread = ChatThread()
        let localId = thread.addPending(body: "Hi", replyTo: nil)
        thread.merge(history: [message("m1")])
        XCTAssertEqual(thread.rows.count, 2)

        thread.markSent(localId, as: message("m1"))
        XCTAssertEqual(thread.rows.map(\.id), ["m1"])
    }

    func testFailedSendKeepsReasonAndReplyContext() {
        var thread = ChatThread()
        let quote = ChatReplyTo(messageId: "m0", sender: .team, snippet: "Hello")
        let localId = thread.addPending(body: "Hi", replyTo: quote)
        thread.markFailed(localId, reason: "Too fast")

        XCTAssertEqual(thread.rows[0].state, .failed)
        XCTAssertEqual(thread.rows[0].failureReason, "Too fast")
        XCTAssertEqual(thread.rows[0].message.replyTo, quote)

        thread.remove(localId)
        XCTAssertTrue(thread.rows.isEmpty)
    }

    func testMergeKeepsStreamedAndPendingRowsAndDedupes() {
        var thread = ChatThread()
        thread.receive(message("m2", .team))
        thread.receive(message("m2", .team))
        let localId = thread.addPending(body: "Hi", replyTo: nil)
        thread.merge(history: [message("m1"), message("m2", .team)])
        XCTAssertEqual(thread.rows.map(\.id), ["m1", "m2", localId])
    }
}

final class PushTests: XCTestCase {

    func testPushPayloadEncoding() throws {
        let payload = PushRegistration(deviceToken: "abcd", chatToken: "dev_x").payload(projectKey: "key")
        let json = try JSONSerialization.jsonObject(with: JSONEncoder().encode(payload)) as! [String: Any]

        XCTAssertEqual(json["project_key"] as? String, "key")
        XCTAssertEqual(json["token"] as? String, "dev_x")
        XCTAssertEqual(json["device_token"] as? String, "abcd")
        // The test host has no provisioning profile.
        XCTAssertEqual(json["environment"] as? String, "production")
    }

    func testUnregisterSendsOnlyTheDeviceToken() throws {
        let payload = PushUnregisterPayload(projectKey: "key", deviceToken: "abcd")
        let json = try JSONSerialization.jsonObject(with: JSONEncoder().encode(payload)) as! [String: Any]
        XCTAssertEqual(json as? [String: String], ["project_key": "key", "device_token": "abcd"])
    }

    func testReadsApsEnvironmentFromProvisioningProfile() {
        func profile(_ environment: String) -> Data {
            Data(("\u{30}\u{82}binary-cms-header<?xml version=\"1.0\" encoding=\"UTF-8\"?>"
                + "<plist version=\"1.0\"><dict><key>Entitlements</key><dict>"
                + "<key>aps-environment</key><string>\(environment)</string>"
                + "</dict></dict></plist>\u{a0}signature").utf8)
        }
        XCTAssertEqual(SeggWat.apsEnvironment(inProvisioningProfile: profile("development")), "development")
        XCTAssertEqual(SeggWat.apsEnvironment(inProvisioningProfile: profile("production")), "production")
        XCTAssertNil(SeggWat.apsEnvironment(inProvisioningProfile: Data("garbage".utf8)))
    }

    func testChatSubjectIgnoresTokenRefresh() {
        // {"sub":"user-1","iat":1} and {"sub":"user-1","iat":2}
        let first = "eyJhbGciOiJIUzI1NiJ9.eyJzdWIiOiJ1c2VyLTEiLCJpYXQiOjF9.sig1"
        let refreshed = "eyJhbGciOiJIUzI1NiJ9.eyJzdWIiOiJ1c2VyLTEiLCJpYXQiOjJ9.sig2"
        XCTAssertEqual(SeggWat.chatSubject(first), "user-1")
        XCTAssertEqual(SeggWat.chatSubject(first), SeggWat.chatSubject(refreshed))
        XCTAssertEqual(SeggWat.chatSubject("dev_abc"), "dev_abc")
    }

    @MainActor
    func testRecognizesSeggWatNotifications() {
        XCTAssertTrue(SeggWat.isSeggWatNotification(["seggwat": ["type": "chat_reply"], "aps": [:]]))
        XCTAssertFalse(SeggWat.isSeggWatNotification(["aps": [:]]))
        XCTAssertFalse(SeggWat.handleNotification(["aps": [:]]))
    }
}
