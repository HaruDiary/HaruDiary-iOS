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
        XCTAssertEqual(SettingsViewModel.profile(for: .signedOut, picture: nil),
                       .init(name: "로그인해주세요", detail: "일기를 저장하려면 로그인하세요", picture: nil, isLoggedIn: false))
        XCTAssertEqual(SettingsViewModel.profile(for: .guest, picture: nil),
                       .init(name: "손님", detail: "일기를 저장하려면 로그인하세요", picture: nil, isLoggedIn: false))
        XCTAssertEqual(SettingsViewModel.profile(for: .member(email: "a@example.com", name: "하루", provider: .google), picture: .avatar(.google)),
                       .init(name: "하루", detail: "Google로 로그인\na@example.com", picture: .avatar(.google), isLoggedIn: true))
    }

    // Apple sends a name only on the first sign-in and may hide the e-mail, so the profile says how the user signed in.
    func testProfileShowsSignInMethodAndAsksForMissingNickname() {
        XCTAssertEqual(SettingsViewModel.profile(for: .member(email: "x1@privaterelay.appleid.com", name: nil, provider: .apple), picture: nil),
                       .init(name: "닉네임을 설정해주세요", detail: "Apple로 로그인\n이메일 가림", picture: .avatar(.apple), isLoggedIn: true))
        XCTAssertEqual(SettingsViewModel.profile(for: .member(email: nil, name: "하루", provider: .apple), picture: nil).detail,
                       "Apple로 로그인")
    }

    // MARK: - Profile picture

    private let uploadedPhoto = URL(string: "https://firebasestorage.googleapis.com/v0/b/app.appspot.com/o/uid123%2Fprofile-A1.jpg?alt=media&token=t")!

    func testAvatarIsStoredAsPhotoURLAndOtherPhotosFallBack() {
        for avatar in ProfileAvatar.allCases {
            XCTAssertEqual(ProfileAvatar(storedURL: avatar.storedURL), avatar)
        }
        XCTAssertNil(ProfileAvatar(storedURL: "https://lh3.googleusercontent.com/a/photo.jpg"))
        XCTAssertNil(ProfileAvatar(storedURL: "harudiary-avatar://unknown"))
        XCTAssertNil(ProfileAvatar(storedURL: nil))
    }

    // Without a chosen picture, members see the picture of their sign-in method, as the first version did.
    func testDefaultPictureFollowsSignInMethod() {
        XCTAssertEqual(SettingsViewModel.profile(for: .member(email: nil, name: "하루", provider: .google), picture: nil).picture, .avatar(.google))
        XCTAssertEqual(SettingsViewModel.profile(for: .member(email: nil, name: "하루", provider: .apple), picture: nil).picture, .avatar(.apple))
        XCTAssertEqual(SettingsViewModel.profile(for: .member(email: nil, name: "하루", provider: .apple), picture: .avatar(.mint)).picture, .avatar(.mint))
    }

    // Values saved by the earlier icon set keep the member's choice instead of resetting to the default.
    func testPreviousAvatarIDsAreStillRead() {
        let expected: [String: ProfileAvatar] = ["purple": .violet, "blue": .apple, "green": .google, "orange": .peach,
                                                  "moon": .violet, "leaf": .google, "cloud": .sky, "heart": .pink]
        for (id, avatar) in expected {
            XCTAssertEqual(ProfileAvatar(storedURL: "harudiary-avatar://\(id)"), avatar)
        }
    }

    func testOnlyTheMembersUploadedProfilePhotoIsReadAsAPhoto() {
        XCTAssertEqual(ProfilePicture(storedURL: uploadedPhoto.absoluteString), .photo(uploadedPhoto))
        XCTAssertEqual(ProfilePicture.storagePath(of: uploadedPhoto), "uid123/profile-A1.jpg")
        XCTAssertEqual(ProfilePicture(storedURL: ProfileAvatar.sky.storedURL), .avatar(.sky))
        // Google's account photo and diary photos are not profile uploads.
        XCTAssertNil(ProfilePicture(storedURL: "https://lh3.googleusercontent.com/a/photo.jpg"))
        XCTAssertNil(ProfilePicture(storedURL: "https://firebasestorage.googleapis.com/v0/b/app.appspot.com/o/uid123%2FDIARY_1.jpg?alt=media"))
        XCTAssertNil(ProfilePicture(storedURL: nil))
    }

    func testSavedPictureIsShownFromTheAccount() async throws {
        let session = FakeAccountSession()
        let model = SettingsViewModel(session: session)
        model.start()
        defer { model.stop() }
        var snapshot = member()
        snapshot.photoURL = ProfileAvatar.peach.storedURL
        session.send(snapshot)
        try await waitUntil { model.profile.picture == .avatar(.peach) }
        snapshot.photoURL = uploadedPhoto.absoluteString
        session.send(snapshot)
        try await waitUntil { model.profile.picture == .photo(self.uploadedPhoto) }
    }

    func testTheAccountKnownAtOpeningIsShownBeforeAnythingIsObserved() {
        let session = FakeAccountSession()
        var snapshot = member()
        snapshot.photoURL = uploadedPhoto.absoluteString
        session.currentAccount = snapshot

        let model = SettingsViewModel(session: session)

        XCTAssertTrue(model.profile.isLoggedIn)
        XCTAssertEqual(model.profile.name, "하루")
        XCTAssertEqual(model.profile.picture, .photo(uploadedPhoto))
    }

    func testANewlyUploadedPhotoIsKeptOnTheDevice() async throws {
        let session = FakeAccountSession()
        let photos = FakeProfilePhotos()
        let model = SettingsViewModel(session: session, photos: photos)
        model.start()
        defer { model.stop() }
        session.send(member())
        try await waitUntil { model.canManageAccount }
        photos.removeCount = 0

        let saved = await model.updateProfile(nickname: "하루", picture: .newPhoto(Data([7])))

        XCTAssertTrue(saved)
        XCTAssertEqual(photos.stored.map(\.url), [session.photoURLAfterUpload])
        XCTAssertEqual(photos.stored.map(\.jpeg), [Data([7])])
        XCTAssertEqual(photos.removeCount, 0)
    }

    func testTheKeptPhotoStaysWhileItIsShownAndGoesWithIt() async throws {
        let session = FakeAccountSession()
        let photos = FakeProfilePhotos()
        let model = SettingsViewModel(session: session, photos: photos)
        model.start()
        defer { model.stop() }
        var snapshot = member()
        snapshot.photoURL = uploadedPhoto.absoluteString
        session.send(snapshot)
        try await waitUntil { model.profile.picture == .photo(self.uploadedPhoto) }
        XCTAssertEqual(photos.removeCount, 0)

        // Keeping the photo while changing the nickname does not touch it.
        let kept = await model.updateProfile(nickname: "새 이름", picture: .currentPhoto(uploadedPhoto))
        XCTAssertTrue(kept)
        XCTAssertEqual(photos.removeCount, 0)
        XCTAssertTrue(photos.stored.isEmpty)

        // Changing to an avatar removes it, and so does signing out.
        let changed = await model.updateProfile(nickname: "새 이름", picture: .avatar(.mint))
        XCTAssertTrue(changed)
        XCTAssertEqual(photos.removeCount, 1)
        session.send(nil)
        try await waitUntil { photos.removeCount == 2 }
    }

    func testAFailedSaveKeepsNoPhoto() async throws {
        let session = FakeAccountSession()
        let photos = FakeProfilePhotos()
        let model = SettingsViewModel(session: session, photos: photos)
        model.start()
        defer { model.stop() }
        session.send(member())
        try await waitUntil { model.canManageAccount }
        session.profileError = URLError(.notConnectedToInternet)

        let saved = await model.updateProfile(nickname: "하루", picture: .newPhoto(Data([7])))

        XCTAssertFalse(saved)
        XCTAssertTrue(photos.stored.isEmpty)
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

        let saved = await model.updateProfile(nickname: "  새 이름 ", picture: .avatar(.pink))

        XCTAssertTrue(saved)
        XCTAssertEqual(session.savedProfiles.map(\.nickname), ["새 이름"])
        XCTAssertEqual(session.savedProfiles.map(\.picture), [.avatar(.pink)])
        XCTAssertEqual(model.nickname, "새 이름")
        XCTAssertEqual(model.profile.name, "새 이름")
        XCTAssertEqual(model.profile.picture, .avatar(.pink))
        XCTAssertEqual(model.notice, .profileSaved)
    }

    func testNewPhotoIsShownAfterItIsSaved() async throws {
        let session = FakeAccountSession()
        let model = try await signedInModel(session)
        defer { model.stop() }
        session.photoURLAfterUpload = uploadedPhoto

        let saved = await model.updateProfile(nickname: "하루", picture: .newPhoto(Data([1, 2, 3])))

        XCTAssertTrue(saved)
        XCTAssertEqual(session.savedProfiles.map(\.picture), [.newPhoto(Data([1, 2, 3]))])
        XCTAssertEqual(model.profile.picture, .photo(uploadedPhoto))
    }

    // A save that finishes after the account changed must not show the previous account's profile.
    func testProfileSavedForAPreviousAccountIsNotShown() async throws {
        let session = FakeAccountSession()
        let model = try await signedInModel(session)
        defer { model.stop() }
        session.suspendsProfile = true

        async let saved = model.updateProfile(nickname: "A의 이름", picture: .avatar(.mint))
        try await waitUntil { model.isSavingProfile }
        session.send(member(provider: "apple.com", email: "b@example.com", name: "B"))
        try await waitUntil { model.account == .member(email: "b@example.com", name: "B", provider: .apple) }
        session.resumeProfile()
        _ = await saved

        XCTAssertEqual(model.account, .member(email: "b@example.com", name: "B", provider: .apple))
        XCTAssertEqual(model.profile.picture, .avatar(.apple))
    }

    func testInvalidOrFailedNicknameIsNotShown() async throws {
        let session = FakeAccountSession()
        let model = try await signedInModel(session)
        defer { model.stop() }

        let invalid = await model.updateProfile(nickname: " ", picture: .avatar(.mint))
        XCTAssertFalse(invalid)
        XCTAssertEqual(model.notice, .nicknameInvalid(.empty))
        XCTAssertTrue(session.savedProfiles.isEmpty)

        // A failed upload or profile change keeps the previous nickname and picture; the editor stays open to retry.
        model.notice = nil
        session.profileError = NSError(domain: "Settings", code: 3)
        let failed = await model.updateProfile(nickname: "다른 이름", picture: .newPhoto(Data([9])))
        XCTAssertFalse(failed)
        XCTAssertNil(model.notice)
        XCTAssertEqual(model.nickname, "하루", "The name shown stays the saved one")
        XCTAssertEqual(model.profile.picture, .avatar(.google))
        XCTAssertFalse(model.isSavingProfile)
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

    // Apple members confirm with Sign in with Apple; its result is what lets Firebase revoke the Apple token.
    func testAppleMemberConfirmsWithAppleBeforeDeleting() async throws {
        let session = FakeAccountSession()
        let model = SettingsViewModel(session: session)
        model.start()
        defer { model.stop() }
        session.send(member(provider: "apple.com"))
        try await waitUntil { model.canManageAccount }
        XCTAssertTrue(model.needsAppleConfirmationToDelete)

        let apple = AppleAuthorization(identityToken: "t", rawNonce: "n", authorizationCode: "c", appleUserID: "apple-1", fullName: nil)
        await model.deleteAccount(appleAuthorization: apple)
        XCTAssertEqual(session.appleAuthorizations, ["apple-1"])
        XCTAssertEqual(model.notice, .accountDeleted)

        session.deleteError = AccountDeletionError.appleRevocationFailed
        await model.deleteAccount(appleAuthorization: apple)
        XCTAssertEqual(model.notice, .appleRevocationFailed)

        session.deleteError = AccountDeletionError.appleConfirmationRequired
        await model.deleteAccount(appleAuthorization: apple)
        XCTAssertEqual(model.notice, .appleConfirmationFailed)
    }

    func testGoogleMemberDeletesWithoutAppleConfirmation() async throws {
        let session = FakeAccountSession()
        let model = try await signedInModel(session)
        defer { model.stop() }
        XCTAssertFalse(model.needsAppleConfirmationToDelete)
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
final class FakeProfilePhotos: ProfilePhotoStoring {
    private(set) var stored: [(jpeg: Data, url: URL)] = []
    var removeCount = 0

    func store(_ jpeg: Data, for url: URL) { stored.append((jpeg, url)) }
    func removeAll() { removeCount += 1 }
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
    var currentAccount: AccountSnapshot?
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

    private(set) var savedProfiles: [(nickname: String, picture: ProfilePictureSelection)] = []
    var profileError: Error?
    var photoURLAfterUpload = URL(string: "https://firebasestorage.googleapis.com/v0/b/a/o/u%2Fprofile-x.jpg")!

    var suspendsProfile = false
    private var pendingProfile: CheckedContinuation<Void, Never>?

    func resumeProfile() {
        pendingProfile?.resume()
        pendingProfile = nil
    }

    func updateProfile(nickname: String, picture: ProfilePictureSelection) async throws -> ProfilePicture {
        if suspendsProfile {
            await withCheckedContinuation { pendingProfile = $0 }
        }
        if let profileError { throw profileError }
        savedProfiles.append((nickname, picture))
        switch picture {
        case .avatar(let avatar): return .avatar(avatar)
        case .currentPhoto(let url): return .photo(url)
        case .newPhoto: return .photo(photoURLAfterUpload)
        }
    }

    private(set) var appleAuthorizations: [String] = []

    func deleteAccount(appleAuthorization: AppleAuthorization?) async throws {
        deleteCount += 1
        if let appleAuthorization { appleAuthorizations.append(appleAuthorization.appleUserID) }
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
    var currentAccount: AccountSnapshot? { nil }
    func observeAccount() -> AsyncStream<AccountSnapshot?> { AsyncStream { $0.finish() } }
    func signOut() throws { XCTFail("Settings is not used here") }
    func updateProfile(nickname: String, picture: ProfilePictureSelection) async throws -> ProfilePicture {
        XCTFail("Settings is not used here")
        return .avatar(.google)
    }
    func deleteAccount(appleAuthorization: AppleAuthorization?) async throws { XCTFail("Settings is not used here") }
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

final class SettingsSummaryTests: XCTestCase {
    private let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Seoul")!
        return calendar
    }()

    func testReminderValueShowsDaysAndTime() {
        XCTAssertEqual(SettingsSummary.reminder(ReminderSettings(), calendar: calendar), "꺼짐")
        XCTAssertEqual(SettingsSummary.reminder(ReminderSettings(isOn: true), calendar: calendar), "매일 오후 9:00")
        XCTAssertEqual(SettingsSummary.reminder(ReminderSettings(isOn: true, hour: 7, minute: 30, weekdays: Set(2...6)),
                                                calendar: calendar), "평일 오전 7:30")
        XCTAssertEqual(SettingsSummary.reminder(ReminderSettings(isOn: true, weekdays: []), calendar: calendar), "요일 없음")
    }

    func testLockValueNamesTheWaysIn() {
        XCTAssertEqual(SettingsSummary.lock(.off, biometry: .faceID), "꺼짐")
        XCTAssertEqual(SettingsSummary.lock(.passcode(biometrics: false), biometry: .faceID), "암호")
        XCTAssertEqual(SettingsSummary.lock(.passcode(biometrics: true), biometry: .touchID), "암호 · Touch ID")
        // Biometrics turned on but no longer available on the device: only the passcode works.
        XCTAssertEqual(SettingsSummary.lock(.passcode(biometrics: true), biometry: .none), "암호")
        XCTAssertEqual(SettingsSummary.lock(.legacyBiometrics, biometry: .faceID), "Face ID")
    }

    func testVersionValue() {
        XCTAssertEqual(SettingsSummary.version(short: "2.0", build: "15"), "버전 2.0 (15)")
        XCTAssertEqual(SettingsSummary.version(short: "2.0", build: "2.0"), "버전 2.0")
        XCTAssertEqual(SettingsSummary.version(short: nil, build: "1"), "")
    }
}
