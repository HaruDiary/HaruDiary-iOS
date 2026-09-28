import Foundation
import Observation

@MainActor
@Observable
final class SettingsViewModel {
    struct Profile: Equatable {
        let name: String
        let detail: String
        /// nil for guests and signed-out users, who get the placeholder picture.
        let avatar: ProfileAvatar?
        let isLoggedIn: Bool
    }

    enum Notice: Equatable {
        case signedOut
        case signOutFailed
        case accountDeleted
        case deletionNeedsRecentLogin
        case dataErasureFailed
        case dataErasedNeedsRecentLogin
        case deletionFailed
        case profileSaved
        case nicknameInvalid(Nickname.Problem)
        case profileFailed
    }

    private(set) var account: AccountState = .signedOut
    private(set) var isDeletingAccount = false
    private(set) var isSavingProfile = false
    /// The picture the member picked; nil until one is saved.
    private(set) var avatar: ProfileAvatar?
    var notice: Notice?

    @ObservationIgnored private let session: any AccountSession
    @ObservationIgnored private var observation: Task<Void, Never>?

    init(session: any AccountSession) {
        self.session = session
    }

    var profile: Profile { Self.profile(for: account, avatar: avatar) }

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
                self?.avatar = ProfileAvatar(storedURL: snapshot?.photoURL)
            }
        }
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

    /// The current nickname to prefill the editor; nil when none is set.
    var nickname: String? {
        if case let .member(_, name, _) = account { return name }
        return nil
    }

    func updateProfile(nickname text: String, avatar: ProfileAvatar) async {
        guard case let .member(email, _, provider) = account, !isSavingProfile else { return }
        let name: String
        do {
            name = try Nickname.validated(text)
        } catch let problem as Nickname.Problem {
            notice = .nicknameInvalid(problem)
            return
        } catch {
            return
        }
        isSavingProfile = true
        defer { isSavingProfile = false }
        do {
            try await session.updateProfile(nickname: name, avatar: avatar)
            // A profile change does not trigger the sign-in listener, so the shown account is updated here.
            account = .member(email: email, name: name, provider: provider)
            self.avatar = avatar
            notice = .profileSaved
        } catch {
            notice = .profileFailed
        }
    }

    func deleteAccount() async {
        guard canManageAccount, !isDeletingAccount else { return }
        isDeletingAccount = true
        defer { isDeletingAccount = false }
        do {
            try await session.deleteAccount()
            notice = .accountDeleted
        } catch AccountDeletionError.requiresRecentLogin {
            notice = .deletionNeedsRecentLogin
        } catch AccountDeletionError.dataErasureFailed {
            notice = .dataErasureFailed
        } catch AccountDeletionError.dataErasedNeedsRecentLogin {
            notice = .dataErasedNeedsRecentLogin
        } catch {
            notice = .deletionFailed
        }
    }

    // Texts and images are the ones the previous settings screen showed for each state.
    static func profile(for account: AccountState, avatar: ProfileAvatar?) -> Profile {
        switch account {
        case .signedOut:
            return Profile(name: "로그인해주세요", detail: "일기를 저장하려면 로그인하세요", avatar: nil, isLoggedIn: false)
        case .guest:
            return Profile(name: "손님", detail: "일기를 저장하려면 로그인하세요", avatar: nil, isLoggedIn: false)
        case let .member(email, name, provider):
            // The sign-in method is written out, so the picture is the member's own choice.
            let method: String
            switch provider {
            case .google: method = "Google로 로그인"
            case .apple: method = "Apple로 로그인"
            case nil: method = "인증 완료"
            }
            return Profile(name: name ?? "닉네임을 설정해주세요", detail: method + "\n" + shownEmail(email),
                           avatar: avatar ?? .default, isLoggedIn: true)
        }
    }

    // Apple's "Hide My Email" relay address is not meaningful to show.
    private static func shownEmail(_ email: String?) -> String {
        guard let email else { return "이메일 정보 없음" }
        return email.hasSuffix("@privaterelay.appleid.com") ? "이메일 가림" : email
    }
}
