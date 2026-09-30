import XCTest

@MainActor
final class SignInViewModelTests: XCTestCase {
    private let google = SocialCredential(provider: .google, raw: NSObject())
    private var accountChanges = 0

    private func model(_ gateway: FakeSignInGateway) -> SignInViewModel {
        SignInViewModel(gateway: gateway, onAccountChanged: { [weak self] in self?.accountChanges += 1 })
    }

    func testMemberWithNameClosesRightAfterSignIn() async {
        let gateway = FakeSignInGateway(isGuest: false)
        gateway.currentName = "하루"
        let model = model(gateway)
        XCTAssertTrue(model.beginProvider())
        await model.complete(with: google, displayName: "하루")
        XCTAssertTrue(model.isFinished)
        XCTAssertFalse(model.isSigningIn)
        XCTAssertNil(model.prompt)
        XCTAssertEqual(accountChanges, 1)
    }

    func testGuestWhoSignsUpPicksANicknameStartingFromTheLinkedName() async {
        let gateway = FakeSignInGateway(isGuest: true)
        gateway.currentName = "하루"
        let model = model(gateway)
        await model.complete(with: google, displayName: "하루")
        XCTAssertFalse(model.isFinished)
        XCTAssertEqual(model.nicknameDraft, "하루")
        XCTAssertEqual(model.prompt?.title, "닉네임 설정")
    }

    func testInvalidNicknameAsksAgainAndKeepsTheText() async {
        let gateway = FakeSignInGateway(isGuest: false)
        let model = model(gateway)
        await model.complete(with: google, displayName: nil)
        model.nicknameDraft = String(repeating: "가", count: Nickname.maxLength + 1)
        await model.saveNickname()
        XCTAssertEqual(model.prompt, .nickname(message: Nickname.Problem.tooLong.message))
        XCTAssertEqual(model.nicknameDraft.count, Nickname.maxLength + 1)
        XCTAssertFalse(model.isFinished)
    }

    func testSavedNicknameClosesTheScreen() async {
        let gateway = FakeSignInGateway(isGuest: false)
        let model = model(gateway)
        await model.complete(with: google, displayName: nil)
        model.nicknameDraft = " 하루 "
        await model.saveNickname()
        XCTAssertEqual(gateway.calls, ["signIn", "name:하루"])
        XCTAssertTrue(model.isFinished)
        XCTAssertEqual(accountChanges, 2)
    }

    // The sign-in itself succeeded, so a failed nickname save is reported and the screen then closes.
    func testNicknameSaveFailureStillKeepsTheSignIn() async {
        let gateway = FakeSignInGateway(isGuest: false)
        let model = model(gateway)
        await model.complete(with: google, displayName: nil)
        gateway.nameError = NSError(domain: "Name", code: 1)
        model.nicknameDraft = "하루"
        await model.saveNickname()
        XCTAssertEqual(model.prompt, .nicknameNotSaved)
        XCTAssertFalse(model.isSigningIn)
        model.finish()
        XCTAssertTrue(model.isFinished)
    }

    func testFailureShowsTheGatewayReasonAndTheErrorCode() async {
        let gateway = FakeSignInGateway(isGuest: false)
        gateway.signInError = NSError(domain: "FIRAuthErrorDomain", code: 17020)
        gateway.failureKind = .network
        let model = model(gateway)
        await model.complete(with: google, displayName: nil)
        XCTAssertEqual(model.prompt, .failure(message: SignInFailure.network.message + "\n(오류: FIRAuthErrorDomain 17020)"))
        XCTAssertFalse(model.isSigningIn)
        XCTAssertFalse(model.isFinished)
        XCTAssertEqual(accountChanges, 0)
    }

    func testProviderFailureWithoutErrorAsksToRetryLater() {
        let model = model(FakeSignInGateway(isGuest: false))
        XCTAssertTrue(model.beginProvider())
        model.providerFailed(nil)
        XCTAssertEqual(model.prompt, .failure(message: SignInFailure.other.message))
        XCTAssertFalse(model.isSigningIn)
    }

    // Closing mid-way would hide a sign-in or guest switch that still completes.
    func testClosingWaitsUntilTheSignInFinishes() {
        let model = model(FakeSignInGateway(isGuest: true))
        XCTAssertTrue(model.beginProvider())
        model.finish()
        XCTAssertFalse(model.isFinished)
        model.providerCancelled()
        model.finish()
        XCTAssertTrue(model.isFinished)
    }

    func testOnlyOneSignInRunsAtATimeAndCancelShowsNothing() {
        let model = model(FakeSignInGateway(isGuest: false))
        XCTAssertTrue(model.beginProvider())
        XCTAssertFalse(model.beginProvider())
        model.providerCancelled()
        XCTAssertNil(model.prompt)
        XCTAssertTrue(model.beginProvider())
    }
}
