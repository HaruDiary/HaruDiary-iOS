import Foundation

/// What Sign in with Apple returned, without depending on AuthenticationServices or FirebaseAuth.
struct AppleAuthorization {
    let identityToken: String
    /// The nonce whose SHA-256 was sent to Apple; Firebase checks it against the token.
    let rawNonce: String
    /// Single use and valid for five minutes; Firebase uses it to revoke the Apple token at withdrawal.
    let authorizationCode: String?
    /// The user identifier Apple returned (`credential.user`).
    let appleUserID: String
    let fullName: PersonNameComponents?

    var displayName: String {
        [fullName?.givenName, fullName?.familyName].compactMap { $0 }.joined(separator: " ")
    }
}
