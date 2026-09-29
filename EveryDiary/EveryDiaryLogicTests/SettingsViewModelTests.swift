import XCTest

@MainActor
final class SettingsViewModelTests: XCTestCase {
    private func waitUntil(_ condition: @MainActor () -> Bool, file: StaticString = #filePath, line: UInt = #line) async throws {
        for _ in 0..<2000 {
            if condition() { return }
            try await Task.sleep(nanoseconds: 1_000_000)
        }
        XCTFail("Timed out waiting for observable state", file: file, line: line)
    }

    private func member(provider: String = "google.com", email: String? = "a@example.com", name: String? = "하루") -> AccountSnapshot {
        AccountSnapshot(isEmailVerified: true, email: email, displayName: name, providerIDs: [provider])
    }

    // MARK: - Account state

    func testAccountStateKeepsPreviousClassification() {
        XCTAssertEqual(AccountState(nil), .signedOut)
        // The anonymous account (no Google/Apple sign-in, unverified) is a guest.
        XCTAssertEqual(AccountState(AccountSnapshot(isEmailVerified: false)), .guest)
        XCTAssertEqual(AccountState(member()), .member(email: "a@example.com", name: "하루", provider: .google))
        XCTAssertEqual(AccountState(member(provider: "apple.com", email: nil, name: nil)), .member(email: nil, name: nil, provider: .apple))
        XCTAssertEqual(AccountState(member(provider: "password")), .member(email: "a@example.com", name: "하루", provider: nil))
    }

    func testGuestLinkedToAppleWithUnverifiedEmailIsAMember() {
        let linked = AccountSnapshot(isEmailVerified: false, email: nil, displayName: "하루", providerIDs: ["apple.com"])
        XCTAssertEqual(AccountState(linked), .member(email: nil, name: "하루", provider: .apple))
        XCTAssertEqual(AccountState(AccountSnapshot(isEmailVerified: false, providerIDs: [])), .guest)
    }

    func testProfileTextsMatchPreviousSettingsScreen() {
        XCTAssertEqual(SettingsViewModel.profile(for: .signedOut, avatar: nil),
                       .init(name: "로그인해주세요", detail: "일기를 저장하려면 로그인하세요", avatar: nil, isLoggedIn: false))
        XCTAssertEqual(SettingsViewModel.profile(for: .guest, avatar: nil),
                       .init(name: "손님", detail: "일기를 저장하려면 로그인하세요", avatar: nil, isLoggedIn: false))
        XCTAssertEqual(SettingsViewModel.profile(for: .member(email: "a@example.com", name: "하루", provider: .google), avatar: .green),
                       .init(name: "하루", detail: "Google로 로그인\na@example.com", avatar: .green, isLoggedIn: true))
    }

    // Apple sends a name only on the first sign-in and may hide the e-mail, so the profile says how the user signed in.
    func testProfileShowsSignInMethodAndAsksForMissingNickname() {
        XCTAssertEqual(SettingsViewModel.profile(for: .member(email: "x1@privaterelay.appleid.com", name: nil, provider: .apple), avatar: nil),
                       .init(name: "닉네임을 설정해주세요", detail: "Apple로 로그인\n이메일 가림", avatar: .default, isLoggedIn: true))
        XCTAssertEqual(SettingsViewModel.profile(for: .member(email: nil, name: "하루", provider: .apple), avatar: nil).detail,
                       "Apple로 로그인\n이메일 정보 없음")
    }

    // MARK: - Profile picture

    func testAvatarIsStoredAsPhotoURLAndOtherPhotosFallBack() {
        for avatar in ProfileAvatar.allCases {
            XCTAssertEqual(ProfileAvatar(storedURL: avatar.storedURL), avatar)
        }
        XCTAssertNil(ProfileAvatar(storedURL: "https://lh3.googleusercontent.com/a/photo.jpg"))
        XCTAssertNil(ProfileAvatar(storedURL: "harudiary-avatar://unknown"))
        XCTAssertNil(ProfileAvatar(storedURL: nil))
    }

    func testSavedAvatarIsShownFromTheAccount() async throws {
        let session = FakeAccountSession()
        let model = SettingsViewModel(session: session)
        model.start()
        defer { model.stop() }
        var snapshot = member()
        snapshot.photoURL = ProfileAvatar.brown.storedURL
        session.send(snapshot)
        try await waitUntil { model.profile.avatar == .brown }
    }

    // MARK: - Nickname

