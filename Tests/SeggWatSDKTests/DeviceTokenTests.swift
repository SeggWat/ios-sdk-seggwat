import XCTest
@testable import SeggWatSDK

final class DeviceTokenTests: XCTestCase {

    func testGeneratedTokenMatchesServerFormat() {
        let token = DeviceToken.generate()
        XCTAssertTrue(token.hasPrefix("dev_"))
        XCTAssertEqual(token.count, 47)
        let allowed = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-_")
        XCTAssertTrue(token.dropFirst(4).unicodeScalars.allSatisfy(allowed.contains))
    }

    func testGeneratedTokensAreUnique() {
        XCTAssertNotEqual(DeviceToken.generate(), DeviceToken.generate())
    }
}
