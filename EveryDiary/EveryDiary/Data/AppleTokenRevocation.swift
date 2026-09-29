import Foundation

/// Keeps the Apple refresh token from sign-in and revokes it when the member withdraws.
/// Uses the project's existing Cloud Functions (getRefreshToken / revokeToken).
@MainActor
final class AppleTokenRevocation {
    private let store: AppleRefreshTokenStore
    private let baseURL = "https://us-central1-everydiary-a9c5e.cloudfunctions.net"

    init(store: AppleRefreshTokenStore) {
        self.store = store
        store.moveLegacyToken()
    }

    var appleUserID: String? { store.appleUserID }

    func rememberAppleUserID(_ id: String) {
        try? store.saveAppleUserID(id)
    }

    func storeRefreshToken(authorizationCode code: String) {
        guard let query = "code=\(code)".addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "\(baseURL)/getRefreshToken?\(query)") else { return }
        URLSession.shared.dataTask(with: url) { [store] data, response, error in
            // Only a successful answer is a token; an error page or empty body was previously stored as one.
            guard error == nil, let status = (response as? HTTPURLResponse)?.statusCode, status == 200,
                  let data, let token = AppleRefreshTokenStore.token(from: data) else {
                let status = (response as? HTTPURLResponse)?.statusCode ?? -1
                print("Apple refresh token not stored: status \(status)")
                return
            }
            try? store.save(token)
        }.resume()
    }

    /// The tokens are removed after the request whatever Apple answers: the account is already deleted,
    /// so nothing is kept that could be used later. The member can still stop Sign in with Apple in Settings.
    func revoke() {
        guard let token = store.token,
              let query = "refresh_token=\(token)".addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "\(baseURL)/revokeToken?\(query)") else {
            store.remove()
            return
        }
        URLSession.shared.dataTask(with: url) { [store] _, response, error in
            if let error {
                print("Apple token revoke failed: \((error as NSError).domain) \((error as NSError).code)")
            } else if let status = (response as? HTTPURLResponse)?.statusCode {
                print("Apple token revoke status: \(status)")
            }
            store.remove()
        }.resume()
    }
}