    func testNicknameRules() throws {
        XCTAssertEqual(try Nickname.validated("  하루 일기 \n"), "하루 일기")
        XCTAssertThrowsError(try Nickname.validated("   ")) { XCTAssertEqual($0 as? Nickname.Problem, .empty) }
        XCTAssertEqual(try Nickname.validated(String(repeating: "가", count: 20)).count, 20)
        XCTAssertThrowsError(try Nickname.validated(String(repeating: "가", count: 21))) { XCTAssertEqual($0 as? Nickname.Problem, .tooLong) }
        // Counted as the user sees characters, so an emoji is one.
        XCTAssertEqual(try Nickname.validated(String(repeating: "👩‍👩‍👧", count: 20)).count, 20)
    }

    func testNicknameIsSavedAndShownRightAway() async throws {
        let session = FakeAccountSession()
        let model = try await signedInModel(session)
        defer { model.stop() }

        await model.updateProfile(nickname: "  새 이름 ", avatar: .pink)

        XCTAssertEqual(session.savedProfiles.map(\.nickname), ["새 이름"])
        XCTAssertEqual(session.savedProfiles.map(\.avatar), [.pink])
        XCTAssertEqual(model.nickname, "새 이름")
        XCTAssertEqual(model.profile.name, "새 이름")
        XCTAssertEqual(model.profile.avatar, .pink)
        XCTAssertEqual(model.notice, .profileSaved)
    }

    func testInvalidOrFailedNicknameIsNotShown() async throws {
        let session = FakeAccountSession()
        let model = try await signedInModel(session)
        defer { model.stop() }

        await model.updateProfile(nickname: " ", avatar: .orange)
        XCTAssertEqual(model.notice, .nicknameInvalid(.empty))
        XCTAssertTrue(session.savedProfiles.isEmpty)

        session.profileError = NSError(domain: "Settings", code: 3)
        await model.updateProfile(nickname: "다른 이름", avatar: .orange)
        XCTAssertEqual(model.notice, .profileFailed)
        XCTAssertEqual(model.nickname, "하루", "The name shown stays the saved one")
        XCTAssertEqual(model.profile.avatar, .default)
    }

    // MARK: - Observation

    func testFollowsAccountChangesAndStopsObserving() async throws {
        let session = FakeAccountSession()
        let model = SettingsViewModel(session: session)
        model.start()
        model.start()
        XCTAssertEqual(session.observationCount, 1)

        session.send(nil)
        try await waitUntil { model.account == .signedOut }
        session.send(AccountSnapshot(isEmailVerified: false))
        try await waitUntil { model.account == .guest }
        session.send(member())
        try await waitUntil { model.canManageAccount }

        model.stop()
        try await waitUntil { session.isTerminated }
    }

    // MARK: - Sign out

    func testSignOutReportsResult() {
        let session = FakeAccountSession()
        let model = SettingsViewModel(session: session)

        model.signOut()
        XCTAssertEqual(session.signOutCount, 1)
        XCTAssertEqual(model.notice, .signedOut)

        session.signOutError = NSError(domain: "Settings", code: 1)
        model.signOut()
        XCTAssertEqual(model.notice, .signOutFailed)
    }

    // MARK: - Account deletion

    private func signedInModel(_ session: FakeAccountSession) async throws -> SettingsViewModel {
        let model = SettingsViewModel(session: session)
        model.start()
        session.send(member())
        try await waitUntil { model.canManageAccount }
        return model
    }

    func testAccountDeletionSuccessIsReportedOnlyAfterItSucceeds() async throws {
        let session = FakeAccountSession()
        let model = try await signedInModel(session)
        defer { model.stop() }

        await model.deleteAccount()

        XCTAssertEqual(session.deleteCount, 1)
        XCTAssertEqual(model.notice, .accountDeleted)
    }

    func testRecentLoginRequirementAndOtherFailuresAreNotReportedAsDeleted() async throws {
        let session = FakeAccountSession()
        let model = try await signedInModel(session)
        defer { model.stop() }

        session.deleteError = AccountDeletionError.requiresRecentLogin
        await model.deleteAccount()
        XCTAssertEqual(model.notice, .deletionNeedsRecentLogin)

        session.deleteError = AccountDeletionError.dataErasureFailed
        await model.deleteAccount()
        XCTAssertEqual(model.notice, .dataErasureFailed)

        session.deleteError = AccountDeletionError.dataErasedNeedsRecentLogin
        await model.deleteAccount()
        XCTAssertEqual(model.notice, .dataErasedNeedsRecentLogin)

        session.deleteError = NSError(domain: "Settings", code: 2)
        await model.deleteAccount()
        XCTAssertEqual(model.notice, .deletionFailed)
    }

