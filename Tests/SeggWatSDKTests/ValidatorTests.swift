import XCTest
@testable import SeggWatSDK

final class ValidatorTests: XCTestCase {

    // MARK: - Project Key

    func testValidUUID() {
        XCTAssertNil(Validator.validateProjectKey("550e8400-e29b-41d4-a716-446655440000"))
    }

    func testUppercaseUUID() {
        XCTAssertNil(Validator.validateProjectKey("550E8400-E29B-41D4-A716-446655440000"))
    }

    func testInvalidProjectKey_notUUID() {
        let result = Validator.validateProjectKey("not-a-uuid")
        XCTAssertEqual(result, .invalidProjectKey)
    }

    func testInvalidProjectKey_empty() {
        XCTAssertEqual(Validator.validateProjectKey(""), .invalidProjectKey)
    }

    func testInvalidProjectKey_missingDashes() {
        XCTAssertEqual(Validator.validateProjectKey("550e8400e29b41d4a716446655440000"), .invalidProjectKey)
    }

    // MARK: - Message

    func testValidMessage() {
        XCTAssertNil(Validator.validateMessage("Hello world"))
    }

    func testEmptyMessage() {
        XCTAssertEqual(Validator.validateMessage(""), .validationFailed("Message cannot be empty."))
    }

    func testWhitespaceOnlyMessage() {
        XCTAssertEqual(Validator.validateMessage("   "), .validationFailed("Message cannot be empty."))
    }

    func testTooShortMessage() {
        XCTAssertEqual(Validator.validateMessage("ab"), .validationFailed("Message must be at least 3 characters."))
    }

    func testExactlyMinLength() {
        XCTAssertNil(Validator.validateMessage("abc"))
    }

    func testTooLongMessage() {
        let long = String(repeating: "a", count: 1001)
        XCTAssertNotNil(Validator.validateMessage(long))
    }

    func testExactlyMaxLength() {
        let exact = String(repeating: "a", count: 1000)
        XCTAssertNil(Validator.validateMessage(exact))
    }

    func testMessageWithLeadingTrailingWhitespace() {
        XCTAssertNil(Validator.validateMessage("  hello  "))
    }

    // MARK: - Version

    func testValidVersion() {
        XCTAssertNil(Validator.validateVersion("1.2.3"))
    }

    func testValidVersionWithDash() {
        XCTAssertNil(Validator.validateVersion("v2.0.0-beta"))
    }

    func testValidVersionWithUnderscore() {
        XCTAssertNil(Validator.validateVersion("1_0_0"))
    }

    func testNilVersion() {
        XCTAssertNil(Validator.validateVersion(nil))
    }

    func testEmptyVersion() {
        XCTAssertNil(Validator.validateVersion(""))
    }

    func testVersionTooLong() {
        let long = String(repeating: "1", count: 51)
        XCTAssertNotNil(Validator.validateVersion(long))
    }

    func testVersionWithSpaces() {
        XCTAssertNotNil(Validator.validateVersion("1.0 beta"))
    }

    // MARK: - User ID

    func testValidUserId() {
        XCTAssertNil(Validator.validateUserId("user-123"))
    }

    func testValidUserIdWithUnderscore() {
        XCTAssertNil(Validator.validateUserId("user_abc_123"))
    }

    func testNilUserId() {
        XCTAssertNil(Validator.validateUserId(nil))
    }

    func testEmptyUserId() {
        XCTAssertNil(Validator.validateUserId(""))
    }

    func testUserIdTooLong() {
        let long = String(repeating: "a", count: 256)
        XCTAssertNotNil(Validator.validateUserId(long))
    }

    func testUserIdWithSpaces() {
        XCTAssertNotNil(Validator.validateUserId("user 123"))
    }

    func testUserIdWithSpecialChars() {
        XCTAssertNotNil(Validator.validateUserId("user@123"))
    }

    // MARK: - Email

    func testValidEmail() {
        XCTAssertNil(Validator.validateEmail("jane@example.com"))
    }

