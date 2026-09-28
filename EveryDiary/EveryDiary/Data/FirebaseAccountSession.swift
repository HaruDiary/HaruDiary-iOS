import FirebaseAuth
import Foundation

@MainActor
final class FirebaseAccountSession: AccountSession {
    private let auth: Auth
    private let dataEraser: any UserDataErasing

    init(auth: Auth, dataEraser: any UserDataErasing) {
        self.auth = auth
        self.dataEraser = dataEraser
    }

    func observeAccount() -> AsyncStream<AccountSnapshot?> {
        AsyncStream(bufferingPolicy: .bufferingNewest(1)) { continuation in
            let handle = auth.addStateDidChangeListener { _, user in
                continuation.yield(user.map(Self.snapshot))
            }
            // LoginVC still reports display-name updates with this notification; the state listener does not fire for them.
            // Remove once the sign-in flow reports through this session.
            let observer = NotificationCenter.default.addObserver(forName: .loginstatusChanged, object: nil, queue: .main) { [auth] _ in
                continuation.yield(auth.currentUser.map(Self.snapshot))
            }
            continuation.onTermination = { [auth] _ in
                auth.removeStateDidChangeListener(handle)
                NotificationCenter.default.removeObserver(observer)
            }
        }
    }

    func signOut() throws {
        try auth.signOut()
    }

    func updateNickname(_ name: String) async throws {
        guard let request = auth.currentUser?.createProfileChangeRequest() else { throw AccountDeletionError.notSignedIn }
        request.displayName = name
        try await request.commitChanges()
    }

    func deleteAccount() async throws {
        guard let user = auth.currentUser else { throw AccountDeletionError.notSignedIn }
        guard let provider = user.providerData.lazy.compactMap({ SocialProvider(providerID: $0.providerID) }).first else {
            throw AccountDeletionError.unsupportedAccount
        }
        let userID = user.uid
        // Both dates come from a freshly issued token, so the device clock does not matter.
        let token = try await user.getIDTokenResult(forcingRefresh: true)
        try await AccountDeletion.run(
            signedInFor: token.issuedAtDate.timeIntervalSince(token.authDate),
            eraseData: { try await dataEraser.eraseAllData(userID: userID) },
            deleteAccount: {
                do {
                    try await user.delete()
                } catch let error as NSError where error.domain == AuthErrorDomain && error.code == AuthErrorCode.requiresRecentLogin.rawValue {
                    throw AccountDeletionError.requiresRecentLogin
                }
            }
        )
        // The Apple token is revoked only after the account is gone, so a failed deletion keeps Sign in with Apple working.
        if provider == .apple {
            revokeAppleToken()
            try? auth.signOut()
        }
    }

    nonisolated private static func snapshot(_ user: User) -> AccountSnapshot {
        AccountSnapshot(isEmailVerified: user.isEmailVerified, email: user.shownEmail, displayName: user.shownName,
                        providerIDs: user.providerData.map(\.providerID))
    }

    // Same Cloud Function and stored refresh token as the previous settings screen. Responses are not logged.
    private func revokeAppleToken() {
        guard let token = UserDefaults.standard.string(forKey: "refreshToken"),
              let query = "refresh_token=\(token)".addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "https://us-central1-everydiary-a9c5e.cloudfunctions.net/revokeToken?\(query)") else { return }
        URLSession.shared.dataTask(with: url) { _, response, error in
            if let error {
                print("Apple token revoke failed: \(error.localizedDescription)")
            } else if let status = (response as? HTTPURLResponse)?.statusCode {
                print("Apple token revoke status: \(status)")
            }
        }.resume()
    }
}
