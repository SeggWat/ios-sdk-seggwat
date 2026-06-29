import XCTest
@testable import SeggWatSDK

final class FeedbackPayloadTests: XCTestCase {

    func testJSONEncoding() throws {
        let payload = FeedbackPayload(
            projectKey: "550e8400-e29b-41d4-a716-446655440000",
            message: "Great app!",
            screenName: "/home",
            version: "1.0.0",
            userId: "user-123",
            userEmail: "jane@example.com"
        )

        let data = try JSONEncoder().encode(payload)
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]

        XCTAssertEqual(json["project_key"] as? String, "550e8400-e29b-41d4-a716-446655440000")
        XCTAssertEqual(json["message"] as? String, "Great app!")
        XCTAssertEqual(json["path"] as? String, "/home")
        XCTAssertEqual(json["source"] as? String, "Widget")
        XCTAssertEqual(json["version"] as? String, "1.0.0")
        XCTAssertEqual(json["submitted_by"] as? String, "user-123")
        XCTAssertEqual(json["submitted_by_email"] as? String, "jane@example.com")
    }

    func testJSONEncodingWithNils() throws {
        let payload = FeedbackPayload(
            projectKey: "550e8400-e29b-41d4-a716-446655440000",
            message: "Bug report"
        )

        let data = try JSONEncoder().encode(payload)
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]

        XCTAssertEqual(json["project_key"] as? String, "550e8400-e29b-41d4-a716-446655440000")
        XCTAssertEqual(json["message"] as? String, "Bug report")
        XCTAssertEqual(json["source"] as? String, "Widget")
        // The server requires a non-empty `path`; the SDK defaults it to "/".
        XCTAssertEqual(json["path"] as? String, "/")
        XCTAssertNil(json["version"])
        XCTAssertNil(json["submitted_by"])
        XCTAssertNil(json["submitted_by_email"])
    }

    func testEquality() {
        let a = FeedbackPayload(projectKey: "abc", message: "hello")
        let b = FeedbackPayload(projectKey: "abc", message: "hello")
        XCTAssertEqual(a, b)
    }

    func testInequality() {
        let a = FeedbackPayload(projectKey: "abc", message: "hello")
        let b = FeedbackPayload(projectKey: "abc", message: "world")
        XCTAssertNotEqual(a, b)
    }

    func testSnakeCaseKeys() throws {
        let payload = FeedbackPayload(
            projectKey: "key",
            message: "msg",
            userId: "uid"
        )

        let data = try JSONEncoder().encode(payload)
        let jsonString = String(data: data, encoding: .utf8)!

        XCTAssertTrue(jsonString.contains("\"project_key\""))
        XCTAssertTrue(jsonString.contains("\"submitted_by\""))
        XCTAssertFalse(jsonString.contains("\"projectKey\""))
        XCTAssertFalse(jsonString.contains("\"submittedBy\""))
    }
}
