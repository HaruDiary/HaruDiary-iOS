import Foundation
import Observation

@MainActor
@Observable
final class SettingsViewModel {
    struct Profile: Equatable {
        let name: String
        let detail: String
        let imageName: String
        let isLoggedIn: Bool
    }

    enum Notice: Equatable {
        case signedOut
        case signOutFailed
        case accountDeleted
        case deletionNeedsRecentLogin
        case deletionFailed
    }

    private(set) var account: AccountState = .signedOut
    private(set) var isDeletingAccount = false
    var notice: Notice?

    @ObservationIgnored private let session: any AccountSession
    @ObservationIgnored private var observation: Task<Void, Never>?

    init(session: any AccountSession) {
        self.session = session
    }

    var profile: Profile { Self.profile(for: account) }

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

    func deleteAccount() async {
        guard canManageAccount, !isDeletingAccount else { return }
        isDeletingAccount = true
        defer { isDeletingAccount = false }
        do {
            try await session.deleteAccount()
            notice = .accountDeleted
        } catch AccountDeletionError.requiresRecentLogin {
            notice = .deletionNeedsRecentLogin
        } catch {
            notice = .deletionFailed
        }
    }

    // Texts and images are the ones the previous settings screen showed for each state.
    static func profile(for account: AccountState) -> Profile {
        switch account {
        case .signedOut:
            return Profile(name: "로그인해주세요", detail: "일기를 저장하려면 로그인하세요", imageName: "profile", isLoggedIn: false)
        case .guest:
            return Profile(name: "손님", detail: "일기를 저장하려면 로그인하세요", imageName: "profile", isLoggedIn: false)
        case let .member(email, name, provider):
            let imageName: String
            switch provider {
            case .google: imageName = "googleProfile"
            case .apple: imageName = "appleProfile"
            case nil: imageName = "profile"
            }
            return Profile(name: name ?? "사용자", detail: email ?? "인증 완료", imageName: imageName, isLoggedIn: true)
        }
    }
}
