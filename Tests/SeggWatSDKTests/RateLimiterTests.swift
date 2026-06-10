import XCTest
@testable import SeggWatSDK

final class RateLimiterTests: XCTestCase {

    func testAllowsFirstSubmission() {
        let limiter = RateLimiter(cooldownSeconds: 10)
        XCTAssertNil(limiter.check())
    }

    func testBlocksImmediateSecondSubmission() {
        let limiter = RateLimiter(cooldownSeconds: 10)
        limiter.recordSubmission()
        let remaining = limiter.check()
        XCTAssertNotNil(remaining)
        XCTAssertGreaterThan(remaining!, 0)
        XCTAssertLessThanOrEqual(remaining!, 10)
    }

    func testAllowsAfterCooldown() {
        let limiter = RateLimiter(cooldownSeconds: 1)
        limiter.recordSubmission()

        // Wait for cooldown
        let expectation = expectation(description: "cooldown")
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.1) {
            XCTAssertNil(limiter.check())
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 3)
    }

    func testReset() {
        let limiter = RateLimiter(cooldownSeconds: 10)
        limiter.recordSubmission()
        XCTAssertNotNil(limiter.check())

        limiter.reset()
        XCTAssertNil(limiter.check())
    }

    func testCustomCooldown() {
        let limiter = RateLimiter(cooldownSeconds: 5)
        limiter.recordSubmission()
        let remaining = limiter.check()
        XCTAssertNotNil(remaining)
        XCTAssertLessThanOrEqual(remaining!, 5)
    }
}
