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

final class AppleRefreshTokenResponseTests: XCTestCase {
    func testOnlyATokenLikeAnswerIsAccepted() {
        XCTAssertEqual(AppleRefreshTokenStore.token(from: Data("r1a2b3.0.abc-DEF_4\n".utf8)), "r1a2b3.0.abc-DEF_4")
        XCTAssertNil(AppleRefreshTokenStore.token(from: Data()))
        XCTAssertNil(AppleRefreshTokenStore.token(from: Data("   ".utf8)))
        XCTAssertNil(AppleRefreshTokenStore.token(from: Data("<html>Error: could not handle the request</html>".utf8)))
        XCTAssertNil(AppleRefreshTokenStore.token(from: Data("{\"error\":\"invalid_grant\"}".utf8)))
        XCTAssertEqual(AppleRefreshTokenStore.token(from: Data("{\"refresh_token\":\"r9.0.xyz\"}".utf8)), "r9.0.xyz")
        XCTAssertNil(AppleRefreshTokenStore.token(from: Data("Error: invalid grant".utf8)), "Text with spaces is not a token")
        XCTAssertNil(AppleRefreshTokenStore.token(from: Data(String(repeating: "a", count: 1025).utf8)))
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
