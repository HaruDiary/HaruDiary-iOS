import AuthenticationServices
import FirebaseAuth
import Foundation

/// Signs out an Apple member whose Sign in with Apple was stopped for this app, as Apple recommends.
@MainActor
final class AppleCredentialMonitor {
    private let auth: Auth
    private let appleRecords: AppleSignInRecords
    private var revokedObserver: NSObjectProtocol?

    init(auth: Auth, appleRecords: AppleSignInRecords) {
        self.auth = auth
        self.appleRecords = appleRecords
        // Sent while the app runs when the member stops Sign in with Apple for it.
        revokedObserver = NotificationCenter.default.addObserver(
            forName: ASAuthorizationAppleIDProvider.credentialRevokedNotification, object: nil, queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.check() }
        }
    }

    deinit {
        if let revokedObserver { NotificationCenter.default.removeObserver(revokedObserver) }
    }

    /// Called when the app becomes active; covers revocations made while it was not running.
    func check() {
        #if targetEnvironment(simulator)
        // Simulator builds are signed without a development team, and Apple then reports every credential
        // as revoked. Checking there would sign members out on every launch.
        return
        #else
        // The ID Apple returned at sign-in; for members signed in before it was kept, the same value from
        // the linked Apple sign-in (checked to be identical on a device).
        guard let user = auth.currentUser,
              let linkedAppleID = user.providerData.first(where: { $0.providerID == "apple.com" })?.uid else { return }
        let appleUserID = appleRecords.appleUserID ?? linkedAppleID
        let firebaseUserID = user.uid
        ASAuthorizationAppleIDProvider().getCredentialState(forUserID: appleUserID) { state, _ in
            let status: AppleCredentialStatus
            switch state {
            case .authorized: status = .authorized
            case .revoked: status = .revoked
            case .transferred: status = .transferred
            default: status = .notFound
            }
            guard status.endsSession else { return }
            Task { @MainActor [weak self] in self?.signOut(ifStill: firebaseUserID) }
        }
        #endif
    }

    private func signOut(ifStill userID: String) {
        // A different account may have signed in while Apple answered.
        guard auth.currentUser?.uid == userID else { return }
        try? auth.signOut()
        NotificationCenter.default.post(name: .loginstatusChanged, object: nil)
        print("Signed out: Sign in with Apple was stopped for this app")
    }
}
