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
