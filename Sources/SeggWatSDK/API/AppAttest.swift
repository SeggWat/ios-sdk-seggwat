import CryptoKit
import DeviceCheck
import Foundation

/// Proves to SeggWat that an anonymous chat identity belongs to a genuine
/// install of this app on a real device, using Apple's App Attest. Only runs
/// when the project requires it (the server answers 428). Done once per
/// identity: the server remembers the attested identity afterwards.
enum AppAttest {
    static func attest(apiClient: APIClient, projectKey: String, token: String) async throws {
        let service = DCAppAttestService.shared
        guard service.isSupported else {
            throw SeggWatError.attestationUnsupported
        }
        do {
            let keyId = try await service.generateKey()
            let challenge = try await apiClient.attestChallenge(projectKey: projectKey)
            let attestation = try await attestKey(
                service,
                keyId: keyId,
                clientDataHash: clientDataHash(challenge: challenge, token: token)
            )
            try await apiClient.submitAttestation(AttestPayload(
                projectKey: projectKey,
                token: token,
                challenge: challenge,
                keyId: keyId,
                attestation: attestation.base64EncodedString()
            ))
        } catch let error as SeggWatError {
            throw error
        } catch let error as DCError where error.code == .serverUnavailable {
            // Apple's servers are down: a network-style error, so callers
            // retry later instead of giving up.
            throw SeggWatError.networkError(error.localizedDescription)
        } catch {
            throw SeggWatError.attestationFailed(error.localizedDescription)
        }
    }

    /// Attest the key, retrying while Apple's servers are unavailable. Apple
    /// asks to retry with the same key and client data hash. Gives up after
    /// about 7 seconds, well inside the challenge's 5 minutes.
    private static func attestKey(
        _ service: DCAppAttestService,
        keyId: String,
        clientDataHash: Data
    ) async throws -> Data {
        var delay: UInt64 = 1
        while true {
            do {
                return try await service.attestKey(keyId, clientDataHash: clientDataHash)
            } catch let error as DCError where error.code == .serverUnavailable && delay <= 4 {
                try await Task.sleep(nanoseconds: delay * 1_000_000_000)
                delay *= 2
            }
        }
    }

    /// SHA-256 of the challenge followed by the token, matching the server, so
    /// the attestation is bound to this challenge and this identity.
    static func clientDataHash(challenge: String, token: String) -> Data {
        Data(SHA256.hash(data: Data((challenge + token).utf8)))
    }
}

struct AttestPayload: Encodable {
    let projectKey: String
    let token: String
    let challenge: String
    let keyId: String
    let attestation: String

    enum CodingKeys: String, CodingKey {
        case projectKey = "project_key"
        case token, challenge
        case keyId = "key_id"
        case attestation
    }
}

struct AttestChallengeResponse: Decodable {
    let challenge: String
}
