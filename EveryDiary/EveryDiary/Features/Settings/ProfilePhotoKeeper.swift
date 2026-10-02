import Foundation

/// Removes the profile photo kept on the device as soon as the account no longer shows it, wherever that
/// happens: a sign-out from settings, an account deletion, a sign-out the app does by itself
/// (a revoked Apple credential) while settings are closed, or another account signing in.
@MainActor
final class ProfilePhotoKeeper {
    private let session: any AccountSession
    private let photos: any ProfilePhotoStoring
    private var observation: Task<Void, Never>?

    init(session: any AccountSession, photos: any ProfilePhotoStoring) {
        self.session = session
        self.photos = photos
    }

    deinit {
        observation?.cancel()
    }

    func start() {
        guard observation == nil else { return }
        let accounts = session.observeAccount()
        observation = Task { [weak self] in
            for await snapshot in accounts {
                guard !Task.isCancelled else { return }
                if case .photo(let url) = ProfilePicture(storedURL: snapshot?.photoURL) {
                    // Another account with its own photo: the previous account's photo goes, this one's stays.
                    self?.photos.keepOnly(url)
                } else {
                    self?.photos.removeAll()
                }
            }
        }
    }

    func stop() {
        observation?.cancel()
        observation = nil
    }
}
