import Foundation

/// Sign-out and account deletion for the signed-in user.
@MainActor
protocol AccountSession {
    /// Emits the current account first, then again after sign-in, sign-out or a profile change.
    func observeAccount() -> AsyncStream<AccountSnapshot?>
    func signOut() throws
    /// Deletes the signed-in Google/Apple account; Apple also revokes its token.
    /// Diaries and photos stored for the account are not deleted here.
    func deleteAccount() async throws
}

enum AccountDeletionError: Error, Equatable {
    case notSignedIn
    /// Only Google and Apple accounts can be deleted from settings.
    case unsupportedAccount
    /// Firebase requires a recent sign-in before an account can be deleted.
    case requiresRecentLogin
}
