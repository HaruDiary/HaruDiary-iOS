import FirebaseAuth
import Foundation

@MainActor
final class FirebaseSocialSignInGateway: SocialSignInGateway {
    private let auth: Auth
    private let appleTokens: AppleTokenRevocation

    init(auth: Auth, appleTokens: AppleTokenRevocation) {
        self.auth = auth
        self.appleTokens = appleTokens
    }

    func rememberAppleAuthorization(code: String?, appleUserID: String) {
        appleTokens.rememberAppleUserID(appleUserID)
        if let code { appleTokens.storeRefreshToken(authorizationCode: code) }
    }

    var isGuest: Bool? { auth.currentUser.map(\.isAnonymous) }
    var currentName: String? { auth.currentUser?.shownName }

    func linkGuest(with credential: SocialCredential) async throws -> GuestLinkResult {
        guard let user = auth.currentUser else { throw SocialSignInError.notSignedIn }
        do {
            _ = try await user.link(with: try Self.authCredential(credential))
            return .linked
        } catch let error as NSError where error.domain == AuthErrorDomain && error.code == AuthErrorCode.credentialAlreadyInUse.rawValue {
            // Apple credentials are single use; Firebase returns a fresh one to sign in with.
            let updated = error.userInfo[AuthErrorUserInfoUpdatedCredentialKey] as? AuthCredential
            return .alreadyInUse(existing: SocialCredential(provider: credential.provider, raw: try updated ?? Self.authCredential(credential)))
        }
    }

    func signIn(with credential: SocialCredential) async throws {
        _ = try await auth.signIn(with: try Self.authCredential(credential))
    }

    func switchFromGuest(to credential: SocialCredential) async throws {
        let guest = auth.currentUser
        _ = try await auth.signIn(with: try Self.authCredential(credential))
        // Only after the sign-in succeeded. The guest can no longer be reached, as before; its diaries are
        // removed with other withdrawn accounts by scripts/admin/withdrawn-account-data.mjs.
        if let guest, guest.isAnonymous {
            try? await guest.delete()
        }
    }

    func updateDisplayName(_ name: String) async throws {
        guard let request = auth.currentUser?.createProfileChangeRequest() else { return }
        request.displayName = name
        try await request.commitChanges()
    }

    // LoginVC wraps the Firebase credentials it builds from the Google/Apple results.
    private static func authCredential(_ credential: SocialCredential) throws -> AuthCredential {
        guard let credential = credential.raw as? AuthCredential else { throw SocialSignInError.invalidCredential }
        return credential
    }
}

enum SocialSignInError: Error {
    case notSignedIn
    case invalidCredential
}
