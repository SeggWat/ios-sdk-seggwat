import XCTest
@testable import SeggWatSDK

final class RatingPayloadTests: XCTestCase {

    private let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return encoder
    }()

    // MARK: - Helpful

    func testHelpfulTrue() throws {
        let rating = RatingValue.helpful(true)
        let json = try jsonDict(rating)
        XCTAssertEqual(json["type"] as? String, "helpful")
        XCTAssertEqual(json["value"] as? Bool, true)
    }

    func testHelpfulFalse() throws {
        let rating = RatingValue.helpful(false)
        let json = try jsonDict(rating)
        XCTAssertEqual(json["type"] as? String, "helpful")
        XCTAssertEqual(json["value"] as? Bool, false)
    }

    // MARK: - Star

    func testStarDefaultMaxStars() throws {
        let rating = RatingValue.star(value: 4)
        let json = try jsonDict(rating)
        XCTAssertEqual(json["type"] as? String, "star")
        XCTAssertEqual(json["value"] as? UInt8, 4)
        XCTAssertEqual(json["max_stars"] as? UInt8, 5)
    }

    func testStarCustomMaxStars() throws {
        let rating = RatingValue.star(value: 8, maxStars: 10)
        let json = try jsonDict(rating)
        XCTAssertEqual(json["type"] as? String, "star")
        XCTAssertEqual(json["value"] as? UInt8, 8)
        XCTAssertEqual(json["max_stars"] as? UInt8, 10)
    }

    // MARK: - NPS

    func testNps() throws {
        let rating = RatingValue.nps(9)
        let json = try jsonDict(rating)
        XCTAssertEqual(json["type"] as? String, "nps")
        XCTAssertEqual(json["value"] as? UInt8, 9)
        XCTAssertNil(json["max_stars"])
    }

    func testNpsZero() throws {
        let rating = RatingValue.nps(0)
        let json = try jsonDict(rating)
        XCTAssertEqual(json["type"] as? String, "nps")
        XCTAssertEqual(json["value"] as? UInt8, 0)
    }

    // MARK: - Round-trip

    func testHelpfulRoundTrip() throws {
        let original = RatingValue.helpful(true)
        let data = try encoder.encode(original)
        let decoded = try JSONDecoder().decode(RatingValue.self, from: data)
        XCTAssertEqual(original, decoded)
    }

    func testStarRoundTrip() throws {
        let original = RatingValue.star(value: 3, maxStars: 7)
        let data = try encoder.encode(original)
        let decoded = try JSONDecoder().decode(RatingValue.self, from: data)
        XCTAssertEqual(original, decoded)
    }

    func testNpsRoundTrip() throws {
        let original = RatingValue.nps(6)
        let data = try encoder.encode(original)
        let decoded = try JSONDecoder().decode(RatingValue.self, from: data)
        XCTAssertEqual(original, decoded)
    }

    // MARK: - UnifiedRatingPayload

    func testUnifiedPayloadEncoding() throws {
        let payload = UnifiedRatingPayload(
            projectKey: "550e8400-e29b-41d4-a716-446655440000",
            rating: .star(value: 5),
            context: RatingContextPayload(
                path: "/settings",
                version: "1.2.0",
                submittedBy: "user-123"
            )
        )

        let data = try encoder.encode(payload)
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]

        XCTAssertEqual(json["project_key"] as? String, "550e8400-e29b-41d4-a716-446655440000")

        let ratingDict = json["rating"] as? [String: Any]
        XCTAssertEqual(ratingDict?["type"] as? String, "star")
        XCTAssertEqual(ratingDict?["value"] as? UInt8, 5)

        let contextDict = json["context"] as? [String: Any]
        XCTAssertEqual(contextDict?["path"] as? String, "/settings")
        XCTAssertEqual(contextDict?["version"] as? String, "1.2.0")
        XCTAssertEqual(contextDict?["submitted_by"] as? String, "user-123")
    }

    func testUnifiedPayloadWithNilContext() throws {
        let payload = UnifiedRatingPayload(
            projectKey: "550e8400-e29b-41d4-a716-446655440000",
            rating: .helpful(false),
            context: nil
        )

        let data = try encoder.encode(payload)
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]

        XCTAssertEqual(json["project_key"] as? String, "550e8400-e29b-41d4-a716-446655440000")
        XCTAssertNil(json["context"])
    }

    // MARK: - Helpers

    private func jsonDict(_ value: RatingValue) throws -> [String: Any] {
        let data = try encoder.encode(value)
        return try JSONSerialization.jsonObject(with: data) as! [String: Any]
    }
}
