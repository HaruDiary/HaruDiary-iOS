import Foundation

/// Removes the profile photo kept on the device as soon as the account no longer shows it, wherever that
/// happens: a sign-out from settings, an account deletion, or a sign-out the app does by itself
/// (a revoked Apple credential) while settings are closed.
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
                if case .photo = ProfilePicture(storedURL: snapshot?.photoURL) { continue }
                self?.photos.removeAll()
            }
        }
    }

    func stop() {
        observation?.cancel()
        observation = nil
    }
}
