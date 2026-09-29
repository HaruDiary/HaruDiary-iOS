import Foundation

/// A Google/Apple credential (Firebase `AuthCredential` in the app) passed through without depending on FirebaseAuth.
struct SocialCredential {
    let provider: SocialProvider
    let raw: AnyObject
}

enum GuestLinkResult {
    case linked
    /// The Google/Apple account already has its own account; `existing` signs in to it.
    case alreadyInUse(existing: SocialCredential)
}

@MainActor
protocol SocialSignInGateway {
    /// nil when signed out.
    var isGuest: Bool? { get }
    /// The profile name of the signed-in account, falling back to the linked Google/Apple name.
    var currentName: String? { get }
    /// Keeps the guest account (and its diaries) and adds the Google/Apple sign-in to it.
    func linkGuest(with credential: SocialCredential) async throws -> GuestLinkResult
    func signIn(with credential: SocialCredential) async throws
    /// Signs in to the existing account, then removes the guest account left behind.
    func switchFromGuest(to credential: SocialCredential) async throws
    func updateDisplayName(_ name: String) async throws
    /// Builds the sign-in credential from Apple's answer.
    func appleCredential(for authorization: AppleAuthorization) -> SocialCredential
    /// Keeps the Apple user identifier used to ask Apple whether Sign in with Apple is still allowed.
    func rememberAppleUserID(_ id: String)
}

/// Which sign-in happens for the current account. Previously any failure while linking a guest deleted the guest
/// account, and some Apple failures were reported as success; now only an account already in use switches accounts.
enum SocialSignIn {
    enum Outcome: Equatable {
        case signedIn
        case linkedGuest
        case switchedFromGuest

        /// A guest that just became a member always picks a nickname; others only when they have none.
        func asksForNickname(currentName: String?) -> Bool {
            self == .linkedGuest || currentName == nil
        }
    }

    @MainActor
    static func run(with credential: SocialCredential, displayName: String?,
                    gateway: any SocialSignInGateway) async throws -> Outcome {
        guard gateway.isGuest == true else {
            try await gateway.signIn(with: credential)
            return .signedIn
        }
        switch try await gateway.linkGuest(with: credential) {
        case .linked:
            // Same as before: the Google/Apple name becomes the profile name of the linked guest.
            if let name = displayName?.trimmingCharacters(in: .whitespaces), !name.isEmpty {
                try? await gateway.updateDisplayName(name)
            }
            return .linkedGuest
        case .alreadyInUse(let existing):
            try await gateway.switchFromGuest(to: existing)
            return .switchedFromGuest
        }
    }
}
