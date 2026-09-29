import Foundation

/// Keeps the Apple user identifier from sign-in (in the Keychain) and clears it at withdrawal.
@MainActor
final class AppleSignInRecords {
    private let secrets: AppleSignInSecrets

    init(secrets: AppleSignInSecrets) {
        self.secrets = secrets
        // Earlier versions kept an Apple refresh token for their own revoke function; it is no longer used.
        secrets.removeStoredRefreshTokens()
    }

    var appleUserID: String? { secrets.appleUserID }

    func remember(appleUserID: String) {
        try? secrets.saveAppleUserID(appleUserID)
    }

    func forget() {
        secrets.removeAll()
    }
}
