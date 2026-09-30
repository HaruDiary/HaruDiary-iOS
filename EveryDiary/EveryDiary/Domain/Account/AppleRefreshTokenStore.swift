import Foundation

/// Where secrets are kept. The app uses the Keychain; tests use memory.
protocol SecretStore: AnyObject {
    func string(for key: String) -> String?
    func set(_ value: String, for key: String) throws
    func remove(_ key: String)
    /// Like `remove`, but throws when the item could not be deleted. An item that is already gone is fine.
    func delete(_ key: String) throws
}

extension SecretStore {
    func delete(_ key: String) throws {
        remove(key)
    }
}

/// What the app keeps about Sign in with Apple: only the Apple user identifier, used to ask Apple whether
/// the member still allows Sign in with Apple. Apple refresh tokens are no longer kept; Firebase revokes
/// the token with a fresh authorization code at withdrawal.
final class AppleSignInSecrets {
    static let userIDKey = "appleUserID"
    /// Where earlier versions kept the Apple refresh token (Keychain, and plain UserDefaults before that).
    static let refreshTokenKey = "appleRefreshToken"
    static let legacyKey = "refreshToken"

    private let secrets: any SecretStore
    private let legacy: UserDefaults

    init(secrets: any SecretStore, legacy: UserDefaults) {
        self.secrets = secrets
        self.legacy = legacy
    }

    var appleUserID: String? { secrets.string(for: Self.userIDKey) }

    func saveAppleUserID(_ id: String) throws {
        try secrets.set(id, for: Self.userIDKey)
    }

    /// Refresh tokens saved by earlier versions are not needed any more and are deleted.
    func removeStoredRefreshTokens() {
        secrets.remove(Self.refreshTokenKey)
        legacy.removeObject(forKey: Self.legacyKey)
    }

    func removeAll() {
        secrets.remove(Self.userIDKey)
        removeStoredRefreshTokens()
    }
}