    func testValidEmailWithDottedLocalPart() {
        XCTAssertNil(Validator.validateEmail("hauke.jung@outlook.de"))
    }

    func testNilEmail() {
        XCTAssertNil(Validator.validateEmail(nil))
    }

    func testEmptyEmail() {
        XCTAssertNil(Validator.validateEmail(""))
    }

    func testEmailMissingAt() {
        XCTAssertNotNil(Validator.validateEmail("janeexample.com"))
    }

    func testEmailMissingDomainDot() {
        XCTAssertNotNil(Validator.validateEmail("jane@example"))
    }

    func testEmailWithSpaces() {
        XCTAssertNotNil(Validator.validateEmail("jane doe@example.com"))
    }

    func testEmailTooLong() {
        let long = String(repeating: "a", count: 320) + "@example.com"
        XCTAssertNotNil(Validator.validateEmail(long))
    }

    // MARK: - Screenshot Size

    func testScreenshotWithinLimit() {
        let data = Data(repeating: 0, count: 1024 * 1024) // 1MB
        XCTAssertNil(Validator.validateScreenshotSize(data, maxSizeMB: 5))
    }

    func testScreenshotOverLimit() {
        let data = Data(repeating: 0, count: 6 * 1024 * 1024) // 6MB
        XCTAssertNotNil(Validator.validateScreenshotSize(data, maxSizeMB: 5))
    }

    func testScreenshotExactlyAtLimit() {
        let data = Data(repeating: 0, count: 5 * 1024 * 1024) // 5MB
        XCTAssertNil(Validator.validateScreenshotSize(data, maxSizeMB: 5))
    }

    // MARK: - Star Rating

    func testValidStarRating() {
        XCTAssertNil(Validator.validateStarRating(value: 3, maxStars: 5))
    }

    func testStarRatingMinValue() {
        XCTAssertNil(Validator.validateStarRating(value: 1, maxStars: 5))
    }

    func testStarRatingMaxValue() {
        XCTAssertNil(Validator.validateStarRating(value: 5, maxStars: 5))
    }

    func testStarRatingZeroValue() {
        XCTAssertEqual(
            Validator.validateStarRating(value: 0, maxStars: 5),
            .invalidRatingValue("Star rating must be between 1 and 5.")
        )
    }

    func testStarRatingExceedsMaxStars() {
        XCTAssertEqual(
            Validator.validateStarRating(value: 6, maxStars: 5),
            .invalidRatingValue("Star rating must be between 1 and 5.")
        )
    }

    func testStarRatingCustomMaxStars() {
        XCTAssertNil(Validator.validateStarRating(value: 8, maxStars: 10))
    }

    func testStarRatingMaxStarsZero() {
        XCTAssertEqual(
            Validator.validateStarRating(value: 1, maxStars: 0),
            .invalidRatingValue("maxStars must be between 1 and 10.")
        )
    }

    func testStarRatingMaxStarsExceedsLimit() {
        XCTAssertEqual(
            Validator.validateStarRating(value: 1, maxStars: 11),
            .invalidRatingValue("maxStars must be between 1 and 10.")
        )
    }

    // MARK: - NPS Rating

    func testValidNpsRating() {
        XCTAssertNil(Validator.validateNpsRating(value: 7))
    }

    func testNpsRatingZero() {
        XCTAssertNil(Validator.validateNpsRating(value: 0))
    }

    func testNpsRatingTen() {
        XCTAssertNil(Validator.validateNpsRating(value: 10))
    }

    func testNpsRatingExceedsMax() {
        XCTAssertEqual(
            Validator.validateNpsRating(value: 11),
            .invalidRatingValue("NPS rating must be between 0 and 10.")
        )
    }

    func testNpsRatingHighValue() {
        XCTAssertEqual(
            Validator.validateNpsRating(value: 255),
            .invalidRatingValue("NPS rating must be between 0 and 10.")
        )
    }
}
