import FirebaseAuth
import FirebaseStorage
import Foundation

@MainActor
final class FirebaseAccountSession: AccountSession {
    private let auth: Auth
    private let dataEraser: any UserDataErasing
    private let storage: Storage

    init(auth: Auth, dataEraser: any UserDataErasing, storage: Storage) {
        self.auth = auth
        self.dataEraser = dataEraser
        self.storage = storage
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

    func updateProfile(nickname: String, picture: ProfilePictureSelection) async throws -> ProfilePicture {
        guard let user = auth.currentUser else { throw AccountDeletionError.notSignedIn }
        let userID = user.uid
        let previousPhoto = user.photoURL.flatMap { ProfilePicture.isUploadedPhoto($0) ? $0 : nil }

        // 1. A new photo gets its own file next to the diary photos, so account deletion removes it too.
        var uploaded: StorageReference?
        let saved: ProfilePicture
        switch picture {
        case .avatar(let avatar):
            saved = .avatar(avatar)
        case .currentPhoto(let url):
            saved = .photo(url)
        case .newPhoto(let data):
            let reference = storage.reference().child("\(userID)/\(ProfilePicture.photoFilePrefix)\(UUID().uuidString).jpg")
            let metadata = StorageMetadata()
            metadata.contentType = "image/jpeg"
            _ = try await reference.putDataAsync(data, metadata: metadata)
            uploaded = reference
            saved = .photo(try await reference.downloadURL())
        }

        // 2. The profile changes only for the account that asked; a sign-out or switch meanwhile cancels it.
        do {
            guard auth.currentUser?.uid == userID else { throw AccountDeletionError.notSignedIn }
            let request = user.createProfileChangeRequest()
            request.displayName = nickname
            switch saved {
            case .avatar(let avatar): request.photoURL = URL(string: avatar.storedURL)
            case .photo(let url): request.photoURL = url
            }
            try await request.commitChanges()
        } catch {
            try? await uploaded?.delete()
            throw error
        }

        // 3. The replaced upload is no longer shown anywhere. A failure only leaves a file that account deletion removes.
        if let previousPhoto, saved != .photo(previousPhoto) {
            _ = await FirebasePhotoFiles.delete(urlString: previousPhoto.absoluteString)
        }
        return saved
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
                        providerIDs: user.providerData.map(\.providerID), photoURL: user.photoURL?.absoluteString)
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
