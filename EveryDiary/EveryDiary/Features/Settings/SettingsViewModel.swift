import Foundation
import Observation

@MainActor
@Observable
final class SettingsViewModel {
    struct Profile: Equatable {
        let name: String
        let detail: String
        /// nil for guests and signed-out users, who get the placeholder picture.
        let picture: ProfilePicture?
        let isLoggedIn: Bool
    }

    enum Notice: Equatable {
        case signedOut
        case signOutFailed
        case accountDeleted
        case deletionNeedsRecentLogin
        case dataErasureFailed
        case dataErasedNeedsRecentLogin
        case appleConfirmationFailed
        case appleRevocationFailed
        case deletionFailed
        case profileSaved
        case nicknameInvalid(Nickname.Problem)
    }

    private(set) var account: AccountState = .signedOut
    private(set) var isDeletingAccount = false
    private(set) var isSavingProfile = false
    /// The picture the member picked; nil until one is saved.
    private(set) var picture: ProfilePicture?
    var notice: Notice?

    @ObservationIgnored private let session: any AccountSession
    @ObservationIgnored private let photos: (any ProfilePhotoStoring)?
    @ObservationIgnored private var observation: Task<Void, Never>?

    init(session: any AccountSession, photos: (any ProfilePhotoStoring)? = nil) {
        self.session = session
        self.photos = photos
        // The account known right now, so the profile is not drawn signed out before the first observed value.
        let current = session.currentAccount
        account = AccountState(current)
        picture = ProfilePicture(storedURL: current?.photoURL)
    }

    var profile: Profile { Self.profile(for: account, picture: picture) }

    /// Account deletion is offered only to Google/Apple members, as before.
    var canManageAccount: Bool {
        if case .member = account { return true }
        return false
    }

    func start() {
        guard observation == nil else { return }
        let accounts = session.observeAccount()
        observation = Task { [weak self] in
            for await snapshot in accounts {
                self?.account = AccountState(snapshot)
                self?.picture = ProfilePicture(storedURL: snapshot?.photoURL)
                self?.forgetPhotoNoLongerShown()
            }
        }
    }

    /// After a sign-out, an account deletion or a change to an avatar the photo kept on the device is removed.
    private func forgetPhotoNoLongerShown() {
        if case .photo = picture { return }
        photos?.removeAll()
    }

    func stop() {
        observation?.cancel()
        observation = nil
    }

    func signOut() {
        do {
            try session.signOut()
            notice = .signedOut
        } catch {
            notice = .signOutFailed
        }
    }

    /// The sign-in method's picture, shown until the member picks one or while a photo loads.
    var defaultAvatar: ProfileAvatar {
        if case let .member(_, _, provider) = account { return .default(for: provider) }
        return .google
    }

    /// The current nickname to prefill the editor; nil when none is set.
    var nickname: String? {
        if case let .member(_, name, _) = account { return name }
        return nil
    }

    /// Returns whether the profile was saved; the editor stays open to retry when it was not,
    /// and the profile shown keeps its previous nickname and picture.
    @discardableResult
    func updateProfile(nickname text: String, picture selection: ProfilePictureSelection) async -> Bool {
        guard case let .member(email, _, provider) = account, !isSavingProfile else { return false }
        let name: String
        do {
            name = try Nickname.validated(text)
        } catch let problem as Nickname.Problem {
            notice = .nicknameInvalid(problem)
            return false
        } catch {
            return false
        }
        isSavingProfile = true
        defer { isSavingProfile = false }
        let requestedFor = account
        do {
            let saved = try await session.updateProfile(nickname: name, picture: selection)
            // If the account changed meanwhile (sign-out, another account), the result belongs to the previous one.
            guard account == requestedFor else { return true }
            // A profile change does not trigger the sign-in listener, so the shown account is updated here.
            account = .member(email: email, name: name, provider: provider)
            picture = saved
            // The photo just uploaded is kept on the device, so it is shown without downloading it back.
            if case .newPhoto(let jpeg) = selection, case .photo(let url) = saved {
                photos?.store(jpeg, for: url)
            }
            forgetPhotoNoLongerShown()
            notice = .profileSaved
            return true
        } catch {
            return false
        }
    }

    /// Apple members confirm with Sign in with Apple before deleting; the screen asks for it.
    var needsAppleConfirmationToDelete: Bool {
        if case .member(_, _, .apple) = account { return true }
        return false
    }

    func deleteAccount(appleAuthorization: AppleAuthorization? = nil) async {
        guard canManageAccount, !isDeletingAccount else { return }
        isDeletingAccount = true
        defer { isDeletingAccount = false }
        do {
            try await session.deleteAccount(appleAuthorization: appleAuthorization)
            notice = .accountDeleted
        } catch AccountDeletionError.requiresRecentLogin {
            notice = .deletionNeedsRecentLogin
        } catch AccountDeletionError.dataErasureFailed {
            notice = .dataErasureFailed
        } catch AccountDeletionError.dataErasedNeedsRecentLogin {
            notice = .dataErasedNeedsRecentLogin
        } catch AccountDeletionError.appleConfirmationRequired {
            notice = .appleConfirmationFailed
        } catch AccountDeletionError.appleRevocationFailed {
            notice = .appleRevocationFailed
        } catch {
            notice = .deletionFailed
        }
    }

    // Texts and images are the ones the previous settings screen showed for each state.
    static func profile(for account: AccountState, picture: ProfilePicture?) -> Profile {
        switch account {
        case .signedOut:
            return Profile(name: "로그인해주세요", detail: "일기를 저장하려면 로그인하세요", picture: nil, isLoggedIn: false)
        case .guest:
            return Profile(name: "손님", detail: "일기를 저장하려면 로그인하세요", picture: nil, isLoggedIn: false)
        case let .member(email, name, provider):
            // The sign-in method is written out, so the picture is the member's own choice.
            let method: String
            switch provider {
            case .google: method = "Google로 로그인"
            case .apple: method = "Apple로 로그인"
            case nil: method = "인증 완료"
            }
            return Profile(name: name ?? "닉네임을 설정해주세요", detail: shownEmail(email).map { method + "\n" + $0 } ?? method,
                           picture: picture ?? .avatar(.default(for: provider)), isLoggedIn: true)
        }
    }

    // Apple's "Hide My Email" relay address is not meaningful to show; without an e-mail only the sign-in method is shown.
    private static func shownEmail(_ email: String?) -> String? {
        guard let email else { return nil }
        return email.hasSuffix("@privaterelay.appleid.com") ? "이메일 가림" : email
    }
}
