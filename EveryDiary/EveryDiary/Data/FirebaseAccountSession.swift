import FirebaseAuth
import FirebaseStorage
import Foundation

@MainActor
final class FirebaseAccountSession: AccountSession {
    private let auth: Auth
    private let dataEraser: any UserDataErasing
    private let storage: Storage
    private let appleRecords: AppleSignInRecords

    init(auth: Auth, dataEraser: any UserDataErasing, storage: Storage, appleRecords: AppleSignInRecords) {
        self.auth = auth
        self.dataEraser = dataEraser
        self.storage = storage
        self.appleRecords = appleRecords
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

    func deleteAccount(appleAuthorization: AppleAuthorization?) async throws {
        guard let user = auth.currentUser else { throw AccountDeletionError.notSignedIn }
        guard let provider = user.providerData.lazy.compactMap({ SocialProvider(providerID: $0.providerID) }).first else {
            throw AccountDeletionError.unsupportedAccount
        }
        let userID = user.uid
        let signedInFor: TimeInterval
        if provider == .apple {
            // Apple members confirm with Sign in with Apple right before deleting. The fresh sign-in satisfies
            // Firebase's recent-login rule, and its single-use code lets Firebase revoke the Apple token.
            guard let apple = appleAuthorization, let code = apple.authorizationCode else {
                throw AccountDeletionError.appleConfirmationRequired
            }
            do {
                _ = try await user.reauthenticate(with: FirebaseSocialSignInGateway.firebaseCredential(for: apple))
            } catch {
                throw AccountDeletionError.appleConfirmationRequired
            }
            // Revoked before anything is erased: if Apple cannot be reached, the account and diaries stay as they were.
            do {
                try await auth.revokeToken(withAuthorizationCode: code)
            } catch {
                let error = error as NSError
                print("Apple token revoke failed: \(error.domain) \(error.code)")
                throw AccountDeletionError.appleRevocationFailed
            }
            signedInFor = 0
        } else {
            // Both dates come from a freshly issued token, so the device clock does not matter.
            let token = try await user.getIDTokenResult(forcingRefresh: true)
            signedInFor = token.issuedAtDate.timeIntervalSince(token.authDate)
        }
        try await AccountDeletion.run(
            signedInFor: signedInFor,
            eraseData: { try await dataEraser.eraseAllData(userID: userID) },
            deleteAccount: {
                do {
                    try await user.delete()
                } catch let error as NSError where error.domain == AuthErrorDomain && error.code == AuthErrorCode.requiresRecentLogin.rawValue {
                    throw AccountDeletionError.requiresRecentLogin
                }
            }
        )
        if provider == .apple {
            appleRecords.forget()
            try? auth.signOut()
        }
    }

    nonisolated private static func snapshot(_ user: User) -> AccountSnapshot {
        AccountSnapshot(isEmailVerified: user.isEmailVerified, email: user.shownEmail, displayName: user.shownName,
                        providerIDs: user.providerData.map(\.providerID), photoURL: user.photoURL?.absoluteString)
    }
}
