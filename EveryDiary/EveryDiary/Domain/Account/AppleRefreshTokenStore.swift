import Foundation

/// Where secrets are kept. The app uses the Keychain; tests use memory.
protocol SecretStore: AnyObject {
    func string(for key: String) -> String?
    func set(_ value: String, for key: String) throws
    func remove(_ key: String)
}

/// The Apple refresh token kept to revoke Sign in with Apple when the member withdraws.
/// Earlier versions saved it in plain UserDefaults; it is moved to the secret store on first use.
final class AppleRefreshTokenStore {
    static let key = "appleRefreshToken"
    static let legacyKey = "refreshToken"
    static let userIDKey = "appleUserID"

    private let secrets: any SecretStore
    private let legacy: UserDefaults

    init(secrets: any SecretStore, legacy: UserDefaults) {
        self.secrets = secrets
        self.legacy = legacy
    }

    var token: String? {
        moveLegacyToken()
        return secrets.string(for: Self.key)
    }

    func save(_ token: String) throws {
        try secrets.set(token, for: Self.key)
        legacy.removeObject(forKey: Self.legacyKey)
    }

    func remove() {
        secrets.remove(Self.key)
        secrets.remove(Self.userIDKey)
        legacy.removeObject(forKey: Self.legacyKey)
    }

    /// The user identifier Apple returned at sign-in (`ASAuthorizationAppleIDCredential.user`),
    /// the value Apple expects when asking whether the sign-in is still allowed.
    var appleUserID: String? { secrets.string(for: Self.userIDKey) }

    func saveAppleUserID(_ id: String) throws {
        try secrets.set(id, for: Self.userIDKey)
    }

    /// Reads the token from the Cloud Function's answer. Apple refresh tokens are printable text without
    /// spaces; error pages (HTML/JSON) or empty bodies were previously stored as if they were tokens.
    static func token(from data: Data) -> String? {
        // The Cloud Function's source is not in this repository; a JSON answer with `refresh_token` is read too.
        if let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let value = object["refresh_token"] as? String {
            return token(from: Data(value.utf8))
        }
        guard let text = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
              !text.isEmpty, text.count <= 1024,
              text.unicodeScalars.allSatisfy({ $0.value > 0x20 && $0.value < 0x7F && $0 != "<" && $0 != "{" }) else { return nil }
        return text
    }

    /// Called when the app starts so a plain-text copy does not wait until the next withdrawal.
    func moveLegacyToken() {
        guard let old = legacy.string(forKey: Self.legacyKey) else { return }
        if !old.isEmpty, secrets.string(for: Self.key) == nil {
            try? secrets.set(old, for: Self.key)
        }
        // Removed even if moving failed: a plain-text copy is not kept either way.
        legacy.removeObject(forKey: Self.legacyKey)
    }
}
