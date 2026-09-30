import XCTest

@MainActor
final class SocialSignInTests: XCTestCase {
    private let google = SocialCredential(provider: .google, raw: NSObject())

    func testSignedOutOrMemberSignsInDirectly() async throws {
        for state: Bool? in [nil, false] {
            let gateway = FakeSignInGateway(isGuest: state)
            let outcome = try await SocialSignIn.run(with: google, displayName: "하루", gateway: gateway)
            XCTAssertEqual(outcome, .signedIn)
            XCTAssertEqual(gateway.calls, ["signIn"])
        }
    }

    func testGuestIsLinkedAndKeepsItsDiaries() async throws {
        let gateway = FakeSignInGateway(isGuest: true)
        let outcome = try await SocialSignIn.run(with: google, displayName: " 하루 ", gateway: gateway)
        XCTAssertEqual(outcome, .linkedGuest)
        XCTAssertEqual(gateway.calls, ["link", "name:하루"])
    }

    func testEmptyNameIsNotSavedAndNameFailureDoesNotFailSignIn() async throws {
        let gateway = FakeSignInGateway(isGuest: true)
        _ = try await SocialSignIn.run(with: google, displayName: "", gateway: gateway)
        XCTAssertEqual(gateway.calls, ["link"])

        let failing = FakeSignInGateway(isGuest: true)
        failing.nameError = NSError(domain: "Name", code: 1)
        let outcome = try await SocialSignIn.run(with: google, displayName: "하루", gateway: failing)
        XCTAssertEqual(outcome, .linkedGuest)
    }

    func testAccountAlreadyInUseSwitchesToIt() async throws {
        let gateway = FakeSignInGateway(isGuest: true)
        gateway.linkResult = .alreadyInUse(existing: SocialCredential(provider: .apple, raw: NSObject()))
        let outcome = try await SocialSignIn.run(with: google, displayName: "하루", gateway: gateway)
        XCTAssertEqual(outcome, .switchedFromGuest)
        XCTAssertEqual(gateway.calls, ["link", "switch:apple"])
    }

    // Previously a network failure while linking deleted the guest account and its diaries became unreachable.
    func testOtherLinkFailuresKeepTheGuestAccount() async {
        let gateway = FakeSignInGateway(isGuest: true)
        gateway.linkError = NSError(domain: "Network", code: -1009)
        do {
            _ = try await SocialSignIn.run(with: google, displayName: nil, gateway: gateway)
            XCTFail("A failed link must be reported")
        } catch {
            XCTAssertEqual((error as NSError).code, -1009)
        }
        XCTAssertEqual(gateway.calls, ["link"])
    }

    func testNicknameIsAskedAfterGuestSignUpOrWhenMissing() {
        XCTAssertTrue(SocialSignIn.Outcome.linkedGuest.asksForNickname(currentName: "하루"))
        XCTAssertTrue(SocialSignIn.Outcome.signedIn.asksForNickname(currentName: nil))
        XCTAssertTrue(SocialSignIn.Outcome.switchedFromGuest.asksForNickname(currentName: nil))
        XCTAssertFalse(SocialSignIn.Outcome.signedIn.asksForNickname(currentName: "하루"))
        XCTAssertFalse(SocialSignIn.Outcome.switchedFromGuest.asksForNickname(currentName: "하루"))
    }

    func testSignInFailureIsReported() async {
        let gateway = FakeSignInGateway(isGuest: nil)
        gateway.signInError = NSError(domain: "Auth", code: 17004)
        do {
            _ = try await SocialSignIn.run(with: google, displayName: nil, gateway: gateway)
            XCTFail("A failed sign-in must be reported")
        } catch {
            XCTAssertEqual((error as NSError).code, 17004)
        }
    }
}

@MainActor
final class FakeSignInGateway: SocialSignInGateway {
    let isGuest: Bool?
    var currentName: String?
    var linkResult: GuestLinkResult = .linked
    var linkError: Error?
    var signInError: Error?
    var nameError: Error?
    var failureKind: SignInFailure = .other
    private(set) var calls: [String] = []

    init(isGuest: Bool?) {
        self.isGuest = isGuest
    }

    func linkGuest(with credential: SocialCredential) async throws -> GuestLinkResult {
        calls.append("link")
        if let linkError { throw linkError }
        return linkResult
    }

    func signIn(with credential: SocialCredential) async throws {
        calls.append("signIn")
        if let signInError { throw signInError }
    }

    func switchFromGuest(to credential: SocialCredential) async throws {
        calls.append("switch:\(credential.provider == .apple ? "apple" : "google")")
    }

    func updateDisplayName(_ name: String) async throws {
        if let nameError { throw nameError }
        calls.append("name:\(name)")
    }

    func appleCredential(for authorization: AppleAuthorization) -> SocialCredential { SocialCredential(provider: .apple, raw: NSObject()) }
    func rememberAppleUserID(_ id: String) {}
    func failure(for error: Error) -> SignInFailure { failureKind }
}

/// For dependency-assembly tests that never open the login screen.
@MainActor
final class UnusedSignInGateway: SocialSignInGateway {
    var isGuest: Bool? { nil }
    var currentName: String? { nil }
    func linkGuest(with credential: SocialCredential) async throws -> GuestLinkResult { .linked }
    func signIn(with credential: SocialCredential) async throws { XCTFail("Login is not used here") }
    func switchFromGuest(to credential: SocialCredential) async throws { XCTFail("Login is not used here") }
    func updateDisplayName(_ name: String) async throws {}
    func appleCredential(for authorization: AppleAuthorization) -> SocialCredential { SocialCredential(provider: .apple, raw: NSObject()) }
    func rememberAppleUserID(_ id: String) {}
    func failure(for error: Error) -> SignInFailure { .other }
}
