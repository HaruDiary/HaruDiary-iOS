import Foundation

/// The signed-in Firebase user as the app uses it, without depending on FirebaseAuth.
struct AccountSnapshot: Equatable {
    var isEmailVerified: Bool
    var email: String?
    var displayName: String?
    var providerIDs: [String] = []
    /// Firebase Auth photo URL; holds the chosen `ProfileAvatar`.
    var photoURL: String?
}

enum SocialProvider: Equatable {
    case google
    case apple

    init?(providerID: String) {
        switch providerID {
        case "google.com": self = .google
        case "apple.com": self = .apple
        default: return nil
        }
    }
}

enum AccountState: Equatable {
    case signedOut
    /// Signed in without a Google/Apple account, e.g. the anonymous account created when saving while signed out.
    case guest
    case member(email: String?, name: String?, provider: SocialProvider?)

    // A linked Google/Apple sign-in makes a member. The previous screen looked only at a verified e-mail,
    // but a guest that links Apple can keep an unverified e-mail and was then still shown as a guest.
    // A verified e-mail without Google/Apple stays a member, as before.
    init(_ snapshot: AccountSnapshot?) {
        guard let snapshot else {
            self = .signedOut
            return
        }
        let provider = snapshot.providerIDs.lazy.compactMap(SocialProvider.init(providerID:)).first
        guard provider != nil || snapshot.isEmailVerified else {
            self = .guest
            return
        }
        self = .member(email: snapshot.email, name: snapshot.displayName, provider: provider)
    }
}
