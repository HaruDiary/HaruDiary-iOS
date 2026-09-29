import XCTest

final class AppleRefreshTokenStoreTests: XCTestCase {
    private var defaults: UserDefaults!
    private let suite = "AppleRefreshTokenStoreTests"

    override func setUp() {
        super.setUp()
        defaults = UserDefaults(suiteName: suite)
        defaults.removePersistentDomain(forName: suite)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suite)
        super.tearDown()
    }

    func testTokenIsKeptInTheSecretStoreNotUserDefaults() throws {
        let secrets = MemorySecretStore()
        let store = AppleRefreshTokenStore(secrets: secrets, legacy: defaults)

        try store.save("token-1")

        XCTAssertEqual(store.token, "token-1")
        XCTAssertEqual(secrets.values[AppleRefreshTokenStore.key], "token-1")
        XCTAssertNil(defaults.string(forKey: AppleRefreshTokenStore.legacyKey))
    }

    // Tokens saved in plain text by earlier versions move to the secret store and the plain copy is deleted.
    func testLegacyPlainTextTokenIsMovedAndErased() {
        defaults.set("old-token", forKey: AppleRefreshTokenStore.legacyKey)
        let secrets = MemorySecretStore()
        let store = AppleRefreshTokenStore(secrets: secrets, legacy: defaults)

        XCTAssertEqual(store.token, "old-token")
        XCTAssertEqual(secrets.values[AppleRefreshTokenStore.key], "old-token")
        XCTAssertNil(defaults.string(forKey: AppleRefreshTokenStore.legacyKey))
    }

    func testNewerSecretIsNotReplacedByLegacyValueAndRemoveClearsBoth() throws {
        let secrets = MemorySecretStore()
        let store = AppleRefreshTokenStore(secrets: secrets, legacy: defaults)
        try store.save("new-token")
        defaults.set("old-token", forKey: AppleRefreshTokenStore.legacyKey)

        XCTAssertEqual(store.token, "new-token")
        XCTAssertNil(defaults.string(forKey: AppleRefreshTokenStore.legacyKey))

        defaults.set("old-token", forKey: AppleRefreshTokenStore.legacyKey)
        try store.saveAppleUserID("001234.abc.0001")
        XCTAssertEqual(store.appleUserID, "001234.abc.0001")
        store.remove()
        XCTAssertNil(store.token)
        XCTAssertNil(store.appleUserID)
        XCTAssertNil(defaults.string(forKey: AppleRefreshTokenStore.legacyKey))
    }
}

final class MemorySecretStore: SecretStore {
    private(set) var values: [String: String] = [:]
    func string(for key: String) -> String? { values[key] }
    func set(_ value: String, for key: String) throws { values[key] = value }
    func remove(_ key: String) { values[key] = nil }
}

final class AppleCredentialStatusTests: XCTestCase {
    func testOnlyAnExplicitRevocationEndsTheSession() {
        XCTAssertTrue(AppleCredentialStatus.revoked.endsSession)
        XCTAssertFalse(AppleCredentialStatus.authorized.endsSession)
        XCTAssertFalse(AppleCredentialStatus.notFound.endsSession)
        XCTAssertFalse(AppleCredentialStatus.transferred.endsSession)
    }
}
