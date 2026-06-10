import XCTest
@testable import SeggWatSDK

final class SeggWatTests: XCTestCase {

    func testErrorFromHTTPStatus400() {
        let error = SeggWatError.fromHTTPStatus(400)
        XCTAssertEqual(error, .serverValidationFailed)
    }

    func testErrorFromHTTPStatus403() {
        let error = SeggWatError.fromHTTPStatus(403)
        XCTAssertEqual(error, .originNotAllowed)
    }

    func testErrorFromHTTPStatus404() {
        let error = SeggWatError.fromHTTPStatus(404)
        XCTAssertEqual(error, .projectNotFound)
    }

    func testErrorFromHTTPStatus413() {
        let error = SeggWatError.fromHTTPStatus(413)
        XCTAssertEqual(error, .screenshotTooLarge)
    }

    func testErrorFromHTTPStatus415() {
        let error = SeggWatError.fromHTTPStatus(415)
        XCTAssertEqual(error, .unsupportedMediaType)
    }

    func testErrorFromHTTPStatus500() {
        let error = SeggWatError.fromHTTPStatus(500, message: "Internal error")
        XCTAssertEqual(error, .serverError(statusCode: 500, message: "Internal error"))
    }

    func testErrorEquality() {
        XCTAssertEqual(SeggWatError.notConfigured, SeggWatError.notConfigured)
        XCTAssertEqual(SeggWatError.invalidProjectKey, SeggWatError.invalidProjectKey)
        XCTAssertEqual(
            SeggWatError.validationFailed("msg"),
            SeggWatError.validationFailed("msg")
        )
        XCTAssertNotEqual(
            SeggWatError.validationFailed("a"),
            SeggWatError.validationFailed("b")
        )
        XCTAssertEqual(
            SeggWatError.rateLimited(secondsRemaining: 5),
            SeggWatError.rateLimited(secondsRemaining: 5)
        )
        XCTAssertNotEqual(
            SeggWatError.rateLimited(secondsRemaining: 5),
            SeggWatError.rateLimited(secondsRemaining: 3)
        )
    }

    func testErrorDescriptions() {
        XCTAssertNotNil(SeggWatError.notConfigured.errorDescription)
        XCTAssertNotNil(SeggWatError.invalidProjectKey.errorDescription)
        XCTAssertNotNil(SeggWatError.validationFailed("test").errorDescription)
        XCTAssertNotNil(SeggWatError.rateLimited(secondsRemaining: 5).errorDescription)
        XCTAssertNotNil(SeggWatError.serverValidationFailed.errorDescription)
        XCTAssertNotNil(SeggWatError.originNotAllowed.errorDescription)
        XCTAssertNotNil(SeggWatError.projectNotFound.errorDescription)
        XCTAssertNotNil(SeggWatError.screenshotTooLarge.errorDescription)
        XCTAssertNotNil(SeggWatError.unsupportedMediaType.errorDescription)
        XCTAssertNotNil(SeggWatError.networkError("timeout").errorDescription)
        XCTAssertNotNil(SeggWatError.serverError(statusCode: 500, message: nil).errorDescription)
        XCTAssertNotNil(SeggWatError.screenshotCaptureFailed.errorDescription)
    }

    func testErrorDescriptionContainsDetails() {
        let error = SeggWatError.rateLimited(secondsRemaining: 7)
        XCTAssertTrue(error.errorDescription!.contains("7"))
    }
}
