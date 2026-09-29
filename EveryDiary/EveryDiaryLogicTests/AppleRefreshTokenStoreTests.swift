import XCTest

final class AppleSignInSecretsTests: XCTestCase {
    private var defaults: UserDefaults!
    private let suite = "AppleSignInSecretsTests"

    override func setUp() {
        super.setUp()
        defaults = UserDefaults(suiteName: suite)
        defaults.removePersistentDomain(forName: suite)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suite)
        super.tearDown()
    }

    // Refresh tokens kept by earlier versions (Keychain, and plain UserDefaults before that) are deleted:
    // Firebase now revokes with a fresh authorization code, so no token is kept on the device.
    func testStoredRefreshTokensAreDeleted() throws {
        let secrets = MemorySecretStore()
        try secrets.set("keychain-token", for: AppleSignInSecrets.refreshTokenKey)
        defaults.set("plain-token", forKey: AppleSignInSecrets.legacyKey)
        let store = AppleSignInSecrets(secrets: secrets, legacy: defaults)

        store.removeStoredRefreshTokens()

        XCTAssertNil(secrets.values[AppleSignInSecrets.refreshTokenKey])
        XCTAssertNil(defaults.string(forKey: AppleSignInSecrets.legacyKey))
    }

    func testAppleUserIDIsKeptInTheSecretStoreAndRemovedWithEverything() throws {
        let secrets = MemorySecretStore()
        let store = AppleSignInSecrets(secrets: secrets, legacy: defaults)

        try store.saveAppleUserID("001234.abc.0001")
        XCTAssertEqual(store.appleUserID, "001234.abc.0001")
        XCTAssertNil(defaults.string(forKey: AppleSignInSecrets.userIDKey), "Not in plain UserDefaults")

        store.removeAll()
        XCTAssertNil(store.appleUserID)
    }
}

final class AppleCredentialStatusTests: XCTestCase {
    func testOnlyAnExplicitRevocationEndsTheSession() {
        XCTAssertTrue(AppleCredentialStatus.revoked.endsSession)
        XCTAssertFalse(AppleCredentialStatus.authorized.endsSession)
        XCTAssertFalse(AppleCredentialStatus.notFound.endsSession)
        XCTAssertFalse(AppleCredentialStatus.transferred.endsSession)
    }
}

final class MemorySecretStore: SecretStore {
    private(set) var values: [String: String] = [:]
    func string(for key: String) -> String? { values[key] }
    func set(_ value: String, for key: String) throws { values[key] = value }
    func remove(_ key: String) { values[key] = nil }
}
