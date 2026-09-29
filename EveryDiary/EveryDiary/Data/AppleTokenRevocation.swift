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
        URLSession.shared.dataTask(with: url) { [store] data, _, _ in
            guard let data, let token = String(data: data, encoding: .utf8) else { return }
            try? store.save(token)
        }.resume()
    }

    func revoke() {
        guard let token = store.token,
              let query = "refresh_token=\(token)".addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "\(baseURL)/revokeToken?\(query)") else { return }
        URLSession.shared.dataTask(with: url) { _, response, error in
            if let error {
                print("Apple token revoke failed: \((error as NSError).domain) \((error as NSError).code)")
            } else if let status = (response as? HTTPURLResponse)?.statusCode {
                print("Apple token revoke status: \(status)")
            }
        }.resume()
    }
}
