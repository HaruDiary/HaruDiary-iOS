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
        legacy.removeObject(forKey: Self.legacyKey)
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
