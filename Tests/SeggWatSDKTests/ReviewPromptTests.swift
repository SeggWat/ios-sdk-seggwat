import XCTest
@testable import SeggWatSDK

final class ReviewPromptTests: XCTestCase {

    func testDefaultStarThresholds() {
        let options = ReviewPromptOptions()
        XCTAssertEqual(options.action(for: .star(value: 5)), .requestReview)
        XCTAssertEqual(options.action(for: .star(value: 4)), .requestReview)
        XCTAssertEqual(options.action(for: .star(value: 3)), .collectFeedback)
        XCTAssertEqual(options.action(for: .star(value: 1)), .collectFeedback)
    }

    func testDefaultNpsThresholds() {
        let options = ReviewPromptOptions()
        XCTAssertEqual(options.action(for: .nps(10)), .requestReview)
        XCTAssertEqual(options.action(for: .nps(9)), .requestReview)
        XCTAssertEqual(options.action(for: .nps(8)), .collectFeedback)
        XCTAssertEqual(options.action(for: .nps(0)), .collectFeedback)
    }

    func testHelpfulNeverPrompts() {
        let options = ReviewPromptOptions()
        XCTAssertEqual(options.action(for: .helpful(true)), .noPrompt)
        XCTAssertEqual(options.action(for: .helpful(false)), .noPrompt)
    }

    func testCustomThresholds() {
        let options = ReviewPromptOptions(minimumStars: 8, minimumNps: 10)
        XCTAssertEqual(options.action(for: .star(value: 8, maxStars: 10)), .requestReview)
        XCTAssertEqual(options.action(for: .star(value: 7, maxStars: 10)), .collectFeedback)
        XCTAssertEqual(options.action(for: .nps(9)), .collectFeedback)
    }
}
