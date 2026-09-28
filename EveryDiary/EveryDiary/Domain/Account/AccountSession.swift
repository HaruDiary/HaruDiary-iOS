import Foundation

/// Sign-out and account deletion for the signed-in user.
@MainActor
protocol AccountSession {
    /// Emits the current account first, then again after sign-in, sign-out or a profile change.
    func observeAccount() -> AsyncStream<AccountSnapshot?>
    func signOut() throws
    /// Erases the user's diaries and photos, then deletes the signed-in Google/Apple account.
    /// Apple also revokes its token.
    func deleteAccount() async throws
}

enum AccountDeletionError: Error, Equatable {
    case notSignedIn
    /// Only Google and Apple accounts can be deleted from settings.
    case unsupportedAccount
    /// Firebase requires a recent sign-in before an account can be deleted.
    case requiresRecentLogin
    /// Some diaries or photos could not be erased, so the account was kept and deletion can be retried.
    case dataErasureFailed
}
