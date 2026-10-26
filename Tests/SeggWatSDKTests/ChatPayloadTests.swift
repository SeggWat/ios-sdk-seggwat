import XCTest
@testable import SeggWatSDK

final class ChatPayloadTests: XCTestCase {

    func testSendPayloadEncoding() throws {
        let payload = SendChatPayload(projectKey: "key", token: "jwt", body: "Hi")
        let json = try JSONSerialization.jsonObject(with: JSONEncoder().encode(payload)) as! [String: Any]

        XCTAssertEqual(json["project_key"] as? String, "key")
        XCTAssertEqual(json["token"] as? String, "jwt")
        XCTAssertEqual(json["body"] as? String, "Hi")
    }

    func testHistoryDecodingIgnoresReplyTo() throws {
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
