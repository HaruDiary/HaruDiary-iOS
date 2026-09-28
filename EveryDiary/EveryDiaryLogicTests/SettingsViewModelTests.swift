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
        // The anonymous account (and any unverified account) was shown as a guest.
        XCTAssertEqual(AccountState(AccountSnapshot(isEmailVerified: false)), .guest)
        XCTAssertEqual(AccountState(member()), .member(email: "a@example.com", name: "하루", provider: .google))
        XCTAssertEqual(AccountState(member(provider: "apple.com", email: nil, name: nil)), .member(email: nil, name: nil, provider: .apple))
        XCTAssertEqual(AccountState(member(provider: "password")), .member(email: "a@example.com", name: "하루", provider: nil))
    }

    func testProfileTextsMatchPreviousSettingsScreen() {
        XCTAssertEqual(SettingsViewModel.profile(for: .signedOut),
                       .init(name: "로그인해주세요", detail: "일기를 저장하려면 로그인하세요", imageName: "profile", isLoggedIn: false))
        XCTAssertEqual(SettingsViewModel.profile(for: .guest),
                       .init(name: "손님", detail: "일기를 저장하려면 로그인하세요", imageName: "profile", isLoggedIn: false))
        XCTAssertEqual(SettingsViewModel.profile(for: .member(email: nil, name: nil, provider: .apple)),
                       .init(name: "사용자", detail: "인증 완료", imageName: "appleProfile", isLoggedIn: true))
        XCTAssertEqual(SettingsViewModel.profile(for: .member(email: "a@example.com", name: "하루", provider: .google)).imageName,
                       "googleProfile")
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
