import Foundation

/// The signed-in Firebase user as the app uses it, without depending on FirebaseAuth.
struct AccountSnapshot: Equatable {
    var isEmailVerified: Bool
    var email: String?
    var displayName: String?
    var providerIDs: [String] = []
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
    /// Signed in without a verified social account, e.g. the anonymous account created when saving while signed out.
    case guest
    case member(email: String?, name: String?, provider: SocialProvider?)

    // Same rule as the previous settings screen: a verified e-mail means a linked Google/Apple account.
    init(_ snapshot: AccountSnapshot?) {
        guard let snapshot else {
            self = .signedOut
            return
        }
        guard snapshot.isEmailVerified else {
            self = .guest
            return
        }
        let provider = snapshot.providerIDs.lazy.compactMap(SocialProvider.init(providerID:)).first
        self = .member(email: snapshot.email, name: snapshot.displayName, provider: provider)
    }
}
