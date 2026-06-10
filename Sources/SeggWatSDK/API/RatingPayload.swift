import Foundation

/// A rating value supporting three types: helpful (thumbs up/down), star (1-5), and NPS (0-10).
public enum RatingValue: Equatable {
    case helpful(Bool)
    case star(value: UInt8, maxStars: UInt8 = 5)
    case nps(UInt8)
}

// MARK: - Codable

extension RatingValue: Codable {
    private enum CodingKeys: String, CodingKey {
        case type
        case value
        case maxStars = "max_stars"
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .helpful(let isHelpful):
            try container.encode("helpful", forKey: .type)
            try container.encode(isHelpful, forKey: .value)
        case .star(let value, let maxStars):
            try container.encode("star", forKey: .type)
            try container.encode(value, forKey: .value)
            try container.encode(maxStars, forKey: .maxStars)
        case .nps(let value):
            try container.encode("nps", forKey: .type)
            try container.encode(value, forKey: .value)
        }
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)
        switch type {
        case "helpful":
            let value = try container.decode(Bool.self, forKey: .value)
            self = .helpful(value)
        case "star":
            let value = try container.decode(UInt8.self, forKey: .value)
            let maxStars = try container.decodeIfPresent(UInt8.self, forKey: .maxStars) ?? 5
            self = .star(value: value, maxStars: maxStars)
        case "nps":
            let value = try container.decode(UInt8.self, forKey: .value)
            self = .nps(value)
        default:
            throw DecodingError.dataCorruptedError(
                forKey: .type,
                in: container,
                debugDescription: "Unknown rating type: \(type)"
            )
        }
    }
}

// MARK: - Payloads

/// Optional context sent alongside a rating.
struct RatingContextPayload: Codable, Equatable {
    let path: String?
    let version: String?
    let submittedBy: String?

    enum CodingKeys: String, CodingKey {
        case path
        case version
        case submittedBy = "submitted_by"
    }
}

/// Unified rating submission payload matching `POST /api/v1/ratings`.
struct UnifiedRatingPayload: Codable, Equatable {
    let projectKey: String
    let rating: RatingValue
    let context: RatingContextPayload?

    enum CodingKeys: String, CodingKey {
        case projectKey = "project_key"
        case rating
        case context
    }
}

/// Server response after creating a rating.
public struct RatingCreatedResponse: Codable, Equatable {
    public let id: String
    public let ratingType: String

    enum CodingKeys: String, CodingKey {
        case id
        case ratingType = "rating_type"
    }
}
