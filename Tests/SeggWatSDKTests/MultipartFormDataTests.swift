import XCTest
@testable import SeggWatSDK

final class MultipartFormDataTests: XCTestCase {

    func testContentType() {
        let multipart = MultipartFormData(boundary: "test-boundary")
        XCTAssertEqual(multipart.contentType, "multipart/form-data; boundary=test-boundary")
    }

    func testEncodeField() {
        var multipart = MultipartFormData(boundary: "test-boundary")
        let jsonData = "{\"key\":\"value\"}".data(using: .utf8)!
        multipart.addField(name: "data", value: jsonData)

        let encoded = multipart.encode()
        let body = String(data: encoded, encoding: .utf8)!

        XCTAssertTrue(body.contains("--test-boundary\r\n"))
        XCTAssertTrue(body.contains("Content-Disposition: form-data; name=\"data\""))
        XCTAssertTrue(body.contains("Content-Type: application/json"))
        XCTAssertTrue(body.contains("{\"key\":\"value\"}"))
        XCTAssertTrue(body.contains("--test-boundary--"))
    }

    func testEncodeFile() {
        var multipart = MultipartFormData(boundary: "test-boundary")
        let imageData = "fake-image-data".data(using: .utf8)!
        multipart.addFile(name: "screenshot", filename: "screenshot.jpg", contentType: "image/jpeg", data: imageData)

        let encoded = multipart.encode()
        let body = String(data: encoded, encoding: .utf8)!

        XCTAssertTrue(body.contains("Content-Disposition: form-data; name=\"screenshot\"; filename=\"screenshot.jpg\""))
        XCTAssertTrue(body.contains("Content-Type: image/jpeg"))
        XCTAssertTrue(body.contains("--test-boundary--"))
        XCTAssertTrue(body.contains("fake-image-data"))
    }

    func testEncodeMultipleParts() {
        var multipart = MultipartFormData(boundary: "b")
        multipart.addField(name: "data", value: "{}".data(using: .utf8)!)
        multipart.addFile(name: "file", filename: "f.jpg", contentType: "image/jpeg", data: Data([0x01]))

        let encoded = multipart.encode()
        let body = String(data: encoded, encoding: .utf8)!

        // Count boundary occurrences: 2 part boundaries + 1 closing boundary
        let boundaryCount = body.components(separatedBy: "--b").count - 1
        XCTAssertEqual(boundaryCount, 3) // 2 parts + 1 closing
    }

    func testBoundaryUniqueness() {
        let a = MultipartFormData()
        let b = MultipartFormData()
        XCTAssertNotEqual(a.contentType, b.contentType)
    }
}
