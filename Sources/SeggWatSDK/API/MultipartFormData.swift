import Foundation

/// Encodes multipart/form-data bodies for screenshot uploads.
struct MultipartFormData {
    private let boundary: String
    private var parts: [Part] = []

    struct Part {
        let name: String
        let filename: String?
        let contentType: String?
        let data: Data
    }

    var contentType: String {
        "multipart/form-data; boundary=\(boundary)"
    }

    init(boundary: String = UUID().uuidString) {
        self.boundary = boundary
    }

    /// Add a JSON field.
    mutating func addField(name: String, value: Data) {
        parts.append(Part(name: name, filename: nil, contentType: "application/json", data: value))
    }

    /// Add a file field.
    mutating func addFile(name: String, filename: String, contentType: String, data: Data) {
        parts.append(Part(name: name, filename: filename, contentType: contentType, data: data))
    }

    /// Encode all parts into the final body data.
    func encode() -> Data {
        var body = Data()
        let crlf = "\r\n"

        for part in parts {
            body.append("--\(boundary)\(crlf)")

            if let filename = part.filename {
                body.append("Content-Disposition: form-data; name=\"\(part.name)\"; filename=\"\(filename)\"\(crlf)")
            } else {
                body.append("Content-Disposition: form-data; name=\"\(part.name)\"\(crlf)")
            }

            if let contentType = part.contentType {
                body.append("Content-Type: \(contentType)\(crlf)")
            }

            body.append(crlf)
            body.append(part.data)
            body.append(crlf)
        }

        body.append("--\(boundary)--\(crlf)")
        return body
    }
}

private extension Data {
    mutating func append(_ string: String) {
        if let data = string.data(using: .utf8) {
            append(data)
        }
    }
}
