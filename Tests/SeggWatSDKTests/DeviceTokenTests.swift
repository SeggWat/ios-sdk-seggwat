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

final class AppAttestTests: XCTestCase {

    func testClientDataHashMatchesServer() {
        // SHA-256("challenge" + "dev_token"), the same input the server hashes.
        let hash = AppAttest.clientDataHash(challenge: "challenge", token: "dev_token")
        XCTAssertEqual(
            hash.map { String(format: "%02x", $0) }.joined(),
            "3b1a543805a79d337c06285a6dec47c6e1d6d28867c951a796fa5186240dbaf8"
        )
    }

    func testPreconditionRequiredMapsToAttestationRequired() {
        XCTAssertEqual(SeggWatError.fromHTTPStatus(428), .attestationRequired)
    }
}
