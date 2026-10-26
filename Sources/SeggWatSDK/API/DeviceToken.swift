import Foundation
import Security

/// The anonymous chat identity of this install: a random bearer secret kept in
/// the Keychain, so the conversation survives relaunches (and usually
/// reinstalls). The server only ever stores a hash of it.
enum DeviceToken {
    private static let service = "com.seggwat.sdk"
    private static let account = "anonymous-chat-device-token"

    /// The stored token, or a newly generated and stored one.
    static func loadOrCreate() -> String {
        if let existing = load() {
            return existing
        }
        let token = generate()
        store(token)
        return token
    }

    /// `dev_` followed by 32 random bytes in unpadded base64url (43 chars).
    static func generate() -> String {
        var bytes = [UInt8](repeating: 0, count: 32)
        _ = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        let encoded = Data(bytes).base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
        return "dev_" + encoded
    }

    private static func load() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var result: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data else {
            return nil
        }
        return String(data: data, encoding: .utf8)
    }

    /// Best-effort: if the Keychain is unavailable the token still works for
    /// this launch, the conversation just won't carry over.
    private static func store(_ token: String) {
        let item: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
            kSecValueData as String: Data(token.utf8),
        ]
        SecItemAdd(item as CFDictionary, nil)
    }
}