    func testGuestCannotDeleteAndRepeatedTapsDeleteOnce() async throws {
        let guestSession = FakeAccountSession()
        let guest = SettingsViewModel(session: guestSession)
        guest.start()
        defer { guest.stop() }
        guestSession.send(AccountSnapshot(isEmailVerified: false))
        try await waitUntil { guest.account == .guest }
        await guest.deleteAccount()
        XCTAssertEqual(guestSession.deleteCount, 0)
        XCTAssertNil(guest.notice)

        let session = FakeAccountSession()
        let model = try await signedInModel(session)
        defer { model.stop() }
        session.suspendsDeletion = true
        async let first: Void = model.deleteAccount()
        try await waitUntil { session.deleteCount == 1 }
        await model.deleteAccount()
        session.resumeDeletion()
        await first
        XCTAssertEqual(session.deleteCount, 1)
        XCTAssertFalse(model.isDeletingAccount)
    }
}

@MainActor
final class FakeAccountSession: AccountSession {
    private(set) var observationCount = 0
    private(set) var isTerminated = false
    private(set) var signOutCount = 0
    private(set) var deleteCount = 0
    var signOutError: Error?
    var deleteError: Error?
    var suspendsDeletion = false
    private var continuation: AsyncStream<AccountSnapshot?>.Continuation?
    private var pendingDeletion: CheckedContinuation<Void, Never>?

    func observeAccount() -> AsyncStream<AccountSnapshot?> {
        observationCount += 1
        let (stream, continuation) = AsyncStream<AccountSnapshot?>.makeStream()
        continuation.onTermination = { [weak self] _ in
            Task { @MainActor in self?.isTerminated = true }
        }
        self.continuation = continuation
        return stream
    }

    func send(_ snapshot: AccountSnapshot?) {
        continuation?.yield(snapshot)
    }

    func signOut() throws {
        signOutCount += 1
        if let signOutError { throw signOutError }
    }

    private(set) var savedProfiles: [(nickname: String, avatar: ProfileAvatar)] = []
    var profileError: Error?

    func updateProfile(nickname: String, avatar: ProfileAvatar) async throws {
        if let profileError { throw profileError }
        savedProfiles.append((nickname, avatar))
    }

    func deleteAccount() async throws {
        deleteCount += 1
        if suspendsDeletion {
            await withCheckedContinuation { pendingDeletion = $0 }
        }
        if let deleteError { throw deleteError }
    }

    func resumeDeletion() {
        pendingDeletion?.resume()
        pendingDeletion = nil
    }
}

/// For dependency-assembly tests that never open settings.
@MainActor
final class UnusedAccountSession: AccountSession {
    func observeAccount() -> AsyncStream<AccountSnapshot?> { AsyncStream { $0.finish() } }
    func signOut() throws { XCTFail("Settings is not used here") }
    func updateProfile(nickname: String, avatar: ProfileAvatar) async throws { XCTFail("Settings is not used here") }
    func deleteAccount() async throws { XCTFail("Settings is not used here") }
}

@MainActor
final class AccountDeletionTests: XCTestCase {
    func testDataIsErasedBeforeTheAccountIsDeleted() async throws {
        var steps: [String] = []
        try await AccountDeletion.run(signedInFor: 60,
                                      eraseData: { steps.append("erase") },
                                      deleteAccount: { steps.append("delete") })
        XCTAssertEqual(steps, ["erase", "delete"])
    }

    func testNothingIsErasedWithoutARecentSignIn() async {
        var steps: [String] = []
        for signedInFor in [nil, AccountDeletion.recentSignInWindow] {
            do {
                try await AccountDeletion.run(signedInFor: signedInFor,
                                              eraseData: { steps.append("erase") },
                                              deleteAccount: { steps.append("delete") })
                XCTFail("Deletion must stop without a recent sign-in")
            } catch {
                XCTAssertEqual(error as? AccountDeletionError, .requiresRecentLogin)
            }
        }
        XCTAssertTrue(steps.isEmpty)
    }

    func testAccountIsKeptWhenErasingFails() async {
        var deleted = false
        do {
            try await AccountDeletion.run(signedInFor: 0,
                                          eraseData: { throw NSError(domain: "Erase", code: 1) },
                                          deleteAccount: { deleted = true })
            XCTFail("Deletion must stop when data remains")
        } catch {
            XCTAssertEqual(error as? AccountDeletionError, .dataErasureFailed)
        }
        XCTAssertFalse(deleted)
    }

    func testSignInExpiringDuringErasureIsReportedAsErasedAndRetryable() async {
        do {
            try await AccountDeletion.run(signedInFor: 0,
                                          eraseData: {},
                                          deleteAccount: { throw AccountDeletionError.requiresRecentLogin })
            XCTFail("Account deletion failed and must be reported")
        } catch {
            XCTAssertEqual(error as? AccountDeletionError, .dataErasedNeedsRecentLogin)
        }
    }
}
